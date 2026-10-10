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
