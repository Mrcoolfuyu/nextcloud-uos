#!/bin/bash
set -u
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority

echo "[*] 关闭旧实例"
pkill -x nextcloud 2>/dev/null
sleep 2

echo "[*] 用修正后的启动器拉起（LIBGL_ALWAYS_SOFTWARE=1）"
setsid /opt/nextcloud/bin/nextcloud-uos.sh > /tmp/nc-verify.log 2>&1 < /dev/null &
sleep 10

echo "[*] 尝试通过 D-Bus 打开主对话框"
dbus-send --session --dest=com.nextcloud.desktopclient --type=method_call /OpenMainDialog com.nextcloud.desktopclient.openMainDialog 2>/dev/null && echo "  dbus openMainDialog ok" || echo "  dbus 方法未触发（可能已自动显示）"
sleep 4

echo "[*] 抓取屏幕 :1"
GEOM=$(xdpyinfo 2>/dev/null | awk '/dimensions:/{print $2}')
W=${GEOM%x*}; H=${GEOM#*x}
echo "  分辨率: ${W}x${H}"
ffmpeg -y -f x11grab -r 1 -s "${W}x${H}" -i :1.0 -frames:v 1 /tmp/nc-screen.png 2>/dev/null
ls -l /tmp/nc-screen.png

echo "[*] 像素分析"
python3 - <<'PY'
from PIL import Image
try:
    im = Image.open('/tmp/nc-screen.png').convert('RGB')
except Exception as e:
    print("  截图读取失败:", e); raise SystemExit
w,h = im.size
px = list(im.getdata())
nonwhite = sum(1 for r,g,b in px if not (r>245 and g>245 and b>245))
print("  尺寸", w, h, "| 非白像素比例", round(nonwhite/(w*h),4))
colors = im.getcolors(maxcolors=3000000)
print("  不同颜色数", len(colors) if colors else ">=3000000")
# Nextcloud 品牌蓝 ~ (0,130,201) #0082c9
blue = sum(1 for r,g,b in px if r<80 and g>90 and g<170 and b>160)
print("  品牌蓝像素数", blue)
# 文本/暗色像素（侧边栏、文字）
dark = sum(1 for r,g,b in px if r<60 and g<60 and b<60)
print("  暗色(文字/侧栏)像素数", dark)
PY

echo "[*] 进程存活检查"
pgrep -x nextcloud >/dev/null && echo "  nextcloud 运行中" || echo "  nextcloud 未运行"
echo "[*] 日志关键行"
grep -aiE "Qt platform plugin|xcb|OpenGL|scenegraph|context|error|fail" /tmp/nc-verify.log | head -10 || true
