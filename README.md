# OffYet · 下班了么

macOS 菜单栏常驻应用：实时显示「今日已赚」和「下班倒计时」，一秒一秒陪你熬到下班。

[![Release](https://img.shields.io/github/release/StephenRi/OffYet.svg)](https://github.com/StephenRi/OffYet/releases)

<img src="assets/screenshots/panel.png" width="300" align="right" alt="OffYet 下拉面板">

## 功能

- **菜单栏三种显示模式**（点击切换）：实时金额（¥xx.xx 按设定频率跳动）/ 下班倒计时 / 品牌 logo 图标
- **下拉面板**：大号倒计时、渐变进度条（含上班/下班时间端点）、今日已赚金额与「持续增长中」徽章
- **三张里程碑卡**：距周末 / 距发薪 / 距退休
- **完整设置**：上班/下班时间、月薪、每月工作日数、发薪日（含「每月最后一个工作日」）、退休日期、菜单栏模式、刷新频率（1–10 次/秒）、开机自启、模拟时间

计算口径：日薪 = 月薪 ÷ 每月工作日数，金额按秒级实时累计；周末为休息日（¥0.00，☕️）。

## 安装

1. 从 [Releases](https://github.com/StephenRi/OffYet/releases) 下载最新 `OffYet-vX.Y.Z.dmg` 并打开
2. 将 OffYet 拖入 Applications 文件夹
3. 首次打开若被 Gatekeeper 拦截（应用为 ad-hoc 签名，未做 Developer ID 公证）：**系统设置 → 隐私与安全性 → 仍要打开**；或在终端执行

   ```bash
   xattr -dr com.apple.quarantine /Applications/OffYet.app
   ```

要求 macOS 13+，Apple Silicon / Intel 均可。

## 开发

Swift Package Manager 双 target 架构：

```
menubar/
├── Sources/OffYetCore/   # 纯计算引擎（状态机、金额、里程碑、格式化），零 UI 依赖
├── Sources/OffYetApp/    # SwiftUI MenuBarExtra：菜单栏、下拉面板、设置
└── Tests/OffYetCoreTests/ # Swift Testing 单元测试
```

```bash
# 运行测试
swift test --package-path menubar

# 构建 .app（ad-hoc 签名）
bash menubar/scripts/build-app.sh

# 构建 + 打包 DMG
bash menubar/scripts/build-app.sh --dmg

# 安装到 /Applications 并启动
bash menubar/scripts/build-app.sh --install

# 发布：要求本地 main 与 origin/main 同步，创建 release 并上传 DMG
bash menubar/scripts/build-app.sh --release
```

发版流程：改 `menubar/Sources/OffYetCore/OffYetCore.swift` 中的 `version` → 提交并推送 → `bash menubar/scripts/build-app.sh --release`。

## Roadmap

- Mac 桌面小组件（复用 OffYetCore）
- 临近下班通知提醒
- 周/月累计收入
