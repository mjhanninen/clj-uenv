(ns uenv.impl
  (:require [clojure.set :as set]
            [#?(:clj uenv.impl.jvm
                :cljs uenv.impl.node) :as platform]))

(defn parse-env-line
  [line]
  (or (cond
        (nil? line) {:type :err}
        (re-matches #"\h*" line) {:type :blank}
        (re-matches #"\h*#.*" line) {:type :comment})
      (when-let [[_ k v] (re-matches #"(\w+)=(.*)" line)]
        {:type :keyval
         :key k
         :value v})
      {:type :err}))

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

(defn source-env
  [paths]
  (concat (mapcat #(platform/source-env-file ->env-file-event %) paths)
          (platform/source-system-env ->sys-env-event)))

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
  [paths]
  (let [events (source-env paths)]
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
