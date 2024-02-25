#!/bin/bash
set -ex

ROOT_DOMAIN=$1

mkdir -p certs
cd certs
rm -f *.key *.crt *.cert v3.ext

# --- --- --- --- --- --- --- --- ---
# 1. Generate a Certificate Authority Certificate

# 1.1 Generate a CA certificate private key.
openssl genrsa -out ca.key 4096
chmod og-rwx ca.key

# 1.2 Generate the CA certificate.
openssl req -x509 -new -nodes -sha512 -days 3650 \
  -subj "/C=JP/ST=Kyoto/L=Kyoto/CN=@making" \
  -key ca.key \
  -out ca.crt

# --- --- --- --- --- --- --- --- ---
# 2. Generate a Server Certificate

# 2.1 Generate a private key.
openssl genrsa -out server.key 4096
chmod og-rwx server.key

# 2.2 Generate a certificate signing request (CSR).
openssl req -sha512 -new \
  -subj "/C=JP/ST=Kyoto/L=Kyoto/CN=${ROOT_DOMAIN}" \
  -key server.key \
  -out server.csr

# 2.3 Generate an x509 v3 extension file.
cat <<EOF >v3.ext
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${ROOT_DOMAIN}
DNS.2 = *.${ROOT_DOMAIN}
DNS.3 = localhost
EOF

# 2.4 Use the v3.ext file to generate a certificate for your host.
openssl x509 -req -sha512 -days 3650 \
  -extfile v3.ext \
  -CA ca.crt -CAkey ca.key -CAcreateserial \
  -in server.csr \
  -out server.crt

# 2.5 Convert server.crt to server.cert, for use by Docker.
openssl x509 -inform PEM \
  -in server.crt \
  -out server.cert

rm -f *.csr v3.ext
