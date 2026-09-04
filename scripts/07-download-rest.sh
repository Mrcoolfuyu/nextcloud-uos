#!/bin/bash
# L420x - 预下载 qtkeychain 与 Nextcloud Desktop 源码（与 Qt 编译并行，仅占网络）
set -u
cd /home/mrcool/ncbuild || exit 1

echo "===== 1. QtKeychain 0.13.2 ====="
if [ -d src/qtkeychain/.git ]; then
  echo "  已存在，跳过"
else
  rm -rf src/qtkeychain
  for i in 1 2 3; do
    echo "  尝试克隆 (第 $i 次)..."
    if git clone --depth 1 -b v0.13.2 https://github.com/frankosterfeld/qtkeychain.git src/qtkeychain 2>&1 | tail -3; then
      [ -d src/qtkeychain/.git ] && break
    fi
    rm -rf src/qtkeychain
    sleep 5
  done
fi
if [ -d src/qtkeychain/.git ]; then
  echo "  OK: $(cd src/qtkeychain && git describe --tags 2>/dev/null)"
else
  echo "  !! qtkeychain 克隆失败"
fi

echo ""
echo "===== 2. Nextcloud Desktop stable-3.13 ====="
if [ -d desktop/.git ]; then
  echo "  已存在，跳过"
else
  rm -rf desktop
  for i in 1 2 3; do
    echo "  尝试克隆 (第 $i 次)..."
    if git clone --depth 1 -b stable-3.13 https://github.com/nextcloud/desktop.git desktop 2>&1 | tail -5; then
      [ -d desktop/.git ] && break
    fi
    rm -rf desktop
    sleep 5
  done
fi

if [ -d desktop/.git ]; then
  cd desktop || exit 1
  echo "  HEAD: $(git rev-parse --short HEAD)"
  echo "  分支: $(git rev-parse --abbrev-ref HEAD)"
  echo ""
  echo "  --- CMakeLists 头部 ---"
  grep -m 12 -E "cmake_minimum_required|project\(|VERSION|CMAKE_CXX_STANDARD" CMakeLists.txt
  echo ""
  echo "  --- 源码体积 ---"
  du -sh /home/mrcool/ncbuild/desktop
  echo ""
  echo "  --- 子模块 ---"
  cat .gitmodules 2>/dev/null | head -20 || echo "  无 .gitmodules"
else
  echo "  !! nextcloud desktop 克隆失败"
fi
