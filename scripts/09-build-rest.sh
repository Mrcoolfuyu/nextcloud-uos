#!/bin/bash
# L420x - Qt 编译完成后：qttools(linguist) -> QtKeychain -> Nextcloud Desktop
set -u
SRC=/home/mrcool/ncbuild
QT=/opt/qt515
NC=/opt/nextcloud
J=$(nproc)

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { log "!!!! 失败: $*"; exit 1; }

export PATH=$QT/bin:$PATH
export LD_LIBRARY_PATH=$QT/lib:${LD_LIBRARY_PATH:-}

# 前置检查
[ -x "$QT/bin/qmake" ] || die "未找到 $QT/bin/qmake，Qt 尚未安装完成"
log "Qt 就绪: $("$QT/bin/qmake" -query QT_VERSION)"

# /opt/nextcloud 目录权限
if [ ! -w "$NC" ]; then
  echo 'Ch3ch2oh' | sudo -S -p '' mkdir -p "$NC" 2>/dev/null
  echo 'Ch3ch2oh' | sudo -S -p '' chown -R mrcool:mrcool "$NC" 2>/dev/null
fi
[ -w "$NC" ] || die "无法写入 $NC"

# ================= [1/3] qttools - linguist =================
log "========== [1/3] qttools (lrelease/lupdate) =========="
mkdir -p "$SRC/build/qttools" && cd "$SRC/build/qttools" || die "cd qttools"
"$QT/bin/qmake" "$SRC/src/qttools-everywhere-src-5.15.2/qttools.pro" > "$SRC/qttools-qmake.log" 2>&1 \
  || { tail -20 "$SRC/qttools-qmake.log"; die "qttools qmake 失败"; }

if make -j$J sub-linguist > "$SRC/qttools-make.log" 2>&1; then
  log "  linguist 增量编译成功"
elif make -j$J > "$SRC/qttools-make.log" 2>&1; then
  log "  linguist 增量失败，已改为全量编译成功"
else
  tail -50 "$SRC/qttools-make.log"; die "qttools make 失败"
fi

make sub-linguist-install_subtargets > "$SRC/qttools-install.log" 2>&1 \
  || make install > "$SRC/qttools-install.log" 2>&1 \
  || die "qttools install 失败"
ls -l "$QT/bin/lrelease" "$QT/bin/lupdate" 2>&1
log "qttools 完成"

# ================= [2/3] QtKeychain =================
log "========== [2/3] QtKeychain 0.13.2 =========="
mkdir -p "$SRC/build/qtkeychain" && cd "$SRC/build/qtkeychain" || die "cd qtkeychain"
cmake "$SRC/src/qtkeychain" \
  -DCMAKE_PREFIX_PATH="$QT" \
  -DCMAKE_INSTALL_PREFIX="$QT" \
  -DCMAKE_BUILD_TYPE=Release \
  -DBUILD_TRANSLATIONS=OFF \
  -DBUILD_TEST_APPLICATION=OFF > "$SRC/qtkeychain-cmake.log" 2>&1 \
  || { tail -40 "$SRC/qtkeychain-cmake.log"; die "qtkeychain cmake 配置失败"; }

make -j$J > "$SRC/qtkeychain-make.log" 2>&1 \
  || { tail -40 "$SRC/qtkeychain-make.log"; die "qtkeychain make 失败"; }
make install > "$SRC/qtkeychain-install.log" 2>&1 || die "qtkeychain install 失败"
ls "$QT/lib/cmake/" 2>/dev/null | grep -i keychain
log "QtKeychain 完成"

# ================= [3/3] Nextcloud Desktop =================
log "========== [3/3] Nextcloud Desktop 3.13 =========="
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
  -DNO_MSG_HANDLER=OFF > "$SRC/nc-cmake.log" 2>&1
RC=$?
echo "----- cmake 输出摘要 -----"
grep -iE "error|warning|not found|found|Qt5|Keychain" "$SRC/nc-cmake.log" | head -30
[ $RC -eq 0 ] || { echo "----- cmake 错误详情 -----"; tail -60 "$SRC/nc-cmake.log"; die "nextcloud cmake 配置失败"; }

log "--- nextcloud make -j$J ---"
make -j$J > "$SRC/nc-make.log" 2>&1 || {
  echo "----- make 末 60 行 -----"
  tail -60 "$SRC/nc-make.log"
  die "nextcloud make 失败"
}
make install > "$SRC/nc-install.log" 2>&1 || die "nextcloud install 失败"

log "========== 编译全部完成 =========="
ls -l "$NC/bin/" 2>/dev/null
echo "--- 翻译文件（中文）---"
find "$NC" -name "client_zh_CN.qm" -o -name "*zh_CN*.qm" 2>/dev/null | head -5
