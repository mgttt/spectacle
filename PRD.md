# Spectacle PRD（从源码还原）

> 范围：[`mgttt/spectacle`](https://github.com/mgttt/spectacle) = 上游 [`eczarny/spectacle`](https://github.com/eczarny/spectacle) 的干净 fork（描述「AI continue dev」）。上游已 archived，最后一次正式发布 **1.2**（2016-12）。
>
> 本文件是 **产品合同**，不是实现说明。实现树见 [docs/TECH-TREE.md](docs/TECH-TREE.md)，修正路径见 [docs/MODERNIZATION-PLAN.md](docs/MODERNIZATION-PLAN.md)。
>
> 当前本机：macOS **26.5**；已安装 `/Applications/Spectacle.app` = 1.2 (672)，**thin x86_64**，SDK **10.12**，Xcode **8.2**，2016-12-22 Developer ID 签名、**未公证**。这就是系统弹出「已过时 / 需要开发者更新」的直接原因。

## 1. 一句话

不碰鼠标，用全局快捷键把**当前前台窗口**放到屏幕上的预定义区域（半屏 / 角落 / 三分 / 全屏 / 居中），支持多显示器、尺寸微调、以及按应用的撤销/重做。

## 2. 非目标（明确不做）

- 不是平铺窗口管理器（不自动重排其它窗口、不维护格子占用表）。
- 不管理未聚焦窗口、不跨应用批量操作。
- 不提供窗口吸附到边缘的拖拽手势（那是 Magnet / Rectangle 后续加的）。
- 不保证能驱动所有应用：只走 macOS Accessibility（AX）。非 Cocoa / 自绘窗口 / 对尺寸有硬约束的窗口可以失败。
- 不修改窗口的 z-order 以外的应用内部状态。

## 3. 角色与场景

| 角色 | 场景 |
|------|------|
| 键盘用户 | 写代码/看文档时把窗口甩到左半 / 右半 / 另一块屏 |
| 多屏用户 | 把当前窗移到 next/previous display |
| 终端用户 | Terminal / iTerm 因行列约束无法精确贴边时，仍要「尽量贴进目标矩形」 |
| 间歇用户 | 演示/游戏时临时关一小时快捷键，或对某个 App 单独禁用 |
| 系统 | 无障碍未授权时必须挡住并引导去「辅助功能」 |

## 4. 功能需求

### 4.1 窗口动作（核心）

每个动作的输入是「前台聚焦窗口 + 源屏可见区 + 目标屏可见区」，输出是一个目标 `CGRect`。动作名是稳定 ID，后续 `agenterm-cu` 应复用同一套 ID。

| Action ID | 默认快捷键 | 行为 |
|-----------|------------|------|
| `MoveToCenter` | ⌥⌘C | 居中，**不改尺寸** |
| `MoveToFullscreen` | ⌥⌘F | 铺满目标屏 **visibleFrame**（不是 macOS 原生全屏 Space） |
| `MoveToLeftHalf` | ⌥⌘← | 左半。重复按在 **1/2 → 2/3 → 1/3** 间循环（仅当垂直中线对齐时） |
| `MoveToRightHalf` | ⌥⌘→ | 右半，同样 1/2↔2/3↔1/3 |
| `MoveToTopHalf` | ⌥⌘↑ | 上半 |
| `MoveToBottomHalf` | ⌥⌘↓ | 下半 |
| `MoveToUpperLeft` | ⌃⌘← | 左上角 1/4；重复按在该象限内走三分宽度 |
| `MoveToLowerLeft` | ⌃⇧⌘← | 左下角 |
| `MoveToUpperRight` | ⌃⌘→ | 右上角 |
| `MoveToLowerRight` | ⌃⇧⌘→ | 右下角 |
| `MoveToNextThird` | ⌃⌥→ | 水平三等分：左 → 中 → 右，再切到垂直三等分循环 |
| `MoveToPreviousThird` | ⌃⌥← | 上一第三 |
| `MakeLarger` | ⌃⌥⇧→ | 向四周长大，尽量保持贴边 |
| `MakeSmaller` | ⌃⌥⇧← | 向内缩小，尽量保持贴边 |
| `MoveToNextDisplay` | ⌃⌥⌘→ | 按稳定屏序移到下一块屏（保留相对布局语义由计算器决定） |
| `MoveToPreviousDisplay` | ⌃⌥⌘← | 上一块屏 |
| `UndoLastMove` | ⌥⌘Z | 当前 **应用** 的窗口位置历史后退 |
| `RedoLastMove` | ⌥⇧⌘Z | 前进 |

循环三分是 Spectacle 的产品指纹，移植时必须保留（Rectangle 也保留了）。

### 4.2 快捷键

- 全局热键，不要求 Spectacle 在前台。
- 用户可在偏好窗口重录或清空（清空 = 禁用该动作）。
- 录制时要避开系统 symbolic hot keys 冲突；冲突则拒绝并提示。
- 至少包含一个修饰键（⌥ / ⌘ / ⌃ / ⇧）；单独 ⌥ 允许。
- 存储可迁移：旧 `NSUserDefaults` → `~/Library/Application Support/Spectacle/Shortcuts.json`。

### 4.3 执行约束（必须遵守，否则「看起来坏了」）

1. **只动前台聚焦窗口**（`kAXFocusedWindowAttribute`）。
2. **尊重应用自己的最小/最大尺寸**。目标矩形与约束冲突时不得强行写成非法尺寸。
3. **Terminal / iTerm 类行列量化窗口**：先写目标矩形；若实际矩形偏大，每次各边减 2pt 重试，直到落入 85% 下限，再把结果在目标矩形内居中。代价是轻微抖动，这是有意的。
4. **Best-effort 夹紧**：量化后若仍溢出 visibleFrame，把窗口夹回可见区（修过 #700：左/右半再 Center 会在菜单栏下留 1–2px 缝，计算要用 round 而不是只 floor）。
5. **sheet / 系统对话框** 拒绝操作并 `NSBeep`。
6. **坐标系**：AX 是顶原点，AppKit `NSScreen.frame` 是底原点。任何读写都必须做 `normalizeCoordinatesOfRect`。
7. **多屏顺序稳定**：主屏（origin 0,0）优先，其余按 y 再按 x 排序，保证 next/previous 可预测。
8. **历史按应用隔离**：每个 bundle 一条 undo stack，不是全局一条。

### 4.4 权限与生命周期

- 启动时若 `AXIsProcessTrusted` 为假，**模态**弹出辅助功能说明，并提供跳转系统设置。
- 菜单栏常驻（`LSUIElement`，无 Dock 图标）。可关菜单栏图标。
- 可设登录启动。
- 可「禁用一小时」或「对当前 App 禁用」。
- 硬黑名单默认含 Photoshop / Steam / Spectacle 自己。
- 双击 Dock/再次打开（虽是 agent）应打开偏好窗口。

### 4.5 非功能

| 项 | 要求 |
|----|------|
| 延迟 | 热键到窗口落地 < 50ms 体感；计算器是纯几何 |
| 可靠性 | 失败只 beep + 打日志，不崩 |
| 兼容 | 当前目标：**本机 macOS 26.5 + Apple Silicon**，不再承诺 10.9 |
| 分发 | 至少能本地 ad-hoc / Developer ID + 公证后运行，不再依赖 spectacleapp.com 的 Sparkle DSA 源 |
| 体积 | 菜单栏工具，应保持小（现依赖 Sparkle 是最大头） |
| 可测试 | 窗口几何必须可单测（现有 Specta/OCMockito 套件覆盖 18 个 calculation + shortcut） |

## 5. 成功标准（这次「适应系统」）

1. macOS 26 不再对二进制弹 **「已过时 / needs to be updated」**。
2. Apple Silicon **原生 arm64**（可保留 universal）。
3. 辅助功能授权流程在「系统设置」（不再是「系统偏好设置」）能走通。
4. 登录项走 `SMAppService`，不再用已删/已废的 `LSSharedFileList`。
5. 18 个默认动作 + 循环三分 + undo/redo + 多屏 行为与 1.2 一致（可用现有 spec 当 oracle）。
6. 不破坏用户已有 `Shortcuts.json`。

## 6. 后续产品延伸（本仓库不再做）

日用停在 1.2.1。吸收合同：[docs/FEATURE-CATALOG.md](docs/FEATURE-CATALOG.md)。

AgenTerm 归口：`prd/PRD_02_32_cu_window_placement.md`（子树 28 下第四个孩子）。
开工：`plan/plan-v0.1.19.md`（v0.1.18 仍是在制版本）。

```text
cu --target current --grant actuate window-place --action left-half [--window HANDLE]
```

`cu` 是 agent 命令面。热键宿主继续是本 App，直到另开产品决定。
