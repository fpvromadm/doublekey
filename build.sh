#!/bin/zsh
# ./build.sh          build build/DoubleKey.app (universal: arm64 + x86_64)
# ./build.sh test     run the debounce logic tests
# ./build.sh install  build, copy to /Applications and start it
#
# Signing: uses $SIGN_ID if set, else the "DoubleKey Local Signing" certificate
# if you made one (scripts/make-signing-cert.sh), else ad-hoc. A stable
# certificate keeps the Accessibility permission across rebuilds; with ad-hoc
# signing you grant it again after each rebuild.
set -euo pipefail
cd "${0:A:h}"

if [[ "${1:-}" == test ]]; then
  mkdir -p build
  swiftc -O Sources/Debouncer.swift Tests/main.swift -o build/tests
  exec build/tests
fi

APP=build/DoubleKey.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for arch in arm64 x86_64; do
  swiftc -O -target $arch-apple-macos13.0 Sources/*.swift -o build/DoubleKey-$arch
done
lipo -create build/DoubleKey-arm64 build/DoubleKey-x86_64 -output "$APP/Contents/MacOS/DoubleKey"
rm build/DoubleKey-arm64 build/DoubleKey-x86_64
cp Resources/Info.plist "$APP/Contents/"

if [[ ! -f build/AppIcon.icns ]]; then
  ICONSET=build/AppIcon.iconset
  mkdir -p $ICONSET
  swift scripts/make-icon.swift build/icon.png
  for s in 16 32 128 256 512; do
    sips -z $s $s build/icon.png --out $ICONSET/icon_${s}x${s}.png >/dev/null
    sips -z $((s*2)) $((s*2)) build/icon.png --out $ICONSET/icon_${s}x${s}@2x.png >/dev/null
  done
  iconutil -c icns $ICONSET -o build/AppIcon.icns
  rm -rf $ICONSET build/icon.png
fi
cp build/AppIcon.icns "$APP/Contents/Resources/"

if [[ -z "${SIGN_ID:-}" ]] && security find-identity -v -p codesigning | grep -q '"DoubleKey Local Signing"'; then
  SIGN_ID="DoubleKey Local Signing"
fi
codesign --force --sign "${SIGN_ID:--}" "$APP"
echo "Built $APP (signed with: ${SIGN_ID:-ad-hoc})"

if [[ "${1:-}" == install ]]; then
  pkill -x DoubleKey || true
  rm -rf /Applications/DoubleKey.app
  cp -R "$APP" /Applications/
  open /Applications/DoubleKey.app
  echo "Installed to /Applications and started"
fi
