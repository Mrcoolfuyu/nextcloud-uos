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
WID=$(xdotool search --class nextcloud 2>/dev/null | head -1)
echo "nextcloud 窗口 id: $WID"
if [ -n "$WID" ]; then
  xwd -id "$WID" -out /tmp/nc.xwd 2>/tmp/xwd.err && echo "xwd OK" || { echo "xwd 失败:"; cat /tmp/xwd.err; }
  ffmpeg -y -loglevel error -i /tmp/nc.xwd /tmp/nc-main.png 2>/tmp/ff.err && echo "PNG 转换 OK" || { echo "转换失败:"; cat /tmp/ff.err; }
else
  echo "未找到窗口，改抓全屏"
  ffmpeg -y -loglevel error -f x11grab -i :1 -frames:v 1 /tmp/nc-main.png 2>/tmp/ff.err && echo "全屏 OK" || cat /tmp/ff.err
fi
ls -l /tmp/nc-main.png 2>/dev/null
pkill -x nextcloud 2>/dev/null
echo done
