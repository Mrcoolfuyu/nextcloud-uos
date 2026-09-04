#!/bin/bash
echo "===== 当前启动器 nextcloud-uos.sh ====="
cat /opt/nextcloud/bin/nextcloud-uos.sh
echo
echo "===== 源码中主窗口的 QML 承载方式 ====="
cd /home/mrcool/ncbuild/desktop 2>/dev/null || { echo "源码树已清理，改查已装二进制里字符串"; }
grep -rn "QQuickWidget\|QQuickView\|QQuickWindow\|setSource\|QQmlEngine" src/gui 2>/dev/null | grep -iE "quick" | head -20
echo
echo "===== 已装二进制是否引用 QQuickWidget ====="
strings /opt/nextcloud/bin/nextcloud 2>/dev/null | grep -i "QQuickWidget" | head -3
echo
echo "===== xcb GL 集成插件 ====="
ls /opt/qt515/plugins/xcbglintegration/ 2>/dev/null
echo
echo "===== swrast 可用性复测 ====="
DISPLAY=:1 LIBGL_ALWAYS_SOFTWARE=1 glxinfo 2>/dev/null | grep -iE "OpenGL renderer|direct rendering" | head -3
echo
echo "===== 当前 DISPLAY / XAUTHORITY ====="
echo "DISPLAY=$DISPLAY"
ls -l /home/mrcool/.Xauthority 2>/dev/null
