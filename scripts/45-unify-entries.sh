#!/bin/bash
# v5：统一入口与图标命名（appid），清理双入口与旧手动残留
set -uo pipefail

APPID=com.cnraft.nextcloud
VER=3.13.4.0
ARCH=arm64
WORK="$HOME/packaging/${APPID}-${VER}"
PKGROOT="$WORK/opt/apps/$APPID"
ENT="$PKGROOT/entries/applications/com.cnraft.nextcloud.desktop"
DEB="$HOME/packaging/${APPID}_${VER}_${ARCH}.deb"

run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

run_sudo chown -R mrcool:mrcool "$WORK" || { echo "!!!! work 目录不存在"; exit 1; }

# ---- 1. 包内只保留 appid 命名的唯一入口 ----
rm -f "$PKGROOT/entries/applications/nextcloud.desktop"
EXEC_PATH="/opt/apps/$APPID/files/bin/com.cnraft.nextcloud"

cat > "$ENT" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=nextcloud
Name[zh_CN]=nextcloud
GenericName=File Synchronizer
GenericName[zh_CN]=文件同步
Comment=Nextcloud desktop synchronization client
Comment[zh_CN]=与 Nextcloud 服务器同步文件
Exec=$EXEC_PATH
Icon=$APPID
Terminal=false
Categories=Network;FileTransfer;Utility;
StartupNotify=false
StartupWMClass=nextcloud
EOF
echo "[*] 包内入口已统一: $ENT (Icon=$APPID)"

# ---- 2. postinst：复制入口到桌面（文件名 nextcloud.desktop，显示名取 Name=）----
cat > "$WORK/DEBIAN/postinst" <<'EOF'
#!/bin/bash
# 安装后：为每个 uid>=1000 的用户在桌面生成启动器图标
APPID=com.cnraft.nextcloud
SRC=/opt/apps/$APPID/entries/applications/com.cnraft.nextcloud.desktop

for home in /home/*; do
  [ -d "$home" ] || continue
  user=$(basename "$home")
  uid=$(id -u "$user" 2>/dev/null) || continue
  [ "$uid" -ge 1000 ] || continue

  desk=$(grep -m1 '^XDG_DESKTOP_DIR' "$home/.config/user-dirs.dirs" 2>/dev/null | sed 's/^XDG_DESKTOP_DIR="\(.*\)"/\1/; s|^\$HOME|'"$home"'|')
  [ -n "$desk" ] || desk="$home/Desktop"
  [ -d "$desk" ] || mkdir -p "$desk" 2>/dev/null
  [ -d "$desk" ] || continue

  cp -f "$SRC" "$desk/nextcloud.desktop" 2>/dev/null || continue
  chown "$user:" "$desk/nextcloud.desktop"
  chmod 755 "$desk/nextcloud.desktop"
  echo "桌面图标已生成: $desk/nextcloud.desktop ($user)"
done
exit 0
EOF

# ---- 3. postrm：清理桌面图标 ----
cat > "$WORK/DEBIAN/postrm" <<'EOF'
#!/bin/bash
rm -f /home/*/Desktop/nextcloud.desktop 2>/dev/null
exit 0
EOF

chmod 755 "$WORK/DEBIAN/postinst" "$WORK/DEBIAN/postrm"

# ---- 4. 清理本机旧手动安装残留（避免三重图标）----
echo "[*] 清理旧手动安装残留..."
run_sudo rm -f /usr/share/applications/nextcloud.desktop \
               /usr/share/pixmaps/nextcloud.png \
               /usr/share/icons/hicolor/128x128/apps/nextcloud.png \
               /usr/share/icons/hicolor/256x256/apps/nextcloud.png
echo "  已删除：旧手动 desktop 入口 + 旧手动图标副本（/opt/nextcloud 本体保留）"

# ---- 5. 重建 deb ----
( cd "$WORK" && find opt -type f -print0 | sort -z | xargs -0 md5sum ) > "$WORK/DEBIAN/md5sums"
rm -f "$DEB"
run_sudo chown -R root:root "$WORK"
run_sudo dpkg-deb --build "$WORK" "$DEB"
run_sudo chown mrcool:mrcool "$DEB" 2>/dev/null || true
ls -lh "$DEB"

# ---- 6. 覆盖安装并验证 ----
echo "[*] 覆盖安装..."
run_sudo dpkg -i "$DEB" 2>&1 | tail -4

echo "=== 验证 1：应用菜单入口（应只有 appid 一条，来自包）==="
ls -l /usr/share/applications/ | grep -iE "nextcloud|cnraft"

echo "=== 验证 2：图标经 trigger 符号链接可达（Icon=$APPID 解析依据）==="
ls -l /usr/share/icons/hicolor/256x256/apps/com.cnraft.nextcloud.png 2>&1

echo "=== 验证 3：桌面图标 ==="
ls -l "$HOME/Desktop/nextcloud.desktop" 2>&1
grep -E "^(Name|Icon|Exec)=" "$HOME/Desktop/nextcloud.desktop"

echo "=== 验证 4：包内启动 ==="
timeout 30 /opt/apps/$APPID/files/bin/com.cnraft.nextcloud --version > /tmp/nc-pkg-ver.log 2>&1
grep -aiE "nextcloud version|using qt|platform plugin" /tmp/nc-pkg-ver.log | head -3
echo "DONE"
