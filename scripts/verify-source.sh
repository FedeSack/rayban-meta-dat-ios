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
require "$root/GlassesDAT/GlassesDAT/Info.plist"
require "$root/GlassesDAT/GlassesDAT/Resources/mock-feed.mp4"
require "$root/GlassesDAT/GlassesDATTests/LatencyTests.swift"
require "$root/scripts/macos-archive-ipa.sh"
require "$root/scripts/exportOptions-development.plist"

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

if [[ "$fail" -ne 0 ]]; then
  echo "verify-source failed"
  exit 1
fi

echo "verify-source passed"
