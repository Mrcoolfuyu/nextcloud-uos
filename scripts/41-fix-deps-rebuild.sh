#!/bin/bash
# 修复 com.cnraft.nextcloud 的 Depends：带捆绑库路径重新 ldd，重建 deb
set -euo pipefail

APPID=com.cnraft.nextcloud
VER=3.13.4.0
ARCH=arm64
WORK="$HOME/packaging/${APPID}-${VER}"
PKGROOT="$WORK/opt/apps/$APPID"
DEB="$HOME/packaging/${APPID}_${VER}_${ARCH}.deb"

run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

# ============ 1. 带捆绑路径重算依赖 ============
export LD_LIBRARY_PATH="$PKGROOT/files/nextcloud/lib:$PKGROOT/files/qt/lib"
echo "[*] 重新 ldd（含捆绑库路径）..."
LIBS=$(mktemp)
{
  ldd "$PKGROOT/files/nextcloud/bin/nextcloud" 2>/dev/null || true
  ldd "$PKGROOT/files/nextcloud/bin/nextcloudcmd" 2>/dev/null || true
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
    [ -f "$f" ] && ldd "$f" 2>/dev/null || true
  done
} | awk '/=> \//{print $3} /^\s*lib/{if ($2=="=>" && $3 ~ /^\//) print $3}' \
  | sort -u | grep -v "/opt/apps/$APPID" > "$LIBS" || true

echo "    外部库数: $(wc -l < "$LIBS")"
DEPLIST=""
while IFS= read -r lib; do
  [ -n "$lib" ] || continue
  pkg=$(dpkg-query -S "$lib" 2>/dev/null | head -1 | cut -d: -f1) || pkg=""
  [ -n "$pkg" ] && DEPLIST="$DEPLIST $pkg"
done < "$LIBS"
rm -f "$LIBS"

# dlopen 的 Mesa DRI 驱动（llvmpipe/swrast）与动态加载库，显式补上
for extra in libgl1-mesa-dri libdbus-1-3 libglib2.0-0 libxkbcommon-x11-0; do
  dpkg-query -W -f='${Status}' "$extra" 2>/dev/null | grep -q "install ok installed" \
    && DEPLIST="$DEPLIST $extra" || true
done

DEPS=$(echo $DEPLIST | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
[ -n "$DEPS" ] || { echo "!!!! 依赖计算为空"; exit 1; }
echo "    Depends: $DEPS"

# ============ 2. 重写 control ============
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

# ============ 3. 重建 deb ============
echo "[*] 重建 deb..."
rm -f "$DEB"
run_sudo chown -R root:root "$WORK"
run_sudo dpkg-deb --build "$WORK" "$DEB"
run_sudo chown mrcool:mrcool "$DEB" 2>/dev/null || true

echo "=== 新 Depends ==="
dpkg-deb -f "$DEB" Depends | tr ',' '\n' | sed 's/^ */  /'
ls -lh "$DEB"

# ============ 4. 覆盖安装 + 启动验证 ============
echo "[*] 覆盖安装..."
run_sudo dpkg -i "$DEB" 2>&1 | tail -3
echo "=== 启动器版本验证（包内产物）==="
timeout 30 /opt/apps/$APPID/files/bin/com.cnraft.nextcloud --version 2>/dev/null | grep -aiE "nextcloud version|using qt|platform plugin" || echo "  (版本输出未捕获)"
echo "DONE"
