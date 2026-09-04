#!/bin/bash
# v4：桌面图标（postinst 自动生成 ~/Desktop/nextcloud.desktop）+ postrm 清理
set -uo pipefail

APPID=com.cnraft.nextcloud
VER=3.13.4.0
ARCH=arm64
WORK="$HOME/packaging/${APPID}-${VER}"
PKGROOT="$WORK/opt/apps/$APPID"
ENT="$PKGROOT/entries/applications/nextcloud.desktop"
DEB="$HOME/packaging/${APPID}_${VER}_${ARCH}.deb"

run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

run_sudo chown -R mrcool:mrcool "$WORK" || { echo "!!!! work 目录不存在"; exit 1; }

echo "[*] 当前包内 desktop 入口:"
cat "$ENT"

# ---- 1. 修正 Name 与 Exec ----
# 启动器二选一：包内 bin/com.cnraft.nextcloud（实际是打包后的 nextcloud-uos.sh）
LAUNCHER=$(ls "$PKGROOT/files/bin/" | head -5 | tr '\n' ' ')
echo "[*] 包内 files/bin 内容: $LAUNCHER"
EXEC_PATH="/opt/apps/$APPID/files/bin/com.cnraft.nextcloud"
[ -f "$EXEC_PATH" ] || EXEC_PATH="/opt/apps/$APPID/files/nextcloud/bin/nextcloud-uos.sh"
echo "[*] 使用 Exec=$EXEC_PATH"

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
Icon=nextcloud
Terminal=false
Categories=Network;FileTransfer;Utility;
StartupNotify=false
StartupWMClass=nextcloud
EOF

# ---- 2. postinst：为每个真实用户生成桌面图标 ----
cat > "$WORK/DEBIAN/postinst" <<'EOF'
#!/bin/bash
# 安装后：为每个 uid>=1000 的用户在桌面生成启动器图标
APPID=com.cnraft.nextcloud
SRC=/opt/apps/$APPID/entries/applications/nextcloud.desktop
ICON_SRC=/opt/apps/$APPID/entries/icons/hicolor/256x256/apps/nextcloud.png

for home in /home/*; do
  [ -d "$home" ] || continue
  user=$(basename "$home")
  uid=$(id -u "$user" 2>/dev/null) || continue
  [ "$uid" -ge 1000 ] || continue

  # 桌面目录：优先 XDG 配置，回退 ~/Desktop
  desk=$(grep -m1 '^XDG_DESKTOP_DIR' "$home/.config/user-dirs.dirs" 2>/dev/null | sed 's/^XDG_DESKTOP_DIR="\(.*\)"/\1/; s|^\$HOME|'"$home"'|')
  [ -n "$desk" ] || desk="$home/Desktop"
  [ -d "$desk" ] || mkdir -p "$desk" 2>/dev/null
  [ -d "$desk" ] || continue

  # 图标：包没装进系统 hicolor 时，兜底放用户图标目录
  if ! ls /usr/share/icons/hicolor/256x256/apps/nextcloud.png >/dev/null 2>&1; then
    mkdir -p "$home/.local/share/icons/hicolor/256x256/apps" 2>/dev/null
    [ -f "$ICON_SRC" ] && cp -f "$ICON_SRC" "$home/.local/share/icons/hicolor/256x256/apps/nextcloud.png" 2>/dev/null
    chown -R "$user:" "$home/.local/share/icons" 2>/dev/null
  fi

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
rm -f /home/*/Desktop/nextcloud.desktop /home/*/.local/share/icons/hicolor/256x256/apps/nextcloud.png 2>/dev/null
exit 0
EOF

chmod 755 "$WORK/DEBIAN/postinst" "$WORK/DEBIAN/postrm"
echo "[*] postinst/postrm 已写入"

# ---- 4. 重建 deb（沿用 v3 已算好的 control，只重算 md5sums）----
( cd "$WORK" && find opt -type f -print0 | sort -z | xargs -0 md5sum ) > "$WORK/DEBIAN/md5sums"

rm -f "$DEB"
run_sudo chown -R root:root "$WORK"
run_sudo dpkg-deb --build "$WORK" "$DEB"
run_sudo chown mrcool:mrcool "$DEB" 2>/dev/null || true
ls -lh "$DEB"

# ---- 5. 覆盖安装并验证 ----
echo "[*] 覆盖安装..."
run_sudo dpkg -i "$DEB" 2>&1 | tail -4

echo "=== 验证桌面图标 ==="
ls -l "$HOME/Desktop/nextcloud.desktop" 2>&1
echo "--- 内容 ---"
cat "$HOME/Desktop/nextcloud.desktop" 2>/dev/null
echo "=== 启动验证 ==="
timeout 30 /opt/apps/$APPID/files/bin/com.cnraft.nextcloud --version > /tmp/nc-pkg-ver.log 2>&1
grep -aiE "nextcloud version|using qt|platform plugin" /tmp/nc-pkg-ver.log | head -5
echo "DONE"
