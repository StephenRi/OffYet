import Foundation

public enum MenuBarMode: String, Codable, CaseIterable {
    case money
    case countdown
    case icon
}

public struct StoredState: Codable, Equatable {
    public var settings: WorkSettings = .standard
    public var menuBarMode: MenuBarMode = .icon
    public var simEnabled: Bool = false
    /// 模拟钟相对真实时钟的偏移（选定时刻 − 保存时刻）。旧存档的 simTime 键无此字段，解码时被忽略
    public var simOffset: TimeInterval?
    public var launchAtLogin: Bool = false

    public init() {}

    /// 生效时刻：模拟钟开启且已设定偏移时，真实时刻叠加偏移（按真实速率 1:1 流动）
    public func effectiveDate(fallback: Date) -> Date {
        guard simEnabled, let offset = simOffset else { return fallback }
        return fallback.addingTimeInterval(offset)
    }

    /// 保存设置时把选择器「选定时刻」换算为模拟钟偏移；选择器未被改动且已有偏移时原样保留（避免模拟钟回跳）
    public static func committedSimOffset(
        enabled: Bool,
        pickedAt: Date,
        pickedAtLoad: Date,
        existing: TimeInterval?,
        now: Date
    ) -> TimeInterval? {
        guard enabled else { return nil }
        if pickedAt == pickedAtLoad, let existing { return existing }
        return pickedAt.timeIntervalSince(now)
    }
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
