#!/bin/bash
set -u
NC=/opt/nextcloud
QT=/opt/qt515
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export LD_LIBRARY_PATH=$NC/lib:$QT/lib
export QT_PLUGIN_PATH=$QT/plugins
export QML2_IMPORT_PATH=$QT/qml
export QT_QPA_PLATFORM_PLUGIN_PATH=$QT/plugins/platforms
export LIBGL_ALWAYS_SOFTWARE=1

pkill -x nextcloud 2>/dev/null; sleep 2
setsid "$NC/bin/nextcloud" >/tmp/nc-bg.log 2>&1 < /dev/null &
sleep 7
# 把 nextcloud 窗口提到前台（若存在）
WID=$(xdotool search --class nextcloud 2>/dev/null | head -1)
[ -n "$WID" ] && xdotool windowactivate "$WID" 2>/dev/null
sleep 2
ffmpeg -y -loglevel error -f x11grab -i :1 -frames:v 1 /tmp/screen.png 2>/tmp/ff.err && echo "全屏截图 OK" || { echo "失败:"; cat /tmp/ff.err; }
ls -l /tmp/screen.png 2>/dev/null
pkill -x nextcloud 2>/dev/null
echo done
