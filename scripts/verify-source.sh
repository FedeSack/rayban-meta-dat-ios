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
require "$root/GlassesDAT/GlassesDAT/Info.plist"
require "$root/GlassesDAT/GlassesDAT/Resources/mock-feed.mp4"
require "$root/GlassesDAT/GlassesDATTests/LatencyTests.swift"

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

if ! rg -q 'https://github.com/facebook/meta-wearables-dat-ios' "$pbx"; then
  echo "pbxproj missing official DAT SPM URL"
  fail=1
fi

if ! rg -q 'version = 0.9.0' "$pbx"; then
  echo "pbxproj missing DAT 0.9.0 pin"
  fail=1
fi

for source in GlassesDATApp.swift Session.swift Stream.swift Latency.swift GlassesSession.swift MockPath.swift RootView.swift ConnectView.swift LiveView.swift FrameSurface.swift LatencyHUD.swift DatButtonStyle.swift LatencyTests.swift mock-feed.mp4; do
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
