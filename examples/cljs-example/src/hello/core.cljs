(ns hello.core
  (:require [cljs.nodejs :as nodejs]
            [cljs.pprint :refer [pprint]]
            [cljs.core.async
             :refer [<! chan put! timeout]
             :refer-macros [go go-loop]]
            [macchiato.server :as s]
            [macchiato.util.response :as response]
            [hiccups.runtime]
            [pg]
            [uenv.core :as e])
  (:require-macros [hiccups.core :as h]))

(nodejs/enable-util-print!)

(defn try-connect-db-once
  [cfg]
  (let [ch (chan)
        db (pg/Client. (clj->js cfg))]
    (.connect db
              (fn [err]
                (put! ch (if-not err
                           {:ok db}
                           {:err (.-code err)}))))
    ch))

(defn try-connect-db
  [cfg]
  (go-loop [attempts 9
            cooldown 100]
    (let [{:keys [ok err]} (<! (try-connect-db-once cfg))]
      (cond
        ok (do
             (println "Connected to database")
             {:ok ok})
        (pos? attempts) (do
                          (println "Failed to connect to database; retrying in"
                                   cooldown "milliseconds")
                          (<! (timeout cooldown))
                          (recur (dec attempts)
                                 (long (* 1.4142 cooldown))))
        :else (do
                (println "Failed to connect to database; giving up")
                {:err err})))))

(defn db-config
  [env]
  {:host (e/get env "DB_HOST")
   :port (long (e/get env "DB_PORT" "5432"))
   :database (e/get env "DB_DATABASE")
   :user (e/get env "DB_USER")
   :password (e/get env "DB_PASSWORD")})

(defn query-db-time
  [{:keys [db]} f raise]
  (.query db
          "SELECT now()"
          (fn [err res]
            (if-not err
              (-> (.-rows res)
                (js->clj :keywordize-keys true)
                first
                :now
                f)
              (raise err)))))

(defn hello-handler
  [ctx req res raise]
  (query-db-time ctx
                 (fn [ts]
                   (-> [:html
                        [:body
                         [:h1 (str ts)]]]
                     h/html
                     response/ok
                     (response/content-type "text/html")
                     res))
                 (fn [err]
                   (raise err))))

(defn start-server
  [env ctx]
  (let [host (e/get env "HOST")
        port (long (e/get env "PORT"))
        handler-fn (partial hello-handler ctx)]
    (s/start {:handler handler-fn
              :host host
              :port port
              :protocol :https
              :certificate (e/get env "CERTIFICATE_FILE")
              :private-key (e/get env "CERTIFICATE_KEY_FILE")
              :on-success #(println (str "server started on https://"
                                         host ":" port "/"))})))

(defn main
  []
  (let [env (e/load [".env"])]
    (go
      (let [{db :ok} (<! (try-connect-db (db-config env)))]
        (when db
          (start-server env {:db db}))))))

(set! *main-cli-fn* main)
