(ns uenv.core
  (:refer-clojure :exclude [get load])
  (:require [uenv.impl :as impl]))

(def default-options
  {:required? true})

(defn load
  ([sources]
   (load sources {}))
  ([sources options]
   {:pre [(or (seq? sources)
              (list? sources)
              (vector? sources))
          (map? options)]}
   (impl/load-env (map impl/normalize-source sources)
                  (merge options default-options))))

(let [g (memoize impl/get-env)]
  (defn get
    ([env k]
     (g env k nil))
    ([env k default]
     {:pre [(map? env) (string? k)]}
     (g env k default))))
