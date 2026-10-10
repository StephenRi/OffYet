import SwiftUI
import OffYetCore

struct StatusBarLabel: View {
    @ObservedObject var store: AppStore

    var body: some View {
        // label 内不可用 TimelineView：macOS 26 状态项会陷入无限重排（100% CPU），改由 AppStore 的 1s ticker 驱动
        content(now: store.currentDate(fallback: store.now))
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        let snap = EarningEngine.snapshot(at: now, settings: store.state.settings)
        switch store.state.menuBarMode {
        case .icon:
            MenuBarGlyph()
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
