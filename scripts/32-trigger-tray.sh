#!/bin/bash
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus

NC_PID=$(pgrep -x nextcloud | head -1)
echo "[*] nextcloud PID=$NC_PID"

echo "[*] 枚举所有 session bus 名，找 StatusNotifierItem"
NAMES=$(dbus-send --session --print-reply --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames 2>/dev/null \
  | grep -oE 'string "[^"]+"' | tr -d '"' | sed 's/^string //')

# 候选：org.kde.StatusNotifierItem-PID-NN
echo "[*] 候选 SNI 总线名:"
for n in $NAMES; do
  case "$n" in
    *StatusNotifierItem*) echo "    $n" ;;
  esac
done

echo
echo "[*] 逐个 introspect, 找 Nextcloud/owns pid=$NC_PID 的项"
for bus in $NAMES; do
  case "$bus" in
    *StatusNotifierItem*)
      out=$(dbus-send --session --print-reply --dest="$bus" /StatusNotifierItem org.freedesktop.DBus.Properties.GetAll string:org.kde.StatusNotifierItem 2>/dev/null)
      title=$(echo "$out" | grep -A1 '"Title"' | tail -1 | sed 's/.*"\(.*\)".*/\1/')
      icon=$(echo "$out" | grep -A1 '"IconName"' | tail -1 | sed 's/.*"\(.*\)".*/\1/')
      catid=$(echo "$out" | grep -A1 '"Id"' | tail -1 | sed 's/.*"\(.*\)".*/\1/')
      echo "    bus=$bus  Title='$title'  Id='$catid'  Icon='$icon'"
      if echo "$title $icon $catid" | grep -qiE 'nextcloud'; then
        echo "    >>> 匹配到 Nextcloud SNI: $bus"
        NC_BUS=$bus
      fi
      ;;
  esac
done

if [ -z "${NC_BUS:-}" ]; then
  echo "[!] 未找到 Nextcloud 的 StatusNotifierItem，无法自动触发"
  exit 0
fi

echo
echo "[*] 触发 Nextcloud SNI Activate(x=0,y=0) — 模拟单击托盘"
dbus-send --session --type=method_call --dest="$NC_BUS" /StatusNotifierItem org.kde.StatusNotifierItem.Activate int32:0 int32:0 2>&1 | head -3
sleep 4

echo "[*] 抓屏"
GEOM=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2}')
ffmpeg -y -f x11grab -r 1 -s "${GEOM}" -i :1.0 -frames:v 1 /tmp/nc-tray.png 2>/dev/null
ls -l /tmp/nc-tray.png

echo "[*] 像素分析 (是否出现 Nextcloud 蓝 #0082c9 与非白内容)"
python3 - <<'PY'
from PIL import Image
im = Image.open('/tmp/nc-tray.png').convert('RGB')
w,h = im.size
px = list(im.getdata())
nonwhite = sum(1 for r,g,b in px if not (r>245 and g>245 and b>245))
blue = sum(1 for r,g,b in px if r<80 and g>90 and g<170 and b>160)
dark = sum(1 for r,g,b in px if r<60 and g<60 and b<60)
print(f"  size={w}x{h}  nonwhite={round(nonwhite/(w*h),4)}  brand_blue={blue}  dark={dark}")
PY