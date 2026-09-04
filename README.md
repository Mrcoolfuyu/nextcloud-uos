# Nextcloud Desktop for UOS（统信 UOS aarch64 源码编译与隔离部署）

在 **统信 UOS 20（aarch64，飞腾/鲲鹏等 ARM 平台）** 上，从源码编译 **Nextcloud Desktop 3.13.x** 并隔离部署的完整方案。重点解决系统自带 Qt 5.11 与 Nextcloud 3.x 不兼容、以及无 GPU 环境下 QML 主窗口白屏等问题。

## 为什么需要它

- UOS 20 自带 Qt 5.11.3（深度定制 DTK 版本），而 Nextcloud Desktop 3.x 需要 Qt ≥ 5.15；apt 源里只有 2.5.1 的旧客户端，无法满足。
- 直接升级系统 Qt 会破坏 DDE 桌面环境。
- 因此采用 **隔离编译**：自编 Qt 5.15.2 装到 `/opt/qt515`，Nextcloud 装到 `/opt/nextcloud`，运行时通过启动器隔离，不污染系统 Qt。

## 特性

- **隔离部署**：自编 Qt 5.15.2 + Nextcloud 3.13.4git，安装于 `/opt`，不影响系统 Qt 5.11 / DDE。
- **中文界面**：补编 `qttools` 模块以生成 `client_zh_CN.qm`。
- **无 GPU 适配**：通过 Mesa llvmpipe 软件 GL 渲染主窗口，避开 `QtGraphicalEffects` 着色器在软件 QML 后端下白屏的问题。
- **启动器隔离**：自动设置 `LD_LIBRARY_PATH` / `QT_PLUGIN_PATH` / `QML2_IMPORT_PATH`，并对 Wayland+XWayland 环境做 `DISPLAY` 兜底。

## 环境要求

| 项目 | 规格 |
| --- | --- |
| 系统 | 统信 UOS 20（aarch64） |
| 编译器 | gcc 8.3（C++17 需显式链接 `libstdc++fs`） |
| 磁盘 | `/opt` 所在分区 ≥ 2GB 可用；构建中间产物另占约 5GB（建议放 `/home`） |
| 服务端 | Nextcloud（本方案对接 `https://home.cnraft.com:9443`，最低支持桌面端 3.2.50，3.13 满足） |

## 目录结构

```
nextcloud-uos/
├── nextcloud-uos.sh          # 启动器（隔离环境 + 软件 GL）
├── nextcloud-dialog-uos.sh   # 仅打开主对话框的封装脚本
├── nextcloud.desktop         # 桌面入口
├── icons/nextcloud.png       # 图标
├── build/                    # 核心编译流水线脚本
│   ├── 01-audit.sh
│   ├── 02-deps.sh
│   ├── 04-download-qt.sh
│   ├── 06-build-qt-all.sh
│   ├── 07-download-rest.sh
│   ├── 08-download-qttools.sh
│   ├── 09-build-rest.sh
│   ├── 10-setup-launcher.sh  # 即 nextcloud-uos.sh 的生成脚本
│   ├── 12-install-xcb-deps.sh
│   ├── 13-rebuild-qtbase-xcb.sh
│   ├── 14-build-nc.sh
│   └── 16-build-websockets.sh
├── scripts/                  # 完整过程脚本（含诊断/验证，共 37 个）
├── README.md
└── LICENSE                   # MIT
```

## 使用方法

在目标 UOS 主机上（需有 sudo 权限的普通用户）：

```bash
# 1. 将 build/ 上传到目标机，例如 /home/<user>/ncbuild
# 2. 依次执行（脚本已处理依赖、下载、编译、隔离部署）
bash build/01-audit.sh
sudo bash build/02-deps.sh
bash build/04-download-qt.sh
bash build/06-build-qt-all.sh
bash build/07-download-rest.sh
bash build/08-download-qttools.sh
bash build/09-build-rest.sh
sudo bash build/12-install-xcb-deps.sh
bash build/13-rebuild-qtbase-xcb.sh
sudo apt-get install -y libkf5archive-dev   # 不牵动系统 Qt，可安全安装
bash build/16-build-websockets.sh
bash build/14-build-nc.sh
bash build/10-setup-launcher.sh
```

完成后双击桌面「Nextcloud」图标，或在终端执行：

```bash
/opt/nextcloud/bin/nextcloud-uos.sh
```

登录服务器，输入账号、选择同步目录，完成首次同步。

## 已知坑（已解决，记录于脚本注释）

1. **xcb 平台插件缺失**：漏装 `libx11-xcb-dev` 会导致 Qt 编出但无 `libqxcb.so`，GUI 起不来 → 补全依赖后重编 qtbase。
2. **`std::filesystem` 链接失败（gcc 8）**：需追加 `libstdc++fs`，且必须用 `CMAKE_CXX_STANDARD_LIBRARIES`（放在链接命令末尾），而非 `CMAKE_*_LINKER_FLAGS`（会被 ld 单遍链接忽略）。
3. **缺 `KF5Archive` / `qtwebsockets`**：Nextcloud 3.13 依赖，需补编/安装。`libkf5archive-dev` 不牵动系统 Qt，可安全安装。
4. **主窗口白屏（QML）**：`QtGraphicalEffects` 着色器在 `QT_QUICK_BACKEND=software` + `QT_XCB_GL_INTEGRATION=none` 下不实现 → 改用 Mesa 软件 GL（`LIBGL_ALWAYS_SOFTWARE=1`），不禁用 GL 集成。
5. **单实例保护**：新实例报 `Already running, exiting...` 是正常行为，非崩溃。

## UOS 商店打包

按统信应用打包规范（UOS Packaging Specification v1.2）打包为标准 deb：

```
com.cnraft.nextcloud_3.13.4.0_arm64.deb   （约 31MB，安装后约 160MB）
```

- 结构：`/opt/apps/com.cnraft.nextcloud/{entries,files,info}`，无 postinst 钩子，不修改系统目录
- `files/qt/` 自带 Qt 5.15.2 运行时；`files/nextcloud/` 为客户端本体；`qt.conf` 使用相对路径，包可重定位
- `info` JSON：appid / name / version / arch(arm64) / permissions（trayicon、notification）
- `Depends` 由 ldd → dpkg-query 实算（含 usr-merge 路径回退），覆盖 X11/xcb/GL/fontconfig/ssl 等全部真实依赖
- 安装时由 UOS 的 `deepin-app-store` 触发器自动把 `entries/` 软链接到 `/usr/share/applications`

一键打包脚本见 `packaging/package-uos.sh`（在目标 UOS 机器上执行）。

## 许可证

[MIT](LICENSE) © 2026 傅宇 / Mrcoolfuyu

## 安装与桌面图标

- 安装后由 `postinst` 自动为每个真实用户（uid>=1000）在桌面生成 `nextcloud.desktop` 启动器图标（显示名 `nextcloud`），卸载时 `postrm` 自动清理。
- 应用入口与图标统一按 appid 命名（`com.cnraft.nextcloud`），由 UOS 的 deepin-app-store 触发器自动符号链接进系统菜单与 hicolor 图标主题，任何 UOS 机器上都能正确显示。

## 依赖安装说明

包内 `Depends` 字段由 ldd + dpkg 实算生成（76 个包，含 X11/xcb 全家桶、libgl1、fontconfig、libssl1.1 等）：

- `sudo apt install ./com.cnraft.nextcloud_3.13.4.0_arm64.deb` 或经 UOS 软件商店/双击安装：**自动安装全部依赖**
- `sudo dpkg -i xxx.deb`：不解析依赖，缺库会报错，补一句 `sudo apt -f install` 即可
- 仅适用于 arm64 架构机器
