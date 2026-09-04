#!/bin/bash
# 修复 v3：usr-merge 路径回退（/lib -> /usr/lib -> */basename）
set -uo pipefail

APPID=com.cnraft.nextcloud
VER=3.13.4.0
ARCH=arm64
WORK="$HOME/packaging/${APPID}-${VER}"
PKGROOT="$WORK/opt/apps/$APPID"
DEB="$HOME/packaging/${APPID}_${VER}_${ARCH}.deb"

run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

run_sudo chown -R mrcool:mrcool "$WORK" || { echo "!!!! work 目录不存在"; exit 1; }

export LD_LIBRARY_PATH="$PKGROOT/files/nextcloud/lib:$PKGROOT/files/qt/lib"
LIBS=$(mktemp)
{
  ldd "$PKGROOT/files/nextcloud/bin/nextcloud" 2>/dev/null
  ldd "$PKGROOT/files/nextcloud/bin/nextcloudcmd" 2>/dev/null
  for f in "$PKGROOT"/files/nextcloud/lib/libnextcloudsync.so* \
           "$PKGROOT"/files/nextcloud/lib/libqt5keychain.so* \
           "$PKGROOT"/files/qt/plugins/platforms/*.so \
           "$PKGROOT"/files/qt/plugins/xcbglintegrations/*.so \
           "$PKGROOT"/files/qt/plugins/imageformats/*.so \
           "$PKGROOT"/files/qt/plugins/sqldrivers/*.so \
           "$PKGROOT"/files/qt/lib/libQt5Core.so.5 \
           "$PKGROOT"/files/qt/lib/libQt5Gui.so.5 \
           "$PKGROOT"/files/qt/lib/libQt5Widgets.so.5 \
           "$PKGROOT"/files/qt/lib/libQt5Network.so.5 \
           "$PKGROOT"/files/qt/lib/libQt5Quick.so.5 \
           "$PKGROOT"/files/qt/lib/libQt5Qml.so.5 \
           "$PKGROOT"/files/qt/lib/libQt5Svg.so.5 \
           "$PKGROOT"/files/qt/lib/libQt5DBus.so.5 \
           "$PKGROOT"/files/qt/lib/libQt5WebSockets.so.5; do
    [ -f "$f" ] && ldd "$f" 2>/dev/null
  done
} | awk '/=> \//{print $3}' | sort -u | grep -v "/opt/apps/$APPID" > "$LIBS"
echo "[*] 外部库总数: $(wc -l < "$LIBS")"

map_pkg() {
  local lib="$1" out=""
  out=$(dpkg-query -S -- "$lib" 2>/dev/null) || out=""
  if [ -z "$out" ]; then
    local alt="${lib/#\/lib\//\/usr\/lib/}"
    out=$(dpkg-query -S -- "$alt" 2>/dev/null) || out=""
  fi
  if [ -z "$out" ]; then
    out=$(dpkg-query -S -- "*/$(basename "$lib")" 2>/dev/null) || out=""
  fi
  printf '%s' "$out" | awk -F: 'NR==1{print $1}'
}

DEPLIST=""
UNMAPPED=""
while IFS= read -r lib; do
  [ -n "$lib" ] || continue
  pkg=$(map_pkg "$lib")
  if [ -n "$pkg" ]; then
    DEPLIST="$DEPLIST $pkg"
  else
    UNMAPPED="$UNMAPPED$lib"$'\n'
  fi
done < "$LIBS"

echo "[*] 未映射库:"
echo "${UNMAPPED:-  (无)}" | head -15

for extra in libgl1-mesa-dri libdbus-1-3 libglib2.0-0 libxkbcommon-x11-0; do
  dpkg-query -W -f='${Status}' "$extra" 2>/dev/null | grep -q "install ok installed" \
    && DEPLIST="$DEPLIST $extra"
done

DEPS=$(echo $DEPLIST | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
[ -n "$DEPS" ] || { echo "!!!! 依赖计算为空"; exit 1; }
echo "[*] 最终 Depends: $DEPS"

ISIZE=$(du -sk "$PKGROOT" | cut -f1)
cat > "$WORK/DEBIAN/control" <<EOF
Package: $APPID
Version: $VER
Section: net
Priority: optional
Architecture: $ARCH
Installed-Size: $ISIZE
Maintainer: 傅宇 <Mrcoolfuyu@users.noreply.github.com>
Homepage: https://github.com/Mrcoolfuyu/nextcloud-uos
Depends: $DEPS
Description: Nextcloud 桌面同步客户端（UOS aarch64 源码编译版）
 自带 Qt 5.15.2 运行时，与系统 Qt 5.11/DTK 完全隔离。
 通过 Mesa llvmpipe 软件 GL 渲染 QML 界面，适配无独显 ARM 设备。
EOF

( cd "$WORK" && find opt -type f -print0 | sort -z | xargs -0 md5sum ) > "$WORK/DEBIAN/md5sums"

echo "[*] 重建 deb..."
rm -f "$DEB"
run_sudo chown -R root:root "$WORK"
run_sudo dpkg-deb --build "$WORK" "$DEB"
run_sudo chown mrcool:mrcool "$DEB" 2>/dev/null || true
ls -lh "$DEB"

echo "[*] 覆盖安装..."
run_sudo dpkg -i "$DEB" 2>&1 | tail -3

echo "=== 启动验证 ==="
timeout 30 /opt/apps/$APPID/files/bin/com.cnraft.nextcloud --version > /tmp/nc-pkg-ver.log 2>&1
grep -aiE "nextcloud version|using qt|platform plugin" /tmp/nc-pkg-ver.log | head -5
echo "DONE"
