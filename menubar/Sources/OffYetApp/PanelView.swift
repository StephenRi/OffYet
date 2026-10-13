import AppKit
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
        // 不用 TimelineView：popover 内容视图会被 MenuBarExtra 保留，隐藏后仍 4Hz 重算耗 CPU；倒计时分、金额 1s 粒度足够
        mainContent(now: store.currentDate(fallback: store.now))
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
            sloganFooter(p: p)
        }
        .padding(14)
        .background(p.bgGradient.ignoresSafeArea())
    }

    @Environment(\.colorScheme) private var colorScheme

    // MARK: 顶栏

    private func header(now: Date, p: Palette) -> some View {
        HStack(spacing: 10) {
            logoView
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

    // 面板是普通窗口（不受菜单栏状态项快照约束），可直接渲染彩色位图；资源由 build-app.sh 拷入 Contents/Resources
    private static let logoImage: NSImage? = {
        guard let url = Bundle.main.url(forResource: "OffYetLogo", withExtension: "png") else { return nil }
        return NSImage(contentsOf: url)
    }()

    private var logoView: some View {
        Group {
            if let logo = Self.logoImage {
                Image(nsImage: logo)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 28, height: 28)
            } else {
                MenuBarGlyph()
            }
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
            MilestoneCard(label: "距离周末", valueText: "\(weekend)", sub: weekendSub,
                          icon: "calendar", tint: p.calendarIcon, tintBg: p.calendarBg, palette: p)
            MilestoneCard(label: "距离发薪", valueText: paydayDays.map { "\($0)" } ?? "--", sub: paydaySub,
                          icon: "banknote", tint: p.walletIcon, tintBg: p.walletBg, palette: p)
            MilestoneCard(label: "距离退休", valueText: retireText, sub: "正在靠近自由",
                          icon: "hourglass", tint: p.hourglassIcon, tintBg: p.hourglassBg, palette: p)
        }
    }

    // MARK: 脚注 slogan

    private func sloganFooter(p: Palette) -> some View {
        Text("打工人，吾日三省吾身：下班未至乎？周末未到乎？退休无期乎？")
            .font(.system(size: 10))
            .foregroundColor(p.text2)
            .multilineTextAlignment(.center)
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
