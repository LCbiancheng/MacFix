#!/bin/bash
set -euo pipefail

# 一键重新编译并更新成品
# 用法：在 sh_file_macOS 目录下运行 bash rebuild.sh

cd "$(dirname "$0")"

APP_NAME="MacFix"
SRC="MacFixApp/build/${APP_NAME}.app"

echo "==> 编译源码"
(cd MacFixApp && bash build.sh)

echo "==> 更新根目录成品 ${APP_NAME}.app"
rm -rf "${APP_NAME}.app"
cp -R "${SRC}" "${APP_NAME}.app"

echo "==> 重新生成安装盘 ${APP_NAME}.dmg"
rm -rf /tmp/macfix_staging "${APP_NAME}.dmg"
mkdir -p /tmp/macfix_staging
cp -R "${SRC}" /tmp/macfix_staging/
ln -s /Applications /tmp/macfix_staging/Applications
hdiutil create -volname "${APP_NAME}" -srcfolder /tmp/macfix_staging -ov -format UDZO "${APP_NAME}.dmg" >/dev/null
rm -rf /tmp/macfix_staging

echo ""
echo "完成："
echo "  - 根目录成品：${APP_NAME}.app"
echo "  - 安装盘：${APP_NAME}.dmg"
echo ""
echo "如需更新启动台，请手动把 ${APP_NAME}.app 拖入 ~/Applications 覆盖。"
