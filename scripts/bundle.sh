#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
(cd assets/sounds && shasum -a 256 -c manifest.sha256 > /dev/null)
zig build --release=small
version=$(cat VERSION)
# Apple's bundle version fields use the numeric version.
bundle_version=${version%%-*}
bundle_version=${bundle_version%%+*}
bundle="dist/Soundy Minified.app"
mkdir -p "$bundle/Contents/MacOS"
cp zig-out/bin/soundy-minified "$bundle/Contents/MacOS/soundy-minified.new"
mv "$bundle/Contents/MacOS/soundy-minified.new" "$bundle/Contents/MacOS/soundy-minified"
cp macos/Info.plist "$bundle/Contents/Info.plist"
mkdir -p "$bundle/Contents/Resources"
cp assets/icons/Soundy.icns "$bundle/Contents/Resources/Soundy.icns"
ditto assets/sounds "$bundle/Contents/Resources/Sounds"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $bundle_version" "$bundle/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $bundle_version" "$bundle/Contents/Info.plist"
codesign --force --sign - --identifier dev.soundy.minified.app "$bundle"
codesign --verify --strict "$bundle"
printf 'Built %s/dist/Soundy Minified.app\n' "$PWD"
