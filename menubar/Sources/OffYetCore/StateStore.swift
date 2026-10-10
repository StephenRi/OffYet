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
    /// 菜单栏金额每秒跳动次数，1 次 ≈ 1% CPU，频率越高占用越高
    public var ticksPerSecond: Int = 1

    public init() {}

    /// 逐字段容错解码：旧存档缺新键时回落该字段默认值，而不是整体重置。
    /// Swift 合成的解码器不会用属性默认值补缺失键（非 optional 缺失即 keyNotFound），
    /// 一旦抛出，StateStore.load() 会把用户全部设置重置回默认。
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        settings = try c.decodeIfPresent(WorkSettings.self, forKey: .settings) ?? .standard
        menuBarMode = try c.decodeIfPresent(MenuBarMode.self, forKey: .menuBarMode) ?? .icon
        simEnabled = try c.decodeIfPresent(Bool.self, forKey: .simEnabled) ?? false
        simOffset = try c.decodeIfPresent(TimeInterval.self, forKey: .simOffset)
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? false
        ticksPerSecond = try c.decodeIfPresent(Int.self, forKey: .ticksPerSecond) ?? 1
    }

    public static let ticksPerSecondRange = 1...10

    /// ticker 周期；越界值钳到 1–10（含旧存档被外部改坏的值）
    public var tickInterval: TimeInterval {
        let clamped = min(max(ticksPerSecond, Self.ticksPerSecondRange.lowerBound),
                          Self.ticksPerSecondRange.upperBound)
        return 1.0 / Double(clamped)
    }

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
