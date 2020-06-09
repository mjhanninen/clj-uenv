SHELL := bash
.SHELLFLAGS := -euo pipefail -c
.ONESHELL:

SOURCES := $(shell git ls-files 'src/**.cljs')
RT_FILES := run/public/CERTIFICATE \
            run/secrets/CERTIFICATE_KEY \
            run/secrets/POSTGRES_PASSWORD

.PHONY: all build-cljs build-rt clean scrub

all: install-deps build-cljs build-rt build-image

build-cljs: out/main.js

out/main.js: $(SOURCES) stamps/npm-install
	clojure -Srepro -m cljs.main \
	        --output-dir $(@D) \
	        --output-to $@ \
	        --target node \
	        --compile hello.core

build-image: stamps/dockerimage

stamps/dockerimage: Dockerfile out/main.js
	docker build -t uenv-demo/server:latest .
	@mkdir -p $(@D)
	@touch $@

build-rt: $(RT_FILES)

run/public/CERTIFICATE run/secrets/CERTIFICATE_KEY &:
	bin/create-cert.sh

run/secrets/POSTGRES_PASSWORD:
	bin/create-pg-pwd.sh

clean:
	[[ ! -d out ]] || rm -Rd out

scrub: clean
	[[ ! -d node_modules ]] || rm -Rd node_modules
	[[ ! -d run ]] || rm -Rd run
	[[ ! -d stamps ]] || rm -Rd stamps

install-deps: stamps/npm-install

stamps/npm-install: package.json package-lock.json
	npm install
	@mkdir -p $(@D)
	@touch $@

# npm -i -save cookies pg ws
