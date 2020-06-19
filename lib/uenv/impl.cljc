(ns uenv.impl
  (:require [clojure.set :as set]
            [#?(:clj uenv.impl.jvm
                :cljs uenv.impl.node) :as platform]))

(defn resolve-one-source
  [source]
  (cond
    (= source :sys) (recur {:src :sys})
    (string? source) (recur {:src source})
    :else (let [src (:src source)
                kind (cond
                       (= src :sys) :sys
                       (string? src) :file
                       :else (throw (ex-info "invalid source description"
                                             {:type :uenv/error
                                              :errors [{:code :bad-source
                                                        :data source}]})))]
            (cond-> {:type kind
                     :required? (-> source
                                  (clojure.core/get :required? true)
                                  boolean)}
              (= kind :file) (assoc :file (platform/resolve-file src))))))

(defn source->id
  [source]
  (case (:type source)
    :sys :sys
    :file (or (-> source :file :id)
              (-> source :file :path))))

(defn merge-sources
  [old new]
  (cond-> new
    old (assoc :required? (or (:required? old)
                              (:required? new)))))

(defn resolve-all-sources
  [sources]
  (let [resolved (map #(-> %1 resolve-one-source (assoc :ix %2))
                      sources
                      (range))
        table (reduce #(update %1 (source->id %2) merge-sources %2)
                      {}
                      resolved)]
    (->> (vals table)
      (sort-by :ix)
      (mapv #(dissoc % :ix)))))

(defn required-but-missing?
  [source]
  (and (:required? source)
       (-> source :file :status (= :not-found))))

(defn check-missing-files
  [sources]
  (when-let [missing (->> sources
                       (filter required-but-missing?)
                       (mapv (comp :path :file))
                       not-empty)]
    (throw (ex-info "required environment files not found"
                    {:type :uenv/error
                     :reason :file-not-found
                     :files missing})))
  sources)

(defn parse-env-line
  [line]
  (or (cond
        (nil? line) {:type :error}
        (re-matches #"\h*" line) {:type :blank}
        (re-matches #"\h*#.*" line) {:type :comment})
      (when-let [[_ k v] (re-matches #"(\w+)=(.*)" line)]
        {:type :keyval
         :key k
         :value v})
      {:type :error}))

(defn ->env-file-event
  [path line-num line]
  (assoc (parse-env-line line)
         :src {:type :file
               :path path
               :line line-num}))

(defn ->sys-env-event
  [k v]
  {:type :keyval
   :key k
   :value v
   :src {:type :system}})

(defn source-any
  [source]
  (case (:type source)
    :sys (platform/source-system-env ->sys-env-event)
    :file (-> source :file :path (platform/source-env-file ->env-file-event))))

(defn source-all-sources
  [sources]
  (mapcat source-any sources))

(defn key-of-file-ptr
  [key]
  (some->> key (re-matches #"(\w+)_FILE") second))

(defn insert-value
  [m k v]
  (update m k (fn [old]
                (cond-> v
                  (some? old) (assoc :occludes old)))))

(defn insert-keyval
  [env {:keys [key] :as keyval}]
  (let [orig-key (key-of-file-ptr key)]
    (cond-> (insert-value env key (-> keyval
                                    (dissoc :key)
                                    (assoc :type :string)))
      orig-key (insert-value orig-key (-> keyval
                                        (set/rename-keys {:key :orig-key
                                                          :value :path})
                                        (assoc :type :file))))))

(defn make-env
  [events]
  (->> events
    (filter #(= (:type %) :keyval))
    (reduce insert-keyval {})))

(defn load-env
  [sources]
  (let [events (-> sources
                 resolve-all-sources
                 check-missing-files
                 source-all-sources)]
    (when-let [errors (->> events
                        (filter #(= (:type %) :error))
                        not-empty)]
      (throw (ex-info "errors while sourcing environment variables"
                      {:type :uenv/error
                       :errors (vec errors)})))
    (make-env events)))

(defn get-env
  [env k default]
  (or (when-let [v (get env k)]
        (case (:type v)
          :string (:value v)
          :file (-> v :path platform/slurp)))
      default))
