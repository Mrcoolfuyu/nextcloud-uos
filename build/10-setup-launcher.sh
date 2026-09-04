#!/bin/bash
# L420x - 配置 Nextcloud 启动隔离环境、桌面入口与图标
set -u
QT=/opt/qt515
NC=/opt/nextcloud

log() { echo "[*] $*"; }
die() { echo "!!!! $*"; exit 1; }

run_sudo() {
  if sudo -n true 2>/dev/null; then sudo -n "$@"; else echo 'Ch3ch2oh' | sudo -S -p '' "$@"; fi
}

[ -x "$NC/bin/nextcloud" ] || die "未找到 $NC/bin/nextcloud，请先完成编译"

# ============ 1. 启动包装脚本 ============
log "写入 $NC/bin/nextcloud-uos.sh"
cat > "$NC/bin/nextcloud-uos.sh" <<'EOS'
#!/bin/bash
# Nextcloud Desktop for UOS 20 (aarch64)
# 系统 Qt 5.11/DTK 与自编 Qt 5.15 插件 ABI 不兼容，必须完整隔离运行
export LD_LIBRARY_PATH=/opt/nextcloud/lib:/opt/qt515/lib:${LD_LIBRARY_PATH:-}
export QT_PLUGIN_PATH=/opt/qt515/plugins
export QML2_IMPORT_PATH=/opt/qt515/qml
export QT_QPA_PLATFORM_PLUGIN_PATH=/opt/qt515/plugins/platforms
export QT_QPA_PLATFORMTHEME=          # 清空，避免加载 deepin 的 Qt5.11 主题插件
export LIBGL_ALWAYS_SOFTWARE=1        # 无独显：强制 Mesa llvmpipe 软件 GL，支撑 QML/QtGraphicalEffects 着色器
# 不设置 QT_QUICK_BACKEND / QT_XCB_GL_INTEGRATION：
#   由 xcb GL 集成插件 + swrast 提供 OpenGL 上下文；否则主窗口 QML(QtGraphicalEffects) 白屏
export XDG_CURRENT_DESKTOP=DDE

# UOS/DDE 桌面跑在 Wayland 上（kwin_wayland + XWayland），
# 从菜单启动时 DISPLAY 可能为空，这里兜底探测 XWayland 的 socket
if [ -z "${DISPLAY:-}" ]; then
  for d in 1 0 2 3; do
    if [ -S "/tmp/.X11-unix/X$d" ] && [ -O "/tmp/.X11-unix/X$d" ]; then
      export DISPLAY=":$d"
      break
    fi
  done
  # 属主探测失败则退回第一个存在的 socket
  if [ -z "${DISPLAY:-}" ]; then
    for d in 1 0 2 3; do
      [ -S "/tmp/.X11-unix/X$d" ] && { export DISPLAY=":$d"; break; }
    done
  fi
fi
export XAUTHORITY="${XAUTHORITY:-$HOME/.Xauthority}"

exec -a "$0" /opt/nextcloud/bin/nextcloud "$@"
EOS
chmod +x "$NC/bin/nextcloud-uos.sh" || die "chmod 失败"

# ============ 2. qt.conf 固定路径 ============
log "写入 $NC/bin/qt.conf"
cat > "$NC/bin/qt.conf" <<'EOS'
[Paths]
Prefix = /opt/qt515
Plugins = plugins
Qml2Imports = qml
Translations = translations
EOS

# ============ 3. 图标 ============
log "查找并部署图标"
ICON=""
for c in \
  "$NC/share/icons/hicolor/256x256/apps/nextcloud.png" \
  "$NC/share/icons/hicolor/128x128/apps/nextcloud.png" \
  "$NC/share/icons/hicolor/64x64/apps/nextcloud.png" \
  "$NC/share/icons/hicolor/scalable/apps/nextcloud.svg" ; do
  [ -f "$c" ] && { ICON="$c"; break; }
done
if [ -z "$ICON" ]; then
  ICON=$(find "$NC" -iname "*nextcloud*" \( -name "*.png" -o -name "*.svg" \) 2>/dev/null | grep -iE "icon" | head -1)
fi
if [ -n "$ICON" ] && [ -f "$ICON" ]; then
  log "  图标来源: $ICON"
  run_sudo cp "$ICON" /usr/share/pixmaps/nextcloud"${ICON##*.}" 2>/dev/null && log "  已复制到 /usr/share/pixmaps/nextcloud.${ICON##*.}"
else
  log "  未找到自带图标，将跳过图标（不影响启动）"
fi

# ============ 4. .desktop 入口 ============
log "写入 /usr/share/applications/nextcloud.desktop"
run_sudo tee /usr/share/applications/nextcloud.desktop > /dev/null <<'EOS'
[Desktop Entry]
Type=Application
Version=1.0
Name=Nextcloud Desktop
Name[zh_CN]=Nextcloud 桌面客户端
GenericName=File Synchronizer
GenericName[zh_CN]=文件同步
Comment=Nextcloud desktop synchronization client
Comment[zh_CN]=与 Nextcloud 服务器同步文件
Exec=/opt/nextcloud/bin/nextcloud-uos.sh
Icon=nextcloud
Terminal=false
Categories=Network;FileTransfer;Utility;
StartupNotify=false
StartupWMClass=nextcloud
EOS
run_sudo chmod 644 /usr/share/applications/nextcloud.desktop

# ============ 5. 桌面快捷方式 ============
DESKTOP_DIR="$HOME/Desktop"
[ -d "$DESKTOP_DIR" ] || DESKTOP_DIR="$HOME/桌面"
if [ -d "$DESKTOP_DIR" ]; then
  cp /usr/share/applications/nextcloud.desktop "$DESKTOP_DIR/nextcloud.desktop"
  chmod +x "$DESKTOP_DIR/nextcloud.desktop"
  log "桌面快捷方式已创建: $DESKTOP_DIR/nextcloud.desktop"
else
  log "未找到桌面目录，跳过快捷方式"
fi

# ============ 6. 校验 ============
echo ""
log "========== 校验 =========="
echo "--- 启动脚本 ---"
ls -l "$NC/bin/nextcloud-uos.sh" "$NC/bin/qt.conf"
echo "--- 可执行文件 ---"
ls -l "$NC/bin/"
echo "--- ldd 检查（应全部指向 /opt/qt515 或系统库，不应出现 Qt 5.11 混链）---"
ldd "$NC/bin/nextcloud" 2>&1 | grep -iE "qt|not found" | head -25
echo "--- 缺失库 ---"
ldd "$NC/bin/nextcloud" 2>&1 | grep "not found" || echo "  无缺失"
log "启动器配置完成"
