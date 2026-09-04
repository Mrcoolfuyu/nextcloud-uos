#!/bin/bash
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

NC_BUS=org.kde.StatusNotifierItem-252109-1

echo "[*] 枚举 Nextcloud 全部顶层 X11 窗口"
# 这次用 _NET_CLIENT_LIST 或 wmctrl
WM_LIST=$(xdotool search --name '' 2>/dev/null)
for id in $WM_LIST; do
  name=$(xdotool getwindowname "$id" 2>/dev/null)
  geom=$(xdotool getwindowgeometry "$id" 2>/dev/null | grep -E 'Position|Size' | tr '\n' ' ')
  echo "  id=$id  name='$name'  $geom"
done

echo
echo "[*] 找 Nextcloud 主窗口（按标题包含 Nextcloud）"
NC_WIN=$(xdotool search --name 'Nextcloud' 2>/dev/null | head -1)
echo "  NC_WIN=$NC_WIN"

if [ -z "$NC_WIN" ]; then
  echo "[!] 仍找不到 Nextcloud 顶层窗口。重新触发 SNI + 再找"
  dbus-send --session --type=method_call --dest="$NC_BUS" /StatusNotifierItem org.kde.StatusNotifierItem.Activate int32:0 int32:0 >/dev/null 2>&1
  sleep 3
  NC_WIN=$(xdotool search --name 'Nextcloud' 2>/dev/null | head -1)
  echo "  重找 NC_WIN=$NC_WIN"
fi

if [ -n "$NC_WIN" ]; then
  echo "[*] 把 Nextcloud 主窗口拉到 1000x700 放到 (60,80)"
  xdotool windowsize "$NC_WIN" 1000 700 2>&1
  xdotool windowmove "$NC_WIN" 60 80 2>&1
  sleep 2
fi

echo "[*] 抓屏"
GEOM=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2}')
ffmpeg -y -f x11grab -r 1 -s "${GEOM}" -i :1.0 -frames:v 1 /tmp/nc-final.png 2>/dev/null
ls -l /tmp/nc-final.png

echo "[*] 在 1000x700 区域(60,80) 做像素分析"
python3 - <<'PY'
from PIL import Image
im = Image.open('/tmp/nc-final.png').convert('RGB')
# 在 (60,80) 起 1000x700 区域做采样
crop = im.crop((60,80,60+1000, 80+700))
w,h = crop.size
px = list(crop.getdata())
nonwhite = sum(1 for r,g,b in px if not (r>245 and g>245 and b>245))
blue = sum(1 for r,g,b in px if r<80 and g>90 and g<170 and b>160)
dark = sum(1 for r,g,b in px if r<60 and g<60 and b<60)
print(f"  crop={w}x{h}  nonwhite={round(nonwhite/(w*h),4)}  brand_blue={blue}  dark={dark}")
PY