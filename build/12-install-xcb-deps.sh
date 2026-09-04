#!/bin/bash
# L420x - 补装 Qt xcb 平台插件所需的 X11-XCB 桥接库（逐个安装，跳过不存在的包）
export DEBIAN_FRONTEND=noninteractive
run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

PKGS="libx11-xcb-dev libxcb-xinput-dev libxcb-util0-dev libsm-dev libice-dev libxext-dev libx11-dev libxcb-render-util0-dev libxcb-render0-dev libxcb-glx0-dev"

echo "===== 逐个安装 ====="
for p in $PKGS; do
  if dpkg -s "$p" >/dev/null 2>&1; then
    echo "  [已装]     $p"
    continue
  fi
  if run_sudo apt-get install -y --no-install-recommends "$p" >/tmp/_apt.log 2>&1; then
    echo "  [新装]     $p"
  else
    echo "  [源中无]   $p  ($(grep -m1 '^E:' /tmp/_apt.log 2>/dev/null | cut -c1-60))"
  fi
done
rm -f /tmp/_apt.log

echo ""
echo "===== 关键库校验（Qt xcb 插件依赖）====="
echo "-- libX11-xcb --"
ls -l /usr/lib/aarch64-linux-gnu/libX11-xcb.so* 2>/dev/null | head -3 || echo "  !! 缺失 libX11-xcb"
echo "-- xcb 辅助库 --"
for l in xcb-icccm xcb-image xcb-keysyms xcb-randr xcb-render-util xcb-shape xcb-shm xcb-sync xcb-xfixes xcb-xinerama xcb-xkb xcb-xinput xcb-glx xcb-util; do
  if ls /usr/lib/aarch64-linux-gnu/lib${l}.so >/dev/null 2>&1; then echo "  [OK]      lib$l"; else echo "  [无]      lib$l"; fi
done
echo "-- 头文件 --"
for h in X11/Xlib-xcb.h xcb/xcb.h xcb/xcb_icccm.h xcb/xcb_keysyms.h; do
  [ -f "/usr/include/$h" ] && echo "  [OK]      $h" || echo "  [无]      $h"
done
