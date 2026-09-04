#!/bin/bash
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

PID=$(pgrep -x nextcloud | head -1)
echo "nextcloud PID=$PID"
echo "===== 进程环境(过滤) ====="
tr '\0' '\n' < /proc/$PID/environ 2>/dev/null | grep -E '^(LD_LIBRARY|QT_|LIBGL|XDG_|XAUTHORITY|DISPLAY|DBUS|QML)' | sort

echo
echo "===== 所有含 next/cloud 的 dbus 服务 ====="
dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames 2>&1 | grep -iE 'next|cloud|tray|deskt'

echo
echo "===== 日志关键关键字(本次启动) ====="
grep -aiE 'OpenGL|libgl|xcb|scenegraph|integration|fail|error|qt.qpa|EGL' /tmp/nc-verify.log 2>/dev/null | head -15
echo "---"
grep -aiE 'OpenGL|libgl|xcb|scenegraph|integration|fail|error|qt.qpa|EGL' ~/.cache/Nextcloud/nextcloud.log 2>/dev/null | tail -15
echo "---"
ls /home/mrcool/.cache/Nextcloud/ 2>/dev/null