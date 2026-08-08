#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT_FILE="ATV Remote.xcodeproj/project.pbxproj"
APP_MARKER="CODE_SIGN_ENTITLEMENTS = App/macOS/ATVRemote.entitlements;"

fail() {
	echo "FAILED: $*" >&2
	exit 1
}

[ -f "$PROJECT_FILE" ] || fail "project file not found: $PROJECT_FILE"

app_configs=$(grep -c "$APP_MARKER" "$PROJECT_FILE" || true)
[ "$app_configs" -eq 2 ] \
	|| fail "expected 2 app build configurations, found $app_configs — the pbxproj layout changed, review before bumping"

current_version=$(awk -F'[ ;]+' '/MARKETING_VERSION = /{print $3; exit}' "$PROJECT_FILE")
current_build=$(awk -F'[ ;]+' '/CURRENT_PROJECT_VERSION = /{print $3; exit}' "$PROJECT_FILE")

[ -n "$current_version" ] || fail "could not read MARKETING_VERSION"
[ -n "$current_build" ] || fail "could not read CURRENT_PROJECT_VERSION"

# The test targets carry their own MARKETING_VERSION / CURRENT_PROJECT_VERSION.
# A plain sed would rewrite those too if the values ever collide, so refuse.
version_hits=$(grep -c "MARKETING_VERSION = $current_version;" "$PROJECT_FILE")
build_hits=$(grep -c "CURRENT_PROJECT_VERSION = $current_build;" "$PROJECT_FILE")
[ "$version_hits" -eq 2 ] \
	|| fail "MARKETING_VERSION = $current_version appears $version_hits times, expected 2 (app Debug + Release) — a test target shares this value"
[ "$build_hits" -eq 2 ] \
	|| fail "CURRENT_PROJECT_VERSION = $current_build appears $build_hits times, expected 2 (app Debug + Release) — a test target shares this value"

IFS='.' read -r major minor patch <<< "$current_version"
[ -n "${patch:-}" ] || fail "MARKETING_VERSION is not major.minor.patch: $current_version"

new_version="${major}.${minor}.$((patch + 1))"
new_build=$((current_build + 1))

echo "Current version: $current_version (build $current_build)"
echo "New version: $new_version (build $new_build)"

sed -i '' \
	-e "s/MARKETING_VERSION = $current_version;/MARKETING_VERSION = $new_version;/g" \
	-e "s/CURRENT_PROJECT_VERSION = $current_build;/CURRENT_PROJECT_VERSION = $new_build;/g" \
	"$PROJECT_FILE"

plutil -lint "$PROJECT_FILE" > /dev/null || fail "pbxproj is no longer a valid plist after the bump"

echo "Version bumped to $new_version (build $new_build)"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
	{
		echo "current_version=$current_version"
		echo "new_version=$new_version"
		echo "new_build=$new_build"
		echo "tag_name=v$new_version"
	} >> "$GITHUB_OUTPUT"
fi
