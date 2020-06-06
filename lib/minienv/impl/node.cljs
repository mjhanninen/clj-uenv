(ns minienv.impl.node
  (:require [clojure.string :as str]
            [fs]
            [process]))

(defn slurp
  [path]
  (-> path (fs/readFileSync {:encoding "utf8"}) .toString))

(defn source-env-file
  [->env-file-event path]
  (mapv #(->env-file-event path (inc %2) %1)
        (-> path slurp str/split-lines)
        (range)))

(defn source-system-env
  [->sys-env-event]
  (into []
        (map #(->sys-env-event % (aget process/env %)))
        (js-keys process/env)))
