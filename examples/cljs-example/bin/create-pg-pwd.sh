#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")/.."
[[ -e "run/secrets" ]] || mkdir -p "run/secrets"
openssl rand -hex 16 | tr -d "\n" > run/secrets/POSTGRES_PASSWORD
