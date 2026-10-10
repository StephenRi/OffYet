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
