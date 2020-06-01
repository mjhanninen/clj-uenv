(ns unit.minienv.impl-test
  (:require [clojure.test :refer [are deftest is testing]]
            [minienv.impl :refer :all]))

(deftest test-parse-env-line
  (testing "is not nil tolerant"
    (are [line expect] (= expect (parse-env-line line))
      nil {:type :err}))
  (testing "recognizes blank lines"
    (are [line expect] (= expect (parse-env-line line))
      "" {:type :blank}
      " \t " {:type :blank}))
  (testing "recognizes comments"
    (are [line expect] (= expect (parse-env-line line))
      "#" {:type :comment}
      "# foo=bar" {:type :comment}
      "\t# foo=bar  " {:type :comment}))
  (testing "parses legal key-value pairs"
    (are [line expect] (= expect (parse-env-line line))
      "foo=bar" {:type :keyval
                 :key "foo"
                 :value "bar"}
      "foo=bar=baz" {:type :keyval
                     :key "foo"
                     :value "bar=baz"}
      "foo==bar" {:type :keyval
                  :key "foo"
                  :value "=bar"}
      "foo=" {:type :keyval
              :key "foo"
              :value ""}))
  (testing "rejects bad input"
    (are [line expect] (= expect (parse-env-line line))
      "foo" {:type :err})))

(deftest test-key-of-file-ptr
  (testing "returns canonical key for keys not defining file source"
   (are [k expect] (= expect (key-of-file-ptr k))
     "FOO_FILE" "FOO"
     "FOO_FILE_FILE" "FOO_FILE"))
  (testing "returns nil for keys not defining file source"
    (are [k] (nil? (key-of-file-ptr k))
      ""
      "FOO"
      "_FILE"                           ; must have non-empty stem
      "_FILE_FOO")))
