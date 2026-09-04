#!/bin/bash
# L420x - 补编 qtwebsockets（Nextcloud libsync 的 REQUIRED 依赖）
set -u
SRC=/home/mrcool/ncbuild/src
BUILD=/home/mrcool/ncbuild/build
PREFIX=/opt/qt515
LOG=/home/mrcool/ncbuild
J=$(nproc)

log() { echo "[$(date +%H:%M:%S)] $*"; }
die() { log "!!!! 失败: $*"; exit 1; }

MIRROR=$(grep "选用镜像" "$LOG/download.log" 2>/dev/null | sed 's/.*镜像: //' | tail -1)
[ -z "$MIRROR" ] && MIRROR="https://mirrors.ustc.edu.cn/qtproject/archive/qt/5.15/5.15.2/submodules"
log "镜像: $MIRROR"

cd "$SRC" || die "cd src"
F=qtwebsockets-everywhere-src-5.15.2.tar.xz
if [ -d qtwebsockets-everywhere-src-5.15.2 ]; then
  log "源码已存在，跳过下载"
else
  log "下载 $F ..."
  curl -fL --retry 3 -m 900 -o "$F" "$MIRROR/$F" || die "下载失败"
  tar xf "$F" || die "解压失败"
  log "解压完成"
fi

log "========== qmake =========="
mkdir -p "$BUILD/qtwebsockets" && cd "$BUILD/qtwebsockets" || die "cd build"
"$PREFIX/bin/qmake" "$SRC/qtwebsockets-everywhere-src-5.15.2/qtwebsockets.pro" > "$LOG/qtwebsockets-qmake.log" 2>&1 \
  || { tail -20 "$LOG/qtwebsockets-qmake.log"; die "qmake 失败"; }

log "--- make -j$J ---"
make -j$J > "$LOG/qtwebsockets-make.log" 2>&1 \
  || { tail -40 "$LOG/qtwebsockets-make.log"; die "make 失败"; }

make install > "$LOG/qtwebsockets-install.log" 2>&1 || die "install 失败"

log "========== 完成 =========="
ls -d "$PREFIX/lib/cmake/Qt5WebSockets" 2>/dev/null && log "Qt5WebSockets 已就位 ✓" || die "Qt5WebSockets 未生成"
