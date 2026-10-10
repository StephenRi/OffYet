# OffYet（下班了么）Mac 菜单栏版 v1 设计文档

日期：2026-10-10
状态：已与用户逐节确认，待实施计划
前置决策：技术方案 A（原生 SwiftUI + SPM），用户已拍板

## 1. 背景与目标

OffYet 已有网页版 v0.1.0（`web/`，已上线）。本版将产品落成 **macOS 菜单栏常驻应用**：菜单栏实时显示「今日已赚 / 下班倒计时 / 图标」，点击弹出完整面板（倒计时 + 金额 + 进度 + 里程碑卡）。定位长期日常使用。

原 Mac spec（2026-10-08 小组件版）中「菜单栏实时显示」为未来项，本次即是该未来项的落地；Mac 小组件仍是后续主线，本版的 OffYetCore 将被其直接复用。

- 用户机器：macOS 26.3，Apple Silicon
- 开发环境：Xcode 26.6 已装（**许可协议未同意，用户需手动跑一次 `sudo xcodebuild -license`**）；xcodegen 未装且不需要；Node/npm 可用（本方案不用）

## 2. v1 范围

### 做

- 菜单栏常驻内容，**三模式可配置**（默认图标）：实时金额（按刷新频率跳动，默认 1 次/秒，最高 10 次/秒）/ 时分倒计时 / 品牌 logo 单色字形图标
- 下拉面板完整对齐网页版 v0.1.0：状态标签、大号倒计时、渐变进度条（含 09:00/18:00 端点）、今日已赚 +「持续增长中」徽章、三张里程碑卡（距周末/距发薪/距退休）
- 设置弹窗：上班/下班时间、月薪、每月工作日数、发薪日（1–31 + 「每月最后一个工作日」）、退休日期、菜单栏显示模式、刷新频率（1–10 次/秒，默认 1，越大 CPU 占用越高）、开机自启（SMAppService）、模拟时间开关
- 计算引擎 OffYetCore（Swift），`swift test` TDD；`engine.test.js` 43 用例全量移植
- `scripts/build-app.sh` 组装 .app + ad-hoc 签名

### 不做（明确排除）

- 与网页版配置同步（两端各自存储）
- 隐私模式（¥****）——用户此前已明确不要
- iPhone / 小组件（后续项目，复用 OffYetCore）
- 中国法定节假日 / 调休（周末=周六日，与网页版一致）
- 多套配置预设、通知提醒、自定义主题

## 3. 技术选型

| 项 | 决定 | 理由 |
|---|---|---|
| 框架 | SwiftUI `MenuBarExtra`（`.menuBarExtraStyle(.window)`） | 菜单栏 + 弹出面板的系统原生方案；macOS 13+，目标机 26.3 |
| 工程 | 单 SPM 包双 target（OffYetCore library + OffYetApp executable） | 全程 `swift build` / `swift test` 命令行可复现，不需要 Xcode 工程与 xcodegen |
| 测试 | Swift Testing | 沿用原 Mac spec 决策 |
| 签名 | ad-hoc（`codesign -s -`） | 无 Apple 账号要求 |
| 开机自启 | `SMAppService.mainApp`（macOS 13+） | 系统标准方式 |
| App 图标 | `assets/offyet-logo-1024.png` 经 sips + iconutil 生成 .icns | 复用既有 logo |
| 命名 | Bundle 名 `OffYet`，显示名「下班了么」，`LSUIElement=true`（无 Dock 图标） | 沿用原 Mac spec 命名决策 |

## 4. 架构与目录

```
menubar/
├── Package.swift              # OffYetCore (library) + OffYetApp (executable) + 测试 target
├── Sources/OffYetCore/        # 纯计算引擎，零 UI 依赖
│   ├── WorkSettings.swift     #   配置值对象 + 校验 + 默认值 + PAYDAY_LAST_WORKDAY=0
│   ├── EarningEngine.swift    #   snapshot(at:settings:calendar:) -> DaySnapshot
│   ├── Milestones.swift       #   daysUntilWeekend / daysUntilPayday / daysUntilRetirement
│   ├── Formatting.swift       #   money / countdownParts / formatCountdown
│   └── OffYetCore.swift       #   OffYetState / DaySnapshot / VERSION（唯一定义点，本版 0.1.0）
├── Sources/OffYetApp/
│   ├── OffYetApp.swift        #   @main，MenuBarExtra 组装
│   ├── StatusBarLabel.swift   #   菜单栏三模式内容
│   ├── PanelView.swift        #   下拉面板
│   ├── SettingsSheet.swift    #   设置弹窗
│   ├── AppStore.swift         #   ObservableObject：设置读写（UserDefaults）+ 模拟时间
│   └── Theme.swift            #   粉彩渐变、卡片、颜色（亮暗双外观）
├── Tests/OffYetCoreTests/     # Swift Testing，43 用例移植
├── Resources/                 # AppIcon.icns
└── scripts/build-app.sh       # build → .app → icns → ad-hoc 签名（--install 可选拷 /Applications）
```

依赖方向：`OffYetApp → OffYetCore`；OffYetCore 不 import SwiftUI/AppKit。

## 5. 计算口径（逐条对齐 web/engine.js v0.1.0）

- 日薪 = 月薪 ÷ 每月工作日数；金额 = round2(日薪 × 已过秒数 / 全天秒数)，**秒级含毫秒**实时累计
- 状态边界：当日 0:00≤now<startMin → beforeWork（¥0.00，进度 0，remaining=距上班）；startMin≤now<endMin → working；endMin≤now<24:00 → afterWork（满额、进度 1）；周六日 → restDay（¥0.00）；恰好整点按「已到达」处理（09:00:00→¥0.00，18:00:00→满额）
- 周末判定：weekday 1（周日）/ 7（周六），与 JS `getDay()===0||6` 等价
- 倒计时：`remainingSeconds = ceil(目标秒 - nowSec)`；显示只时/分：≥1h「N时 M分」，<1h「M分」，<1min 按 1 分显示，0 防御路径→「0分」，不补零
- round2 语义：金额恒非负，`(x*100).rounded()/100`（half away from zero）与 JS `Math.round` 在非负域等价
- 发薪日：`payDay` 1–31 月末钳制；`0`=末工作日（从月末回退跳过周六日）；当日已过目标日→跨月顺延；非法（非 1–31 且非 0）→ nil 显示 `--`
- 退休日期：严格 `YYYY-MM-DD` 正则 + Date 回验；过去→0；非法→nil
- 里程碑副文案：周末 0→「享受周末」1→「明天就是」else→「周六见」；发薪 0→「今天到账」else→「M月D日」；退休→「正在靠近自由」；天数千分位分组
- 非法配置（end≤start、月薪≤0、工作日数≤0）→ `.invalid` 快照，不崩溃不出 NaN
- 日期差一律用年月日分量（Swift `DateComponents`/`Calendar.date(from:)`）防夏令时 23/25h 日；`calendar` 参数可注入以支持非本机时区测试

### OffYetCore API

```swift
public enum OffYetState: Equatable { case beforeWork, working, afterWork, restDay, invalid }

public struct WorkSettings: Codable, Equatable {
    public var startMin: Int          // 默认 540
    public var endMin: Int            // 默认 1080
    public var monthlySalary: Double  // 默认 20000
    public var workDaysPerMonth: Double // 默认 21.75
    public var payDay: Int            // 默认 20；0 = lastWorkday
    public var retirementDate: String // 默认 "2050-01-01"
    public static let payDayLastWorkday = 0
    public static let standard = WorkSettings(...)
    public var isValid: Bool
}

public struct DaySnapshot: Equatable {
    public let state: OffYetState
    public let remainingSeconds: Int?   // beforeWork/working 有值，其余 nil
    public let earned: Double
    public let progress: Double
    public let dailySalary: Double
}

public enum EarningEngine {
    public static func snapshot(at date: Date, settings: WorkSettings,
                                calendar: Calendar = .current) -> DaySnapshot
}
```

## 6. 菜单栏常驻内容（三模式，默认图标）

| 模式 | working | beforeWork | afterWork | restDay |
|---|---|---|---|---|
| 金额 | ¥xx.xx 按刷新频率跳动（默认 1 次/秒） | ¥0.00 | 满额金额 | ☕️ |
| 倒计时 | 距下班 时/分 | 距上班 时/分 | 已下班 🎉 | 休息 ☕️ |
| 图标（默认） | 品牌 logo 单色字形（template image，跟随深浅色） | 同左 | 同左 | 同左 |

- 刷新：菜单栏与面板均由定时器（@Published state）驱动，频率用户可配（`StoredState.ticksPerSecond`，范围 1–10 Hz，默认 1；实测 5Hz 面板开启约 5.5% CPU，1Hz 约 1%，设置页有「频率越高，CPU 占用越高」提示）；分粒度倒计时 + 默认每秒金额跳动已足够（曾用 TimelineView 0.25s，MenuBarExtra 场景下引发更新循环，已弃用）；金额 `monospacedDigit` 防抖
- 图标字形（`MenuBarGlyph.swift`）：按品牌 logo 几何（圆环 + 12/3/9 刻度 + 地平线弦 + 实心半日，无指针/支点/挖空槽——18pt 下元素过多会糊）用 CoreGraphics 画进位图 → 模板 `NSImage` → `Image(nsImage:)`。**原因**：macOS 26 状态项快照只渲染 Text/Image 原语，任意 Shape/Canvas 绘制被静默丢弃（离屏 ImageRenderer 正常，会误导）；此约束经 A/B 探针证实（红矩形/蓝 Shape 0 像素、仅 Text 渲染）
- 菜单栏刷新实现：`@Published state` + `Timer.publish(every: ticksPerSecond 换算的周期)` 驱动 label/panel 重算；保存设置时重建 ticker 即刻生效无需重启；不做事预测量，引擎计算为微秒级纯函数

## 7. 下拉面板

宽约 360pt，`.window` 样式弹出，自上而下（元素与网页版第三版一一对应）：

1. 顶栏：logo（`assets/offyet-logo-tile.png` → 打包为 `Contents/Resources/OffYetLogo.png`，`Image(nsImage:)` 28×28 彩色渲染；缺失时回落 `MenuBarGlyph()`）+「下班了么」+ `v` + 版本号；居中日期「10月10日 · 周五」（用当前时刻，随模拟时间联动）；右侧圆形齿轮按钮。注：面板是普通窗口，不受菜单栏状态项快照「只渲染 Text/Image」约束
2. 状态标签（「距离下班还有」等）+ 大号倒计时：数字+小单位标（`.cd-num` 视觉对应，时/分）
3. 渐变进度条，两端点标签 09:00 / 18:00（取自配置）
4. 绿色金额大字 +「持续增长中」徽章（仅 working 显示）
5. 三张里程碑卡：距周末（日历蓝）/ 距发薪（钱包浅蓝）/ 距退休（沙漏紫），天数+副文案

视觉：粉彩渐变背景 + 白色圆角卡 + 柔和阴影，在 SwiftUI 重写；深浅色跟随系统（资产与颜色均提供双外观）。点齿轮弹设置 sheet。

## 8. 配置存储与登录启动

- UserDefaults 单键 `offyet.settings.v1`，JSON Codable：

```json
{
  "settings": { "startMin":540, "endMin":1080, "monthlySalary":20000,
                "workDaysPerMonth":21.75, "payDay":20, "retirementDate":"2050-01-01" },
  "menuBarMode": "icon",         // money | countdown | icon
  "simEnabled": false,
  "simOffset": null,              // 秒；模拟钟偏移 = 选定时刻 − 保存时刻
  "launchAtLogin": false
}
```

- 读取容错：字段缺失/解码失败→整体回落默认值（网页版同策略）；旧版本键不存在，无迁移问题
- 设置保存时校验：下班≤上班、月薪≤0、工作日数≤0 → 保存按钮禁用并提示；`.invalid` 引擎分支是最后防线
- 开机自启：toggle 变化时 `SMAppService.mainApp.register()/unregister()`；失败时 UI 提示。**验证点**：ad-hoc 签名 + /Applications 下 SMAppService 是否可用；不可用则 toggle 显示「需要将 App 放入 /Applications」提示（降级，不阻塞）
- 模拟时间（流动时钟，有意偏离网页版的冻结语义）：选定时刻作为模拟钟起点，之后按真实速率 1:1 走动——金额/倒计时/里程碑持续变化。存储为 `simOffset`（选定时刻 − 保存时刻）；选择器未改动且已有偏移时原样保留，避免模拟钟回跳。旧存档 `simTime` 键解码时被忽略（JSONDecoder 忽略未知键），其余设置不丢

## 9. 打包与签名

`scripts/build-app.sh`：

1. `swift build -c release`
2. 组装 `build/OffYet.app/Contents/{MacOS,Resources}`：可执行文件 + Info.plist（`CFBundleName=OffYet`、`CFBundleDisplayName=下班了么`、`CFBundleIdentifier=local.offyet.menubar`、`LSUIElement=true`、`CFBundleShortVersionString` 取 OffYetCore 版本）+ AppIcon.icns
3. `sips -z` 生成 iconset 各尺寸 → `iconutil` 合 .icns；`assets/offyet-logo-tile.png` 拷入 `Resources/OffYetLogo.png`（面板顶栏 logo）
4. `codesign --force -s -` ad-hoc 签名
5. `--install` 参数：拷贝到 /Applications（需覆盖时先 `osascript` 提示退出旧实例）

## 10. 测试策略

**OffYetCore 单测（TDD，先写测试）**：`Tests/OffYetCoreTests/` 用 Swift Testing 移植 `engine.test.js` 全部 43 用例——状态边界（08:59/09:00/12:00/17:59/18:00/18:01/周末全天/周日 23:59→周一 00:00 跨天）、金额精度（12:00=日薪 1/3）、秒级/毫秒级累计、发薪日（固定日/末工作日/月末钳制/跨月/非法）、退休（严格解析/过去/非法）、格式化（千分位/两位小数/时分倒计时）、非法配置、非零时区 Calendar。

**手动验收（无法自动化）**：菜单栏三模式 × 四状态；面板排版与深浅色；设置保存/持久化/重启恢复；刷新频率调节（保存后即时生效、重启保持）；模拟时间驱动状态切换（流动时钟：开启后金额/倒计时持续变化）；开机自启（含降级提示）；.app 从 /Applications 正常启动、无 Dock 图标。

## 11. 风险与预案

| 风险 | 预案 |
|---|---|
| Xcode 许可未同意阻塞编译 | 用户跑一次 `sudo xcodebuild -license`（一次性，无法代办） |
| ad-hoc 签名下 SMAppService 不可用 | toggle 降级为提示手动加登录项 |
| MenuBarExtra label 高频刷新抖动/性能 | 金额模式 1Hz 已留余量；若实测抖动改 0.5s 或仅金额变化时刷新 |
| SwiftUI 面板与网页版视觉差距 | 以深浅色截图对照网页版迭代，里程碑卡/渐变优先还原 |
| SPM executable 进 Info.plist/.icns 打包细节 | build-app.sh 模板化一次搞定；不引入 Xcode 工程作为后备（SwiftUI 代码无工程依赖） |

## 12. 未来项（非承诺）

- Mac 小组件（复用 OffYetCore，原主线）
- 隐私模式、通知提醒（临近下班）、周/月累计
- 与网页版配置互通（URL scheme / 手动导出）
- 中国节假日 / 调休日历
