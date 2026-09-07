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
bundle="${PRODUCT_BUNDLE_IDENTIFIER:-com.bobilabs.glassesdat}"
export_method="${EXPORT_METHOD:-development}"
template="$root/scripts/exportOptions-development.plist"
build_dir="${BUILD_DIR:-$root/build}"
archive_path="${ARCHIVE_PATH:-$build_dir/GlassesDAT.xcarchive}"
export_path="${EXPORT_PATH:-$build_dir/ipa}"
allow_provisioning="${ALLOW_PROVISIONING_UPDATES:-1}"

usage() {
  cat <<'EOF'
Usage: ./scripts/macos-archive-ipa.sh

Archives GlassesDAT (generic iOS device) and exports an IPA.

Required on the Mac:
  1. Xcode → Settings → Accounts → sign in (team FKR9U47TSF / Bobi Labs)
  2. Automatic signing for com.bobilabs.glassesdat
  3. App ID com.bobilabs.glassesdat exists, or Xcode creates it

Environment:
  EXPORT_METHOD                 development (default) or ad-hoc
  DEVELOPMENT_TEAM              default FKR9U47TSF
  PRODUCT_BUNDLE_IDENTIFIER     default com.bobilabs.glassesdat
  CONFIGURATION                 default Release
  BUILD_DIR / ARCHIVE_PATH / EXPORT_PATH
  ALLOW_PROVISIONING_UPDATES    1 (default) passes -allowProvisioningUpdates
                                for Automatic signing

This is not App Store distribution.
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

[[ "$(uname -s)" == "Darwin" ]] || die "this script must run on macOS with Xcode (found $(uname -s))."
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild not found. Install Xcode and accept the license."
command -v security >/dev/null 2>&1 || die "security(1) not found. Cannot inspect codesigning identities."
[[ -f "$project" ]] || die "missing Xcode project at $project"
[[ -f "$template" ]] || die "missing export options template at $template"

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
echo "archive $scheme for generic iOS device"
echo "  team=$team bundle=$bundle method=$export_method configuration=$configuration"

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
echo "Install on a registered device (development/ad-hoc). DAT is developer preview — not App Store."
