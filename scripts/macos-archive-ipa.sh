#!/usr/bin/env bash
# Archive GlassesDAT for a generic iOS device and export a development or ad-hoc IPA.
# Run on a Mac after Xcode Accounts has a signing identity for team FKR9U47TSF.
# Does not invent certificates. DAT remains developer preview — not App Store distribution.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
project="$root/GlassesDAT/GlassesDAT.xcodeproj"
scheme="GlassesDAT"
configuration="${CONFIGURATION:-Release}"
team="${DEVELOPMENT_TEAM:-FKR9U47TSF}"
bundle="${PRODUCT_BUNDLE_IDENTIFIER:-com.bobilabs.glasses}"
export_method="${EXPORT_METHOD:-development}"
template="$root/scripts/exportOptions-development.plist"
build_dir="${BUILD_DIR:-$root/build}"
archive_path="${ARCHIVE_PATH:-$build_dir/GlassesDAT.xcarchive}"
export_path="${EXPORT_PATH:-$build_dir/ipa}"
allow_provisioning="${ALLOW_PROVISIONING_UPDATES:-1}"
build_number_override="${BUILD_NUMBER:-}"
pbxproj="$project/project.pbxproj"
bump_script="$root/scripts/bump-project-build.py"
marketing_version=""
project_build=""

usage() {
  cat <<'EOF'
Usage: ./scripts/macos-archive-ipa.sh [--bump-only]

Archives GlassesDAT (generic iOS device) and exports an IPA.

Before archive, CURRENT_PROJECT_VERSION is bumped +1 (or set to BUILD_NUMBER
if that integer is strictly greater than the current value). The pbxproj is
updated so the next upload cannot reuse a TestFlight build number.

Required on the Mac:
  1. Xcode → Settings → Accounts → sign in (team FKR9U47TSF / Bobi Labs)
  2. Automatic signing for com.bobilabs.glasses
  3. App ID com.bobilabs.glasses exists, or Xcode creates it

Environment:
  EXPORT_METHOD                 development (default) or ad-hoc
  DEVELOPMENT_TEAM              default FKR9U47TSF
  PRODUCT_BUNDLE_IDENTIFIER     default com.bobilabs.glasses
  CONFIGURATION                 default Release
  BUILD_NUMBER                  optional next CFBundleVersion (must be > current)
  BUILD_DIR / ARCHIVE_PATH / EXPORT_PATH
  ALLOW_PROVISIONING_UPDATES    1 (default) passes -allowProvisioningUpdates
                                for Automatic signing

  --bump-only                   increment/write the build number and exit
                                (no xcodebuild; useful to inspect the bump)

This is not App Store distribution. See docs/VERSIONING.md.
EOF
}

die() {
  echo "error: $*" >&2
  exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

case "$export_method" in
  development|ad-hoc) ;;
  *)
    die "EXPORT_METHOD must be 'development' or 'ad-hoc' (got '$export_method'). App Store export is not supported."
    ;;
esac

command -v python3 >/dev/null 2>&1 || die "python3 not found. Needed to bump CURRENT_PROJECT_VERSION."
[[ -d "$project" ]] || die "missing Xcode project at $project"
[[ -f "$pbxproj" ]] || die "missing pbxproj at $pbxproj"
[[ -f "$bump_script" ]] || die "missing version bump helper at $bump_script"
[[ -f "$template" ]] || die "missing export options template at $template"

bump_project_build() {
  local report
  local -a bump_args
  bump_args=("$bump_script" "$pbxproj")
  if [[ -n "$build_number_override" ]]; then
    bump_args+=(--build-number "$build_number_override")
  fi
  report="$(python3 "${bump_args[@]}")" || die "failed to bump CURRENT_PROJECT_VERSION"
  marketing_version="$(printf '%s\n' "$report" | awk -F= '/^MARKETING_VERSION=/{print $2; exit}')"
  project_build="$(printf '%s\n' "$report" | awk -F= '/^CURRENT_PROJECT_VERSION=/{print $2; exit}')"
  [[ -n "$marketing_version" && -n "$project_build" ]] || die "bump helper did not print marketing/build"
  echo "Bobi Glasses version for this archive:"
  echo "$report"
  echo
}

if [[ "${1:-}" == "--bump-only" ]]; then
  bump_project_build
  echo "stopped after version bump (--bump-only). Commit CURRENT_PROJECT_VERSION after a TestFlight upload."
  exit 0
fi

[[ "$(uname -s)" == "Darwin" ]] || die "this script must run on macOS with Xcode (found $(uname -s))."
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild not found. Install Xcode and accept the license."
command -v security >/dev/null 2>&1 || die "security(1) not found. Cannot inspect codesigning identities."

identity_list="$(security find-identity -v -p codesigning 2>/dev/null || true)"
if [[ -z "$identity_list" ]] || echo "$identity_list" | grep -Eq '^[[:space:]]*0 valid identities found'; then
  cat >&2 <<EOF
error: no codesigning identities in the keychain.

Device / IPA builds need an Apple Development (or Distribution) identity
for team $team. This script will not create certificates.

On the Mac:
  1. Xcode → Settings → Accounts → add the Apple ID for team $team (Bobi Labs)
  2. Select the team → Manage Certificates → Apple Development (Xcode can issue it)
  3. Open GlassesDAT.xcodeproj → Signing & Capabilities → Automatic signing
  4. Confirm bundle $bundle and that App ID $bundle exists or is created
  5. Re-run: ./scripts/macos-archive-ipa.sh

Current identities:
${identity_list:-"(none)"}
EOF
  exit 1
fi

if ! echo "$identity_list" | grep -Eq 'Apple (Development|Distribution)|iPhone (Developer|Distribution)'; then
  cat >&2 <<EOF
error: keychain has codesigning identities, but none look like Apple Development/Distribution.

Need a valid Apple identity for team $team. Do not invent certificates.
Log into Xcode Accounts and let Automatic signing manage the identity.

Current identities:
$identity_list
EOF
  exit 1
fi

echo "codesigning identities:"
echo "$identity_list"
echo

bump_project_build

echo "archive $scheme for generic iOS device"
echo "  team=$team bundle=$bundle method=$export_method configuration=$configuration"
echo "  MARKETING_VERSION=$marketing_version CURRENT_PROJECT_VERSION=$project_build"

mkdir -p "$build_dir" "$export_path"

export_options="$template"
cleanup_export_options=""
if [[ "$export_method" != "development" ]]; then
  export_options="$(mktemp -t glassesdat-exportOptions)"
  cleanup_export_options="$export_options"
  python3 - "$template" "$export_options" "$export_method" "$team" <<'PY'
import sys
from pathlib import Path

src, dest, method, team = sys.argv[1:5]
text = Path(src).read_text()
text = text.replace("<string>development</string>", f"<string>{method}</string>", 1)
text = text.replace("<string>FKR9U47TSF</string>", f"<string>{team}</string>")
Path(dest).write_text(text)
PY
fi
if [[ -n "$cleanup_export_options" ]]; then
  trap 'rm -f "$cleanup_export_options"' EXIT
fi

provisioning_args=()
if [[ "$allow_provisioning" == "1" ]]; then
  # Automatic signing: let Xcode create/refresh the profile for this App ID.
  provisioning_args+=(-allowProvisioningUpdates)
fi

echo "→ xcodebuild archive"
xcodebuild \
  -project "$project" \
  -scheme "$scheme" \
  -configuration "$configuration" \
  -destination "generic/platform=iOS" \
  -archivePath "$archive_path" \
  DEVELOPMENT_TEAM="$team" \
  PRODUCT_BUNDLE_IDENTIFIER="$bundle" \
  MARKETING_VERSION="$marketing_version" \
  CURRENT_PROJECT_VERSION="$project_build" \
  CODE_SIGN_STYLE=Automatic \
  "${provisioning_args[@]}" \
  archive

echo "→ xcodebuild -exportArchive ($export_method)"
xcodebuild \
  -exportArchive \
  -archivePath "$archive_path" \
  -exportOptionsPlist "$export_options" \
  -exportPath "$export_path" \
  "${provisioning_args[@]}"

ipa=""
for candidate in "$export_path"/*.ipa; do
  if [[ -f "$candidate" ]]; then
    ipa="$candidate"
    break
  fi
done
[[ -n "$ipa" ]] || die "export finished but no .ipa in $export_path"

echo
echo "IPA ready: $ipa"
echo "Bobi Glasses $marketing_version ($project_build) — MARKETING_VERSION=$marketing_version CURRENT_PROJECT_VERSION=$project_build"
echo "suggested git tag: v${marketing_version}+${project_build}"
echo "Commit the CURRENT_PROJECT_VERSION bump after the TestFlight upload. Do not reuse this build number."
echo "Install on a registered device (development/ad-hoc). DAT is developer preview — not App Store."
