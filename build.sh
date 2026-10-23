#!/bin/bash
# Builds Sola Birthdays and installs it on your iPhone.
#
#   ./build.sh                  build for the iPhone and install it
#   ./build.sh --no-install     build for the iPhone, don't install
#   ./build.sh --install-only   don't build, install the last build
#   ./build.sh --sim            build for the simulator without signing (quick compile check)
#   ./build.sh --icloud         build with iCloud sync (needs a paid developer team)
#
# Environment:
#   DEVICE_ID   iPhone to install on (default: the one paired physical iPhone;
#               "xcrun devicectl list devices" shows the IDs)
#   TEAM_ID     Apple team for signing (default: SOLA_TEAM from Config/Config.xcconfig,
#               overridable in ../sola-local.xcconfig)
#   BUILD_DIR   builds and logs (default: /tmp/sola-build, shared with ../build-sola-apps.sh)
#
# For your own copy, set SOLA_TEAM and BUNDLE_ID_PREFIX in ../sola-local.xcconfig
# (see Config/Config.xcconfig). The free Personal Team can sign
# the app as long as you leave out --icloud.

APP_KEY=birthdays
NAME="Sola Birthdays"
SCHEME=SolaBirthdays
APPFILE="Sola Birthdays.app"

HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE" || exit 1
PROJECT="$SCHEME.xcodeproj"
OUT="${BUILD_DIR:-/tmp/sola-build}"   # keep out of ~/Documents, iCloud file attributes break code signing
DEVICE_APP="$OUT/$APP_KEY-device/Build/Products/Release-iphoneos/$APPFILE"

MODE=device
INSTALL=1
SETTINGS=()   # build settings passed to xcodebuild
[ -n "$TEAM_ID" ] && SETTINGS+=("SOLA_TEAM=$TEAM_ID")
for arg in "$@"; do
  case "$arg" in
    --no-install)   INSTALL=0 ;;
    --install-only) MODE=install ;;
    --sim)          MODE=sim ;;
    --icloud)       SETTINGS+=("SOLA_ICLOUD=YES") ;;
    -h|--help)      sed -n '2,/^$/p' "$HERE/$(basename "$0")" | sed -e '$d' -e 's/^# \{0,1\}//'; exit 0 ;;
    *)              echo "Unknown argument: $arg (see --help)"; exit 2 ;;
  esac
done

if [ "$MODE" = install ] && [ "$INSTALL" = 0 ]; then
  echo "--install-only and --no-install exclude each other."
  exit 2
fi
if ! command -v xcodebuild >/dev/null 2>&1; then
  echo "xcodebuild not found. Install Xcode and open it once."
  exit 1
fi
mkdir -p "$OUT"

FAILED=0
SUMMARY=""

# step "label" logfile command...
step() {
  local label="$1" log="$2"; shift 2
  printf '%-34s' "$label …"
  if "$@" >"$log" 2>&1; then
    echo "✓"
    SUMMARY="$SUMMARY
  ✓ $label"
    return 0
  else
    echo "✗"
    grep -E 'error:' "$log" | sort -u | head -5 | sed 's/^/    /'
    if grep -q "maximum App ID limit" "$log"; then
      echo "    The free Personal Team may register only 10 new App IDs per 7 days. Wait, or sign"
      echo "    with a paid team: TEAM_ID=<team> ./build.sh, or SOLA_TEAM in ../sola-local.xcconfig."
    fi
    echo "    Log: $log"
    SUMMARY="$SUMMARY
  ✗ $label"
    FAILED=1
    return 1
  fi
}

# Sets DEVICE_ID to the only paired physical iPhone unless it is already set.
find_device() {
  [ -n "$DEVICE_ID" ] && return 0
  local json
  json="$(mktemp)"
  xcrun devicectl list devices --quiet --json-output "$json" >/dev/null 2>&1
  DEVICE_ID="$(/usr/bin/python3 -I - "$json" <<'PY'
import json, sys
try:
    devices = json.load(open(sys.argv[1]))["result"]["devices"]
except Exception:
    devices = []
phones = [d for d in devices
          if d["hardwareProperties"].get("reality") == "physical"
          and d["hardwareProperties"].get("platform") == "iOS"
          and d["connectionProperties"].get("pairingState") == "paired"]
if len(phones) == 1:
    print(phones[0]["hardwareProperties"]["udid"])
PY
)"
  rm -f "$json"
  if [ -z "$DEVICE_ID" ]; then
    echo "Found no paired iPhone, or more than one. Pick one with DEVICE_ID=<id> ./build.sh"
    xcrun devicectl list devices
    return 1
  fi
}

install_device() {
  if [ ! -d "$DEVICE_APP" ]; then
    echo "$NAME: no iPhone build in $OUT, build first."
    SUMMARY="$SUMMARY
  ✗ $NAME on the iPhone (no build)"
    FAILED=1
    return 1
  fi
  find_device || { FAILED=1; return 1; }
  step "$NAME on the iPhone" "$OUT/$APP_KEY-install.log" \
    xcrun devicectl device install app --device "$DEVICE_ID" "$DEVICE_APP"
}

START=$(date +%s)
case "$MODE" in
  install)
    install_device
    ;;
  sim)
    step "$NAME (simulator)" "$OUT/$APP_KEY-sim.log" \
      xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Debug \
        -destination 'generic/platform=iOS Simulator' -derivedDataPath "$OUT/$APP_KEY-sim" \
        CODE_SIGNING_ALLOWED=NO "${SETTINGS[@]}" build
    ;;
  device)
    if step "$NAME (iPhone)" "$OUT/$APP_KEY-device.log" \
        xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release \
          -destination 'generic/platform=iOS' -derivedDataPath "$OUT/$APP_KEY-device" \
          -allowProvisioningUpdates "${SETTINGS[@]}" build; then
      [ "$INSTALL" = 1 ] && install_device
    fi
    ;;
esac

echo
echo "Done in $(( $(date +%s) - START )) s:$SUMMARY"
exit $FAILED
