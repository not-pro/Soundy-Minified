#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
sh scripts/bundle.sh
version=$(cat VERSION)
arch=$(uname -m)
bundle="dist/Soundy Minified.app"
lipo "$bundle/Contents/MacOS/soundy-minified" -verify_arch "$arch"
"$bundle/Contents/MacOS/soundy-minified" --check

staging=$(mktemp -d "${TMPDIR:-/tmp}/soundy-installer.XXXXXX")
trap 'rm -rf "$staging"' EXIT HUP INT TERM
mkdir -p "$staging/root" "$staging/resources"
ditto "$bundle" "$staging/root/Soundy Minified.app"
pkgbuild --root "$staging/root" --component-plist macos/installer/components.plist \
    --install-location /Applications --identifier dev.soundy.minified.app --version "$version" \
    "$staging/Soundy-Minified-component.pkg"
swift -module-cache-path .zig-cache/installer-swift-cache scripts/installer-pages.swift "$staging/resources"
sed "s/@VERSION@/$version/g; s/@ARCH@/$arch/g" macos/installer/Distribution.xml > "$staging/Distribution.xml"
productbuild --distribution "$staging/Distribution.xml" --package-path "$staging" \
    --resources "$staging/resources" "$staging/product.pkg"
# productbuild cannot import RTFD directories. Add the self-contained native pages
# after it has generated package metadata; the signed application payload is unchanged.
pkgutil --expand "$staging/product.pkg" "$staging/product"
ditto "$staging/resources/welcome.rtfd" "$staging/product/Resources/welcome.rtfd"
ditto "$staging/resources/conclusion.rtfd" "$staging/product/Resources/conclusion.rtfd"
python3 - "$staging/product/Distribution" <<'PY'
import sys
import xml.etree.ElementTree as ET
document = ET.parse(sys.argv[1])
for name in ("welcome", "conclusion"):
    element = document.getroot().find(name)
    element.attrib.clear()
    element.attrib.update(file=name + ".rtfd", uti="com.apple.rtfd")
document.write(sys.argv[1], encoding="utf-8", xml_declaration=True)
PY
pkgutil --flatten "$staging/product" "dist/Soundy-Minified-v${version}-macos-${arch}.pkg"

cd dist
archive="Soundy-Minified-v${version}-macos-${arch}"
ditto -c -k --sequesterRsrc --keepParent "Soundy Minified.app" "$archive.zip"
shasum -a 256 "$archive.pkg" > "$archive.pkg.sha256"
shasum -a 256 "$archive.zip" > "$archive.zip.sha256"
printf 'Packaged %s.pkg and %s.zip\n' "$archive" "$archive"
