# OffYet Mac 菜单栏版实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 OffYet 落成 macOS 菜单栏常驻应用：菜单栏三模式显示（金额/倒计时/图标），点击弹出完整面板（倒计时+金额+进度+里程碑卡）+ 设置页。

**Architecture:** 单 SPM 包双 target——`OffYetCore`（纯计算，Foundation only，可单测）+ `OffYetApp`（SwiftUI MenuBarExtra）。引擎是 `web/engine.js` 的逐条 Swift 移植，口径完全一致；UI 在 SwiftUI 重刻网页版粉彩视觉。

**Tech Stack:** Swift 5.10 tools / Swift Testing / SwiftUI MenuBarExtra（macOS 13+）/ UserDefaults 持久化 / SMAppService 登录项 / ad-hoc 签名打包脚本。

**Spec:** `docs/superpowers/specs/2026-10-10-offyet-menubar-design.md`（实现时与 spec 一并阅读）

## Global Constraints

- 计算口径与 `web/engine.js` v0.1.0 **逐条一致**：`round2 = ((x + Double.ulpOfOne) * 100).rounded() / 100`；`remainingSeconds` 用 `ceil`；周末=weekday 1（周日）/7（周六）；倒计时只时/分、<1min 按 1 分、0 防御→0 分；发薪日哨兵 `0`=末工作日、月末钳制、跨月顺延；退休日期严格 `YYYY-MM-DD` 回验；非法配置→`.invalid` 不出 NaN。
- 零第三方依赖；最低部署 macOS 13.0；开发机 macOS 26.3 / Xcode 26.6。
- 全程命令行：`swift build` / `swift test`；不用 XcodeGen、不开 Xcode GUI。
- UI 文案与网页版一致：「距离下班还有」「距离上班还有」「今天已经赚到」「持续增长中」「享受周末」「明天就是」「周六见」「今天到账」「正在靠近自由」「已下班 🎉」「今天休息 ☕️」「请检查设置」。
- 版本号唯一定义在 `OffYetCore.VERSION = "0.1.0"`（打包脚本读它写 Info.plist）。
- 命名：Bundle `OffYet`，显示名「下班了么」，`local.offyet.menubar`，`LSUIElement=true`。
- 测试日期构造用 `Calendar.current`（与机器时区解耦，同 web 测试约定）；时区注入测试单独显式构造 Calendar。
- 面板宽 360pt；菜单栏刷新 1Hz、面板 4Hz；金额 `monospacedDigit`。
- 仓库当前不是 git 仓库——Task 1 首步 `git init`（用户已在方案确认时知悉，每任务一提交）。

---

### Task 0: 前置——用户同意 Xcode 许可

**唯一需要人工的操作**（无法代办 sudo）：

```bash
sudo xcodebuild -license accept
```

跑完后 `swift --version` 应正常输出版本号。此项未完成前，所有 `swift build/test` 步骤会失败。

---

### Task 1: 包脚手架 + 核心类型与版本号

**Files:**
- Create: `menubar/Package.swift`
- Create: `menubar/Sources/OffYetCore/OffYetCore.swift`
- Create: `menubar/Tests/OffYetCoreTests/VersionTests.swift`
- Create: `menubar/.gitignore`

**Interfaces:**
- Produces: `OffYetState`（五态枚举）、`DaySnapshot`（state/remainingSeconds:Int?/earned/progress/dailySalary）、`OffYetCore.version: String = "0.1.0"`——后续所有任务依赖。

- [ ] **Step 1: git init 与目录**

```bash
cd /Users/shuaibing.zsb/Documents/Agent-Project/OffYet
git init
mkdir -p menubar/Sources/OffYetCore menubar/Sources/OffYetApp menubar/Tests/OffYetCoreTests menubar/scripts
```

- [ ] **Step 2: 写 .gitignore 与 Package.swift**

`menubar/.gitignore`（内容）：

```
.build/
build/
*.xcodeproj
.DS_Store
```

`menubar/Package.swift`：

```swift
// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OffYet",
    platforms: [.macOS(.v13)],
    targets: [
        .target(name: "OffYetCore"),
        .executableTarget(name: "OffYetApp", dependencies: ["OffYetApp"]),
        .testTarget(name: "OffYetCoreTests", dependencies: ["OffYetCore"]),
    ]
)
```

（`OffYetApp` target 本任务先不存在会编译失败——同一步里建占位文件，见 Step 3。）

- [ ] **Step 3: 核心类型骨架**

`menubar/Sources/OffYetCore/OffYetCore.swift`：

```swift
import Foundation

public enum OffYetState: Equatable {
    case beforeWork
    case working
    case afterWork
    case restDay
    case invalid
}

public struct DaySnapshot: Equatable {
    public let state: OffYetState
    public let remainingSeconds: Int?
    public let earned: Double
    public let progress: Double
    public let dailySalary: Double

    public init(state: OffYetState, remainingSeconds: Int?,
                earned: Double, progress: Double, dailySalary: Double) {
        self.state = state
        self.remainingSeconds = remainingSeconds
        self.earned = earned
        self.progress = progress
        self.dailySalary = dailySalary
    }
}

public let version = "0.1.0"
```

`menubar/Sources/OffYetApp/main.swift`（占位，Task 7 重写）：

```swift
import Foundation
print("OffYetApp scaffold")
```

注意：executableTarget 用 `main.swift` 时不能用 `@main` 属性；Task 7 会删掉 main.swift 改用 `OffYetApp.swift` 的 `@main`。

- [ ] **Step 4: 写版本号测试（先红）**

`menubar/Tests/OffYetCoreTests/VersionTests.swift`：

```swift
import Testing
@testable import OffYetCore

struct VersionTests {
    @Test func versionIs010() {
        #expect(version == "0.1.0")
    }
}
```

- [ ] **Step 5: swift test 验证**

Run: `cd menubar && swift test`
Expected: PASS（1 个用例）。若 `import Testing` 报不可用（工具链异常），降级改用 XCTest（`import XCTest` + `XCTestCase` + `XCTAssertEqual`），全计划测试同理替换——预期用不到。

- [ ] **Step 6: Commit**

```bash
git add menubar
git commit -m "chore(menubar): SPM scaffold with core types and version"
```

---

### Task 2: WorkSettings 与配置校验

**Files:**
- Create: `menubar/Sources/OffYetCore/WorkSettings.swift`
- Test: `menubar/Tests/OffYetCoreTests/SettingsValidationTests.swift`

**Interfaces:**
- Consumes: 无
- Produces: `WorkSettings`（Codable/Equatable，6 字段 + `payDayLastWorkday = 0` + `.standard` + `.isValid`）。

- [ ] **Step 1: 写失败测试**

`menubar/Tests/OffYetCoreTests/SettingsValidationTests.swift`：

```swift
import Testing
@testable import OffYetCore

struct SettingsValidationTests {
    // web engine.test.js：默认配置含发薪日 20 号、退休日期 2050-01-01
    @Test func standardDefaults() {
        let s = WorkSettings.standard
        #expect(s.startMin == 540)
        #expect(s.endMin == 1080)
        #expect(s.monthlySalary == 20000)
        #expect(s.workDaysPerMonth == 21.75)
        #expect(s.payDay == 20)
        #expect(s.retirementDate == "2050-01-01")
        #expect(s.isValid)
    }

    @Test func sentinelIsZero() {
        #expect(WorkSettings.payDayLastWorkday == 0)
    }

    @Test func endNotAfterStartIsInvalid() {
        var s = WorkSettings.standard
        s.startMin = 1080; s.endMin = 540
        #expect(!s.isValid)
        s.endMin = 540
        #expect(!s.isValid)   // end == start 同样非法
    }

    @Test func salaryAndDaysMustBePositive() {
        var s = WorkSettings.standard
        s.monthlySalary = 0
        #expect(!s.isValid)
        s.monthlySalary = -100
        #expect(!s.isValid)
        s.monthlySalary = 20000
        s.workDaysPerMonth = 0
        #expect(!s.isValid)
        s.workDaysPerMonth = -1
        #expect(!s.isValid)
        s.workDaysPerMonth = 21.75
        #expect(s.isValid)
    }

    @Test func nanIsInvalid() {
        var s = WorkSettings.standard
        s.monthlySalary = Double.nan
        #expect(!s.isValid)
    }
}
```

- [ ] **Step 2: 跑测试确认编译失败**

Run: `cd menubar && swift test`
Expected: FAIL（`WorkSettings` 未定义）

- [ ] **Step 3: 最小实现**

`menubar/Sources/OffYetCore/WorkSettings.swift`：

```swift
import Foundation

public struct WorkSettings: Codable, Equatable {
    /// 「每月最后一个工作日」哨兵值；工作日口径 = 只跳过周六日（与网页版一致，不含法定节假日）
    public static let payDayLastWorkday = 0

    public var startMin: Int
    public var endMin: Int
    public var monthlySalary: Double
    public var workDaysPerMonth: Double
    public var payDay: Int
    public var retirementDate: String

    public init(startMin: Int = 540, endMin: Int = 1080,
                monthlySalary: Double = 20000, workDaysPerMonth: Double = 21.75,
                payDay: Int = 20, retirementDate: String = "2050-01-01") {
        self.startMin = startMin
        self.endMin = endMin
        self.monthlySalary = monthlySalary
        self.workDaysPerMonth = workDaysPerMonth
        self.payDay = payDay
        self.retirementDate = retirementDate
    }

    public static let standard = WorkSettings()

    public var isValid: Bool {
        // NaN 参与 > 比较恒为 false，天然覆盖非法输入
        endMin > startMin && monthlySalary > 0 && workDaysPerMonth > 0
    }
}
```

- [ ] **Step 4: swift test 全绿**

Run: `cd menubar && swift test`
Expected: PASS（6 个用例）

- [ ] **Step 5: Commit**

```bash
git add menubar && git commit -m "feat(menubar): WorkSettings with validation"
```

---

### Task 3: EarningEngine.snapshot 状态机（核心）

**Files:**
- Create: `menubar/Sources/OffYetCore/EarningEngine.swift`
- Test: `menubar/Tests/OffYetCoreTests/EarningEngineTests.swift`

**Interfaces:**
- Consumes: `WorkSettings.isValid`
- Produces: `EarningEngine.snapshot(at: Date, settings: WorkSettings, calendar: Calendar = .current) -> DaySnapshot`；内部 `round2`。

- [ ] **Step 1: 写失败测试（移植 web 全部快照用例）**

`menubar/Tests/OffYetCoreTests/EarningEngineTests.swift`：

```swift
import Testing
import Foundation
@testable import OffYetCore

struct EarningEngineTests {
    // 设计文档 §5 示例配置：日薪 1000.00，全天 540 分钟
    private let example = WorkSettings(startMin: 540, endMin: 1080,
                                       monthlySalary: 21750, workDaysPerMonth: 21.75)

    // 2026-10-05 为周一；本地时间构造，与机器时区无关（同 web 测试约定）
    private func at(_ day: Int, _ h: Int, _ m: Int = 0, _ s: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day,
                                                   hour: h, minute: m, second: s))!
    }

    @Test func weekdayAssumptions() {
        // Swift weekday：1=周日 … 2=周一 … 7=周六
        #expect(Calendar.current.component(.weekday, from: at(5)) == 2)
        #expect(Calendar.current.component(.weekday, from: at(10)) == 7)
        #expect(Calendar.current.component(.weekday, from: at(11)) == 1)
    }

    @Test func monday0859BeforeWork() {
        let snap = EarningEngine.snapshot(at: at(5, 8, 59), settings: example)
        #expect(snap.state == .beforeWork)
        #expect(snap.earned == 0)
        #expect(snap.progress == 0)
        #expect(snap.remainingSeconds == 60)
        #expect(snap.dailySalary == 1000)
    }

    @Test func monday085959OneSecondLeft() {
        let snap = EarningEngine.snapshot(at: at(5, 8, 59, 59), settings: example)
        #expect(snap.state == .beforeWork)
        #expect(snap.remainingSeconds == 1)
    }

    @Test func monday0900WorkStartsAtZero() {
        let snap = EarningEngine.snapshot(at: at(5, 9), settings: example)
        #expect(snap.state == .working)
        #expect(snap.earned == 0)
        #expect(snap.progress == 0)
        #expect(snap.remainingSeconds == 9 * 3600)
    }

    @Test func monday1200OneThird() {
        let snap = EarningEngine.snapshot(at: at(5, 12), settings: example)
        #expect(snap.state == .working)
        #expect(snap.earned == 333.33)
        #expect(snap.progress == 180.0 / 540.0)
        #expect(snap.remainingSeconds == 6 * 3600)
    }

    @Test func secondLevelAccumulation() {
        let snap = EarningEngine.snapshot(at: at(5, 12, 0, 30), settings: example)
        #expect(snap.earned == 334.26)
        #expect(snap.progress == 10830.0 / 32400.0)
    }

    @Test func secondLevelAtWorkStart() {
        let snap = EarningEngine.snapshot(at: at(5, 9, 0, 30), settings: example)
        #expect(snap.earned == 0.93)
        #expect(snap.progress == 30.0 / 32400.0)
    }

    @Test func millisecondsCount() {
        let d = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5,
                                                           hour: 9, minute: 0, second: 0,
                                                           nanosecond: 500_000_000))!
        let snap = EarningEngine.snapshot(at: d, settings: example)
        #expect(snap.earned == 0.02)
        #expect(snap.progress == 0.5 / 32400.0)
    }

    @Test func monday1759LastMinute() {
        let snap = EarningEngine.snapshot(at: at(5, 17, 59), settings: example)
        #expect(snap.state == .working)
        #expect(snap.earned == 998.15)
        #expect(snap.remainingSeconds == 60)
    }

    @Test func monday1800FullSalary() {
        let snap = EarningEngine.snapshot(at: at(5, 18), settings: example)
        #expect(snap.state == .afterWork)
        #expect(snap.earned == 1000)
        #expect(snap.progress == 1)
        #expect(snap.remainingSeconds == nil)
    }

    @Test func monday1801StaysFull() {
        let snap = EarningEngine.snapshot(at: at(5, 18, 1), settings: example)
        #expect(snap.state == .afterWork)
        #expect(snap.earned == 1000)
    }

    @Test func saturdayAllDayRest() {
        for h in [0, 10, 23] {
            let snap = EarningEngine.snapshot(at: at(10, h), settings: example)
            #expect(snap.state == .restDay)
            #expect(snap.earned == 0)
            #expect(snap.progress == 0)
            #expect(snap.remainingSeconds == nil)
        }
    }

    @Test func sunday2359ThenMonday0000() {
        let sun = EarningEngine.snapshot(at: at(11, 23, 59), settings: example)
        #expect(sun.state == .restDay)
        #expect(sun.earned == 0)

        let mon = EarningEngine.snapshot(at: at(12, 0), settings: example)
        #expect(mon.state == .beforeWork)
        #expect(mon.earned == 0)
        #expect(mon.remainingSeconds == 9 * 3600)
    }

    @Test func dailySalaryExactDivision() {
        let snap = EarningEngine.snapshot(at: at(5, 18),
            settings: WorkSettings(startMin: 540, endMin: 1080,
                                   monthlySalary: 21750, workDaysPerMonth: 21.75))
        #expect(snap.dailySalary == 1000)
        #expect(snap.earned == 1000)
    }

    @Test func customWorkDays() {
        let snap = EarningEngine.snapshot(at: at(5, 18),
            settings: WorkSettings(startMin: 540, endMin: 1080,
                                   monthlySalary: 20000, workDaysPerMonth: 20))
        #expect(snap.dailySalary == 1000)
        #expect(snap.earned == 1000)
    }

    @Test func roundedDailySalary() {
        let snap = EarningEngine.snapshot(at: at(5, 18),
            settings: WorkSettings(startMin: 540, endMin: 1080,
                                   monthlySalary: 20000, workDaysPerMonth: 21.75))
        #expect(snap.earned == 919.54)
    }

    @Test func invalidEndConfig() {
        for s in [WorkSettings(startMin: 1080, endMin: 540),
                  WorkSettings(startMin: 540, endMin: 540)] {
            let snap = EarningEngine.snapshot(at: at(5, 12), settings: s)
            #expect(snap.state == .invalid)
            #expect(snap.earned == 0)
            #expect(snap.progress == 0)
            #expect(snap.remainingSeconds == nil)
            #expect(snap.dailySalary.isFinite)
        }
    }

    @Test func invalidSalary() {
        for salary in [0.0, -100.0] {
            var s = WorkSettings.standard
            s.monthlySalary = salary
            let snap = EarningEngine.snapshot(at: at(5, 12), settings: s)
            #expect(snap.state == .invalid)
            #expect(snap.earned == 0)
        }
    }

    @Test func invalidWorkDays() {
        for days in [0.0, -1.0] {
            var s = WorkSettings.standard
            s.workDaysPerMonth = days
            let snap = EarningEngine.snapshot(at: at(5, 12), settings: s)
            #expect(snap.state == .invalid)
        }
    }

    @Test func nanSalaryInvalidNotNaNOut() {
        var s = WorkSettings.standard
        s.monthlySalary = Double.nan
        let snap = EarningEngine.snapshot(at: at(5, 12), settings: s)
        #expect(snap.state == .invalid)
        #expect(snap.earned == 0)
        #expect(!snap.earned.isNaN)
        #expect(!snap.progress.isNaN)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd menubar && swift test`
Expected: FAIL（`EarningEngine` 未定义）

- [ ] **Step 3: 实现**

`menubar/Sources/OffYetCore/EarningEngine.swift`：

```swift
import Foundation

public enum EarningEngine {
    /// 与 web/engine.js 的 round2 完全一致：Math.round((x + EPSILON) * 100) / 100
    static func round2(_ x: Double) -> Double {
        ((x + Double.ulpOfOne) * 100).rounded() / 100
    }

    public static func snapshot(at date: Date, settings: WorkSettings,
                                calendar: Calendar = .current) -> DaySnapshot {
        guard settings.isValid else {
            return DaySnapshot(state: .invalid, remainingSeconds: nil,
                               earned: 0, progress: 0, dailySalary: 0)
        }

        let workSeconds = Double((settings.endMin - settings.startMin) * 60)
        let dailySalary = settings.monthlySalary / settings.workDaysPerMonth

        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return DaySnapshot(state: .restDay, remainingSeconds: nil,
                               earned: 0, progress: 0, dailySalary: dailySalary)
        }

        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let nowSec = Double(c.hour!) * 3600 + Double(c.minute!) * 60
            + Double(c.second!) + Double(c.nanosecond!) / 1_000_000_000
        let startSec = Double(settings.startMin * 60)
        let endSec = Double(settings.endMin * 60)

        if nowSec < startSec {
            return DaySnapshot(state: .beforeWork,
                               remainingSeconds: Int(ceil(startSec - nowSec)),
                               earned: 0, progress: 0, dailySalary: dailySalary)
        }
        if nowSec < endSec {
            let workedSec = nowSec - startSec
            return DaySnapshot(state: .working,
                               remainingSeconds: Int(ceil(endSec - nowSec)),
                               earned: round2(dailySalary * workedSec / workSeconds),
                               progress: workedSec / workSeconds,
                               dailySalary: dailySalary)
        }
        return DaySnapshot(state: .afterWork, remainingSeconds: nil,
                           earned: round2(dailySalary), progress: 1, dailySalary: dailySalary)
    }
}
```

- [ ] **Step 4: swift test 全绿**

Run: `cd menubar && swift test`
Expected: PASS（此前全部 + 新增 16 个快照用例）

- [ ] **Step 5: Commit**

```bash
git add menubar && git commit -m "feat(menubar): EarningEngine snapshot state machine"
```

---

### Task 4: Formatting（金额 / 倒计时）

**Files:**
- Create: `menubar/Sources/OffYetCore/Formatting.swift`
- Test: `menubar/Tests/OffYetCoreTests/FormattingTests.swift`

**Interfaces:**
- Consumes: 无
- Produces: `Formatting.money(_ n: Double) -> String`、`Formatting.countdownParts(_ s: Int) -> [Formatting.CountdownPart]`（`value: Int` / `unit: String`）、`Formatting.formatCountdown(_ s: Int) -> String`、`Formatting.headDate(_ date: Date, calendar: Calendar = .current) -> String`、`Formatting.hhmm(_ minutes: Int) -> String`（UI 用）。

- [ ] **Step 1: 写失败测试**

`menubar/Tests/OffYetCoreTests/FormattingTests.swift`：

```swift
import Testing
import Foundation
@testable import OffYetCore

struct FormattingTests {
    @Test func money() {
        #expect(Formatting.money(1000) == "¥1,000.00")
        #expect(Formatting.money(333.33) == "¥333.33")
        #expect(Formatting.money(0) == "¥0.00")
        #expect(Formatting.money(0.5) == "¥0.50")
        #expect(Formatting.money(919.54) == "¥919.54")
        #expect(Formatting.money(1234567.891) == "¥1,234,567.89")
    }

    @Test func countdownFormat() {
        #expect(Formatting.formatCountdown(9 * 3600) == "9时 0分")
        #expect(Formatting.formatCountdown(6 * 3600) == "6时 0分")
        #expect(Formatting.formatCountdown(3 * 3600 + 25 * 60 + 19) == "3时 25分")
        #expect(Formatting.formatCountdown(3600) == "1时 0分")
        #expect(Formatting.formatCountdown(3599) == "59分")
        #expect(Formatting.formatCountdown(61) == "1分")
        #expect(Formatting.formatCountdown(45) == "1分")
        #expect(Formatting.formatCountdown(5) == "1分")
        #expect(Formatting.formatCountdown(0) == "0分")
    }

    @Test func countdownPartsSplit() {
        #expect(Formatting.countdownParts(3 * 3600 + 25 * 60 + 19) ==
                [Formatting.CountdownPart(value: 3, unit: "时"),
                 Formatting.CountdownPart(value: 25, unit: "分")])
        #expect(Formatting.countdownParts(25 * 60 + 19) ==
                [Formatting.CountdownPart(value: 25, unit: "分")])
        #expect(Formatting.countdownParts(45) == [Formatting.CountdownPart(value: 1, unit: "分")])
        #expect(Formatting.countdownParts(5) == [Formatting.CountdownPart(value: 1, unit: "分")])
        #expect(Formatting.countdownParts(0) == [Formatting.CountdownPart(value: 0, unit: "分")])
        #expect(Formatting.countdownParts(3600) ==
                [Formatting.CountdownPart(value: 1, unit: "时"),
                 Formatting.CountdownPart(value: 0, unit: "分")])
    }

    @Test func headDateAndHHMM() {
        let d = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12))!
        // 2026-10-09 周四
        #expect(Formatting.headDate(d) == "10月9日 · 周四")
        #expect(Formatting.hhmm(540) == "09:00")
        #expect(Formatting.hhmm(1080) == "18:00")
        #expect(Formatting.hhmm(0) == "00:00")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd menubar && swift test`
Expected: FAIL（`Formatting` 未定义）

- [ ] **Step 3: 实现**

`menubar/Sources/OffYetCore/Formatting.swift`：

```swift
import Foundation

public enum Formatting {
    public struct CountdownPart: Equatable {
        public let value: Int
        public let unit: String

        public init(value: Int, unit: String) {
            self.value = value
            self.unit = unit
        }
    }

    public static func money(_ n: Double) -> String {
        let fixed = String(format: "%.2f", abs(n))
        let parts = fixed.split(separator: ".")
        let sign = n < 0 ? "-" : ""
        return "\(sign)¥\(grouped(parts[0])).\(parts[1])"
    }

    static func grouped(_ digits: some StringProtocol) -> String {
        var result = ""
        let chars = Array(digits)
        for (i, c) in chars.enumerated() {
            if i > 0 && (chars.count - i) % 3 == 0 { result.append(",") }
            result.append(c)
        }
        return result
    }

    public static func countdownParts(_ totalSeconds: Int) -> [CountdownPart] {
        let s = max(0, totalSeconds)
        if s >= 3600 {
            return [CountdownPart(value: s / 3600, unit: "时"),
                    CountdownPart(value: (s % 3600) / 60, unit: "分")]
        }
        let m = s > 0 ? max(1, s / 60) : 0
        return [CountdownPart(value: m, unit: "分")]
    }

    public static func formatCountdown(_ totalSeconds: Int) -> String {
        countdownParts(totalSeconds).map { "\($0.value)\($0.unit)" }.joined(separator: " ")
    }

    /// 顶栏日期：「10月9日 · 周四」
    public static func headDate(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.month, .day, .weekday], from: date)
        let weeks = ["日", "一", "二", "三", "四", "五", "六"]
        return "\(c.month!)月\(c.day!)日 · 周\(weeks[c.weekday! - 1])"
    }

    /// 分钟数 → 「09:00」
    public static func hhmm(_ minutes: Int) -> String {
        String(format: "%02d:%02d", minutes / 60, minutes % 60)
    }
}
```

- [ ] **Step 4: swift test 全绿**

Run: `cd menubar && swift test`
Expected: PASS（新增 4 用例）

- [ ] **Step 5: Commit**

```bash
git add menubar && git commit -m "feat(menubar): money and countdown formatting"
```

---

### Task 5: Milestones（周末 / 发薪 / 退休 + 时区注入）

**Files:**
- Create: `menubar/Sources/OffYetCore/Milestones.swift`
- Test: `menubar/Tests/OffYetCoreTests/MilestoneTests.swift`

**Interfaces:**
- Consumes: `WorkSettings.payDayLastWorkday`
- Produces:
  - `Milestones.daysUntilWeekend(at: Date, calendar: Calendar = .current) -> Int`
  - `Milestones.daysUntilPayday(at: Date, payDay: Int, calendar: Calendar = .current) -> Int?`
  - `Milestones.nextPayday(after: Date, payDay: Int, calendar: Calendar = .current) -> Date?`（UI 副文案「M月D日」用）
  - `Milestones.daysUntilRetirement(at: Date, retirementDate: String, calendar: Calendar = .current) -> Int?`

- [ ] **Step 1: 写失败测试（移植 web 全部里程碑用例 + 新增时区注入）**

`menubar/Tests/OffYetCoreTests/MilestoneTests.swift`：

```swift
import Testing
import Foundation
@testable import OffYetCore

struct MilestoneTests {
    private func at(_ day: Int, _ h: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h))!
    }
    private func atDate(_ y: Int, _ mo: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: mo, day: d, hour: 12))!
    }

    /* ---------- 距离周末 ---------- */

    @Test func weekendMondayAndThursday() {
        #expect(Milestones.daysUntilWeekend(at: at(5, 12)) == 5)
        #expect(Milestones.daysUntilWeekend(at: at(8, 12)) == 2)
    }

    @Test func weekendFridaySaturdaySunday() {
        #expect(Milestones.daysUntilWeekend(at: at(9, 12)) == 1)
        #expect(Milestones.daysUntilWeekend(at: at(10, 12)) == 0)
        #expect(Milestones.daysUntilWeekend(at: at(11, 12)) == 0)
    }

    /* ---------- 距离发薪：固定日 ---------- */

    @Test func paydayOct8To20() {
        #expect(Milestones.daysUntilPayday(at: at(8, 12), payDay: 20) == 12)
    }

    @Test func paydayToday() {
        #expect(Milestones.daysUntilPayday(at: at(20, 12), payDay: 20) == 0)
    }

    @Test func paydayRollsToNextMonth() {
        #expect(Milestones.daysUntilPayday(at: at(25, 12), payDay: 20) == 26)
    }

    @Test func payday31ClampedToMonthEnd() {
        #expect(Milestones.daysUntilPayday(at: atDate(2026, 4, 1), payDay: 31) == 29)
        #expect(Milestones.daysUntilPayday(at: atDate(2027, 2, 1), payDay: 31) == 27)
        #expect(Milestones.daysUntilPayday(at: atDate(2028, 2, 1), payDay: 31) == 28)
    }

    @Test func paydayOnClampedDay() {
        #expect(Milestones.daysUntilPayday(at: atDate(2026, 4, 30), payDay: 31) == 0)
        #expect(Milestones.daysUntilPayday(at: atDate(2027, 2, 28), payDay: 31) == 0)
    }

    @Test func paydayInvalid() {
        // Int 类型天然排除 1.5/NaN/字符串；-1 与 32 必须返回 nil
        for pd in [-1, 32] {
            #expect(Milestones.daysUntilPayday(at: at(8, 12), payDay: pd) == nil)
        }
    }

    /* ---------- 距离发薪：末工作日（哨兵 0） ---------- */

    @Test func lastWorkdayWeekdayAssumptions() {
        // 2026-10-31 周六、2027-02-28 周日、2028-12-31 周日
        #expect(Calendar.current.component(.weekday, from: atDate(2026, 10, 31)) == 7)
        #expect(Calendar.current.component(.weekday, from: atDate(2027, 2, 28)) == 1)
        #expect(Calendar.current.component(.weekday, from: atDate(2028, 12, 31)) == 1)
    }

    @Test func lastWorkdaySaturdayRollback() {
        // 2026-10 月末逢周六 → 回退到 30 日（周五）；10-08 → 22 天
        #expect(Milestones.daysUntilPayday(at: at(8, 12), payDay: WorkSettings.payDayLastWorkday) == 22)
    }

    @Test func lastWorkdayToday() {
        #expect(Milestones.daysUntilPayday(at: atDate(2026, 10, 30),
                                           payDay: WorkSettings.payDayLastWorkday) == 0)
    }

    @Test func lastWorkdayJustPassedRollsOver() {
        // 10-31 周六刚过末工作日 → 顺延 11-30 周一，30 天
        #expect(Milestones.daysUntilPayday(at: atDate(2026, 10, 31),
                                           payDay: WorkSettings.payDayLastWorkday) == 30)
    }

    @Test func lastWorkdaySundayRollback() {
        // 2027-02-28 周日 → 02-26 周五；02-01 → 25 天
        #expect(Milestones.daysUntilPayday(at: atDate(2027, 2, 1),
                                           payDay: WorkSettings.payDayLastWorkday) == 25)
    }

    @Test func lastWorkdayLeapFeb29() {
        // 2028-02-29 本身是工作日 → 按 29 日；02-01 → 28 天
        #expect(Milestones.daysUntilPayday(at: atDate(2028, 2, 1),
                                           payDay: WorkSettings.payDayLastWorkday) == 28)
    }

    @Test func lastWorkdayCrossYear() {
        // 2028-12-31 周日 → 2029-01-31 周三，31 天
        #expect(Milestones.daysUntilPayday(at: atDate(2028, 12, 31),
                                           payDay: WorkSettings.payDayLastWorkday) == 31)
    }

    /* ---------- 距离退休 ---------- */

    @Test func retirement8486Days() {
        #expect(Milestones.daysUntilRetirement(at: at(8, 12), retirementDate: "2050-01-01") == 8486)
    }

    @Test func retirementClampedToZero() {
        #expect(Milestones.daysUntilRetirement(at: at(8, 12), retirementDate: "2026-10-08") == 0)
        #expect(Milestones.daysUntilRetirement(at: at(8, 12), retirementDate: "2026-10-01") == 0)
    }

    @Test func retirementInvalidDates() {
        for d in ["", "2050-1-1", "2050/01/01", "abc", "2050-13-01", "2050-02-30"] {
            #expect(Milestones.daysUntilRetirement(at: at(8, 12), retirementDate: d) == nil)
        }
    }

    /* ---------- 时区注入（web 做不到、Swift 端补充） ---------- */

    @Test func injectedNonLocalTimezone() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let instant = utc.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 15))!

        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 东京 2026-10-12 00:00 周一 → beforeWork，距上班 9h
        let tk = EarningEngine.snapshot(at: instant, settings: .standard, calendar: tokyo)
        #expect(tk.state == .beforeWork)
        #expect(tk.remainingSeconds == 9 * 3600)

        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        // 纽约 2026-10-11 11:00 周日（仍在 EDT）→ restDay
        let us = EarningEngine.snapshot(at: instant, settings: .standard, calendar: ny)
        #expect(us.state == .restDay)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd menubar && swift test`
Expected: FAIL（`Milestones` 未定义）

- [ ] **Step 3: 实现**

`menubar/Sources/OffYetCore/Milestones.swift`：

```swift
import Foundation

public enum Milestones {
    public static func daysUntilWeekend(at date: Date, calendar: Calendar = .current) -> Int {
        let w = calendar.component(.weekday, from: date)
        let jsDay = w == 1 ? 0 : w - 1   // 对齐 JS getDay()：周日 0 … 周六 6
        if jsDay == 0 || jsDay == 6 { return 0 }
        return 6 - jsDay
    }

    /// 发薪日非法（非 0 哨兵且不在 1…31）→ nil
    public static func nextPayday(after date: Date, payDay: Int,
                                  calendar: Calendar = .current) -> Date? {
        if payDay != WorkSettings.payDayLastWorkday && (payDay < 1 || payDay > 31) { return nil }

        var y = calendar.component(.year, from: date)
        var m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        var target = paydayTargetDay(year: y, month: m, payDay: payDay, calendar: calendar)
        if d > target {
            m += 1
            if m > 12 { m = 1; y += 1 }
            target = paydayTargetDay(year: y, month: m, payDay: payDay, calendar: calendar)
        }
        return calendar.date(from: DateComponents(year: y, month: m, day: target))
    }

    public static func daysUntilPayday(at date: Date, payDay: Int,
                                       calendar: Calendar = .current) -> Int? {
        guard let target = nextPayday(after: date, payDay: payDay, calendar: calendar) else { return nil }
        return daysBetween(date, target, calendar: calendar)
    }

    public static func daysUntilRetirement(at date: Date, retirementDate: String,
                                           calendar: Calendar = .current) -> Int? {
        guard let r = parseDateOnly(retirementDate, calendar: calendar) else { return nil }
        return max(0, daysBetween(date, r, calendar: calendar))
    }

    // MARK: - 内部

    /// 闰月钳制 / 末工作日回退（末工作日只跳过周六日，与 web 一致）
    static func paydayTargetDay(year y: Int, month m: Int, payDay: Int, calendar: Calendar) -> Int {
        if payDay == WorkSettings.payDayLastWorkday { return lastWorkdayDay(y, m, calendar) }
        return min(payDay, daysInMonth(year: y, month: m, calendar: calendar))
    }

    static func daysInMonth(year y: Int, month m: Int, calendar: Calendar) -> Int {
        let first = calendar.date(from: DateComponents(year: y, month: m, day: 1))!
        return calendar.range(of: .day, in: .month, for: first)!.count
    }

    static func lastWorkdayDay(_ y: Int, _ m: Int, _ calendar: Calendar) -> Int {
        var d = daysInMonth(year: y, month: m, calendar: calendar)
        while true {
            let date = calendar.date(from: DateComponents(year: y, month: m, day: d))!
            let w = calendar.component(.weekday, from: date)
            if w != 1 && w != 7 { return d }
            d -= 1
        }
    }

    /// 年月日分量取本地零点再求天数差，避开夏令时 23/25 小时日（对齐 web 的 Date.UTC 技巧）
    static func daysBetween(_ a: Date, _ b: Date, calendar: Calendar) -> Int {
        let ca = calendar.dateComponents([.year, .month, .day], from: a)
        let cb = calendar.dateComponents([.year, .month, .day], from: b)
        let da = calendar.date(from: ca)!
        let db = calendar.date(from: cb)!
        return calendar.dateComponents([.day], from: da, to: db).day!
    }

    /// 严格 YYYY-MM-DD：正则级格式检查 + 分量范围 + Date 回验
    static func parseDateOnly(_ str: String, calendar: Calendar) -> Date? {
        let parts = str.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { ("0"..."9").contains($0) } }),
              let y = Int(parts[0]), let mo = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(mo), (1...31).contains(d),
              let dt = calendar.date(from: DateComponents(year: y, month: mo, day: d))
        else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: dt)
        guard back.year == y, back.month == mo, back.day == d else { return nil }
        return dt
    }
}
```

- [ ] **Step 4: swift test 全绿**

Run: `cd menubar && swift test`
Expected: PASS（新增 19 用例；累计 46）

- [ ] **Step 5: Commit**

```bash
git add menubar && git commit -m "feat(menubar): milestones with payday and retirement"
```

---

### Task 6: StoredState + StateStore 持久化

**Files:**
- Create: `menubar/Sources/OffYetCore/StoredState.swift`
- Test: `menubar/Tests/OffYetCoreTests/PersistenceTests.swift`

**Interfaces:**
- Consumes: `WorkSettings`（Codable）
- Produces:
  - `MenuBarMode: String, Codable, CaseIterable`（`.money` / `.countdown` / `.icon`，rawValue 即存储串）
  - `StoredState: Codable, Equatable`（settings/menuBarMode/simEnabled/simTime:Date?/launchAtLogin，全默认值）
  - `StateStore(defaults: UserDefaults = .standard)`；`load() -> StoredState`（缺键/坏数据→默认）；`save(_:)`

- [ ] **Step 1: 写失败测试**

`menubar/Tests/OffYetCoreTests/PersistenceTests.swift`：

```swift
import Testing
import Foundation
@testable import OffYetCore

struct PersistenceTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.offyet.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func missingKeyFallsBackToDefaults() {
        let store = StateStore(defaults: makeDefaults())
        #expect(store.load() == StoredState())
    }

    @Test func roundtrip() {
        let defaults = makeDefaults()
        let store = StateStore(defaults: defaults)
        var s = StoredState()
        s.settings.monthlySalary = 30000
        s.settings.payDay = WorkSettings.payDayLastWorkday
        s.menuBarMode = .countdown
        s.simEnabled = true
        s.simTime = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))
        s.launchAtLogin = true
        store.save(s)
        #expect(store.load() == s)
    }

    @Test func corruptDataFallsBackToDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "offyet.settings.v1")
        let store = StateStore(defaults: defaults)
        #expect(store.load() == StoredState())
    }

    @Test func menuBarModeRawValues() {
        #expect(MenuBarMode.money.rawValue == "money")
        #expect(MenuBarMode.countdown.rawValue == "countdown")
        #expect(MenuBarMode.icon.rawValue == "icon")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `cd menubar && swift test`
Expected: FAIL（类型未定义）

- [ ] **Step 3: 实现**

`menubar/Sources/OffYetCore/StoredState.swift`：

```swift
import Foundation

public enum MenuBarMode: String, Codable, CaseIterable {
    case money
    case countdown
    case icon
}

public struct StoredState: Codable, Equatable {
    public var settings: WorkSettings = .standard
    public var menuBarMode: MenuBarMode = .money
    public var simEnabled: Bool = false
    public var simTime: Date?
    public var launchAtLogin: Bool = false

    public init() {}
}

public final class StateStore {
    private let defaults: UserDefaults
    private static let key = "offyet.settings.v1"

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 缺键或解码失败 → 整体回落默认值（对齐网页版容错策略）
    public func load() -> StoredState {
        guard let data = defaults.data(forKey: Self.key) else { return StoredState() }
        guard let s = try? JSONDecoder().decode(StoredState.self, from: data) else { return StoredState() }
        return s
    }

    public func save(_ state: StoredState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        defaults.set(data, forKey: Self.key)
    }
}
```

- [ ] **Step 4: swift test 全绿**

Run: `cd menubar && swift test`
Expected: PASS（新增 4 用例；累计 50）

- [ ] **Step 5: Commit**

```bash
git add menubar && git commit -m "feat(menubar): stored state and UserDefaults persistence"
```

---

### Task 7: OffYetApp 骨架 + 菜单栏三模式

**Files:**
- Delete: `menubar/Sources/OffYetApp/main.swift`
- Create: `menubar/Sources/OffYetApp/OffYetApp.swift`
- Create: `menubar/Sources/OffYetApp/AppStore.swift`
- Create: `menubar/Sources/OffYetApp/StatusBarLabel.swift`
- Create: `menubar/Sources/OffYetApp/Theme.swift`
- Create: `menubar/Sources/OffYetApp/PanelView.swift`（本任务先放最小占位，Task 8 完善）

**Interfaces:**
- Consumes: OffYetCore 全部公开 API（Task 1–6）
- Produces:
  - `AppStore`（`@MainActor final class: ObservableObject`）：`@Published private(set) var state: StoredState`、`apply(_:)`（写盘 + 登录项）、`currentDate(fallback:) -> Date`（模拟时间注入点）、`version` 透传
  - `LoginItemService.set(_ enabled: Bool)`（SMAppService，失败静默降级）
  - `PanelView(store:)`——MenuBarExtra 的窗口内容（Task 8 填充）
  - `StatusBarLabel(store:)`——菜单栏 label，三模式
  - `Theme.palette(_ dark: Bool) -> Palette`（全部色板）

- [ ] **Step 1: 删除 main.swift，写应用入口**

`menubar/Sources/OffYetApp/OffYetApp.swift`：

```swift
import SwiftUI
import OffYetCore

@main
struct OffYetMainApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            StatusBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 2: AppStore 与登录项**

`menubar/Sources/OffYetApp/AppStore.swift`：

```swift
import Foundation
import ServiceManagement
import OffYetCore

struct LoginItemService {
    /// ad-hoc 签名 + 非 /Applications 环境下 register 可能失败——静默降级，UI 提示手动加登录项
    func set(_ enabled: Bool) {
        if enabled {
            try? SMAppService.mainApp.register()
        } else {
            try? SMAppService.mainApp.unregister()
        }
    }
}

@MainActor
final class AppStore: ObservableObject {
    @Published private(set) var state: StoredState

    private let store: StateStore
    private let login = LoginItemService()

    init(store: StateStore = StateStore()) {
        self.store = store
        self.state = store.load()
    }

    var version: String { OffYetCore.version }

    /// 所有「当前时刻」的唯一入口：模拟时间开启时用 simTime
    func currentDate(fallback: Date) -> Date {
        state.simEnabled ? (state.simTime ?? fallback) : fallback
    }

    func apply(_ newState: StoredState) {
        state = newState
        store.save(newState)
        login.set(newState.launchAtLogin)
    }
}
```

- [ ] **Step 3: 色板（从 web/styles.css 逐值抄录）**

`menubar/Sources/OffYetApp/Theme.swift`：

```swift
import SwiftUI

struct Palette {
    let bgGradient: LinearGradient
    let card: Color
    let border: Color
    let text: Color
    let text2: Color
    let accent: Color
    let accent2: Color
    let money: Color
    let moneyBadge: Color
    let track: Color
    let error: Color
    let calendarIcon: Color
    let calendarBg: Color
    let walletIcon: Color
    let walletBg: Color
    let hourglassIcon: Color
    let hourglassBg: Color

    static func palette(_ dark: Bool) -> Palette {
        if dark {
            return Palette(
                bgGradient: LinearGradient(colors: [Color(hex: 0x1B1B24), Color(hex: 0x17181F), Color(hex: 0x161D1A)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing),
                card: Color(hex: 0x232328),
                border: Color.white.opacity(0.10),
                text: Color(hex: 0xF5F5F7),
                text2: Color(hex: 0x9D9DA3),
                accent: Color(hex: 0x409CFF),
                accent2: Color(hex: 0x9D7CFF),
                money: Color(hex: 0x30D158),
                moneyBadge: Color(hex: 0x30D158).opacity(0.16),
                track: Color.white.opacity(0.12),
                error: Color(hex: 0xE5484D),
                calendarIcon: Color(hex: 0x409CFF), calendarBg: Color(hex: 0x409CFF).opacity(0.16),
                walletIcon: Color(hex: 0x64D2FF), walletBg: Color(hex: 0x64D2FF).opacity(0.16),
                hourglassIcon: Color(hex: 0x9D7CFF), hourglassBg: Color(hex: 0x9D7CFF).opacity(0.16))
        }
        return Palette(
            bgGradient: LinearGradient(colors: [Color(hex: 0xEEF0FE), Color(hex: 0xE6F0FD), Color(hex: 0xE8F8EF)],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
            card: .white,
            border: Color.black.opacity(0.08),
            text: Color(hex: 0x1D1D1F),
            text2: Color(hex: 0x6E6E73),
            accent: Color(hex: 0x0A84FF),
            accent2: Color(hex: 0x7A5CFF),
            money: Color(hex: 0x1D9D54),
            moneyBadge: Color(hex: 0x1D9D54).opacity(0.12),
            track: Color.black.opacity(0.08),
            error: Color(hex: 0xE5484D),
            calendarIcon: Color(hex: 0x0A84FF), calendarBg: Color(hex: 0x0A84FF).opacity(0.12),
            walletIcon: Color(hex: 0x32ADE6), walletBg: Color(hex: 0x32ADE6).opacity(0.14),
            hourglassIcon: Color(hex: 0x7A5CFF), hourglassBg: Color(hex: 0x7A5CFF).opacity(0.12))
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}
```

- [ ] **Step 4: 菜单栏 label（三模式 + 1Hz）**

`menubar/Sources/OffYetApp/StatusBarLabel.swift`：

```swift
import SwiftUI
import OffYetCore

struct StatusBarLabel: View {
    @ObservedObject var store: AppStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            content(now: store.currentDate(fallback: context.date))
                // 强制每拍重建视图，规避 MenuBarExtra label 不刷新的平台怪癖
                .id(context.date)
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let snap = EarningEngine.snapshot(at: now, settings: store.state.settings)
        switch store.state.menuBarMode {
        case .icon:
            Image(systemName: "sun.max.fill")
        case .money:
            switch snap.state {
            case .working, .afterWork:
                Text(Formatting.money(snap.earned)).monospacedDigit()
            case .beforeWork:
                Text("¥0.00")
            case .restDay:
                Text("☕️")
            case .invalid:
                Text("OffYet")
            }
        case .countdown:
            switch snap.state {
            case .working, .beforeWork:
                Text(Formatting.formatCountdown(snap.remainingSeconds ?? 0)).monospacedDigit()
            case .afterWork:
                Text("已下班 🎉")
            case .restDay:
                Text("休息 ☕️")
            case .invalid:
                Text("OffYet")
            }
        }
    }
}
```

- [ ] **Step 5: 面板占位**

`menubar/Sources/OffYetApp/PanelView.swift`：

```swift
import SwiftUI
import OffYetCore

struct PanelView: View {
    @ObservedObject var store: AppStore

    var body: some View {
        Text("OffYet").padding(20).frame(width: 360)
    }
}
```

- [ ] **Step 6: 构建并启动冒烟**

Run: `cd menubar && swift build && timeout 5 .build/debug/OffYetApp; echo "exit=$?"`
Expected: 编译通过；进程启动后 5 秒被 timeout 杀掉（菜单栏应短暂出现太阳图标/金额——开发态无 bundle，Dock 图标会出现，正常）。`timeout` 若本机没有，用 `swift run` 后手动 Ctrl-C。

- [ ] **Step 7: Commit**

```bash
git add menubar && git commit -m "feat(menubar): app skeleton with menu bar label modes"
```

---

### Task 8: 面板主视图（对照网页版）

**Files:**
- Modify: `menubar/Sources/OffYetApp/PanelView.swift`（整文件重写）
- Create: `menubar/Sources/OffYetApp/MilestoneCards.swift`

**Interfaces:**
- Consumes: `AppStore`、`Theme.palette`、`EarningEngine`、`Formatting`、`Milestones`
- Produces: `PanelView(store:)`（完整面板）；`MilestoneCard`（label/days/sub/icon/tint/tintBg）；`PanelView` 新增内部状态 `showSettings: Bool`（Task 9 的设置页通过它切入）。

- [ ] **Step 1: 里程碑卡片组件**

`menubar/Sources/OffYetApp/MilestoneCards.swift`：

```swift
import SwiftUI

struct MilestoneCard: View {
    let label: String
    let days: Int?
    let sub: String
    let icon: String      // SF Symbol 名
    let tint: Color
    let tintBg: Color
    let palette: Palette

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(tint)
                .frame(width: 36, height: 36)
                .background(tintBg)
                .cornerRadius(11)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.system(size: 11)).tracking(1).foregroundColor(palette.text2)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(days.map { "\($0)" } ?? "--")
                        .font(.system(size: 21, weight: .bold)).monospacedDigit()
                    Text("天").font(.system(size: 11)).foregroundColor(palette.text2)
                }
                Text(sub).font(.system(size: 11)).foregroundColor(palette.text2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(palette.card)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(palette.border))
    }
}
```

- [ ] **Step 2: 面板整文件重写**

`menubar/Sources/OffYetApp/PanelView.swift`：

```swift
import SwiftUI
import OffYetCore

struct PanelView: View {
    @ObservedObject var store: AppStore
    @State private var showSettings = false

    var body: some View {
        Group {
            if showSettings {
                SettingsView(store: store, onBack: { showSettings = false })
            } else {
                mainPanel
            }
        }
        .frame(width: 360)
    }

    private var mainPanel: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            mainContent(now: store.currentDate(fallback: context.date))
        }
    }

    @ViewBuilder
    private func mainContent(now: Date) -> some View {
        let dark = colorScheme == .dark
        let p = Palette.palette(dark)
        let s = store.state.settings
        let snap = EarningEngine.snapshot(at: now, settings: s)

        VStack(spacing: 12) {
            header(now: now, p: p)
            bodyCard(snap: snap, settings: s, now: now, p: p)
            milestones(now: now, settings: s, p: p)
        }
        .padding(14)
        .background(p.bgGradient.ignoresSafeArea())
    }

    @Environment(\.colorScheme) private var colorScheme

    // MARK: 顶栏

    private func header(now: Date, p: Palette) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "sun.max.fill")
                .font(.system(size: 20))
                .foregroundStyle(p.accent, p.accent2)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    Text("下班了么").font(.system(size: 16, weight: .bold))
                    Text(" v\(store.version)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(p.text2.opacity(0.7))
                }
                Text("OffYet").font(.system(size: 8)).tracking(2.5).foregroundColor(p.text2)
            }
            Spacer()
            Text(Formatting.headDate(now))
                .font(.system(size: 12, weight: .medium)).monospacedDigit()
                .foregroundColor(p.text2)
            Button { showSettings = true } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(p.text2)
                    .frame(width: 26, height: 26)
                    .background(p.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(p.border))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 中央卡（倒计时 + 进度 + 金额）

    @ViewBuilder
    private func bodyCard(snap: DaySnapshot, settings: WorkSettings, now: Date, p: Palette) -> some View {
        VStack(spacing: 14) {
            if snap.state == .invalid {
                VStack(spacing: 6) {
                    Text("请检查设置").font(.system(size: 18, weight: .semibold)).foregroundColor(p.error)
                    Text("下班时间需晚于上班时间，月薪与每月工作日数需大于 0")
                        .font(.system(size: 12)).foregroundColor(p.text2)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                stateLabel(snap: snap, p: p)
                countdownValue(snap: snap, p: p)
                progressBar(snap: snap, settings: settings, p: p)
                moneySection(snap: snap, p: p)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .background(p.card)
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(p.border))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.38 : 0.08), radius: 10, y: 4)
    }

    private func stateLabel(snap: DaySnapshot, p: Palette) -> some View {
        let label: String
        switch snap.state {
        case .beforeWork: label = "距离上班还有"
        case .working: label = "距离下班还有"
        case .afterWork: label = "已下班 🎉"
        case .restDay: label = "今天休息 ☕️"
        case .invalid: label = ""
        }
        return Text(label)
            .font(.system(size: 12, weight: .medium)).tracking(1)
            .foregroundColor(p.text2)
    }

    @ViewBuilder
    private func countdownValue(snap: DaySnapshot, p: Palette) -> some View {
        if snap.state == .afterWork || snap.state == .restDay {
            EmptyView()
        } else {
            let parts = Formatting.countdownParts(snap.remainingSeconds ?? 0)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                ForEach(Array(parts.enumerated()), id: \.offset) { _, part in
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(part.value)")
                            .font(.system(size: 42, weight: .bold)).monospacedDigit()
                        Text(part.unit).font(.system(size: 17, weight: .regular)).foregroundColor(p.text2)
                    }
                }
            }
        }
    }

    private func progressBar(snap: DaySnapshot, settings: WorkSettings, p: Palette) -> some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(p.track)
                    Capsule()
                        .fill(LinearGradient(colors: [p.accent, p.accent2],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, min(1, snap.progress)) * geo.size.width)
                }
            }
            .frame(height: 8)
            HStack {
                Text(Formatting.hhmm(settings.startMin))
                Spacer()
                Text(Formatting.hhmm(settings.endMin))
            }
            .font(.system(size: 10)).monospacedDigit().foregroundColor(p.text2)
        }
    }

    @ViewBuilder
    private func moneySection(snap: DaySnapshot, p: Palette) -> some View {
        VStack(spacing: 5) {
            Text("今天已经赚到")
                .font(.system(size: 12, weight: .medium)).tracking(1).foregroundColor(p.text2)
            Text(Formatting.money(snap.earned))
                .font(.system(size: 34, weight: .bold)).monospacedDigit()
                .foregroundColor(p.money)
            if snap.state == .working {
                Text("持续增长中")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(p.money)
                    .padding(.horizontal, 10).padding(.vertical, 3)
                    .background(p.moneyBadge)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: 里程碑

    @ViewBuilder
    private func milestones(now: Date, settings: WorkSettings, p: Palette) -> some View {
        let weekend = Milestones.daysUntilWeekend(at: now)
        let weekendSub = weekend == 0 ? "享受周末" : (weekend == 1 ? "明天就是" : "周六见")

        let paydayDays = Milestones.daysUntilPayday(at: now, payDay: settings.payDay)
        let paydaySub: String = {
            guard let days = paydayDays else { return "--" }
            if days == 0 { return "今天到账" }
            guard let target = Milestones.nextPayday(after: now, payDay: settings.payDay) else { return "--" }
            let c = Calendar.current.dateComponents([.month, .day], from: target)
            return "\(c.month!)月\(c.day!)日"
        }()

        let retireDays = Milestones.daysUntilRetirement(at: now, retirementDate: settings.retirementDate)
        let retireText = retireDays.map {
            Self.grouped("\($0)")
        } ?? "--"

        VStack(spacing: 8) {
            MilestoneCard(label: "距离周末", days: weekend, sub: weekendSub,
                          icon: "calendar", tint: p.calendarIcon, tintBg: p.calendarBg, palette: p)
            MilestoneCard(label: "距离发薪", days: paydayDays, sub: paydaySub,
                          icon: "banknote", tint: p.walletIcon, tintBg: p.walletBg, palette: p)
            MilestoneCard(label: "距离退休", days: retireDays, sub: "正在靠近自由",
                          icon: "hourglass", tint: p.hourglassIcon, tintBg: p.hourglassBg, palette: p)
        }
    }

    static func grouped(_ s: String) -> String {
        var r = ""
        let chars = Array(s)
        for (i, c) in chars.enumerated() {
            if i > 0 && (chars.count - i) % 3 == 0 { r.append(",") }
            r.append(c)
        }
        return r
    }
}
```

注意：退休卡 `days` 直接显示千分位分组文本（如 `8,486`），而 `MilestoneCard.days` 是 `Int?` 会原样 `"\($0)"` 输出——为保持千分位，把 `MilestoneCard` 的数值显示参数改为 `valueText: String`（计划内直接按此实现：上面 `MilestoneCard` 中 `Text(days.map { "\($0)" } ?? "--")` 一行替换为 `Text(valueText)`，并把 `let days: Int?` 换成 `let valueText: String`；三张卡分别传 `"\(weekend)"`、`paydayDays.map { "\($0)" } ?? "--"`、`retireText`）。

- [ ] **Step 3: 构建验证**

Run: `cd menubar && swift build`
Expected: 编译通过，无警告级错误

- [ ] **Step 4: Commit**

```bash
git add menubar && git commit -m "feat(menubar): full panel view aligned with web v0.1.0"
```

---

### Task 9: 设置页（面板内切换）

**Files:**
- Create: `menubar/Sources/OffYetApp/SettingsView.swift`
- Modify: `menubar/Sources/OffYetApp/PanelView.swift`（无需改动——Task 8 的 `showSettings` 分支已引用 `SettingsView`）

**Interfaces:**
- Consumes: `AppStore.apply`、`WorkSettings`、`MenuBarMode`、`Formatting.hhmm`
- Produces: `SettingsView(store: AppStore, onBack: () -> Void)`

实现说明（相对 spec 的实现决策）：MenuBarExtra 窗口里系统 sheet/presentation 有已知的焦点与尺寸问题，设置页做成**面板内切换**（齿轮 → 设置页 → 返回），交互语义与 spec 一致。

- [ ] **Step 1: 实现 SettingsView**

`menubar/Sources/OffYetApp/SettingsView.swift`：

```swift
import SwiftUI
import OffYetCore

struct SettingsView: View {
    @ObservedObject var store: AppStore
    let onBack: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var draft = StoredState()
    @State private var startAt = Date()
    @State private var endAt = Date()
    @State private var retireAt = Date()
    @State private var salaryText = ""
    @State private var daysText = ""
    @State private var simAt = Date()

    private var p: Palette { Palette.palette(colorScheme == .dark) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                Text("设置").font(.system(size: 15, weight: .semibold))
                Spacer()
                saveButton
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field("上班时间") { DatePicker("", selection: $startAt, displayedComponents: .hourAndMinute).labelsHidden() }
                    field("下班时间") { DatePicker("", selection: $endAt, displayedComponents: .hourAndMinute).labelsHidden() }
                    field("月薪（元）") { TextField("20000", text: $salaryText).textFieldStyle(.roundedBorder) }
                    field("每月工作日数") { TextField("21.75", text: $daysText).textFieldStyle(.roundedBorder) }
                    field("发薪日") {
                        Picker("", selection: $draft.settings.payDay) {
                            Text("每月最后一个工作日").tag(WorkSettings.payDayLastWorkday)
                            ForEach(1...31, id: \.self) { d in Text("每月 \(d) 号").tag(d) }
                        }.labelsHidden()
                    }
                    field("退休日期") { DatePicker("", selection: $retireAt, displayedComponents: .date).labelsHidden() }
                    field("菜单栏显示") {
                        Picker("", selection: $draft.menuBarMode) {
                            Text("今日已赚（实时）").tag(MenuBarMode.money)
                            Text("下班倒计时").tag(MenuBarMode.countdown)
                            Text("图标").tag(MenuBarMode.icon)
                        }.labelsHidden()
                    }
                    Toggle("开机自启", isOn: $draft.launchAtLogin)
                    Toggle("模拟时间（调试）", isOn: $draft.simEnabled)
                    if draft.simEnabled {
                        DatePicker("模拟时刻", selection: $simAt)
                            .font(.system(size: 12))
                    }
                    if !canSave {
                        Text("下班时间需晚于上班时间；月薪与工作日数需为大于 0 的数字")
                            .font(.system(size: 11)).foregroundColor(p.error)
                    }
                }
            }
        }
        .padding(14)
        .background(p.bgGradient.ignoresSafeArea())
        .onAppear(perform: load)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundColor(p.text2)
            content()
        }
    }

    private var canSave: Bool {
        guard let salary = Double(salaryText), salary > 0,
              let days = Double(daysText), days > 0 else { return false }
        var s = draft.settings
        s.startMin = minutesFrom(startAt)
        s.endMin = minutesFrom(endAt)
        s.monthlySalary = salary
        s.workDaysPerMonth = days
        s.retirementDate = yyyyMMdd(retireAt)
        return s.isValid
    }

    private var saveButton: some View {
        Button("保存") { save() }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
    }

    private func load() {
        draft = store.state
        let cal = Calendar.current
        startAt = dateFrom(minutes: draft.settings.startMin, calendar: cal)
        endAt = dateFrom(minutes: draft.settings.endMin, calendar: cal)
        simAt = draft.simTime ?? Date()
        salaryText = trimDouble(draft.settings.monthlySalary)
        daysText = trimDouble(draft.settings.workDaysPerMonth)
        var comps = cal.dateComponents([.year, .month, .day], from: cal.startOfDay(for: Date()))
        if let r = Milestones.parseDateOnlyPublic(draft.settings.retirementDate) {
            let rc = cal.dateComponents([.year, .month, .day], from: r)
            comps = rc
        }
        retireAt = cal.date(from: comps) ?? Date()
    }

    private func save() {
        var s = draft
        s.settings.startMin = minutesFrom(startAt)
        s.settings.endMin = minutesFrom(endAt)
        s.settings.monthlySalary = Double(salaryText) ?? 0
        s.settings.workDaysPerMonth = Double(daysText) ?? 0
        s.settings.retirementDate = yyyyMMdd(retireAt)
        s.simEnabled = draft.simEnabled
        s.simTime = draft.simEnabled ? simAt : nil
        guard s.settings.isValid else { return }
        store.apply(s)
        onBack()
    }

    // MARK: - 转换工具

    private func minutesFrom(_ d: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return c.hour! * 60 + c.minute!
    }

    private func dateFrom(minutes: Int, calendar: Calendar) -> Date {
        var c = calendar.dateComponents([.year, .month, .day], from: Date())
        c.hour = minutes / 60
        c.minute = minutes % 60
        return calendar.date(from: c)!
    }

    private func yyyyMMdd(_ d: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// 20000 → "20000"，21.75 → "21.75"
    private func trimDouble(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : "\(v)"
    }
}
```

其中 `Milestones.parseDateOnlyPublic(_:)`：在 `menubar/Sources/OffYetCore/Milestones.swift` 的 `Milestones` enum 中追加一个薄包装（不改既有内部函数）：

```swift
public static func parseDateOnlyPublic(_ s: String) -> Date? {
    parseDateOnly(s, calendar: .current)
}
```

- [ ] **Step 2: 构建验证**

Run: `cd menubar && swift build`
Expected: 编译通过

- [ ] **Step 3: Commit**

```bash
git add menubar && git commit -m "feat(menubar): in-panel settings page with validation"
```

---

### Task 10: 打包脚本 build-app.sh

**Files:**
- Create: `menubar/scripts/build-app.sh`（可执行权限）

**Interfaces:**
- Consumes: `swift build -c release` 产物、`assets/offyet-logo-1024.png`、`OffYetCore.version`
- Produces: `build/OffYet.app`（ad-hoc 签名，LSUIElement，含 .icns）；`--install` 拷入 /Applications 并启动

- [ ] **Step 1: 写脚本**

`menubar/scripts/build-app.sh`：

```bash
#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."

CONFIG=release
TRIPLE_DIR=".build/arm64-apple-macosx/$CONFIG"
APP="menubar/build/OffYet.app"
VERSION=$(sed -n 's/^public let version = "\(.*\)"$/\1/p' menubar/Sources/OffYetCore/OffYetCore.swift)

echo "==> swift build -c $CONFIG"
swift build -c $CONFIG

echo "==> assemble $APP (v$VERSION)"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$TRIPLE_DIR/OffYetApp" "$APP/Contents/MacOS/OffYet"

ICONSET="menubar/build/AppIcon.iconset"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
SRC="assets/offyet-logo-1024.png"
sips -z 16 16    "$SRC" --out "$ICONSET/icon_16x16.png"     >/dev/null
sips -z 32 32    "$SRC" --out "$ICONSET/icon_16x16@2x.png"  >/dev/null
sips -z 32 32    "$SRC" --out "$ICONSET/icon_32x32.png"     >/dev/null
sips -z 64 64    "$SRC" --out "$ICONSET/icon_32x32@2x.png"  >/dev/null
sips -z 128 128  "$SRC" --out "$ICONSET/icon_128x128.png"   >/dev/null
sips -z 256 256  "$SRC" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 256 256  "$SRC" --out "$ICONSET/icon_256x256.png"   >/dev/null
sips -z 512 512  "$SRC" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 512 512  "$SRC" --out "$ICONSET/icon_512x512.png"   >/dev/null
sips -z 1024 1024 "$SRC" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>OffYet</string>
    <key>CFBundleDisplayName</key><string>下班了么</string>
    <key>CFBundleIdentifier</key><string>local.offyet.menubar</string>
    <key>CFBundleExecutable</key><string>OffYet</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$VERSION</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHumanReadableCopyright</key><string>OffYet</string>
</dict>
</plist>
PLIST

echo "==> codesign (ad-hoc)"
codesign --force --sign - "$APP"

echo "Built: $APP"
if [ "${1:-}" = "--install" ]; then
    osascript -e 'tell application "OffYet" to quit' 2>/dev/null || true
    sleep 1
    rm -rf /Applications/OffYet.app
    cp -R "$APP" /Applications/OffYet.app
    open /Applications/OffYet.app
    echo "Installed and launched: /Applications/OffYet.app"
fi
```

- [ ] **Step 2: 加执行权限并构建**

Run: `chmod +x menubar/scripts/build-app.sh && menubar/scripts/build-app.sh`
Expected: 末行输出 `Built: menubar/build/OffYet.app`；`codesign -dv menubar/build/OffYet.app` 显示 Signature=adhoc；`plutil -lint menubar/build/OffYet.app/Contents/Info.plist` 通过

- [ ] **Step 3: Commit**

```bash
git add menubar && git commit -m "build(menubar): app bundle packaging script"
```

---

### Task 11: 手动验收（用户参与）

**Files:** 无新文件；必要时修 bug 回到对应任务

- [ ] **Step 1: 安装并启动**

Run: `menubar/scripts/build-app.sh --install`
Expected: 菜单栏出现 OffYet（金额模式，工作中时金额每秒跳动）

- [ ] **Step 2: 手动验收清单（逐项过，用户确认）**

1. 菜单栏三模式：设置里切换 金额/倒计时/图标，立即生效且重启 App 后保持
2. 四状态：默认配置下用「模拟时间」分别验证 上班前（¥0.00/距上班倒计时）、工作中（秒跳金额+徽章+进度条）、已下班（满额+🎉）、休息日（☕️）——把模拟时刻拨到对应时间
3. 面板视觉：与网页版（`web/index.html` 浏览器打开）对照——渐变背景、白卡、倒计时数字+小单位标、进度条端点 09:00/18:00、绿色金额、三张里程碑卡副文案（「享受周末」「明天就是」「今天到账」「正在靠近自由」）
4. 深浅色：系统外观切换下面板与菜单栏自动适配
5. 设置持久化：改月薪为 30000 保存 → 重启 App → 金额按新日薪计算；故意输入「下班早于上班」→ 保存禁用+红字提示
6. 发薪日「每月最后一个工作日」选项 → 发薪卡天数与网页版一致
7. 开机自启 toggle：系统设置 → 通用 → 登录项出现 OffYet（若因 ad-hoc 签名未出现，确认 UI 有「需放入 /Applications」降级提示）
8. 无 Dock 图标；Activity Monitor 中 CPU 占用 < 1%
9. 模拟时间关闭后恢复真实时间

- [ ] **Step 3: 验收问题修复后收尾**

```bash
git add -A && git commit -m "chore(menubar): acceptance fixes"
```

---

## Self-Review 记录

- **Spec 覆盖**：§2 做→Task 1–11 全覆盖（菜单栏三模式=T7、面板=T8、设置=T9、引擎=T2–5、持久化=T6、打包=T10、验收=T11）；§5 口径→T3/T5 逐条移植；§8 存储结构→T6（`menuBarMode` 等 5 字段一致）；§10 测试→43 用例移植（非法发薪日/退休日期中 Int/String 类型天然不可表示的输入按类型语义裁剪，其余全保留）+ 新增时区注入；§9 打包→T10。
- **占位符扫描**：无 TBD/TODO；所有代码步骤含完整代码。
- **类型一致性**：`MilestoneCard.valueText`（T8 Step 2 注意事项已同步到组件与三处调用）；`SettingsView` 引用的 `parseDateOnlyPublic` 在同任务内定义；`Palette.palette(_:)` / `Color(hex:)` / `AppStore.currentDate(fallback:)` 在 T7 定义、T8/T9 使用一致。
