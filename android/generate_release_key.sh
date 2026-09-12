#!/usr/bin/env bash
# Generates a real Android upload keystore + android/key.properties for
# release signing (see build.gradle.kts, which reads key.properties and
# falls back to debug signing with a warning when it's absent).
#
# Run this yourself, once, on your own machine: it creates the permanent
# signing identity for your app on the Play Store. Nothing here is run
# automatically and no secrets are generated for you ahead of time —
# keytool prompts you interactively for the passwords and identity fields.
#
# Usage: ./android/generate_release_key.sh
set -euo pipefail

cd "$(dirname "$0")"

if [ -f key.properties ]; then
  echo "android/key.properties already exists — refusing to overwrite it."
  echo "Delete it first if you really want to generate a new keystore (this"
  echo "will make you unable to publish updates to an app already signed"
  echo "with the old key, so make sure that's really what you want)."
  exit 1
fi

read -rp "Key alias [upload]: " ALIAS
ALIAS=${ALIAS:-upload}

read -rp "Validity in days [10000]: " VALIDITY
VALIDITY=${VALIDITY:-10000}

KEYSTORE_FILE="app/upload-keystore.jks"

echo
echo "This will prompt you for a keystore password, a key password, and"
echo "identity fields (name, org, etc.) used in the certificate."
echo

keytool -genkeypair -v \
  -keystore "$KEYSTORE_FILE" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity "$VALIDITY"

echo
read -rp "Re-enter the keystore password (to save into key.properties): " -s STORE_PASSWORD
echo
read -rp "Re-enter the key password (to save into key.properties): " -s KEY_PASSWORD
echo

cat > key.properties <<EOF
storePassword=$STORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$ALIAS
storeFile=upload-keystore.jks
EOF

echo
echo "Wrote android/key.properties and android/$KEYSTORE_FILE."
echo "Both are already gitignored — never commit them."
echo "Back up upload-keystore.jks somewhere safe: losing it means you can"
echo "never publish an update to an app already live under this key."
