#!/bin/bash
# setup-signing.sh — one-time: create a STABLE self-signed code-signing identity
# so rebuilds keep the same code identity. macOS ties the notification permission
# (and other TCC grants) to that identity; ad-hoc signing regenerates it on every
# build, so the grant is lost each time you rebuild. A stable cert fixes that.
#
#   ./setup-signing.sh          create the identity (idempotent — safe to re-run)
#   ./setup-signing.sh --remove delete the identity and its keychain
#
# The cert lives in its own keychain with an empty password — it only ever holds
# this one local signing key, never touches your login keychain, and needs no
# admin rights. The cert is self-signed and NOT trusted for Gatekeeper (you build
# the app yourself), which is all codesign needs to produce a stable identity.
set -euo pipefail

NAME="Magnetize Local Signing"                       # also the codesign identity name
KEYCHAIN="$HOME/Library/Keychains/magnetize-signing.keychain-db"
OPENSSL=/usr/bin/openssl                              # LibreSSL: p12 macOS can import

remove() {
    security delete-keychain "$KEYCHAIN" 2>/dev/null \
        && echo "Removed signing identity and $KEYCHAIN" \
        || echo "Nothing to remove."
    exit 0
}
[[ "${1:-}" == "--remove" ]] && remove

# Already set up? — nothing to do. (No -v: the cert is self-signed and untrusted,
# which is fine for signing but excludes it from the "valid identities" list.)
if security find-identity -p codesigning "$KEYCHAIN" 2>/dev/null | grep -q "$NAME"; then
    echo "Signing identity \"$NAME\" already exists."
    exit 0
fi

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

# 1) self-signed cert with the key-usage + EKU codesign requires of a leaf.
cat > "$TMP/cert.cnf" <<EOF
[req]
distinguished_name = dn
x509_extensions    = ext
prompt             = no
[dn]
CN = $NAME
[ext]
basicConstraints     = critical,CA:false
keyUsage             = critical,digitalSignature
extendedKeyUsage     = critical,codeSigning
EOF

# A throwaway password on the .p12 — macOS `security import` rejects the MAC of
# an empty-password PKCS#12. It only protects the temp file (deleted on exit);
# the keychain it lands in stays password-less.
P12_PW="magnetize"

"$OPENSSL" req -x509 -newkey rsa:2048 -nodes -days 3650 \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" -config "$TMP/cert.cnf" 2>/dev/null
"$OPENSSL" pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" \
    -out "$TMP/id.p12" -passout "pass:$P12_PW" -name "$NAME" 2>/dev/null

# 2) dedicated keychain we fully control (empty password → no prompts, no
#    auto-lock so the build never has to unlock it interactively).
security create-keychain -p "" "$KEYCHAIN" 2>/dev/null || true
security set-keychain-settings "$KEYCHAIN"           # no timeout, no lock-on-sleep
security unlock-keychain -p "" "$KEYCHAIN"

# 3) import the identity and authorize codesign to use the key without prompting.
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$P12_PW" -T /usr/bin/codesign -A
security set-key-partition-list -S apple-tool:,apple:,codesign: -k "" "$KEYCHAIN" >/dev/null 2>&1

# 4) put the keychain on the user search list so codesign can find the identity
#    by name (without dropping the login keychain).
SEARCH=$(security list-keychains -d user | sed -E 's/^[[:space:]]*"//; s/"$//')
if ! grep -qF "$KEYCHAIN" <<< "$SEARCH"; then
    # shellcheck disable=SC2086
    security list-keychains -d user -s "$KEYCHAIN" $SEARCH
fi

echo "Created code-signing identity \"$NAME\"."
echo "Now run ./build-app.sh --install — it will use this identity automatically."
