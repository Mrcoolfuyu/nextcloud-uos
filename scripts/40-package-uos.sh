#!/bin/bash
# UOS 商店规范打包：Nextcloud Desktop 3.13 -> com.cnraft.nextcloud
# 结构遵循 UOS 打包规范 v1.2：/opt/apps/<appid>/{entries,files,info}
set -euo pipefail

APPID=com.cnraft.nextcloud
VER=3.13.4.0
ARCH=$(dpkg --print-architecture)
WORK="$HOME/packaging/${APPID}-${VER}"
PKGROOT="$WORK/opt/apps/$APPID"
DEB="$HOME/packaging/${APPID}_${VER}_${ARCH}.deb"

run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

[ -d /opt/qt515 ] || { echo "!!!! 缺 /opt/qt515"; exit 1; }
[ -x /opt/nextcloud/bin/nextcloud ] || { echo "!!!! 缺 /opt/nextcloud/bin/nextcloud"; exit 1; }
echo "[*] 架构: $ARCH  工作目录: $WORK"

rm -rf "$WORK"
mkdir -p "$WORK/DEBIAN" \
         "$PKGROOT/entries/applications" \
         "$PKGROOT/entries/icons/hicolor" \
         "$PKGROOT/files/bin" \
         "$PKGROOT/files/doc"

# ============ 1. 复制产物 ============
echo "[*] 复制 Qt 5.15 运行时..."
cp -a /opt/qt515 "$PKGROOT/files/qt"
find "$PKGROOT/files/qt" \( -name '*.a' -o -name '*.prl' -o -name '*.la' \) -delete

echo "[*] 复制 Nextcloud..."
cp -a /opt/nextcloud "$PKGROOT/files/nextcloud"
rm -f "$PKGROOT/files/nextcloud/bin/nextcloud-uos.sh" \
      "$PKGROOT/files/nextcloud/bin/nextcloud-dialog-uos.sh"

# qt.conf 使用相对路径（相对 qt.conf 所在目录解析），保证包可重定位
cat > "$PKGROOT/files/nextcloud/bin/qt.conf" <<'EOF'
[Paths]
Prefix = ../../qt
Plugins = plugins
Qml2Imports = qml
Translations = translations
EOF

# ============ 2. 包内启动器 ============
cat > "$PKGROOT/files/bin/com.cnraft.nextcloud" <<'EOF'
#!/bin/bash
# Nextcloud Desktop (com.cnraft.nextcloud) UOS 启动器
BASE=/opt/apps/com.cnraft.nextcloud/files
export LD_LIBRARY_PATH=$BASE/nextcloud/lib:$BASE/qt/lib:${LD_LIBRARY_PATH:-}
export QT_PLUGIN_PATH=$BASE/qt/plugins
export QML2_IMPORT_PATH=$BASE/qt/qml
export QT_QPA_PLATFORM_PLUGIN_PATH=$BASE/qt/plugins/platforms
export QT_QPA_PLATFORMTHEME=
export LIBGL_ALWAYS_SOFTWARE=1
export XDG_CURRENT_DESKTOP=DDE

# Wayland 会话下 DISPLAY 兜底探测
if [ -z "${DISPLAY:-}" ]; then
  for d in 1 0 2 3; do
    if [ -S "/tmp/.X11-unix/X$d" ] && [ -O "/tmp/.X11-unix/X$d" ]; then
      export DISPLAY=":$d"; break
    fi
  done
  if [ -z "${DISPLAY:-}" ]; then
    for d in 1 0 2 3; do
      [ -S "/tmp/.X11-unix/X$d" ] && { export DISPLAY=":$d"; break; }
    done
  fi
fi
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

exec $BASE/nextcloud/bin/nextcloud "$@"
EOF
chmod 755 "$PKGROOT/files/bin/com.cnraft.nextcloud"

# ============ 3. 图标 ============
echo "[*] 部署图标..."
for sz in 16x16 24x24 32x32 48x48 64x64 128x128 256x256 512x512; do
  src="$PKGROOT/files/nextcloud/share/icons/hicolor/$sz/apps/Nextcloud.png"
  [ -f "$src" ] || src="$PKGROOT/files/nextcloud/share/icons/hicolor/$sz/apps/nextcloud.png"
  if [ -f "$src" ]; then
    mkdir -p "$PKGROOT/entries/icons/hicolor/$sz/apps"
    cp "$src" "$PKGROOT/entries/icons/hicolor/$sz/apps/com.cnraft.nextcloud.png"
    echo "    icon $sz"
  fi
done
for svg in "$PKGROOT/files/nextcloud/share/icons/hicolor/scalable/apps/Nextcloud.svg" \
           "$PKGROOT/files/nextcloud/share/icons/hicolor/scalable/apps/nextcloud.svg"; do
  if [ -f "$svg" ]; then
    mkdir -p "$PKGROOT/entries/icons/hicolor/scalable/apps"
    cp "$svg" "$PKGROOT/entries/icons/hicolor/scalable/apps/com.cnraft.nextcloud.svg"
    echo "    icon scalable(svg)"
    break
  fi
done

# ============ 4. desktop 入口 ============
cat > "$PKGROOT/entries/applications/com.cnraft.nextcloud.desktop" <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Nextcloud Desktop
Name[zh_CN]=Nextcloud 桌面客户端
GenericName=File Synchronizer
GenericName[zh_CN]=文件同步
Comment=Nextcloud desktop synchronization client
Comment[zh_CN]=与 Nextcloud 服务器同步文件
Exec=/opt/apps/com.cnraft.nextcloud/files/bin/com.cnraft.nextcloud
Icon=com.cnraft.nextcloud
Terminal=false
Categories=Network;FileTransfer;Utility;
StartupNotify=false
StartupWMClass=nextcloud
EOF

# ============ 5. info ============
cat > "$PKGROOT/info" <<EOF
{
  "appid": "$APPID",
  "name": "Nextcloud",
  "version": "$VER",
  "arch": ["$ARCH"],
  "permissions": {
    "autostart": false,
    "notification": true,
    "trayicon": true,
    "clipboard": false,
    "account": false,
    "bluetooth": false,
    "camera": false,
    "audio_record": false,
    "installed_apps": false
  }
}
EOF

# ============ 6. copyright ============
cat > "$PKGROOT/files/doc/copyright" <<'EOF'
Format: https://www.debian.org/doc/packaging-manuals/copyright-format/1.0/
Upstream-Name: Nextcloud Desktop Client
Source: https://github.com/nextcloud/desktop

本包由 UOS 20 aarch64 源码编译脚本构建（build scripts: MIT License, (c) 2026 傅宇）。
上游程序版权与许可证：
  Nextcloud Desktop Client: GPLv2+，Copyright Nextcloud GmbH and contributors
  Qt 5.15.2: LGPL-3 / GPL-3（Qt Company / The Qt Company Ltd.）
EOF

# ============ 7. 计算 Depends（ldd -> 排除捆绑 -> dpkg -S）============
echo "[*] 计算系统依赖..."
LIBS=$(mktemp)
{
  ldd "$PKGROOT/files/nextcloud/bin/nextcloud" 2>/dev/null || true
  ldd "$PKGROOT/files/nextcloud/bin/nextcloudcmd" 2>/dev/null || true
  for f in "$PKGROOT"/files/nextcloud/lib/libnextcloudsync.so* \
           "$PKGROOT"/files/qt/plugins/platforms/*.so \
           "$PKGROOT"/files/qt/plugins/xcbglintegrations/*.so \
           "$PKGROOT"/files/qt/lib/libQt5Core.so* \
           "$PKGROOT"/files/qt/lib/libQt5Gui.so* \
           "$PKGROOT"/files/qt/lib/libQt5Widgets.so* \
           "$PKGROOT"/files/qt/lib/libQt5Network.so* \
           "$PKGROOT"/files/qt/lib/libQt5Quick.so* \
           "$PKGROOT"/files/qt/lib/libQt5Qml.so* \
           "$PKGROOT"/files/qt/lib/libQt5WebSockets.so*; do
    [ -f "$f" ] && ldd "$f" 2>/dev/null || true
  done
} | awk '/=> \//{print $3}' | sort -u | grep -v "/opt/apps/$APPID" > "$LIBS" || true

DEPLIST=""
while IFS= read -r lib; do
  [ -n "$lib" ] || continue
  pkg=$(dpkg-query -S "$lib" 2>/dev/null | head -1 | cut -d: -f1) || pkg=""
  [ -n "$pkg" ] && DEPLIST="$DEPLIST $pkg"
done < "$LIBS"
rm -f "$LIBS"

# dlopen 的 Mesa DRI 驱动（llvmpipe/swrast）与 ldd 覆盖不到的库，显式补上
for extra in libgl1-mesa-dri libdbus-1-3 libglib2.0-0 libxkbcommon-x11-0; do
  dpkg-query -W -f='${Status}' "$extra" 2>/dev/null | grep -q "install ok installed" \
    && DEPLIST="$DEPLIST $extra" || true
done

DEPS=$(echo $DEPLIST | tr ' ' '\n' | sort -u | tr '\n' ',' | sed 's/,$//; s/,/, /g')
[ -n "$DEPS" ] || DEPS="libc6"
echo "    Depends: $DEPS"

# ============ 8. control ============
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

# ============ 9. md5sums ============
echo "[*] 生成 md5sums..."
( cd "$WORK" && find opt -type f -print0 | sort -z | xargs -0 md5sum ) > "$WORK/DEBIAN/md5sums"

# ============ 10. 构建 deb ============
echo "[*] 构建 deb..."
run_sudo chown -R root:root "$WORK"
run_sudo dpkg-deb --build "$WORK" "$DEB"
run_sudo chown mrcool:mrcool "$DEB" 2>/dev/null || true

echo "=== 产物 ==="
ls -lh "$DEB"
echo "=== control ==="
dpkg-deb -f "$DEB" Package Version Architecture Installed-Size Depends
echo "=== info ==="
cat "$PKGROOT/info"
echo "=== 安装测试 ==="
run_sudo dpkg -i "$DEB" 2>&1 | tail -5
echo "=== 桌面入口符号链接 ==="
ls -l /usr/share/applications/com.cnraft.nextcloud.desktop 2>&1 || echo "  (未自动创建符号链接)"
echo "=== 包内启动器版本测试 ==="
timeout 30 /opt/apps/$APPID/files/bin/com.cnraft.nextcloud --version 2>&1 | head -4
echo "DONE"
