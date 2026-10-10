import Foundation
import ServiceManagement
import Combine
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
    @Published private(set) var now: Date = Date()

    private let store: StateStore
    private let login = LoginItemService()
    private var ticker: AnyCancellable?

    init(store: StateStore = StateStore()) {
        self.store = store
        self.state = store.load()
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                MainActor.assumeIsolated { self?.now = date }
            }
    }

    var version: String { OffYetCore.version }

    /// 所有「当前时刻」的唯一入口：模拟钟开启时以真实速率 1:1 流动（金额/倒计时持续变化）
    func currentDate(fallback: Date) -> Date {
        state.effectiveDate(fallback: fallback)
    }

    func apply(_ newState: StoredState) {
        state = newState
        store.save(newState)
        login.set(newState.launchAtLogin)
    }
}
