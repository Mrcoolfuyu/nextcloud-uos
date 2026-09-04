#!/bin/bash
# L420x - 列出 Nextcloud Desktop 3.13 所需的全部 Qt5 模块，并与已安装模块对比
SRC=/home/mrcool/ncbuild/desktop
QT=/opt/qt515

echo "===== 1. 源码中引用的 Qt5:: 模块 ====="
grep -rhoE "Qt5::[A-Za-z0-9]+" "$SRC/src" "$SRC/CMakeLists.txt" 2>/dev/null | sort -u | sed 's/Qt5:://' > /tmp/_need.txt
cat /tmp/_need.txt

echo ""
echo "===== 2. find_package(Qt5 ...) 声明 ====="
grep -rhoE "find_package\(Qt5[^)]*\)" "$SRC/src" "$SRC/CMakeLists.txt" 2>/dev/null | sort -u | head -30

echo ""
echo "===== 3. 已安装的 Qt5 CMake 模块 ====="
ls "$QT/lib/cmake/" 2>/dev/null | sort > /tmp/_have.txt
cat /tmp/_have.txt | tr '\n' ' '; echo

echo ""
echo "===== 4. 缺失模块（需下载编译）====="
echo "--- 需要的 ---"
cat /tmp/_need.txt | tr '\n' ' '; echo
echo "--- 缺失的 ---"
MISSING=""
while read -r m; do
  [ -z "$m" ] && continue
  if [ ! -d "$QT/lib/cmake/Qt5$m" ]; then
    echo "  [缺] Qt5$m"
    MISSING="$MISSING $m"
  fi
done < /tmp/_need.txt
[ -z "$MISSING" ] && echo "  无缺失"
echo ""
echo "缺失列表:$MISSING"
