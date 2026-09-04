#!/bin/bash
# L420x Nextcloud 移植 - 环境审计脚本
echo "===== 1. 依赖包状态 ====="
for p in libgl1-mesa-dev libssl-dev zlib1g-dev libsqlite3-dev pkg-config \
         libsecret-1-dev build-essential git curl cmake ninja-build python3 \
         libxkbcommon-dev libxcb1-dev libxcb-keysyms1-dev libxcb-image0-dev \
         libxcb-shm0-dev libxcb-icccm4-dev libxcb-sync-dev libxcb-xfixes0-dev \
         libxcb-shape0-dev libxcb-randr0-dev libxcb-render-util0-dev \
         libxcb-xinerama0-dev libxcb-xkb-dev libxkbcommon-x11-dev \
         libfontconfig1-dev libfreetype6-dev libxi-dev libxrender-dev \
         libdbus-1-dev libglib2.0-dev libpng-dev libjpeg-dev \
         libicu-dev libpcre2-dev libdouble-conversion-dev libzstd-dev; do
  if dpkg -s "$p" >/dev/null 2>&1; then echo "  [OK]      $p"; else echo "  [MISSING] $p"; fi
done

echo ""
echo "===== 2. apt 中可用的 Qt 版本 ====="
for q in qtbase5-dev qtbase5-private-dev qtdeclarative5-dev libqt5svg5-dev \
         qtquickcontrols2-5-dev qml-module-qtquick-controls2 qml-module-qtgraphicaleffects \
         qt5-qmake qtbase5-dev-tools; do
  printf "  %-38s " "$q"
  apt-cache policy "$q" 2>/dev/null | awk '/已安装|Installed/{i=$2} /候选|Candidate/{c=$2} END{print "installed="i"  candidate="c}'
done

echo ""
echo "===== 3. 系统 Qt 现状 ====="
qmake --version 2>&1 | head -3
echo "  -- 系统 QML 模块 --"
ls /usr/lib/aarch64-linux-gnu/qt5/qml/ 2>/dev/null | tr '\n' ' '; echo
echo "  -- 系统 Qt plugins --"
ls /usr/lib/aarch64-linux-gnu/qt5/plugins/platforms/ 2>/dev/null | tr '\n' ' '; echo

echo ""
echo "===== 4. 磁盘 ====="
df -h / /home /opt /tmp 2>/dev/null

echo ""
echo "===== 5. NAS 上的 Nextcloud 服务端探测 ====="
for url in "http://192.168.50.100/status.php" \
           "https://192.168.50.100/status.php" \
           "http://192.168.50.100:8080/status.php" \
           "http://192.168.50.100/nextcloud/status.php" \
           "http://192.168.50.100:8088/status.php" \
           "http://192.168.50.100:8888/status.php"; do
  code=$(curl -s -o /tmp/_st.json -w "%{http_code}" -m 8 "$url" 2>/dev/null)
  if [ "$code" = "200" ]; then
    echo "  [FOUND] $url"
    head -c 400 /tmp/_st.json; echo
  else
    echo "  [$code]  $url"
  fi
done
rm -f /tmp/_st.json

echo ""
echo "===== 6. 编译器/工具 ====="
gcc --version | head -1
g++ --version | head -1
cmake --version | head -1
ldd --version | head -1
echo "  nproc = $(nproc)"
