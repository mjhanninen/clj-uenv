(ns uenv.impl.jvm
  (:refer-clojure :exclude [slurp])
  (:require [clojure.java.io :as io]))

(defn slurp
  [path]
  (-> path io/as-file clojure.core/slurp))

(defn source-env-file
  [->env-file-event path]
  (let [f (io/as-file path)]
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
