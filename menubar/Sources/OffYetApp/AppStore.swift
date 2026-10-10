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
