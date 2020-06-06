(ns minienv.core
  (:refer-clojure :exclude [get load])
  (:require [minienv.impl :as impl]))

(defn load
  ([]
   (impl/load-env nil))
  ([paths]
   (impl/load-env paths)))

(let [g (memoize impl/get-env)]
  (defn get
    ([env k]
     (g env k nil))
    ([env k default]
     (g env k default))))
