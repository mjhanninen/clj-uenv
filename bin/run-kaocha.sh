#!/usr/bin/env bash
exec clojure -Srepro -A:test:kaocha -m kaocha.runner "$@"
