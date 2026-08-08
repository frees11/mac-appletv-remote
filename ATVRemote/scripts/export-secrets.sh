#!/bin/bash
# Builds the GitHub Secrets that .github/workflows/release-mas.yml needs.
#
# The signing material is taken from the loose cert/key files in the repo root
# rather than exported out of the login keychain, so only the two MAS identities
# are packaged — no unrelated certificates leak into the secrets.
set -euo pipefail

cd "$(dirname "$0")/../.."

APP_CERT="mac_app.pem"
APP_KEY="mas_certificate.key"
INSTALLER_CERT="PDCHSWQDNU.cer"
INSTALLER_KEY="PDCHSWQDNU.p12"
PROFILE="ATVRemote/App/macOS/embedded.provisionprofile"

OUT_DIR=""
UPLOAD=0

usage() {
	cat <<EOF
Usage: $(basename "$0") [--out DIR] [--upload]

  --out DIR   Where to write the secret files. Default: a fresh mktemp dir.
  --upload    Push the secrets straight to GitHub with 'gh secret set' instead
              of leaving files behind. Requires an authenticated gh.

Writes one file per secret, 0600, plus a README naming each one. Delete the
directory when the secrets are in place — it holds private keys.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--out) OUT_DIR="${2:?--out needs a directory}"; shift ;;
		--upload) UPLOAD=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

fail() { echo "FAILED: $*" >&2; exit 1; }

for f in "$APP_CERT" "$APP_KEY" "$INSTALLER_CERT" "$INSTALLER_KEY" "$PROFILE"; do
	[ -f "$f" ] || fail "missing input: $f"
done

# Refuse to run if a key does not belong to the certificate it is paired with —
# a mismatch produces a p12 that imports fine and then fails to sign in CI.
assert_pair() {
	local cert="$1" key="$2" form="$3" label="$4"
	local cert_mod key_mod
	cert_mod=$(openssl x509 ${form:+-inform "$form"} -in "$cert" -noout -modulus | openssl md5)
	key_mod=$(openssl rsa -in "$key" -noout -modulus | openssl md5)
	[ "$cert_mod" = "$key_mod" ] || fail "$label: $key is not the private key for $cert"
	echo "  ok  $label key matches certificate"
}

echo "=== Checking signing material ==="
assert_pair "$APP_CERT" "$APP_KEY" "" "application"
assert_pair "$INSTALLER_CERT" "$INSTALLER_KEY" "DER" "installer"

P12_PASSWORD=$(openssl rand -hex 24)

if [ -z "$OUT_DIR" ]; then
	OUT_DIR=$(mktemp -d "${TMPDIR:-/tmp}/atvremote-secrets.XXXXXX")
fi
mkdir -p "$OUT_DIR"
chmod 700 "$OUT_DIR"

build_p12() {
	local cert="$1" key="$2" form="$3" out="$4"
	local pem_cert="$OUT_DIR/.cert.pem"
	if [ "$form" = "DER" ]; then
		openssl x509 -inform DER -in "$cert" -out "$pem_cert"
	else
		cp "$cert" "$pem_cert"
	fi
	# -legacy keeps the PBE algorithms that macOS 'security import' accepts.
	local legacy=()
	if openssl pkcs12 -help 2>&1 | grep -q -- -legacy; then legacy=(-legacy); fi
	openssl pkcs12 -export \
		-inkey "$key" -in "$pem_cert" \
		-out "$out" -passout "pass:$P12_PASSWORD" \
		"${legacy[@]+"${legacy[@]}"}"
	rm -f "$pem_cert"
}

echo ""
echo "=== Building p12 bundles ==="
build_p12 "$APP_CERT" "$APP_KEY" "" "$OUT_DIR/.app.p12"
build_p12 "$INSTALLER_CERT" "$INSTALLER_KEY" "DER" "$OUT_DIR/.installer.p12"

# Prove the bundles actually import the way CI will import them.
echo ""
echo "=== Verifying the bundles import ==="
VERIFY_KEYCHAIN="$OUT_DIR/verify.keychain-db"
VERIFY_PASSWORD=$(uuidgen)
security create-keychain -p "$VERIFY_PASSWORD" "$VERIFY_KEYCHAIN"
security unlock-keychain -p "$VERIFY_PASSWORD" "$VERIFY_KEYCHAIN"
trap 'security delete-keychain "$VERIFY_KEYCHAIN" 2>/dev/null || true' EXIT

for p12 in "$OUT_DIR/.app.p12" "$OUT_DIR/.installer.p12"; do
	security import "$p12" -k "$VERIFY_KEYCHAIN" -P "$P12_PASSWORD" \
		-T /usr/bin/codesign -T /usr/bin/productbuild > /dev/null \
		|| fail "generated bundle does not import: $p12"
done
security find-identity -v "$VERIFY_KEYCHAIN" | grep -q "3rd Party Mac Developer Application" \
	|| fail "application identity is not usable after import"
echo "  ok  both bundles import and the application identity is usable"
security delete-keychain "$VERIFY_KEYCHAIN" 2>/dev/null || true
trap - EXIT

write_secret() { printf '%s' "$2" > "$OUT_DIR/$1"; chmod 600 "$OUT_DIR/$1"; }

write_secret MAS_CERTIFICATE "$(base64 < "$OUT_DIR/.app.p12")"
write_secret MAS_CERTIFICATE_PASSWORD "$P12_PASSWORD"
write_secret MAS_INSTALLER_CERTIFICATE "$(base64 < "$OUT_DIR/.installer.p12")"
write_secret MAS_INSTALLER_CERTIFICATE_PASSWORD "$P12_PASSWORD"
write_secret MAS_PROVISIONING_PROFILE "$(base64 < "$PROFILE")"
rm -f "$OUT_DIR/.app.p12" "$OUT_DIR/.installer.p12"

ASC_KEY=$(ls -1 "$HOME/.appstoreconnect/private_keys/"AuthKey_*.p8 2>/dev/null | head -1 || true)
if [ -n "$ASC_KEY" ]; then
	key_id=$(basename "$ASC_KEY" .p8); key_id=${key_id#AuthKey_}
	write_secret ASC_KEY_P8_BASE64 "$(base64 < "$ASC_KEY")"
	write_secret ASC_KEY_ID "$key_id"
	echo "  ok  App Store Connect key found: $key_id"
	echo ""
	echo "ASC_ISSUER_ID is not derivable from the key file — copy it from"
	echo "App Store Connect > Users and Access > Integrations and set it by hand."
else
	echo ""
	echo "No App Store Connect key in ~/.appstoreconnect/private_keys/."
	echo "ASC_KEY_P8_BASE64, ASC_KEY_ID and ASC_ISSUER_ID still have to be set."
fi

if [ "$UPLOAD" -eq 1 ]; then
	command -v gh > /dev/null || fail "gh is not installed"
	gh auth status > /dev/null 2>&1 || fail "gh is not authenticated — run: gh auth login"
	echo ""
	echo "=== Uploading to GitHub ==="
	for f in "$OUT_DIR"/*; do
		name=$(basename "$f")
		case "$name" in verify.keychain-db|README.txt) continue ;; esac
		gh secret set "$name" < "$f"
		echo "  set $name"
	done
	rm -rf "$OUT_DIR"
	echo ""
	echo "Secrets uploaded, local copies deleted."
	exit 0
fi

cat > "$OUT_DIR/README.txt" <<EOF
GitHub Secrets for .github/workflows/release-mas.yml

Set each file's contents as the repository secret named after the file:
  Settings > Secrets and variables > Actions > New repository secret

Still missing unless listed above: ASC_KEY_P8_BASE64, ASC_KEY_ID, ASC_ISSUER_ID.
PAT_TOKEN is only needed if main is protected against the default GITHUB_TOKEN.

These files contain private keys. Delete this directory once the secrets are in:
  rm -rf "$OUT_DIR"
EOF

echo ""
echo "=== Done ==="
echo "Secrets written to: $OUT_DIR"
ls -1 "$OUT_DIR"
echo ""
echo "Delete the directory once the secrets are set — it holds private keys."
