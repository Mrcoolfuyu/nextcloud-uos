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

exec /opt/nextcloud/bin/nextcloud "$@"
