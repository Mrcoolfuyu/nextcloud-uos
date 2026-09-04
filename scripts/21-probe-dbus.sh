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

QDBUS=$(command -v qdbus || ls $QT/bin/qdbus 2>/dev/null || echo "")
echo "qdbus: ${QDBUS:-NONE}"

pkill -x nextcloud 2>/dev/null; sleep 2
"$NC/bin/nextcloud" >/tmp/nc-bg.log 2>&1 &
sleep 5
echo "=== running? ==="
pgrep -x nextcloud | head -1

echo "=== dbus services ==="
if [ -n "$QDBUS" ]; then
  "$QDBUS" 2>/dev/null | grep -i nextcloud || echo "  (无 nextcloud 服务)"
  echo "=== 尝试列举 /Gui 方法 ==="
  "$QDBUS" com.nextcloud.desktop /Gui 2>/dev/null | grep -iE "raise|show|main|dialog|window" || echo "  (无法列举 /Gui)"
fi
echo "=== xdotool 找窗口 ==="
xdotool search --class nextcloud 2>/dev/null | head -3 || echo "  (无窗口)"
echo "done"
