# Spectacle 功能收录（给 agenterm-cu）

本文件是吸收 SSOT。菜单栏 / 热键 / 登录项 **不进 cu**。cu 只收「对指定窗口施加命名摆放动作」。

来源：本仓库 1.2 行为 + 1.2.1 日用宿主。许可 MIT（Eric Czarny）。Action 字符串保持原样，避免两套词典。

AgenTerm 产品合同：`prd/PRD_02_32_cu_window_placement.md`。执行：`plan/plan-v0.1.19.md`（v0.1.18 仍是在制版本；0.1.19 **开始**做，不承诺一次做完）。

## 收

### 动作 ID（稳定）

| Action ID | 默认快捷键（宿主才用） | 语义 |
|-----------|------------------------|------|
| `SpectacleWindowActionCenter` | ⌥⌘C | 居中，不改尺寸 |
| `SpectacleWindowActionFullscreen` | ⌥⌘F | 铺满目标屏 visibleFrame（不是原生 Space 全屏） |
| `SpectacleWindowActionLeftHalf` | ⌥⌘← | 左半；连按 1/2 → 2/3 → 1/3（中线容差 ≤ 1pt） |
| `SpectacleWindowActionRightHalf` | ⌥⌘→ | 右半，同上循环 |
| `SpectacleWindowActionTopHalf` | ⌥⌘↑ | 上半 |
| `SpectacleWindowActionBottomHalf` | ⌥⌘↓ | 下半 |
| `SpectacleWindowActionUpperLeft` | ⌃⌘← | 左上；象限内宽度三分循环 |
| `SpectacleWindowActionLowerLeft` | ⌃⇧⌘← | 左下 |
| `SpectacleWindowActionUpperRight` | ⌃⌘→ | 右上 |
| `SpectacleWindowActionLowerRight` | ⌃⇧⌘→ | 右下 |
| `SpectacleWindowActionNextThird` | ⌃⌥→ | 水平左→中→右，再切垂直三等分 |
| `SpectacleWindowActionPreviousThird` | ⌃⌥← | 上一第三 |
| `SpectacleWindowActionNextDisplay` | ⌃⌥⌘→ | 稳定屏序下一块 |
| `SpectacleWindowActionPreviousDisplay` | ⌃⌥⌘← | 上一块 |
| `SpectacleWindowActionLarger` | ⌃⌥⇧→ | 向外长大，尽量保持已贴边 |
| `SpectacleWindowActionSmaller` | ⌃⌥⇧← | 向内缩小，尽量保持已贴边 |
| `SpectacleWindowActionUndo` | ⌥⌘Z | **可选后期**：按应用历史后退 |
| `SpectacleWindowActionRedo` | ⌥⇧⌘Z | **可选后期**：前进 |

CLI 可用短名（kebab，与常量双写、一对一）：`center` `fullscreen` `left-half` `right-half` `top-half` `bottom-half` `upper-left` `lower-left` `upper-right` `lower-right` `next-third` `previous-third` `next-display` `previous-display` `larger` `smaller` `undo` `redo`。

### 必须保住的规则

1. 只动指定窗（cu 用 `--window`；缺省才是前台聚焦窗）。
2. 尊重应用最小/最大尺寸；不得写成非法框。
3. Terminal / iTerm 行列量化：写目标 → 实际偏大则每次 −2pt，下限 85%，再在目标框内居中。
4. Best-effort：量化后仍溢出 visibleFrame 则夹回。几何用 round，避免菜单栏下 1–2px 缝。
5. sheet / 系统对话框：拒绝，typed `failed`（宿主是 beep）。
6. 坐标：AX 顶原点 ↔ AppKit 底原点；库内统一顶原点，调用方转换。
7. 多屏顺序：origin (0,0) 优先，再 y，再 x。
8. half/corner 循环依赖「当前框相对目标框」的几何，不依赖按键计数器。

可执行规格：`Spectacle/Resources/Window Position Calculations/*.js`。  
Oracle：`SpectacleSpecs/Sources/*CalculationSpec.m`。重写先搬 fixture，再删 JS。

### 移动管线（cu 要复现，不是可选项）

```text
place(action, win, srcVisible, dstVisible) → targetRect
  → write size/position/size          (standard)
  → shrink-by-2 until fits or 85%     (quantized)
  → clamp to visibleFrame             (best-effort)
```

## 不收（明确）

- 全局热键、ShortcutRecorder、`Shortcuts.json`、菜单栏、登录项
- Sparkle / 自动更新
- 黑名单 / 对某 App 禁用一小时（cu 用 grant/audit，不用这份名单）
- 拖拽吸附、磁铁、平铺占用表、未聚焦窗批量操作
- Rectangle 后续功能（gaps、几乎最大化、自定义框）
- 把 Spectacle.app 嵌进 agenterm

日用热键继续用本仓库 1.2.1 宿主，直到另开产品决定。

## 建议 cu 形状（不在本仓库实现）

```text
cu --target current --grant actuate window-place \
    --action left-half \
    [--window HANDLE]
```

- 无 `--window`：前台聚焦窗（与 Spectacle 相同）。
- 观察用 `windows`；等待用已有 `wait`，禁止 sleep。
- `actuate`；未授权 `refused`；无 AX `unsupported`；约束夹不进 `failed`。
- 审计写失败则不执行。

v0.1.19 整图并发（不是半屏 MVP）：全部计算动作的几何核、各 `current` 后端写框、`window-place` 命令与授权、每应用 undo/redo。测调推进。ID 表以本文件为准。
