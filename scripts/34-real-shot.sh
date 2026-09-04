#!/bin/bash
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

NC_BUS=org.kde.StatusNotifierItem-252109-1

echo "[*] 当前 Nextcloud 真主窗口列表"
for id in $(xdotool search --name '' 2>/dev/null); do
  name=$(xdotool getwindowname "$id" 2>/dev/null)
  if echo "$name" | grep -qE '^Nextcloud$|Qt Selection Owner|Qt Clipboard'; then
    geom=$(xdotool getwindowgeometry "$id" 2>/dev/null | grep -E 'Position|Size' | tr '\n' ' ')
    echo "  id=$id  name='$name'  $geom"
  fi
done

echo
echo "[*] 找位置最靠右/下的 Nextcloud 真主窗口（标题=Nextcloud, 非 Selection/Clipboard）"
MAIN_ID=""
for id in $(xdotool search --name 'Nextcloud' 2>/dev/null); do
  name=$(xdotool getwindowname "$id" 2>/dev/null)
  if [ "$name" = "Nextcloud" ]; then
    pos=$(xdotool getwindowgeometry "$id" 2>/dev/null | awk '/Position:/{print $2}')
    echo "  候选 id=$id  Position=$pos"
    # 取位置最靠右的
    if [ -z "$MAIN_ID" ] || [ "${pos#*:}" != "${pos}" ]; then
      # 简单策略——选最后一个
      MAIN_ID=$id
    fi
  fi
done
echo "  -> 选中 MAIN_ID=$MAIN_ID"

if [ -z "$MAIN_ID" ]; then
  echo "[!] 没找到真主窗口——SNI 触发一次再试"
  dbus-send --session --type=method_call --dest="$NC_BUS" /StatusNotifierItem org.kde.StatusNotifierItem.Activate int32:0 int32:0 >/dev/null 2>&1
  sleep 3
  MAIN_ID=$(xdotool search --name 'Nextcloud' 2>/dev/null | while read id; do
    n=$(xdotool getwindowname "$id" 2>/dev/null); [ "$n" = "Nextcloud" ] && echo "$id"; done | head -1)
  echo "  重找 MAIN_ID=$MAIN_ID"
fi

echo
echo "[*] 把主窗口拉到 1100x720, 居中 (60,80)"
xdotool windowmove "$MAIN_ID" 60 80 2>&1
xdotool windowsize "$MAIN_ID" 1100 720 2>&1
sleep 3

echo "[*] 抓屏"
GEOM=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2}')
ffmpeg -y -f x11grab -r 1 -s "${GEOM}" -i :1.0 -frames:v 1 /tmp/nc-real.png 2>/dev/null
ls -l /tmp/nc-real.png

echo "[*] 在主窗口区域(60,80,1160,800) 像素分析"
python3 - <<'PY'
from PIL import Image
im = Image.open('/tmp/nc-real.png').convert('RGB')
crop = im.crop((60,80,1160,800))
w,h = crop.size
px = list(crop.getdata())
nonwhite = sum(1 for r,g,b in px if not (r>245 and g>245 and b>245))
blue = sum(1 for r,g,b in px if r<80 and g>90 and g<170 and b>160)
dark = sum(1 for r,g,b in px if r<60 and g<60 and b<60)
print(f"  crop={w}x{h}  nonwhite={round(nonwhite/(w*h),4)}  brand_blue={blue}  dark={dark}")
PY