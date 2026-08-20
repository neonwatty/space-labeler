# SpaceLabeler

[![Discord](https://img.shields.io/badge/Discord-Join%20Server-7289da?style=flat&logo=discord&logoColor=white)](https://discord.gg/7xsxU4ZG6A)

一个极简的 macOS 菜单栏应用，用于给你的虚拟桌面（Spaces）命名和配色。

macOS 本身不支持为 Spaces 命名——而 `TotalSpaces2` 又因 Apple 的 SIP 加固而消亡——SpaceLabeler 正好填补了这个让人恼火的小空缺。它会在菜单栏显示一个彩色圆点和当前 Space 的名称，切换 Space 时自动更新，并支持在弹出面板中为每个 Space 重命名、换色。

网站：https://neonwatty.github.io/space-labeler/

## 环境要求

- macOS 13（Ventura）或更高版本
- Xcode 15 或更高版本
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`

## 安装

```sh
git clone https://github.com/neonwatty/space-labeler.git
cd space-labeler
make install
```

该命令会生成 Xcode 工程、构建 Release 版本、把产物拷贝到 `~/Applications/SpaceLabeler.app`，并启动它。

### 开机自启（可选）

```sh
make install-login
```

这会写入 `~/Library/LaunchAgents/com.jeremywatt.SpaceLabeler.plist` 并用 `launchctl load` 加载，重启后菜单栏图标会自动恢复。卸载方式：

```sh
launchctl unload ~/Library/LaunchAgents/com.jeremywatt.SpaceLabeler.plist
rm ~/Library/LaunchAgents/com.jeremywatt.SpaceLabeler.plist
```

如果未执行 `install-login`，应用**不会**随登录自动启动——重启后需通过 `Cmd+Space` → "Space Labeler" → `Enter` 手动启动。

### 为什么用 LaunchAgent 而不是 `SMAppService`？

应用采用 ad-hoc 签名（无开发者 ID）。对 ad-hoc 签名 bundle 调用 `SMAppService.mainApp.register()` 虽然返回 `.enabled` 且无报错，但 macOS 的 BackgroundTaskManagement 守护进程会静默拒绝持久化记录——应用实际上不会在登录时重新启动。LaunchAgent plist 是可行的解决方案。

## 使用说明

看你的菜单栏——会看到一个彩色圆点和当前 Space 的名称（例如 `● Space 1`）。用 `Ctrl+←` / `Ctrl+→` 切换 Space 时标签会同步更新。点击菜单栏图标打开弹出面板，即可重命名或重新着色当前 Space。

点击「All Spaces」列表中的任意 Space 可直接跳转过去。跳转通过合成系统自带的「切换到桌面 N」快捷键（`Ctrl+1` … `Ctrl+9`）实现，因此切换使用 macOS 原生的过渡动画。需要一次性完成两项配置：

1. **授予辅助功能权限** — 设置 → 隐私与安全 → 辅助功能 → 打开 Space Labeler（应用通过它来发送 `Ctrl+N` 键事件）。
2. **开启桌面切换快捷键** — 设置 → 键盘 → 键盘快捷键 → 调度中心 → 勾选「切换到桌面 1/2/3…」。

列表按照调度中心（Mission Control）看到的桌面顺序（1、2、3…）展示，因此映射是自动的。第 9 个桌面之后的 Space 无法直接跳转——请改用 `Ctrl+←` / `Ctrl+→`。如果缺少权限或快捷键，弹出面板会内联显示同样的配置路径（设置 → 隐私与安全 → 辅助功能 → 打开 Space Labeler），而不是静默失败。

标签与颜色在重启后仍会保留，存储在 `UserDefaults` 的 `SpaceLabels.v1` 键下。

## 开发

```sh
make build      # xcodegen + xcodebuild Release
make test       # xcodebuild test
make clean      # 删除生成的 xcodeproj 与 build/
```

或者使用原始命令：

```sh
xcodegen generate
xcodebuild build -project SpaceLabeler.xcodeproj -scheme SpaceLabeler \
  -configuration Release -destination 'platform=macOS' -derivedDataPath build
xcodebuild test  -project SpaceLabeler.xcodeproj -scheme SpaceLabeler \
  -destination 'platform=macOS' -derivedDataPath build
swift-format lint --recursive Sources Tests
```

Xcode 工程文件（`SpaceLabeler.xcodeproj`）已被 gitignore——真正的源头是 `project.yml`。克隆仓库后或修改 `project.yml` 后，务必先运行 `xcodegen generate`（`make build` 会自动执行）。

## 关于私有 API 的说明

`Sources/SkyLight.swift` 在运行时通过 `dlsym` 解析以下未文档化的 CoreGraphics 符号：

- `CGSMainConnectionID` — 窗口服务器的连接 ID
- `CGSGetActiveSpace` — 当前激活的 Space ID
- `CGSCopyManagedDisplayForSpace` — Space 归属的显示器
- `CGSCopyManagedDisplaySpaces` — 某显示器上按调度中心顺序排列的 Spaces

前两个用于读取当前 Space ID；后两个支撑「点击 Space 跳转」功能。注意：旧的枚举符号 `CGSCopySpacesForDisplay`（TotalSpaces/Hammerspoon 时代的用法）在 macOS 26 上已不存在——`CGSCopyManagedDisplaySpaces` 是其现代替代品，返回按显示器组织的字典（`Spaces`、`Current Space`、`Display Identifier`）。

这些符号自 macOS 10.11 左右以来一直保持稳定，但不属于 Apple 的公共 API 契约。如果 Apple 移除它们，`SkyLight.currentSpaceID()` 会返回 `nil`，应用会优雅降级为只显示一个 "Space" 标签，而不会崩溃。测试套件包含冒烟测试（`SkyLightSmokeTests`），一旦新 macOS 版本上符号无法解析，会在 CI 中大声失败。

切换 Space 刻意**不**使用私有的 "move to space" 调用——在现代 macOS 上它们都无法真正触发切换。取而代之的是发送系统自带的 `Ctrl+N` 快捷键，这正是需要辅助功能权限和开启调度中心快捷键的原因（见[使用说明](#使用说明)）。

由于私有符号查找与沙盒不兼容，App Sandbox 和 Hardened Runtime 均已关闭。该应用有意不通过 Mac App Store 分发。

## 许可证

MIT。详见 `LICENSE`。
