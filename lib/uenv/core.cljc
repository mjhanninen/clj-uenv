(ns uenv.core
  (:refer-clojure :exclude [get load])
  (:require [uenv.impl :as impl]))

(defn load
  ([]
   (impl/load-env nil))
  ([paths]
   {:pre [(or (nil? paths)
              (seq? paths)
              (list? paths)
              (vector? paths))]}
   (impl/load-env paths)))

(let [g (memoize impl/get-env)]
  (defn get
    ([env k]
     (g env k nil))
    ([env k default]
     {:pre [(map? env) (string? k)]}
     (g env k default))))
