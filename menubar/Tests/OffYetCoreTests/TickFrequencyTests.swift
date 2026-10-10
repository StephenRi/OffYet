import Testing
import Foundation
@testable import OffYetCore

struct TickFrequencyTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.offyet.tick.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func defaultTicksPerSecondIsOne() {
        #expect(StoredState().ticksPerSecond == 1)
    }

    @Test func tickIntervalForCommonFrequencies() {
        var s = StoredState()
        s.ticksPerSecond = 1
        #expect(s.tickInterval == 1.0)
        s.ticksPerSecond = 5
        #expect(s.tickInterval == 0.2)
        s.ticksPerSecond = 10
        #expect(s.tickInterval == 0.1)
    }

    @Test func tickIntervalClampsOutOfRangeValues() {
        var s = StoredState()
        s.ticksPerSecond = 0
        #expect(s.tickInterval == 1.0)
        s.ticksPerSecond = -5
        #expect(s.tickInterval == 1.0)
        s.ticksPerSecond = 999
        #expect(s.tickInterval == 0.1)
    }

    /// 旧版本存档没有 ticksPerSecond 键：解码后该字段回落 1，且其余设置必须完好（不得整体重置）
    @Test func legacyArchiveWithoutTickKeyDefaultsToOne() throws {
        let defaults = makeDefaults()
        let store = StateStore(defaults: defaults)
        var s = StoredState()
        s.settings.monthlySalary = 51000
        s.menuBarMode = .money
        s.simEnabled = true
        s.simOffset = -108_635
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as? [String: Any])
        json.removeValue(forKey: "ticksPerSecond")
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "offyet.settings.v1")
        let loaded = store.load()
        #expect(loaded.ticksPerSecond == 1)
        #expect(loaded.settings.monthlySalary == 51000)
        #expect(loaded.menuBarMode == .money)
        #expect(loaded.simEnabled)
        #expect(loaded.simOffset == -108_635)
    }

    @Test func roundtripPreservesTickFrequency() {
        let defaults = makeDefaults()
        let store = StateStore(defaults: defaults)
        var s = StoredState()
        s.ticksPerSecond = 5
        store.save(s)
        #expect(store.load().ticksPerSecond == 5)
    }
}
