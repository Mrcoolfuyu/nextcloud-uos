#!/bin/bash
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

ID=106954764  # Nextcloud 真主窗口（位置 1382,8 那个）
echo "[*] 移到 (60,80) 并设为 1100x720"
xdotool windowmove "$ID" 60 80
xdotool windowsize "$ID" 1100 720
sleep 3

GEOM=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2}')
echo "[*] 抓屏 ${GEOM}"
ffmpeg -y -f x11grab -r 1 -s "${GEOM}" -i :1.0 -frames:v 1 /tmp/nc-real2.png 2>/dev/null
ls -l /tmp/nc-real2.png

python3 - <<'PY'
from PIL import Image
im = Image.open('/tmp/nc-real2.png').convert('RGB')
crop = im.crop((60,80,60+1100, 80+720))
w,h = crop.size
px = list(crop.getdata())
nonwhite = sum(1 for r,g,b in px if not (r>245 and g>245 and b>245))
blue = sum(1 for r,g,b in px if r<80 and g>90 and g<170 and b>160)
dark = sum(1 for r,g,b in px if r<60 and g<60 and b<60)
colors = crop.getcolors(maxcolors=1000000)
print(f"  crop={w}x{h}  nonwhite={round(nonwhite/(w*h),4)}  brand_blue={blue}  dark={dark}  colors={len(colors) if colors else 'many'}")
PY