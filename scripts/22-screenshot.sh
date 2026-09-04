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
sleep 6
WIDS=$(xdotool search --class nextcloud 2>/dev/null)
echo "nextcloud 窗口: $WIDS"
MAIN=$(echo "$WIDS" | head -1)
import -window "$MAIN" /tmp/nc-main.png 2>/tmp/import.err && echo "截图成功" || { echo "截图失败:"; cat /tmp/import.err; }
ls -l /tmp/nc-main.png 2>/dev/null
pkill -x nextcloud 2>/dev/null
echo "done"
