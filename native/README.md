# 原生 Qt 客户端

`native` 是 DouyuMonitor 当前唯一维护的桌面客户端：Qt Quick/QML 负责界面，C++20 负责应用逻辑，libmpv 负责播放，独立 `streamget_service.exe` 负责斗鱼资料与播放变体解析。

## CSTG狼团S1导航页

顶栏房间列表按钮右侧提供 CSTG狼团S1导航页入口。导航页读取应用内置的公会名单，并按“设置 -> 队伍管理”中维护的队伍顺序分组展示；没有分配队伍的成员进入“未分队”。队伍栏位独立于房间分组和工作区预设，支持空队伍、重命名、排序和删除，也不会混用旧分组语义。

导航页展示内置名单、主播头像、开播状态、房间号及加入状态，并按团长、队伍、队长、队员、其他分层展示。角色在设置页的本地活动配置中维护，队伍管理可预览并导入野榜队伍。已确认房间号可直接加入当前工作区；无法自动确认的成员显示“待确认”，需要在成员行手工输入房间号。快捷加入受当前构建的布局容量限制，并会接受控制器返回的重复房间或容量错误。

开播状态会写入工作区缓存，并记录检查时间。15 分钟内的重复打开导航页直接复用缓存，不再为全部主播重新排队发送状态请求；导航页可见期间仍每分钟刷新状态。空工作区且导航页隐藏时延迟启动名单检查。状态更新保留列表行，导航页隐藏、页面切换或窗口失去激活会关闭悬浮卡片。

## 目录职责

| 目录 | 职责 |
| --- | --- |
| `app` | Qt 入口与 QML 界面资源。 |
| `src/ui` | 控制器、QML 模型与 libmpv Quick Item。 |
| `src/workspace` | 多房协调、持久化、刷新、质量和通知规则。 |
| `src/media` | 播放源与播放控制。 |
| `src/service` | StreamGet 子进程协议与客户端。 |
| `src/danmaku` | 斗鱼弹幕协议、连接、治理和会话。 |
| `service` | StreamGet Python 服务和 Python 单元测试。 |
| `tests` | C++、QML 和运行时回归测试。 |
| `cmake` | Qt 部署、运行时依赖和发布载荷校验脚本。 |
| `scripts` | 依赖准备、服务构建和安装包生成脚本。 |

完整逐文件说明见根目录的 [文件职责索引](../docs/文件职责索引.md)。

## 前置条件

Windows x64：

- Windows x64
- Visual Studio 2022（MSVC x64 工具链）
- CMake 3.24 或更高版本、Ninja
- Qt 6.8.3 MSVC 2022 x64
- libmpv SDK：`include/mpv/client.h`、`libmpv.lib`、`libmpv-2.dll`

macOS（Apple Silicon）：

- macOS 13 或更高版本、Xcode Command Line Tools
- Homebrew Qt（`brew install qt`）与 libmpv（`brew install mpv`）
- CMake 3.24 或更高版本、Ninja（`brew install ninja`）
- 使用独立 libmpv SDK 构建时，把 `MPV_ROOT` 指向包含 `include/mpv/client.h` 和 `libmpv.dylib` 的目录

`vcpkg-configuration.json` 固定项目依赖基线。libmpv 不通过 vcpkg 分发，Windows 必须由 `MPV_ROOT` 显式指定；macOS 默认从 Homebrew 前缀解析 `qt` 与 `mpv`，无需额外环境变量。

## 配置和构建

### Windows

在 `native` 目录内的 Visual Studio x64 Developer PowerShell 中设置环境变量：

```powershell
$env:QT_ROOT = 'D:\Qt\6.8.3\msvc2022_64'
$env:MPV_ROOT = (Resolve-Path .\sdk\mpv).Path
```

Debug：

```powershell
cmake --preset windows-x64
cmake --build --preset windows-x64-debug
ctest --preset windows-x64-debug
```

Release：

```powershell
cmake --preset windows-x64-release
cmake --build --preset windows-x64-release --target douyu_monitor_native
ctest --preset windows-x64-release
```

Release 可执行文件为：

```text
native/out/build/windows-x64-release/douyu_monitor_native.exe
```

部署步骤由 CMake 调用匹配的 `windeployqt` 完成。Release 目录必须包含 `platforms/qwindows.dll` 和按导入库实际名称部署的 `mpv.dll`；不要混用 Debug 与 Release 的 Qt DLL 或平台插件。SDK 源文件仍为 `libmpv-2.dll`，构建后会复制为应用加载名 `mpv.dll`。

### macOS

```bash
brew install qt mpv ninja
cd native

cmake --preset macos-arm64-release
cmake --build --preset macos-arm64-release --target douyu_monitor_native
ctest --preset macos-arm64-release
```

macOS 目标构建为应用包：

```text
native/out/build/macos-arm64-release/douyu_monitor_native.app
```

Qt 由 `cmake --preset` 自动从 `brew --prefix qt` 解析；需要指定其他 SDK 时设置 `QT_ROOT`。开发构建直接使用 Homebrew 的 `libmpv.2.dylib`，无需复制运行库。应用包图标由 `app/assets/douyu_monitor.icns` 提供，状态栏和窗口图标使用同源的 `douyu_monitor.png`。

生成可分发（已内嵌 Qt 与 libmpv 依赖）的应用包：

```bash
./scripts/bundle-macos-app.sh
```

输出 `native/out/installer/DouyuMonitor.app`，其中已包含 `macdeployqt` 部署的 Qt 框架、内嵌到 `Contents/Frameworks` 的 libmpv 依赖树、StreamGet 服务以及 ad-hoc 签名。仓库不提供代码签名与公证，首次运行需要在“系统设置 -> 隐私与安全性”中放行。

## StreamGet 服务

准备 Python 构建环境并打包服务：

```powershell
.\scripts\bootstrap-streamget-service.ps1
.\scripts\build-streamget-service.ps1
```

macOS/Linux：

```bash
./scripts/bootstrap-streamget-service.sh
./scripts/build-streamget-service.sh
```

Windows 产物是 `native/out/service/streamget_service/streamget_service.exe`，macOS 产物是同目录下的 `streamget_service`。主程序按平台可执行文件名查找服务：Windows 安装在程序目录或其 `streamget_service` 子目录，macOS 应用包使用 `Contents/Resources/streamget_service`（`Contents/MacOS` 下的嵌套目录无法通过代码签名校验）。

服务以私有 JSONL stdin/stdout 协议运行。主程序只在内存中持有当前播放会话的地址；不会持久化播放 URL、查询参数、Cookie、Token、签名、原始弹幕帧或原始服务诊断。

搜索结果的可选布尔字段 `statusKnown` 默认 `true`，兼容旧服务。名单提示在元数据查询失败时使用 `statusKnown: false`；此时 `online` 不是权威开播状态，界面显示“状态未知”，不触发离线通知。精确名单查询补充房间资料，模糊查询合并名单与远程结果并按房间号去重。

导航页可见时每分钟刷新开播状态，已验证的房间资料与头像使用缓存。工作区保存失败会保留内存中的更改并显示重试入口。活动角色映射在设置页编辑，存储于 `DouyuMonitor/eventMappingV1`，JSON 版本为 1；远端明确的队伍优先于本地队长回退配置，角色配置不代表远端角色自动同步。

## 后台托管

关闭窗口和最小化都会隐藏主窗口并进入系统托盘。Windows 使用 `Shell_NotifyIcon`，macOS 使用状态栏条目（NSStatusItem）并提供“显示窗口 / 退出程序”菜单；没有托盘后端时（例如未打包的 macOS 测试进程）应用保持前台运行。后台期间 StreamGet、房间状态检测、系统通知和 libmpv 音频继续运行；Qt Quick 视频渲染和弹幕展示会暂停，以降低后台资源占用。通过托盘“显示窗口”恢复时，播放器重新建立渲染上下文并恢复弹幕展示。托盘“退出程序”才会停止服务并结束应用进程。

系统通知在 Windows 使用 Shell_NotifyIcon 气泡，在 macOS 使用 UserNotifications，需要应用包身份和用户授权；未授权时通知静默降级，其余功能不受影响。

## 自测与安装包

Windows 运行程序自测：

```powershell
.\out\build\windows-x64-release\douyu_monitor_native.exe --self-test
```

macOS：

```bash
./out/build/macos-arm64-release/douyu_monitor_native.app/Contents/MacOS/douyu_monitor_native --self-test
```

构建安装包：

```powershell
.\scripts\build-windows-installer.ps1
```

输出文件：

```text
native/out/installer/DouyuMonitor-Setup-V0.2.18.exe
```

安装器使用 Inno Setup 6。正式版安装包名为 `DouyuMonitor-Setup-V0.2.18.exe`；24 路全解码测试版使用 `-Version 0.2.18-beta.24` 生成独立文件名。安装时可选择目标目录；选择 `D:\` 等磁盘根目录时会自动归一化到 `D:\DouyuMonitor`。安装完成后创建开始菜单和可选的桌面快捷方式，并登记到 Windows 设置的“已安装的应用”。安装目录中的 `unins000.exe` 是标准卸载入口。运行时载荷校验会拒绝测试程序、构建残留以及 Electron、Chromium、Node、Qt WebEngine 文件。

安装器脚本回归检查：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\test-installer-script.ps1
```

重新生成应用图标：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\generate-app-icon.ps1
```

macOS 图标（`.icns` 与运行时 PNG）从同一个 SVG 生成：

```bash
./scripts/generate-app-icon-macos.sh
```

## 验收边界

自动化验证覆盖 C++、QML、服务协议、libmpv 依赖与自测入口。正式版布局最多支持 16 路并全部解码，24 路全解码测试版通过独立构建开关生成。发布前仍应在目标用户环境完成真实斗鱼 1/4/9/12/16/24 路长时间播放验收，重点观察高路数下的弹幕、CPU/GPU、内存和关闭稳定性。
