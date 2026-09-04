#!/bin/bash
# L420x - 编译 Qt 5.15.2 五个子模块到 /opt/qt515
set -u
SRC=/home/mrcool/ncbuild/src
BUILD=/home/mrcool/ncbuild/build
PREFIX=/opt/qt515
J=$(nproc)
LOGDIR=/home/mrcool/ncbuild

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { log "!!!! 失败: $*"; exit 1; }

log "CPU 线程数 J=$J"

# 准备安装目录（/opt 属 root，改属主给当前用户，后续免 sudo）
if [ ! -w "$PREFIX" ]; then
  echo 'Ch3ch2oh' | sudo -S -p '' mkdir -p "$PREFIX" 2>/dev/null
  echo 'Ch3ch2oh' | sudo -S -p '' chown -R mrcool:mrcool "$PREFIX" 2>/dev/null
fi
[ -w "$PREFIX" ] || die "无法写入 $PREFIX"
log "安装目录就绪: $PREFIX"

# ============ 1/5 qtbase ============
log "========== [1/5] qtbase configure =========="
mkdir -p "$BUILD/qtbase" && cd "$BUILD/qtbase" || die "cd build/qtbase"
"$SRC/qtbase-everywhere-src-5.15.2/configure" \
  -prefix "$PREFIX" \
  -opensource -confirm-license \
  -nomake examples -nomake tests \
  -opengl desktop \
  -v > "$LOGDIR/qtbase-configure.log" 2>&1
RC=$?
tail -35 "$LOGDIR/qtbase-configure.log"
[ $RC -eq 0 ] && [ -f Makefile ] || die "qtbase configure 失败 (rc=$RC)，详见 qtbase-configure.log"
log "qtbase configure 成功"

log "--- qtbase make -j$J 开始（预计 40-60 分钟）---"
start=$(date +%s)
make -j$J > "$LOGDIR/qtbase-make.log" 2>&1 || {
  echo "===== make 末 60 行 ====="
  tail -60 "$LOGDIR/qtbase-make.log"
  die "qtbase make 失败"
}
log "qtbase make 完成，耗时 $(( ($(date +%s)-start)/60 )) 分钟"

make install > "$LOGDIR/qtbase-install.log" 2>&1 || die "qtbase install 失败"
log "qtbase 安装完成"

# ============ 2-5 其余模块 ============
for m in qtdeclarative qtsvg qtgraphicaleffects qtquickcontrols2; do
  log "========== $m =========="
  mkdir -p "$BUILD/$m" && cd "$BUILD/$m" || die "cd $m"
  "$PREFIX/bin/qmake" "$SRC/${m}-everywhere-src-5.15.2/${m}.pro" > "$LOGDIR/${m}-qmake.log" 2>&1 \
    || { tail -20 "$LOGDIR/${m}-qmake.log"; die "$m qmake 失败"; }

  start=$(date +%s)
  make -j$J > "$LOGDIR/${m}-make.log" 2>&1 || {
    echo "===== $m make 末 60 行 ====="
    tail -60 "$LOGDIR/${m}-make.log"
    die "$m make 失败"
  }
  log "$m make 完成，耗时 $(( ($(date +%s)-start)/60 )) 分钟"

  make install > "$LOGDIR/${m}-install.log" 2>&1 || die "$m install 失败"
  log "$m 安装完成"
done

log "========== Qt 5.15.2 全部完成 =========="
ls "$PREFIX/bin/"
echo "--- QML 模块 ---"
ls "$PREFIX/qml/" 2>/dev/null | tr '\n' ' '; echo
echo "--- 平台插件 ---"
ls "$PREFIX/plugins/platforms/" 2>/dev/null | tr '\n' ' '; echo
df -h /opt | tail -1
