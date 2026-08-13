# 修正计划：先让 Spectacle 活在 macOS 26，再抽到 agenterm-cu

## 0. 决策（已按你的思路定）

| 阶段 | 做什么 | 不做什么 |
|------|--------|----------|
| **P0 修改** | 原仓库内把 1.2 编过、装上、去掉系统过时警告，行为对齐 | 不换品牌、不改默认快捷键、不加拖拽吸附 |
| **P1 抽核** | JS 几何 → 无 UI 库（先仍可 ObjC/Swift，契约按 TECH-TREE §可拆边界） | 不在这一步重写菜单栏 |
| **P2 Rust / cu** | `~/repos/agenterm/crates/agenterm-cu` 加 `window-place`；几何用 Rust 重写并对齐 spec | 不把菜单栏 App 塞进 cu |

官方继任是 [Rectangle](https://github.com/rxhanson/Rectangle)（Swift，明确写了 based on Spectacle）。我们不 fork Rectangle：目标是 **自己能改的最小宿主 + 以后给 cu 用的动作核**。

## 1. 本机约束（开工前必须承认）

```text
macOS 26.5 (25F71)
xcode-select → /Library/Developer/CommandLineTools
xcodebuild → 需要完整 Xcode.app   ← P0 编译硬阻塞
/Applications/Spectacle.app = 2016 x86_64 1.2
```

没有完整 Xcode，**改 ObjC 工程无法验证**。P0 第一步是装 Xcode（App Store 或 `xcode-select -s /Applications/Xcode.app`），不是继续改源码碰运气。

## 2. P0 — 原仓库最小现代化（修改，不是重写）

按依赖顺序，每步都要能独立验证。

### P0.1 工程能在现代 Xcode 打开

- `LastUpgradeCheck` 走一遍 Xcode 推荐升级。
- `MACOSX_DEPLOYMENT_TARGET`：`10.9` → **13.0**（为 `SMAppService`；本机是 26，无需更老）。
- `ARCHS` = `arm64`（需要 Intel 再 universal）。
- `GCC_TREAT_WARNINGS_AS_ERRORS` 先保留，把警告清掉，不要关。
- Carthage：
  - 测试框架改 SPM（Specta 老，可先改 XCTest 只跑 calculation，或暂时从 target 摘掉 specs）。
  - **Sparkle 从 P0 主程序拿掉**。spectacleapp.com feed 已无意义，还拖着 DSA。更新需求记到以后自建。

**完成标准**：`xcodebuild -scheme Spectacle -configuration Debug` 退出码 0。

### P0.2 过时 API 替换（系统警告的代码侧）

| 文件 | 改 |
|------|----|
| `SpectacleLoginItemHelper.m` | `LSSharedFileList*` → `SMAppService.mainApp` register/unregister/status |
| `SpectacleAppDelegate.m` `openSystemPreferences:` | 删 scpt / `.prefPane`；改 `URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")` |
| `SpectacleShortcutTranslations.m` 等 | `NSControlKeyMask` → `NSEventModifierFlagControl`（其余同类） |
| Alert / 菜单 state | `NSWarningAlertStyle` → `NSAlertStyleWarning`；`NSOnState` → `NSControlStateValueOn` |
| `enableStatusItem` | 去掉 `highlightMode`（已 implicit）；用 `button.image` |
| Info.plist | 加 `NSAppleEventsUsageDescription`；删 `SU*` 或留着但主程序不再链 Sparkle |
| 新 `Spectacle.entitlements` | Hardened Runtime；如需要 Apple Events |

Carbon `RegisterEventHotKey` **P0 保留**。它不是弹「app is deprecated」的主因，换热键栈风险高于收益。

**完成标准**：干净编译；登录项在「登录项与扩展」里能开关；辅助功能跳转进对的面板。

### P0.3 打包形态（系统警告的二进制侧）

已装 app 报警是因为 **2016 SDK + thin Intel + 无公证**，只改源码不重签重装无效。

1. 用 **当前 macOS SDK** 编 Release。
2. `LSMinimumSystemVersion` 提到与 deployment target 一致。
3. 本地先 ad-hoc：`codesign -s - --deep --force --options runtime`。
4. 装到 `/Applications` 替换旧包，重启确认不再弹过时框。
5. 若仍弹：查 `spctl --assess`、Console 里 `amfid` / `syspolicyd`，补公证（有开发者账号再用 `notarytool`）。

**完成标准**：打开 app 无「需要更新」对话框；`file .../Spectacle` 含 `arm64`；18 个默认动作手测通过。

### P0.4 行为回归

- 跑还活着的 specs（calculation 是真值）。
- 手测清单：半屏循环、角落循环、thirds、跨屏、larger/smaller、Terminal.app 量化、undo/redo、黑名单、一小时禁用、`Shortcuts.json` 仍被读取。

## 3. P1 — 抽出几何核（仍在本仓库）

目的：让 P2 的 Rust 重写有规格，而不是对着 JS 臆造。

1. 把 `Window Position Calculations/*.js` 的规则写成一份语言无关伪代码（或直接 Rust，测试对着现有 spec 用例）。
2. `WindowPositionCalculator` 增加一条「native」路径，与 JS 并行，两边结果必须逐像素相等（允许 1pt，与现有中线容差一致）。
3. mover 链（standard / quantized / best-effort）保持 ObjC，先不搬。

**完成标准**：同一组 fixture，JS 与 native 输出一致。

## 4. P2 — Rust + agenterm-cu（以后，不在本次改 Spectacle 里做）

落点：[`~/repos/agenterm/crates/agenterm-cu`](../../agenterm/crates/agenterm-cu)。

```text
cu --target current --grant observe|actuate window-place \
    --action SpectacleWindowActionLeftHalf \
    [--window HANDLE]
```

约束（对齐 cu PRD 28/29/31）：

- 必须 `--target` + `--grant actuate`；未授权 `refused`。
- 走 AX 设框，不走截图坐标。
- 失败类型分开：`unsupported`（无 AX）/ `failed`（约束导致夹不进）/ `refused`。
- 审计写 `cu-audit.jsonl`，写不了就不执行。
- Action 字符串与 Spectacle 常量一致，避免两套词典。

菜单栏热键宿主可以继续是现代化后的 Spectacle；cu 只消费 `spectacle-core`。

## 5. 明确不走的路

- **在本机硬扛 2016 二进制**：Rosetta / 旧 SDK 只会更严，不是时间问题。
- **大改 UI / 加拖拽吸附 / 复制 Rectangle 全部功能**：超出「适应系统」。
- **P0 就上 Rust GUI**（cacao / tao / iced）：热键 + 菜单栏 + AX + 登录项一次性重写，回归面太大。核可以 Rust，壳先 ObjC/Swift。
- **继续依赖 Sparkle 1 / Carthage / Travis**：全是死工具链。

## 6. 建议开工顺序（P0 可执行清单）

1. 安装完整 Xcode，`xcode-select -s /Applications/Xcode.app/Contents/Developer`。
2. 开 `Spectacle.xcodeproj`，接受升级，记一份 warning 清单。
3. 删 Sparkle 链入；login item 换 `SMAppService`；系统设置 URL 换新。
4. 清 deprecated 枚举，deployment 13.0，arch arm64。
5. Debug 跑起来授权 AX，手测核心动作。
6. Release + runtime codesign，替换 `/Applications/Spectacle.app`，确认警告消失。
7. 再开 P1 几何双跑。

**P0 微修已落地（1.2.1）**：CLT `Makefile` 出 arm64，Sparkle stub，`SMAppService` 登录项，辅助功能跳转新 URL。本机已安装日用宿主。完整 Xcode / 公证仍可选，不是日用阻塞。

**停工**：P1/P2 不再在本仓库做。收录见 [FEATURE-CATALOG.md](FEATURE-CATALOG.md)；实现归 AgenTerm PRD 32 / v0.1.19。
