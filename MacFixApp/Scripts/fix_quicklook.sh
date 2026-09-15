#!/bin/bash

echo "正在重置 Quick Look 预览服务..."

qlmanage -r
qlmanage -r cache

echo "正在重启 Finder..."
killall Finder

echo "完成！现在可以重新选中文件按空格预览。"
