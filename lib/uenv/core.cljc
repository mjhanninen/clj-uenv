(ns uenv.core
  (:refer-clojure :exclude [get load])
  (:require [uenv.impl :as impl]))

(defn load
  [sources]
  {:pre [(or (seq? sources)
             (list? sources)
             (vector? sources))]}
  (impl/load-env sources))

(let [g (memoize impl/get-env)]
  (defn get
    ([env k]
     (g env k nil))
    ([env k default]
     {:pre [(map? env) (string? k)]}
     (g env k default))))
