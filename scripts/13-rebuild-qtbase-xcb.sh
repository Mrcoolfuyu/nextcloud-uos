#!/bin/bash
# L420x - 补装 X11-XCB 依赖后重新编译 qtbase，产出 libqxcb.so 平台插件
set -u
SRC=/home/mrcool/ncbuild/src
BUILD=/home/mrcool/ncbuild/build
PREFIX=/opt/qt515
LOG=/home/mrcool/ncbuild
J=$(nproc)

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { log "!!!! 失败: $*"; exit 1; }

log "清理旧 qtbase 构建目录（避免 config.cache 残留旧的 XCB Xlib=no）"
rm -rf "$BUILD/qtbase"
mkdir -p "$BUILD/qtbase" && cd "$BUILD/qtbase" || die "cd qtbase"

log "=== configure（全新检测）==="
"$SRC/qtbase-everywhere-src-5.15.2/configure" \
  -prefix "$PREFIX" \
  -opensource -confirm-license \
  -nomake examples -nomake tests \
  -opengl desktop > "$LOG/qtbase-reconfigure.log" 2>&1
RC=$?
echo "----- QPA 后端检测结果 -----"
grep -A 25 "QPA backends" "$LOG/qtbase-reconfigure.log" | grep -iE "XCB|X11|LinuxFB|EGLFS|VNC|DirectFB" | head -15
echo "----- X11 specific -----"
grep -A 5 "X11 specific" "$LOG/qtbase-reconfigure.log" | head -6
[ $RC -eq 0 ] && [ -f Makefile ] || { tail -30 "$LOG/qtbase-reconfigure.log"; die "configure 失败 (rc=$RC)"; }

if ! grep -q "XCB Xlib ................................ yes" "$LOG/qtbase-reconfigure.log" 2>/dev/null; then
  log "!! 警告：XCB Xlib 仍未启用，检查日志"
fi

log "--- make -j$J ---"
start=$(date +%s)
make -j$J > "$LOG/qtbase-remake.log" 2>&1 || { tail -50 "$LOG/qtbase-remake.log"; die "make 失败"; }
log "make 完成，耗时 $(( ($(date +%s)-start)/60 )) 分钟"

make install > "$LOG/qtbase-reinstall.log" 2>&1 || die "install 失败"

log "========== 平台插件验证 =========="
ls -l "$PREFIX/plugins/platforms/"
if [ -f "$PREFIX/plugins/platforms/libqxcb.so" ]; then
  log ">>> libqxcb.so 已生成 ✓"
  echo "--- ldd libqxcb.so ---"
  ldd "$PREFIX/plugins/platforms/libqxcb.so" | grep -E "not found|X11-xcb|xcb" | head -15
  ldd "$PREFIX/plugins/platforms/libqxcb.so" | grep -c "not found" | xargs -I{} echo "缺失依赖数: {}"
else
  die "libqxcb.so 仍未生成"
fi
