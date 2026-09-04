#!/bin/bash
# 诊断 Nextcloud 主窗口白屏：抓取 QML 错误 + 核对 QML 模块与软件 GL
set -u
NC=/opt/nextcloud
QT=/opt/qt515

echo "===== A. QML 模块盘点（/opt/qt515/qml）====="
for m in QtQuick QtQuick.2 QtQuick/Controls QtQuick/Controls.2 QtQuick/Window.2 QtQuick/Layouts QtQuick/Dialogs QtGraphicalEffects Qt/labs QtQuick/Templates.2; do
  if [ -d "$QT/qml/$m" ]; then echo "  [OK] $m"; else echo "  [MISSING] $m"; fi
done
echo "--- 关键 QML 文件是否存在 ---"
ls "$QT/qml/QtQuick.2/qtquick2plugin.so" 2>/dev/null && echo "  qtquick2plugin OK" || echo "  qtquick2plugin MISSING"
ls "$QT/qml/QtQuick/Controls.2/qtquickcontrols2plugin.so" 2>/dev/null && echo "  controls2 OK" || echo "  controls2 MISSING"

echo
echo "===== B. 软件 OpenGL（llvmpipe）可用性 ====="
dpkg -l libgl1-mesa-dri 2>/dev/null | tail -1
ls /usr/lib/aarch64-linux-gnu/dri/ 2>/dev/null | grep -i llvmpipe || echo "  (无 llvmpipe_dri.so -> 无软件 GL)"
which glxinfo 2>/dev/null && LIBGL_ALWAYS_SOFTWARE=1 glxinfo 2>/dev/null | grep -i "renderer" | head -1 || echo "  (glxinfo 不可用)"

echo
echo "===== C. 当前启动脚本的渲染相关环境变量 ====="
grep -E "QT_QUICK_BACKEND|QT_XCB_GL_INTEGRATION|QT_QPA_PLATFORMTHEME|QML2" "$NC/bin/nextcloud-uos.sh"

echo
echo "===== D. 启动客户端并抓取 QML/运行时错误（15s）====="
pkill -x nextcloud 2>/dev/null; sleep 2
export DISPLAY=:1
export XAUTHORITY=/home/mrcool/.Xauthority
export LD_LIBRARY_PATH=$NC/lib:$QT/lib
export QT_PLUGIN_PATH=$QT/plugins
export QML2_IMPORT_PATH=$QT/qml
export QT_QPA_PLATFORM_PLUGIN_PATH=$QT/plugins/platforms
export QT_LOGGING_RULES="qt.qml.imports=true;qt.qml.connections=true;qt.quick*.debug=true;qt.qml.bug=true"
export QT_QUICK_BACKEND=software
timeout 15 "$NC/bin/nextcloud" --logfile /tmp/nc-blank.log > /tmp/nc-blank-stdout.log 2>&1
echo "--- 退出码 $? ---"
echo "--- stderr/stdout 中 QML/错误关键字 ---"
grep -aiE "qml|import|module|plugin|scene|Failed to|error|not installed|Cannot|undefined|ShaderEffect|OpacityMask|context" /tmp/nc-blank-stdout.log | head -40
echo "--- 完整尾部 ---"
tail -25 /tmp/nc-blank-stdout.log
echo
echo "===== E. 客户端日志文件尾部 ====="
tail -20 /tmp/nc-blank.log 2>/dev/null
pkill -x nextcloud 2>/dev/null
echo "done"
