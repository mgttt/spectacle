# Spectacle 技术要点树

源码根：[`Spectacle/Sources`](../Spectacle/Sources) + [`Spectacle/Resources/Window Position Calculations`](../Spectacle/Resources/Window%20Position%20Calculations)。

```text
spectacle 1.2 (ObjC / AppKit / AX / Carbon / JavaScriptCore)
│
├── 0. 构建与分发（这次报警的根因）
│   ├── Xcode 工程 objectVersion=47，LastUpgradeCheck=1120（Xcode 11.2）
│   ├── MACOSX_DEPLOYMENT_TARGET = 10.9
│   ├── LSMinimumSystemVersion = 10.9
│   ├── 已装二进制：thin x86_64，DTSDKName=macosx10.12，DTXcode=0820
│   ├── 签名：Developer ID (P8TAT4Q25S)，2016-12-22，无 Hardened Runtime，无公证
│   ├── 依赖管理：Carthage（Cartfile）
│   │   ├── Sparkle ~> 1.22（DSA 公钥 dsa_public.pem，feed=spectacleapp.com）
│   │   └── 测试：Specta / Expecta / OCHamcrest / OCMockito
│   ├── 无 entitlements、无 PrivacyUsageDescription
│   └── 本机现状：只有 Command Line Tools，没有完整 Xcode → 当前无法 xcodebuild
│
├── 1. 进程形态
│   ├── LSUIElement=true（agent，无 Dock）
│   ├── NSMainNibFile=Spectacle（XIB 菜单 + 辅助功能对话框）
│   ├── 偏好窗口：SpectaclePreferencesWindow.xib + SpectaclePreferencesController
│   ├── 菜单栏：NSStatusItem + template 图
│   └── 登录项：SpectacleLoginItemHelper → LSSharedFileListSessionLoginItems  ❌ 已废
│
├── 2. 启动编排  SpectacleAppDelegate
│   ├── registerDefaults (Defaults.plist)
│   ├── shortcut storage = Migrating(UserDefaults → JSON)
│   ├── ShortcutManager.installApplicationEventHandler
│   ├── WindowPositionCalculator(JS) + WindowPositionManager(mover 链)
│   ├── AXIsProcessTrustedWithOptions → 模态辅助功能窗
│   ├── 打开辅助功能：AppleScript「系统偏好设置」scpt，失败再 open Security.prefPane  ❌ 路径过时
│   ├── Sparkle SUUpdater 自动检查  ❌ 源站/算法过时
│   └── 观察：
│       ├── NSWorkspaceDidActivate/DeactivateApplication（黑名单/单应用禁用）
│       ├── SpectacleShortcutChanged / RestoreDefault / StatusItemEnabled
│       └── NSTextInputContextKeyboardSelectionDidChange（输入源变了要重画快捷键文案）
│
├── 3. 权限 / 辅助功能
│   ├── 协议：AXUIElement（Accessibility）
│   ├── 前台应用：NSWorkspace.frontmostApplication → AXUIElementCreateApplication(pid)
│   ├── 前台窗：kAXFocusedWindowAttribute
│   ├── 读：kAXPositionAttribute / kAXSizeAttribute / kAXRole / kAXSubrole
│   ├── 写：先 size 再 position 再 size（经典 AX 顺序，减少约束抖动）
│   ├── 拒绝：kAXSheetRole、kAXSystemDialogSubrole
│   └── 坐标：AX 顶原点 ↔ AppKit 底原点
│       └── normalizeCoordinatesOfRect: 用 screens[0].frame 当「带菜单栏的主屏」做 Y 翻转
│
├── 4. 热键  SpectacleShortcutManager
│   ├── Carbon Event Manager
│   │   ├── RegisterEventHotKey / UnregisterEventHotKey
│   │   ├── InstallApplicationEventHandler(kEventClassKeyboard, kEventHotKeyPressed)
│   │   └── GetEventParameter(typeEventHotKeyID)
│   ├── ID 空间：signature='ZERO' + 自增 id
│   ├── 修饰键：内部统一存 Carbon mask（cmdKey/optionKey/controlKey/shiftKey）
│   │   └── Cocoa ↔ Carbon：SpectacleShortcutTranslations
│   │       仍用 NSControlKeyMask 等旧名  ⚠️ 10.12+ deprecated，应用 NSEventModifierFlag*
│   ├── 录制：SpectacleShortcutRecorder（吃 NSEvent，过滤纯修饰）
│   ├── 校验：SpectacleShortcutValidation + RegisteredShortcutValidator
│   │   └── 查系统 symbolic hot keys，冲突则清掉注册
│   └── 开关：registerShortcuts / unregisterShortcuts（一小时禁用、前台黑名单）
│
├── 5. 动作语义  SpectacleWindowAction
│   ├── 字符串常量（稳定 ID，cu 应原样复用）
│   │   ├── Center / Fullscreen
│   │   ├── LeftHalf / RightHalf / TopHalf / BottomHalf
│   │   ├── UpperLeft / LowerLeft / UpperRight / LowerRight
│   │   ├── NextDisplay / PreviousDisplay
│   │   ├── NextThird / PreviousThird
│   │   ├── Larger / Smaller
│   │   └── Undo / Redo / None
│   └── 谓词：IsUndo / IsRedo / IsNextDisplay / IsPreviousDisplay / IsMovingToDisplay
│
├── 6. 几何引擎（可纯函数化，这是要抽到 Rust 的核）
│   ├── 入口：SpectacleWindowPositionCalculator
│   │   └── JavaScriptCore JSContext
│   ├── 引导：SpectacleJavaScriptEnvironment
│   │   └── bundle 内 `Window Position Calculations/*.js` 全部 evaluate
│   ├── 注册表：SpectacleWindowPositionCalculationRegistry
│   │   └── action string → JS function(windowRect, srcVisible, dstVisible) → rect
│   ├── 脚本清单
│   │   ├── Helpers: SpectacleWindowCalculationHelpers.js
│   │   ├── SpectacleWindowSizeAdjuster.js（larger/smaller 贴边）
│   │   ├── SpectacleNextOrPreviousThirds.js / Display.js
│   │   └── 每个 action 一个 *WindowCalculation.js
│   ├── 产品规则（必须保持）
│   │   ├── half 重复触发：1/2 → 2/3 → 1/3（要求中线对齐容差 ≤ 1pt）
│   │   ├── 角落重复触发：该象限内宽度三分循环
│   │   ├── thirds：先水平左中右，再垂直上中下
│   │   ├── larger/smaller：尽量保持已贴的边不松开
│   │   └── 结果曾从 floor 改为 round，修菜单栏下 1–2px 缝
│   └── 失败：JS 异常 → NSAlert（NSWarningAlertStyle ⚠️ 旧枚举）
│
├── 7. 屏幕检测  SpectacleScreenDetector
│   ├── source = 窗口矩形与各屏相交面积最大者；完全包含则短路
│   ├── next/previous display 才换 destination
│   └── 稳定排序：origin (0,0) 最先，再按 y，再按 x
│
├── 8. 移动管线  SpectacleWindowPositionManager
│   ├── 历史：NSMutableDictionary<bundleId, SpectacleHistory>
│   │   └── HistoryItem = (AX element, windowRect)
│   ├── 失败反馈：默认 NSBeep
│   └── mover 责任链（装饰器，从外到内）
│       ├── StandardWindowMover     写一次目标 rect
│       ├── QuantizedWindowMover    实际比目标大 → 每次 -2pt，下限 85%，再居中
│       └── BestEffortWindowMover   夹进 visibleFrame
│
├── 9. 持久化
│   ├── Defaults.plist
│   │   ├── AutomaticUpdateCheckEnabled
│   │   ├── StatusItemEnabled
│   │   ├── BackgroundAlertSuppressed
│   │   ├── BlacklistedApplications = Photoshop / Steam / self
│   │   └── DisabledApplications = []
│   ├── Shortcuts.json  (~/Library/Application Support/Spectacle/)
│   └── 迁移：SpectacleMigratingShortcutStorage
│
├── 10. UI
│   ├── 状态菜单：每个动作一条，动态填 keyEquivalent
│   ├── 偏好：ShortcutRecorder 控件阵列 + 登录启动勾选 + 更新勾选
│   ├── 辅助功能教学窗 + 10.9 Crash Fix 图集（历史包袱，现已无用）
│   └── 本地化：en / es / fi / fr / it / pt（XIB strings + Localizable.strings）
│
└── 11. 测试  SpectacleSpecs
    ├── calculation specs ≈ 每个 JS action 一份
    ├── Shortcut / KeyBindings / Translations
    └── WindowPositionManagerSpec（OCMockito mock NSRunningApplication / NSWorkspace）
```

## 当前系统上会炸 / 会报警的节点

| 节点 | 现象 | 现代替代 |
|------|------|----------|
| thin x86_64 + 10.12 SDK | 「此 App 需要更新」/ 未来停 Rosetta 即死 | 用当前 SDK 出 arm64（或 universal） |
| 无 Hardened Runtime / 无公证 | Gatekeeper 越来越严 | `com.apple.security.automation.apple-events` 等 entitlements + notarytool |
| `LSSharedFileList*` | API 已删/空转，登录项失效或警告 | `SMAppService.mainApp`（macOS 13+） |
| 打开 `Security.prefPane` + 旧 scpt | 「系统偏好设置」已改名「系统设置」 | `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility` 或 `SMAppService` 引导 |
| Sparkle 1 + DSA + spectacleapp.com | 更新通道死、DSA 已被 Sparkle 弃用 | 关掉更新，或 Sparkle 2 + EdDSA + 自己的 feed |
| Carthage bootstrap | 工具链老、Sparkle 1 拉不下来很常见 | SPM / 直接 vendoring |
| `NSControlKeyMask` / `NSWarningAlertStyle` / `NSOnState` / `highlightMode` | 编译警告；工程开了 `GCC_TREAT_WARNINGS_AS_ERRORS=YES` 会编不过 | 新枚举名 |
| Carbon `RegisterEventHotKey` | 仍能用，但是遗留栈；与输入法/安全输入偶发冲突 | 短期保留；中期 `CGEventTap` 或 `MASShortcut` / `HotKey` crate |
| 无 `NSAccessibility` usage 说明 | 新系统辅助功能面板展示差 | Info.plist 补齐 |
| XIB + 10.9 asset hack | 现代 IB / Dark Mode / 菜单栏尺寸都不友好 | 先不动 UI，能编过再说 |

## 可拆成库的边界（给 Rust / agenterm-cu 用）

```text
spectacle-core (纯几何，无 AppKit)
├── Action enum           ← 与上表 ID 稳定对应
├── Rect / ScreenFrame    ← 顶原点，调用方负责转换
├── place(action, win, src, dst) -> Rect
├── cycle thirds / halves ← 含 1pt 中线容差
└── adjust larger/smaller

spectacle-host-macos
├── AX frontmost window get/set
├── screen list + visibleFrame + Y flip
├── quantized + best-effort movers
└── per-app history

spectacle-hotkey-macos     （菜单栏 App 才需要）
└── 全局热键 + 录制 + Shortcuts.json

agenterm-cu  (后续)
└── window-place --action <id> [--window HANDLE]
    复用 spectacle-core + host 的 AX setRect
```

现有 JS 文件就是 `spectacle-core` 的可执行规格；18 个 `*Spec.m` 是 oracle。重写时先把这些 spec 变成 Rust 测试，再删 JS。
