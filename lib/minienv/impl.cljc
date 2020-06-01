(ns minienv.impl
  (:require [clojure.java.io :as io]
            [clojure.set :as set]))

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

(defn source-env-file
  [path]
  (let [f (io/as-file path)
        p (.getAbsolutePath f)]
    (with-open [r (io/reader f)]
      (mapv (fn [s i]
              (assoc (parse-env-line s)
                     :src {:type :file
                           :path p
                           :line (inc i)}))
            (line-seq r)
            (range)))))

(defn source-system-env
  []
  (map (fn [[k v]]
         {:type :keyval
          :key k
          :value v
          :src {:type :system}})
       (System/getenv)))

(defn source-env
  [paths]
  (concat (mapcat source-env-file paths)
          (source-system-env)))

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
    (when-let [errors (filter #(= (:type %) :error) events)]
      (throw (ex-info "errors while sourcing environment variables"
                      {:type :minienv/error
                       :errors (vec errors)})))
    (make-env events)))

(defn get-env
  [env k default]
  (or (when-let [v (-> env :env (get k))]
        (case (:type v)
          :string (:value v)
          :file (-> v :path io/as-file slurp)))
      default))
