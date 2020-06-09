#!/usr/bin/env bash
cd "$(dirname "${BASH_SOURCE}")/.."
[[ -e "run/public" ]] || mkdir -p "run/public"
[[ -e "run/secrets" ]] || mkdir -p "run/secrets"
cat <<EOF | openssl req -x509 \
                    -out "run/public/CERTIFICATE" \
                    -keyout "run/secrets/CERTIFICATE_KEY" \
                    -newkey rsa:2048 -nodes -sha256 \
                    -subj '/CN=localhost' \
                    -extensions EXT \
                    -config -
[dn]
CN=localhost

[req]
distinguished_name=dn

[EXT]
subjectAltName=DNS:localhost
keyUsage=digitalSignature
extendedKeyUsage=serverAuth
EOF
