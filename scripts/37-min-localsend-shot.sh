#!/bin/bash
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

echo "[*] 找 LocalSend 顶层窗口"
LS_ID=""
for id in $(xdotool search --name '' 2>/dev/null); do
  n=$(xdotool getwindowname "$id" 2>/dev/null)
  if echo "$n" | grep -q 'LocalSend'; then
    geom=$(xdotool getwindowgeometry "$id" 2>/dev/null | grep Position)
    echo "  候选 id=$id  name='$n'  $geom"
    LS_ID=$id
  fi
done
# 也试 classname
if [ -z "$LS_ID" ]; then
  LS_ID=$(xdotool search --classname 'localsend' 2>/dev/null | head -1)
  echo "  by classname: $LS_ID"
fi

echo "[*] 最小化 LocalSend"
if [ -n "$LS_ID" ]; then
  xdotool windowminimize "$LS_ID" 2>&1
  sleep 1
fi

echo "[*] Nextcloud 主窗口几何"
xdotool getwindowgeometry 106954764 2>&1 | head -8

echo "[*] 抓屏"
GEOM=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2}')
ffmpeg -y -f x11grab -r 1 -s "$GEOM" -i :1.0 -frames:v 1 /tmp/nc-clean.png 2>/dev/null
ls -l /tmp/nc-clean.png

echo "[*] Nextcloud 区域(60,80,1160,800) 像素"
python3 - <<'PY'
from PIL import Image
im = Image.open('/tmp/nc-clean.png').convert('RGB')
crop = im.crop((60,80,60+1100, 80+720))
w,h = crop.size
px = list(crop.getdata())
nonwhite = sum(1 for r,g,b in px if not (r>245 and g>245 and b>245))
blue = sum(1 for r,g,b in px if r<80 and g>90 and g<170 and b>160)
dark = sum(1 for r,g,b in px if r<60 and g<60 and b<60)
print(f"  crop={w}x{h}  nonwhite={round(nonwhite/(w*h),4)}  brand_blue={blue}  dark={dark}")
PY