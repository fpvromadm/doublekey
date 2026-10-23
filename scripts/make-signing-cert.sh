#!/bin/zsh
# Creates a self-signed "DoubleKey Local Signing" certificate in your login
# keychain, trusted for code signing only. build.sh picks it up by name.
#
# Why: macOS ties the Accessibility permission to the app's signature. With a
# stable certificate, rebuilds keep the permission; with ad-hoc signing you
# have to grant it again after every rebuild. You only need this if you build
# from source more than once.
#
# macOS asks for your password once, to trust the certificate.
# Remove it later in Keychain Access (search "DoubleKey Local Signing").
set -euo pipefail

NAME="DoubleKey Local Signing"
KEYCHAIN=~/Library/Keychains/login.keychain-db

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
  echo "\"$NAME\" already exists"
  exit 0
fi

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name=dn
x509_extensions=ext
prompt=no
[dn]
CN=$NAME
[ext]
basicConstraints=critical,CA:false
keyUsage=critical,digitalSignature
extendedKeyUsage=critical,codeSigning
EOF

openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.cnf" \
  -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
# -legacy: the macOS keychain can't read OpenSSL 3's default PKCS#12 encryption
openssl pkcs12 -export -legacy -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
  -out "$TMP/cert.p12" -passout pass:doublekey
security import "$TMP/cert.p12" -k $KEYCHAIN -P doublekey -T /usr/bin/codesign
security add-trusted-cert -r trustRoot -p codeSign -k $KEYCHAIN "$TMP/cert.pem"

echo "Created \"$NAME\". Run ./build.sh install"
