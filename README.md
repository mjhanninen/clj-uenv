# Uenv

**Uenv** is a minimal library helping to configure Clojure and ClojureScript
backends through in the spirit of 12-factor app.  It supports `.env` files to
facilitate local development and the `*_FILE` convention for handling large
and, in some settings, secret values.

## Status

This library is at the **experimental** stage. Things may still break.

## Features

- Reads environment variables from `.env` style files
- Supports the `*_FILE` convention for handling secret or large values
- Platforms:
  - Clojure 1.8 and up
  - ClojureScript NodeJS target
  - [Babashka][babashka]
- No external dependencies

[babashka]: https://github.com/borkdude/babashka

## Things to do before first release

- [ ] Support multiline values in `.env` files
- [ ] Coherent errors
- [ ] Document rules for resolving values
- [ ] Improve test coverage

## Non-goals

- Structured configuration: Use [Aero][aero] instead
- EDN support: Use [Aero][aero] instead
- Conversion (or "coercion" in Clojure lingo) and validation

[aero]: https://github.com/juxt/aero

## Examples

### General usage

(To be written)

- Tests in `bin/run-shell-tests.sh` give a starting point

### Handling secrets with Docker

(To be written)

- Use `docker secret`
- Use `*_FILE` convention by defining `MY_SECRET_VAR_FILE=/run/secrets/MY_SECRET_VAR`

### Handling secrets with Kubernetes

(To be written)

- Similar to Docker

### Handling secrets with AWS

(To be written)

- AWS has facilities for passing secrets securely from SSM to container
  through environment variables

## License

Copyright © 2020 Matti Hänninen

Available under the terms of the Eclipse Public License 2.0.
