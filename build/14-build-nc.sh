#!/bin/bash
# L420x - 编译 Nextcloud Desktop 3.13（qtbase/qttools/qtkeychain 已就绪）
set -u
SRC=/home/mrcool/ncbuild
QT=/opt/qt515
NC=/opt/nextcloud
J=$(nproc)

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { log "!!!! 失败: $*"; exit 1; }

export PATH=$QT/bin:$PATH
export LD_LIBRARY_PATH=$QT/lib:${LD_LIBRARY_PATH:-}

[ -x "$QT/bin/qmake" ] || die "Qt 未就绪"
log "Qt: $("$QT/bin/qmake" -query QT_VERSION)"
log "xcb 插件: $(ls "$QT/plugins/platforms/" 2>/dev/null | grep -c xcb) 个"

# 安装目录权限
if [ ! -w "$NC" ]; then
  echo 'Ch3ch2oh' | sudo -S -p '' mkdir -p "$NC" 2>/dev/null
  echo 'Ch3ch2oh' | sudo -S -p '' chown -R mrcool:mrcool "$NC" 2>/dev/null
fi
[ -w "$NC" ] || die "无法写入 $NC"

log "========== cmake 配置 =========="
rm -rf "$SRC/build/desktop"
mkdir -p "$SRC/build/desktop" && cd "$SRC/build/desktop" || die "cd desktop"

cmake "$SRC/desktop" \
  -DCMAKE_PREFIX_PATH="$QT" \
  -DCMAKE_INSTALL_PREFIX="$NC" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_WITH_WEBENGINE=OFF \
  -DBUILD_SHELL_INTEGRATION=OFF \
  -DBUILD_SHELL_INTEGRATION_NAUTILUS=OFF \
  -DBUILD_SHELL_INTEGRATION_DOLPHIN=OFF \
  -DBUILD_TESTING=OFF \
  -DBUILD_UPDATER=OFF \
  -DNO_MSG_HANDLER=OFF \
  -DCMAKE_CXX_STANDARD_LIBRARIES="-lstdc++fs" > "$SRC/nc-cmake.log" 2>&1
RC=$?
echo "----- 关键检测项 -----"
grep -iE "Found |Could NOT find|Using Qt|KF5|error" "$SRC/nc-cmake.log" | head -20
if [ $RC -ne 0 ]; then
  echo "----- 错误详情 -----"
  grep -iB 3 -A 12 "CMake Error" "$SRC/nc-cmake.log" | head -60
  die "cmake 配置失败 (rc=$RC)"
fi

log "========== make -j$J =========="
start=$(date +%s)
make -j$J > "$SRC/nc-make.log" 2>&1 || {
  echo "----- make 末 60 行 -----"
  tail -60 "$SRC/nc-make.log"
  die "make 失败"
}
log "make 完成，耗时 $(( ($(date +%s)-start)/60 )) 分钟"

make install > "$SRC/nc-install.log" 2>&1 || die "install 失败"

log "========== Nextcloud 编译完成 =========="
ls -l "$NC/bin/" 2>/dev/null
echo "--- 可执行文件大小 ---"
du -h "$NC/bin/nextcloud" 2>/dev/null
echo "--- 中文翻译 ---"
find "$NC" -name "*zh_CN*.qm" 2>/dev/null | head -5
echo "--- ldd 缺失库检查 ---"
ldd "$NC/bin/nextcloud" 2>/dev/null | grep "not found" || echo "  无缺失"
