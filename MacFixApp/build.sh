#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

APP_NAME="MacFix"
BUILD_DIR="build"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS="${APP_DIR}/Contents"

echo "==> 清理旧构建"
rm -rf "${APP_DIR}" "${BUILD_DIR}/AppIcon.iconset" "${BUILD_DIR}/AppIcon.png"
mkdir -p "${CONTENTS}/MacOS" "${CONTENTS}/Resources/Scripts"

echo "==> 编译 Swift 源码"
swiftc -O \
    -framework SwiftUI \
    -framework AppKit \
    Sources/App.swift Sources/Support.swift \
    -o "${CONTENTS}/MacOS/${APP_NAME}"

echo "==> 复制脚本"
cp Scripts/*.sh "${CONTENTS}/Resources/Scripts/"
chmod +x "${CONTENTS}/Resources/Scripts/"*.sh

echo "==> 复制资源"
cp Assets/* "${CONTENTS}/Resources/"

echo "==> 复制 Info.plist"
cp Info.plist "${CONTENTS}/Info.plist"

echo "==> 生成应用图标"
swift generate_icon.swift "${BUILD_DIR}/AppIcon.png"

ICONSET="${BUILD_DIR}/AppIcon.iconset"
mkdir -p "${ICONSET}"
sips -z 16 16     "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_16x16.png" >/dev/null
sips -z 32 32     "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_16x16@2x.png" >/dev/null
sips -z 32 32     "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_32x32.png" >/dev/null
sips -z 64 64     "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_32x32@2x.png" >/dev/null
sips -z 128 128   "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_128x128.png" >/dev/null
sips -z 256 256   "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_128x128@2x.png" >/dev/null
sips -z 256 256   "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_256x256.png" >/dev/null
sips -z 512 512   "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_256x256@2x.png" >/dev/null
sips -z 512 512   "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${BUILD_DIR}/AppIcon.png" --out "${ICONSET}/icon_512x512@2x.png" >/dev/null
iconutil -c icns "${ICONSET}" -o "${CONTENTS}/Resources/AppIcon.icns"

echo "==> 签名（ad-hoc）"
codesign --force --sign - "${APP_DIR}"

echo ""
echo "构建完成：$(cd "${BUILD_DIR}" && pwd)/${APP_NAME}.app"
