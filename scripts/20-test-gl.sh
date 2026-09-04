#!/bin/bash
# 重部署启动器并用 Mesa 软件 GL 实测主窗口 QML 是否能初始化
set -u
NC=/opt/nextcloud
QT=/opt/qt515

echo "===== 重部署启动器 ====="
bash /home/mrcool/ncbuild/10-setup-launcher.sh >/dev/null 2>&1 && echo "launcher redeployed"
grep -E "LIBGL_ALWAYS_SOFTWARE|QT_QUICK_BACKEND|QT_XCB_GL_INTEGRATION" "$NC/bin/nextcloud-uos.sh" || true

echo
echo "===== 杀旧实例并启动（15s，抓 GL/RHI/scenegraph 日志）====="
pkill -x nextcloud 2>/dev/null; sleep 2
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export LD_LIBRARY_PATH=$NC/lib:$QT/lib
export QT_PLUGIN_PATH=$QT/plugins
export QML2_IMPORT_PATH=$QT/qml
export QT_QPA_PLATFORM_PLUGIN_PATH=$QT/plugins/platforms
export QT_LOGGING_RULES="qt.qpa.gl=true;qt.rhi.*=true;qt.scenegraph.*=true;qt.qml.imports=true"
export LIBGL_ALWAYS_SOFTWARE=1
timeout 15 "$NC/bin/nextcloud" --logfile /tmp/nc-gl.log > /tmp/nc-gl-stdout.log 2>&1
echo "退出码 $? (124=存活)"
echo "--- 关键错误扫描 ---"
grep -aiE "Failed to create|context|scene graph|RHI|EGL|GLX|could not|libGL error|QGL|OpenGL" /tmp/nc-gl-stdout.log | head -25
echo "--- stdout 尾部 ---"
tail -15 /tmp/nc-gl-stdout.log
echo
echo "===== 版本（确认 xcb + Qt 版本）====="
DISPLAY=:1 XAUTHORITY=/home/mrcool/.Xauthority /opt/nextcloud/bin/nextcloud-uos.sh --version 2>&1 | head -4
pkill -x nextcloud 2>/dev/null
echo "done"
