(ns uenv.impl.bb
  (:require [clojure.java.io :as io]))

(defn resolve-file
  [path]
  (let [f (-> path io/file .getCanonicalFile)]
    (-> (if (.exists f)
          {:status (if (.isFile f)
                     :found
                     :not-file)
           :id (.getPath f)}
          {:status :not-found})
      (assoc :path path))))

(defn slurp
  [path]
  (slurp path))

(defn source-env-file
  [path ->env-file-event]
  (let [f (io/file path)]
    (when (.exists f)
      (let [p (.getAbsolutePath f)]
        (with-open [r (io/reader f)]
          (mapv #(->env-file-event p (inc %2) %1)
                (line-seq r)
                (range)))))))

(defn source-system-env
  [->sys-env-event]
  (into []
        (map #(->sys-env-event (key %) (val %)))
        (System/getenv)))
