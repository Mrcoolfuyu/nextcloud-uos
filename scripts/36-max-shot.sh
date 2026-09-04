#!/bin/bash
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

ID=106954764

echo "[*] 当前主窗口几何"
xdotool getwindowgeometry "$ID" 2>&1 | head -8

echo "[*] 尝试 Super+Up 最大化"
xdotool key --window "$ID" super+Up 2>&1
sleep 2
xdotool key --window "$ID" super+Up 2>&1
sleep 2

echo "[*] 之后几何"
xdotool getwindowgeometry "$ID" 2>&1 | head -8

GEOM=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2}')
echo "[*] 抓屏 $GEOM"
ffmpeg -y -f x11grab -r 1 -s "$GEOM" -i :1.0 -frames:v 1 /tmp/nc-max.png 2>/dev/null
ls -l /tmp/nc-max.png