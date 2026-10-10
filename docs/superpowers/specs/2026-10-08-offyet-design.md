# OffYet（下班了么）Mac 版 v1 设计文档

日期：2026-10-08
状态：已与用户确认，待实施计划

## 1. 背景与目标

做一个桌面小组件：上班时随时能看到「距离下班还有多久」和「今天已经赚了多少钱」，实时刷新、有进度感。App 名 OffYet，中文显示名「下班了么」。

v1 仅支持 macOS（用户本人 Mac，macOS 26.3，Apple Silicon）。iPhone 版为未来项，技术选型已考虑复用。

## 2. v1 范围

### 做

- macOS 桌面 / 通知中心小组件，支持小、中、大三种尺寸，可放置多个实例
- 每个小组件实例独立配置：上班时间、下班时间、月薪、每月工作日数
- 展示：下班倒计时（秒级跳动）、今日已赚金额（每分钟跳动）、今日进度（条/环）
- 状态表现：上班前 / 工作中 / 已下班 / 休息日
- 容器 App：添加小组件引导 + 实时效果演示
- 计算引擎单元测试（TDD）

### 不做（明确排除）

- iPhone / iPad 版、iCloud 同步、App 与小组件共享配置（App Group）——未来项
- 菜单栏显示、隐私模式（¥****）——用户明确不要
- 中国法定节假日 / 调休日历——v1 只按周六日判定休息
- 自定义主题、通知提醒、多套配置预设

## 3. 技术选型与约束

| 项 | 决定 | 理由 |
|---|---|---|
| 框架 | SwiftUI + WidgetKit | 系统原生小组件唯一可行方案 |
| 最低系统 | macOS 14.0+ | 桌面小组件与 AppIntent 小组件配置均为 14+ |
| 配置入口 | 小组件的「编辑小组件」面板（WidgetConfigurationIntent） | 不依赖 App Group，本机签名即可用，零账号成本 |
| 签名 | "Sign to Run Locally"（本地签名） | 无需任何 Apple 账号，无 7 天过期问题 |
| 共享代码 | 本地 Swift Package `OffYetCore` | 纯计算逻辑，`swift test` 可独立测试，无需 Xcode GUI |
| 工程生成 | XcodeGen（project.yml 声明式）为首选；若用户不愿安装则 Xcode GUI 建工程 | 可复现、可由 CLI 维护；fallback 不影响架构 |
| 测试框架 | Swift Testing | 现代、语法简洁；仅用于 OffYetCore |
| 命名约定 | App 显示名「下班了么」，target 名 `OffYet` / `OffYetWidget`，Bundle ID `local.offyet.app` / `local.offyet.app.widget` | 本地签名不要求注册 Bundle ID |

关键事实（已验证）：

- WidgetKit 中 `Text(timerInterval:countsDown:)` 是渲染层自更新时间文本，**每秒自动跳动，不消耗 timeline 刷新预算**
- 预排时间线（一次提供全天多个 entry）不消耗刷新次数预算，系统按 entry 时间自动切换显示
- 免费 Apple 账号的 7 天重签问题只影响 iOS 设备部署；macOS 本机签名无此问题
- App Group / iCloud 属付费能力，v1 设计完全绕开

## 4. 架构

```
OffYetCore（本地 Swift Package，纯函数，无 UI 依赖）
   ↑                                ↑
OffYet.app                      OffYetWidget（小组件扩展 .appex）
主窗口：引导 + 演示              TimelineProvider + 三尺寸视图
（不含配置，不含存储）           （配置来自 WidgetConfigurationIntent）
```

依赖方向：两个 UI target 都依赖 OffYetCore；OffYetCore 不依赖任何 UI 框架。

### 组件职责

- **OffYetCore**
  - `WorkSettings`：配置值对象（时间用「从 0 点起的分钟数」表示，如 9:00 = 540）
  - `EarningEngine.snapshot(at:settings:calendar:)`：纯函数，输入时刻与配置，输出该时刻的 `DaySnapshot`
  - `DaySnapshot`：state、倒计时秒数、今日已赚、进度 0~1、日薪总额
  - 金额/时长格式化工具
- **OffYetWidget**
  - `OffYetIntent`：配置 Intent（4 个参数）
  - `TimelineProvider`：先生成每分钟 entry 序列，交给系统
  - `OffYetWidgetView`：按 family 分支三种布局，渲染 `DaySnapshot`
- **OffYet.app**
  - 引导页：图文说明如何把小组件添加到桌面/通知中心
  - 演示卡片：`TimelineView` 每秒刷新，用演示配置展示运行效果（说明文字注明：小组件上的配置请在小组件编辑面板里设置）

## 5. 计算规则（精确）

设：`startMin` = 上班分钟数，`endMin` = 下班分钟数，`workMinutes = endMin - startMin`

- 日薪 = 月薪 ÷ 每月工作日数
- 每分钟收入 = 日薪 ÷ workMinutes
- 今日已赚（工作中）= round(日薪 × 已过分钟 / workMinutes, 2)，线性连续累积，无午休暂停
- 进度 = clamp(已过时长 / 全天时长, 0, 1)
- 到下班时刻恰好显示赚满日薪

示例（9:00–18:00、月薪 21750、21.75 天）：

- 日薪 = 1000.00，全天 540 分钟
- 09:00:00 → ¥0.00；12:00:00 → ¥333.33；18:00:00 → ¥1000.00

### 边界规则

- 上班前（工作日、当日 0:00 ≤ now < startMin）：金额 ¥0.00、进度 0
- 工作中（startMin ≤ now < endMin）：如上
- 已下班（endMin ≤ now < 24:00）：金额 = 日薪全额、进度 1
- 休息日（周六或周日，用 `Calendar.isDateInWeekend` 判定）：全天休息状态，金额 ¥0.00
- 恰好整点（如 09:00:00、18:00:00）按「已到达该时刻」处理（09:00:00 显示 ¥0.00；18:00:00 显示满额）

## 6. 状态机与显示规则（用户已确认）

| 状态 | 倒计时显示 | 金额 | 进度 |
|---|---|---|---|
| 上班前 | 「距上班 H:MM:SS」→ 到点后切换为下班倒计时 | ¥0.00 | 0 |
| 工作中 | 「距下班 H:MM:SS」 | 线性累积 | 按比例 |
| 已下班 | 「已下班 🎉」 | 日薪全额 | 100% |
| 休息日 | 「今天休息 ☕️」 | ¥0.00 | 0 |

- 用户的决策：上班前显示**距离上班倒计时**（而非下班倒计时）
- 日期切换、状态切换全部由计算引擎按本地 Calendar 判定，无持久化状态

## 7. 配置模型

WidgetConfigurationIntent 的 4 个参数（存储于每个小组件实例，由系统管理）：

| 参数 | 类型 | 默认 | 说明 |
|---|---|---|---|
| 上班时间 | Date | 09:00 | 仅使用时/分部分（面板显示为时间选择） |
| 下班时间 | Date | 18:00 | 仅使用时/分部分 |
| 月薪 | Double | 20000 | 单位：元 |
| 每月工作日数 | Double | 21.75 | 用于日薪折算 |

## 8. 刷新机制（时间线策略）

- `getTimeline` 生成从「当前时刻所在分钟」到次日 00:00 的每分钟一条 entry（工作日最多约 1440 条，实际上午 0 点至次日 0 点），每条携带该分钟的 `DaySnapshot`
- 刷新策略：`.atEnd`（次日 0:00 触发重建），全天几乎零额外刷新
- 倒计时文字在 entry 内部用 `Text(timerInterval:)` 自更新为秒级；金额与进度随 entry 每分钟切换
- 非工作时段（已下班、休息日：状态与金额恒定）可只提供少量 entry，实现时若统一每分钟生成更简单则允许统一处理
- **实现期验证点**：macOS 桌面小组件对分钟级 entry 的切换准时性。若实测肉眼可见延迟（> 1 分钟），金额/进度降级为 5 分钟粒度；倒计时不受影响（始终秒级）

## 9. UI 设计

### 小组件三尺寸

- **小**：倒计时大字（主视觉）+ 金额小字；已下班/休息日时大字替换为状态文案
- **中**：左倒计时、右金额，底部横向进度条
- **大**：中号内容上移 + 环形进度图中心放倒计时，金额在下方
- 视觉基调：简洁、数字用等宽字体（monospacedDigit）避免跳动，深浅色模式自动适配

### 容器 App 主窗口

- 上半：演示卡片（实时跳动的倒计时/金额/进度，用演示配置）
- 下半：三步引导（打开小组件库 → 搜索「下班了么」→ 拖到桌面，并在编辑面板配置参数）
- 不做设置页、不做存储

## 10. 错误处理

- 配置非法（`endMin ≤ startMin`、月薪 ≤ 0、工作日数 ≤ 0）：小组件渲染「请检查小组件配置」提示视图，不倒计时、不出 NaN
- 金额格式化：`¥` + 千分位 + 两位小数；倒计时格式 `H:MM:SS`（不足 1 小时显示 `MM:SS`）

## 11. 测试策略

**OffYetCore 单元测试（TDD，先写测试）**，覆盖：

- 状态判定：周一 08:59（上班前）、09:00（工作中，金额 0）、12:00、17:59、18:00（已下班，满额）、18:01、周六/周日全天（休息日）、周日 23:59 与周一 00:00 跨天
- 金额精度：12:00 = 日薪的 1/3（示例配置下 ¥333.33）
- 折算：默认 21.75 天；自定义工作日数；月薪为 0 的退化
- 非法配置：end ≤ start、负数输入 → 返回「配置错误」状态而非崩溃/NaN
- 格式化：千分位、两位小数、H:MM:SS / MM:SS
- 可注入非零时区 Calendar 的测试

**手动验收（无法自动化的部分）**：

- Xcode 预览检查三尺寸 × 四状态排版
- 实际添加到桌面：确认倒计时秒级跳动、金额每分钟跳、深浅色模式正常
- 省电观察：Activity Monitor 中小组件 CPU 占用可忽略

## 12. 项目结构与实施顺序概览

```
OffYet/
├── project.yml                  # XcodeGen 工程描述
├── OffYetCore/                  # 本地 Swift Package
│   ├── Package.swift
│   ├── Sources/OffYetCore/      # WorkSettings / EarningEngine / DaySnapshot / Formatting
│   └── Tests/OffYetCoreTests/
├── App/                         # 容器 App（OffYet target）
│   ├── OffYetApp.swift
│   └── ContentView.swift        # 引导 + 演示
├── Widget/                      # 小组件扩展（OffYetWidget target）
│   ├── OffYetIntent.swift
│   ├── OffYetTimelineProvider.swift
│   └── OffYetWidgetView.swift
└── docs/superpowers/specs/
```

实施顺序（详见后续计划文档）：

1. 搭建 OffYetCore + 全部单元测试（仅需 CommandLineTools，可先行）
2. 用户安装 Xcode（并行，App Store 下载）
3. 生成 Xcode 工程，接入 App + Widget target
4. 实现小组件渲染与时间线
5. 桌面实测与降级预案验证

## 13. 风险与验证点

| 风险 | 预案 |
|---|---|
| macOS 桌面小组件分钟级 entry 切换不准时 | 降级为 5 分钟粒度，倒计时不受影响 |
| XcodeGen 不可用或用户不愿安装 | 用 Xcode GUI 新建工程（架构不变） |
| 小组件不出现在小组件库（本地签名常见坑） | 将 app 放入 /Applications 并启动一次以注册 LaunchServices |
| Widget 配置面板中 Date 参数编辑体验 | 预期可接受（时间轮选择）；若差，改为小时/分钟数字参数 |
| 桌面小组件在桌面被「堆叠」收纳导致不显眼 | 属用户桌面行为，文档中提示可单独摆放 |

## 14. 未来项（非承诺）

- iPhone 版（SwiftUI 多平台 + 免费账号每周重签，或付费账号）
- App Group 共享配置 + App 内设置页
- 菜单栏实时显示（金额秒级跳动）
- 中国节假日 / 调休日历、隐私模式、周/月累计、发薪日倒计时、菜单栏等趣味数据
