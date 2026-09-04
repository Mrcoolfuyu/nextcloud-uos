#!/bin/bash
# 检查 entries 布局与潜在双入口
APPID=com.cnraft.nextcloud
echo "=== 已安装系统的 entries 目录 ==="
find /opt/apps/$APPID/entries -type f -o -type l 2>/dev/null
echo
echo "=== /usr/share/applications 中的 nextcloud 相关入口 ==="
ls -l /usr/share/applications/ | grep -i nextcloud
echo
echo "=== 桌面目录 ==="
ls -l ~/Desktop/ | grep -i nextcloud
echo
echo "=== dpkg 包内文件清单（entries 部分）==="
dpkg -L $APPID 2>/dev/null | grep entries
echo
echo "=== 图标安装情况 ==="
ls -l /usr/share/icons/hicolor/256x256/apps/nextcloud.png 2>&1
ls -l /opt/apps/$APPID/entries/icons/hicolor/*/apps/ 2>/dev/null
