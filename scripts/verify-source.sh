#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
pbx="$root/GlassesDAT/GlassesDAT.xcodeproj/project.pbxproj"
plist="$root/GlassesDAT/GlassesDAT/Info.plist"
fail=0

require() {
  if [[ ! -f "$1" ]]; then
    echo "missing $1"
    fail=1
  fi
}

require "$root/GlassesDAT/GlassesDAT/GlassesDATApp.swift"
require "$root/GlassesDAT/GlassesDAT/Domain/Session.swift"
require "$root/GlassesDAT/GlassesDAT/Domain/Stream.swift"
require "$root/GlassesDAT/GlassesDAT/Domain/Latency.swift"
require "$root/GlassesDAT/GlassesDAT/Session/GlassesSession.swift"
require "$root/GlassesDAT/GlassesDAT/Session/MockPath.swift"
require "$root/GlassesDAT/GlassesDAT/UI/RootView.swift"
require "$root/GlassesDAT/GlassesDAT/UI/ConnectView.swift"
require "$root/GlassesDAT/GlassesDAT/UI/LiveView.swift"
require "$root/GlassesDAT/GlassesDAT/UI/FrameSurface.swift"
require "$root/GlassesDAT/GlassesDAT/UI/LatencyHUD.swift"
require "$root/GlassesDAT/GlassesDAT/UI/DatTheme.swift"
require "$root/GlassesDAT/GlassesDAT/Assets.xcassets/DatBackground.colorset/Contents.json"
require "$root/GlassesDAT/GlassesDAT/Assets.xcassets/DatAccent.colorset/Contents.json"
require "$root/GlassesDAT/GlassesDAT/Assets.xcassets/AppIcon.appiconset/Contents.json"
require "$root/GlassesDAT/GlassesDAT/Assets.xcassets/AppIcon.appiconset/AppIcon-60@2x.png"
require "$root/GlassesDAT/GlassesDAT/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
require "$root/GlassesDAT/GlassesDAT/Info.plist"
require "$root/scripts/generate-app-icons.py"
require "$root/GlassesDAT/GlassesDAT/Resources/mock-feed.mp4"
require "$root/GlassesDAT/GlassesDATTests/LatencyTests.swift"
require "$root/scripts/macos-archive-ipa.sh"
require "$root/scripts/bump-project-build.py"
require "$root/scripts/exportOptions-development.plist"
require "$root/docs/VERSIONING.md"

for symbol in Wearables MWDATCore MWDATCamera MWDATMockDevice addCamera StreamConfiguration videoFramePublisher makeUIImage; do
  if ! rg -q "$symbol" "$root/GlassesDAT/GlassesDAT"; then
    echo "missing DAT symbol $symbol"
    fail=1
  fi
done

for key in MetaAppID ClientToken TeamID AppLinkURLScheme com.meta.ar.wearable glassesdat:// fb-viewapp; do
  if ! rg -q "$key" "$plist"; then
    echo "missing Info.plist key $key"
    fail=1
  fi
done

if ! rg -q 'FKR9U47TSF' "$root/scripts/exportOptions-development.plist"; then
  echo "exportOptions-development.plist missing team FKR9U47TSF"
  fail=1
fi
if ! rg -q '<string>development</string>' "$root/scripts/exportOptions-development.plist"; then
  echo "exportOptions-development.plist missing method development"
  fail=1
fi
if ! rg -q 'generic/platform=iOS' "$root/scripts/macos-archive-ipa.sh"; then
  echo "macos-archive-ipa.sh missing generic iOS destination"
  fail=1
fi
if ! rg -q 'allowProvisioningUpdates' "$root/scripts/macos-archive-ipa.sh"; then
  echo "macos-archive-ipa.sh missing -allowProvisioningUpdates"
  fail=1
fi
if ! rg -q 'BUILD_NUMBER' "$root/scripts/macos-archive-ipa.sh"; then
  echo "macos-archive-ipa.sh missing BUILD_NUMBER override"
  fail=1
fi
if ! rg -q 'bump-project-build.py' "$root/scripts/macos-archive-ipa.sh"; then
  echo "macos-archive-ipa.sh missing CURRENT_PROJECT_VERSION bump"
  fail=1
fi
if ! rg -q 'MARKETING_VERSION="\$marketing_version"' "$root/scripts/macos-archive-ipa.sh"; then
  echo "macos-archive-ipa.sh missing MARKETING_VERSION pass-through"
  fail=1
fi
if ! rg -q 'CURRENT_PROJECT_VERSION="\$project_build"' "$root/scripts/macos-archive-ipa.sh"; then
  echo "macos-archive-ipa.sh missing CURRENT_PROJECT_VERSION pass-through"
  fail=1
fi
if ! rg -q 'MARKETING_VERSION' "$root/docs/VERSIONING.md"; then
  echo "docs/VERSIONING.md missing MARKETING_VERSION"
  fail=1
fi
if ! rg -q 'CURRENT_PROJECT_VERSION' "$root/docs/VERSIONING.md"; then
  echo "docs/VERSIONING.md missing CURRENT_PROJECT_VERSION"
  fail=1
fi
if ! rg -q 'vMAJOR\.MINOR\.PATCH\+BUILD' "$root/docs/VERSIONING.md"; then
  echo "docs/VERSIONING.md missing optional git tag format"
  fail=1
fi
if ! python3 -c '
import re, pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
markets = re.findall(r"MARKETING_VERSION = ([^;]+);", text)
builds = re.findall(r"CURRENT_PROJECT_VERSION = ([^;]+);", text)
semver = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
pint = re.compile(r"^[1-9][0-9]*$")
if not markets or any(not semver.fullmatch(v.strip()) for v in markets):
    raise SystemExit("pbxproj MARKETING_VERSION is not MAJOR.MINOR.PATCH")
if not builds or any(not pint.fullmatch(v.strip()) for v in builds):
    raise SystemExit("pbxproj CURRENT_PROJECT_VERSION is not a positive integer")
' "$pbx"; then
  echo "pbxproj version fields are not locked to semver + integer build"
  fail=1
fi
if ! rg -q '0 valid identities found' "$root/scripts/macos-archive-ipa.sh"; then
  echo "macos-archive-ipa.sh missing signing-identity failure"
  fail=1
fi

if ! rg -q 'https://github.com/facebook/meta-wearables-dat-ios' "$pbx"; then
  echo "pbxproj missing official DAT SPM URL"
  fail=1
fi

if ! rg -q 'version = 0.9.0' "$pbx"; then
  echo "pbxproj missing DAT 0.9.0 pin"
  fail=1
fi

if ! rg -q '<string>Bobi Glasses</string>' "$plist"; then
  echo "Info.plist CFBundleDisplayName is not Bobi Glasses"
  fail=1
fi
if ! rg -q '<key>CFBundleIconName</key>' "$plist" || ! awk '/<key>CFBundleIconName<\/key>/{getline; exit !($0 ~ /<string>AppIcon<\/string>/)}' "$plist"; then
  echo "Info.plist missing CFBundleIconName = AppIcon"
  fail=1
fi
if ! rg -q 'ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;' "$pbx"; then
  echo "pbxproj missing ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon"
  fail=1
fi
if ! rg -q 'INFOPLIST_KEY_CFBundleIconName = AppIcon;' "$pbx"; then
  echo "pbxproj missing INFOPLIST_KEY_CFBundleIconName = AppIcon"
  fail=1
fi
if ! rg -q 'PRODUCT_BUNDLE_IDENTIFIER = com.bobilabs.glasses;' "$pbx"; then
  echo "pbxproj missing app bundle com.bobilabs.glasses"
  fail=1
fi
if ! rg -q 'PRODUCT_BUNDLE_IDENTIFIER = com.bobilabs.glasses.tests;' "$pbx"; then
  echo "pbxproj missing tests bundle com.bobilabs.glasses.tests"
  fail=1
fi
if ! rg -q 'DEVELOPMENT_TEAM = FKR9U47TSF;' "$pbx"; then
  echo "pbxproj missing DEVELOPMENT_TEAM FKR9U47TSF"
  fail=1
fi
if rg -n 'com\.bobilabs\.glassesdat|com\.fedesack\.glassesdat' "$pbx" "$root/README.md"; then
  echo "leftover glassesdat / fedesack bundle identifier"
  fail=1
fi

for source in GlassesDATApp.swift Session.swift Stream.swift Latency.swift GlassesSession.swift MockPath.swift RootView.swift ConnectView.swift LiveView.swift FrameSurface.swift LatencyHUD.swift DatButtonStyle.swift DatTheme.swift LatencyTests.swift mock-feed.mp4; do
  if ! rg -q "$source" "$pbx"; then
    echo "pbxproj missing $source"
    fail=1
  fi
done

if rg -n "AVCaptureSession|WKWebView|getUserMedia|webrtc|WebRTC" "$root/GlassesDAT/GlassesDAT"; then
  echo "found a non-DAT camera path"
  fail=1
fi

if ! ffprobe -v error -select_streams v:0 -show_entries stream=codec_name,codec_tag_string,width,height,r_frame_rate -of csv=p=0 "$root/GlassesDAT/GlassesDAT/Resources/mock-feed.mp4" | rg -q 'hevc,hvc1,504,896,24/1'; then
  echo "mock-feed.mp4 is not HEVC hvc1 504x896@24"
  fail=1
fi

for token in 0x0A 0x0B 0x1C 0x1E 0x00 0x6C 0xEB 0x8E 0x93 0x30 0xD1 0x58 0xFF 0x45 0x3A; do
  if ! rg -q "$token" "$root/GlassesDAT/GlassesDAT/Assets.xcassets"; then
    echo "missing color component $token"
    fail=1
  fi
done

if ! rg -q 'static let safeTop: CGFloat = 59' "$root/GlassesDAT/GlassesDAT/UI/DatTheme.swift"; then
  echo "missing Figma safeTop 59"
  fail=1
fi
if ! rg -q 'static let liveButtonWidth: CGFloat = 345' "$root/GlassesDAT/GlassesDAT/UI/DatTheme.swift"; then
  echo "missing Figma live button width 345"
  fail=1
fi
if ! rg -q 'static let latencyTop: CGFloat = 67' "$root/GlassesDAT/GlassesDAT/UI/DatTheme.swift"; then
  echo "missing Figma latency top 67"
  fail=1
fi

if rg -n "func startStream|func connectMock|func registerWithMetaAI|addCamera|Wearables.configure" "$root/GlassesDAT/GlassesDAT/Session/GlassesSession.swift" >/dev/null; then
  :
else
  echo "DAT session methods missing"
  fail=1
fi

python3 - "$root/GlassesDAT/GlassesDAT/Assets.xcassets/AppIcon.appiconset" <<'PY'
import json
import struct
import sys
from pathlib import Path

iconset = Path(sys.argv[1])
manifest = json.loads((iconset / "Contents.json").read_text())
required = {
    ("iphone", "20x20", "2x", 40, "AppIcon-20@2x.png"),
    ("iphone", "20x20", "3x", 60, "AppIcon-20@3x.png"),
    ("iphone", "29x29", "2x", 58, "AppIcon-29@2x.png"),
    ("iphone", "29x29", "3x", 87, "AppIcon-29@3x.png"),
    ("iphone", "40x40", "2x", 80, "AppIcon-40@2x.png"),
    ("iphone", "40x40", "3x", 120, "AppIcon-40@3x.png"),
    ("iphone", "60x60", "2x", 120, "AppIcon-60@2x.png"),
    ("iphone", "60x60", "3x", 180, "AppIcon-60@3x.png"),
    ("ios-marketing", "1024x1024", "1x", 1024, "AppIcon-1024.png"),
}
found = set()
for image in manifest.get("images", []):
    found.add(
        (
            image.get("idiom"),
            image.get("size"),
            image.get("scale"),
            image.get("filename"),
        )
    )

for idiom, size, scale, pixels, filename in sorted(required):
    if (idiom, size, scale, filename) not in found:
        raise SystemExit(f"AppIcon Contents.json missing {idiom} {size} {scale} ({filename})")
    path = iconset / filename
    if not path.is_file():
        raise SystemExit(f"missing AppIcon PNG {filename}")
    data = path.read_bytes()
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise SystemExit(f"{filename} is not a PNG")
    width, height, bit, color = struct.unpack(">IIBB", data[16:26])
    if (width, height) != (pixels, pixels):
        raise SystemExit(f"{filename} is {width}x{height}, expected {pixels}x{pixels}")
    if bit != 8 or color != 2:
        raise SystemExit(f"{filename} must be 8-bit RGB without alpha (ITMS marketing icon)")

print("AppIcon catalog ok (includes 120x120 60pt@2x, RGB, no alpha)")
PY

python3 - <<'PY'
def ms(pts, now, received):
    if pts is not None and pts > 100:
        return max(0, int(round((now - pts) * 1000)))
    return max(0, int(round((now - received) * 1000)))

assert ms(1000, 1000.250, 1000.249) == 250
assert ms(0.04, 12.020, 12.001) == 19
assert ms(None, 5.010, 5.000) == 10
assert ms(2000, 1999.5, 1999.4) == 0
print("latency arithmetic ok")
PY

python3 - "$root/scripts/bump-project-build.py" "$pbx" <<'PY'
import subprocess
import sys
import tempfile
from pathlib import Path

helper, pbx = sys.argv[1], sys.argv[2]
src = Path(pbx).read_text()
assert "MARKETING_VERSION = 1.0.0;" in src
assert "CURRENT_PROJECT_VERSION = 1;" in src

def run(path, extra, expect_ok):
    cmd = [sys.executable, helper, str(path), *extra]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if expect_ok and result.returncode != 0:
        raise SystemExit(result.stderr or result.stdout or "bump failed")
    if not expect_ok and result.returncode == 0:
        raise SystemExit(f"expected failure for {extra}, got:\n{result.stdout}")
    return result

with tempfile.TemporaryDirectory() as tmp:
    copy = Path(tmp) / "project.pbxproj"
    copy.write_text(src)

    dry = run(copy, ["--dry-run"], True)
    assert "CURRENT_PROJECT_VERSION=2" in dry.stdout
    assert "MARKETING_VERSION=1.0.0" in dry.stdout
    assert "git_tag=v1.0.0+2" in dry.stdout
    assert "CURRENT_PROJECT_VERSION = 1;" in copy.read_text()

    first = run(copy, [], True)
    assert "CURRENT_PROJECT_VERSION=2" in first.stdout
    assert copy.read_text().count("CURRENT_PROJECT_VERSION = 2;") == 4
    assert "CURRENT_PROJECT_VERSION = 1;" not in copy.read_text()

    reuse = run(copy, ["--build-number", "2"], False)
    assert "never reuse or decrease" in reuse.stderr
    decrease = run(copy, ["--build-number", "1"], False)
    assert "never reuse or decrease" in decrease.stderr
    bad = run(copy, ["--build-number", "1.0"], False)
    assert "positive integer" in bad.stderr

    skip = run(copy, ["--build-number", "10"], True)
    assert "CURRENT_PROJECT_VERSION=10" in skip.stdout
    assert "version=1.0.0 (10)" in skip.stdout
    assert copy.read_text().count("CURRENT_PROJECT_VERSION = 10;") == 4

print("build bump helper ok")
PY

if [[ "$fail" -ne 0 ]]; then
  echo "verify-source failed"
  exit 1
fi

echo "verify-source passed"
