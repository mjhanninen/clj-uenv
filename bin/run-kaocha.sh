#!/usr/bin/env bash
exec clojure -A:test:kaocha -m kaocha.runner "$@"
