#!/bin/bash
# L420x - 安装 Qt 5.15.2 编译依赖
export DEBIAN_FRONTEND=noninteractive

run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

echo "===== sudo 自检 ====="
if sudo -n true 2>/dev/null; then
  echo "  sudo 免密可用"
else
  echo "  sudo 需要密码，使用提供的口令"
fi
run_sudo id -u

echo ""
echo "===== apt-get update ====="
run_sudo apt-get update -o Acquire::Retries=3 2>&1 | tail -8

PKGS="
libsqlite3-dev
libsecret-1-dev
build-essential
libxcb-keysyms1-dev
libxcb-image0-dev
libxcb-shm0-dev
libxcb-icccm4-dev
libxcb-sync-dev
libxcb-xfixes0-dev
libxcb-shape0-dev
libxcb-randr0-dev
libxcb-render-util0-dev
libxcb-xinerama0-dev
libxcb-xkb-dev
libxkbcommon-x11-dev
libfontconfig1-dev
libfreetype6-dev
libxi-dev
libxrender-dev
libdbus-1-dev
libicu-dev
libpcre2-dev
libdouble-conversion-dev
libzstd-dev
libegl1-mesa-dev
libgbm-dev
libinput-dev
libudev-dev
libmtdev-dev
libts-dev
libsystemd-dev
libxslt1-dev
libharfbuzz-dev
libgl1-mesa-dev
libglu1-mesa-dev
libssl-dev
zlib1g-dev
pkg-config
ninja-build
"

echo ""
echo "===== 开始安装 ====="
run_sudo apt-get install -y --no-install-recommends $PKGS 2>&1 | tail -40

echo ""
echo "===== 安装后校验 ====="
FAIL=0
for p in $PKGS; do
  if ! dpkg -s "$p" >/dev/null 2>&1; then echo "  [STILL MISSING] $p"; FAIL=1; fi
done
if [ $FAIL -eq 0 ]; then echo "  全部依赖已就位"; else echo "  存在未装成功的包，见上"; fi
