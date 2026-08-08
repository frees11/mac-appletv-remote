#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="ATV Remote.xcodeproj"
SCHEME="ATV Remote"
ARCHIVE_PATH="build/ATVRemote.xcarchive"
EXPORT_PATH="build/export"
LOG_DIR="build/logs"
BUMP=1
ARCHIVE_ONLY=0

usage() {
	cat <<EOF
Usage: $(basename "$0") [--no-bump] [--archive-only]

  --no-bump        Skip the version bump (CI bumps and tags separately).
  --archive-only   Stop after archiving. Nothing leaves this machine — use it
                   to check the signing chain without touching App Store Connect.

Environment:
  ASC_KEY_PATH    Path to the App Store Connect API key (.p8).
                  Defaults to the single key in ~/.appstoreconnect/private_keys/.
  ASC_KEY_ID      Key ID from App Store Connect.
  ASC_ISSUER_ID   Issuer ID from App Store Connect.

Without the ASC_* variables the archive is built and exported locally but not
uploaded.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		--no-bump) BUMP=0 ;;
		--archive-only) ARCHIVE_ONLY=1 ;;
		-h|--help) usage; exit 0 ;;
		*) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
	esac
	shift
done

fail() {
	echo "" >&2
	echo "FAILED: $*" >&2
	exit 1
}

# The application cert is a codesigning identity; the installer cert is not,
# so it only shows up in the unfiltered listing.
require_identity() {
	security find-identity -v ${2:-} | grep -q "$1" \
		|| fail "signing identity not found in keychain: $1"
	echo "  ok  $1"
}

echo "=== Preflight ==="
require_identity "3rd Party Mac Developer Application" "-p codesigning"
require_identity "3rd Party Mac Developer Installer"

[ -f "$PROJECT/project.pbxproj" ] || fail "project not found: $PROJECT"
[ -f ExportOptions.plist ] || fail "ExportOptions.plist not found"
[ -f App/macOS/embedded.provisionprofile ] \
	|| fail "App/macOS/embedded.provisionprofile not found — it is gitignored, restore it from the MAS_PROVISIONING_PROFILE secret"

AUTH_ARGS=()
if [ -z "${ASC_KEY_PATH:-}" ]; then
	default_key=$(ls -1 "$HOME/.appstoreconnect/private_keys/"AuthKey_*.p8 2>/dev/null | head -1 || true)
	[ -n "$default_key" ] && ASC_KEY_PATH="$default_key"
fi

if [ -n "${ASC_KEY_PATH:-}" ] && [ -n "${ASC_KEY_ID:-}" ] && [ -n "${ASC_ISSUER_ID:-}" ]; then
	[ -f "$ASC_KEY_PATH" ] || fail "ASC key not readable: $ASC_KEY_PATH"
	AUTH_ARGS=(
		-authenticationKeyPath "$ASC_KEY_PATH"
		-authenticationKeyID "$ASC_KEY_ID"
		-authenticationKeyIssuerID "$ASC_ISSUER_ID"
	)
	echo "  ok  App Store Connect API key: $(basename "$ASC_KEY_PATH")"
else
	echo "  --  no App Store Connect credentials — export will not upload"
fi

if [ "$BUMP" -eq 1 ]; then
	echo ""
	echo "=== Version bump ==="
	./scripts/bump-version.sh
fi

VERSION=$(grep -m1 "MARKETING_VERSION = " "$PROJECT/project.pbxproj" | sed 's/.*= \(.*\);/\1/')
BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION = " "$PROJECT/project.pbxproj" | sed 's/.*= \(.*\);/\1/')

echo ""
echo "=== Building $VERSION (build $BUILD) ==="
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"
mkdir -p "$LOG_DIR"

xcodebuild -project "$PROJECT" \
	-scheme "$SCHEME" \
	-configuration Release \
	-archivePath "$ARCHIVE_PATH" \
	archive \
	> "$LOG_DIR/archive.log" 2>&1 \
	|| { grep -E "error:|ARCHIVE FAILED" "$LOG_DIR/archive.log" | tail -30 >&2 || true
	     fail "archive failed — full log: $LOG_DIR/archive.log"; }

[ -d "$ARCHIVE_PATH" ] || fail "archive path missing after a successful build: $ARCHIVE_PATH"
echo "  ok  $ARCHIVE_PATH"

codesign --verify --strict --verbose=2 "$ARCHIVE_PATH/Products/Applications/ATV Remote.app" 2>&1 \
	| sed 's/^/  /' \
	|| fail "codesign verification failed"

if [ "$ARCHIVE_ONLY" -eq 1 ]; then
	echo ""
	echo "=== Archive-only: stopping before export. Nothing was uploaded. ==="
	exit 0
fi

echo ""
if [ ${#AUTH_ARGS[@]} -gt 0 ]; then
	echo "=== Exporting and uploading to App Store Connect ==="
else
	echo "=== Exporting (no upload) ==="
fi

xcodebuild -exportArchive \
	-archivePath "$ARCHIVE_PATH" \
	-exportOptionsPlist ExportOptions.plist \
	-exportPath "$EXPORT_PATH" \
	"${AUTH_ARGS[@]+"${AUTH_ARGS[@]}"}" \
	> "$LOG_DIR/export.log" 2>&1 \
	|| { grep -E "error:|EXPORT FAILED" "$LOG_DIR/export.log" | tail -30 >&2 || true
	     fail "export failed — full log: $LOG_DIR/export.log"; }

# ExportOptions.plist sets destination=upload, so xcodebuild hands the package
# straight to App Store Connect and leaves -exportPath empty.
if [ ${#AUTH_ARGS[@]} -gt 0 ]; then
	echo "  ok  uploaded to App Store Connect"
else
	echo "  ok  $EXPORT_PATH"
	ls -1 "$EXPORT_PATH"
fi

echo ""
echo "=== Release $VERSION (build $BUILD) complete ==="
if [ ${#AUTH_ARGS[@]} -gt 0 ]; then
	echo "Check processing status at https://appstoreconnect.apple.com"
fi
