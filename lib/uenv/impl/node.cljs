(ns uenv.impl.node
  (:require [clojure.string :as str]
            [fs]
            [process]))

(defn resolve-file
  [path]
  (-> (if (fs/existsSync path)
        (let [s (fs/statSync path)]
          {:status (if (.isFile s)
                     :found
                     :not-file)
           :id (.-ino s)})
        {:status :not-found})
    (assoc :path path)))

(defn slurp
  [path]
  (-> path (fs/readFileSync {:encoding "utf8"}) .toString))

(defn source-env-file
  [path ->env-file-event]
  (when (fs/existsSync path)
    (mapv #(->env-file-event path (inc %2) %1)
          (-> path slurp str/split-lines)
          (range))))

(defn source-system-env
  [->sys-env-event]
  (into []
        (map #(->sys-env-event % (aget process/env %)))
        (js-keys process/env)))
