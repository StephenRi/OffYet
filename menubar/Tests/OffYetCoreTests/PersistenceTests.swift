import Testing
import Foundation
@testable import OffYetCore

struct PersistenceTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.offyet.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    @Test func missingKeyFallsBackToDefaults() {
        let store = StateStore(defaults: makeDefaults())
        #expect(store.load() == StoredState())
    }

    @Test func roundtrip() {
        let defaults = makeDefaults()
        let store = StateStore(defaults: defaults)
        var s = StoredState()
        s.settings.monthlySalary = 30000
        s.settings.payDay = WorkSettings.payDayLastWorkday
        s.menuBarMode = .countdown
        s.simEnabled = true
        s.simOffset = -3600
        s.launchAtLogin = true
        store.save(s)
        #expect(store.load() == s)
    }

    @Test func corruptDataFallsBackToDefaults() {
        let defaults = makeDefaults()
        defaults.set(Data("not json".utf8), forKey: "offyet.settings.v1")
        let store = StateStore(defaults: defaults)
        #expect(store.load() == StoredState())
    }

    @Test func menuBarModeRawValues() {
        #expect(MenuBarMode.money.rawValue == "money")
        #expect(MenuBarMode.countdown.rawValue == "countdown")
        #expect(MenuBarMode.icon.rawValue == "icon")
    }

    @Test func defaultMenuBarModeIsIcon() {
        #expect(StoredState().menuBarMode == .icon)
    }

    /// 旧版本存档含 simTime 键：解码时必须忽略未知键、其余设置不丢
    @Test func legacySimTimeKeyIsIgnoredOnDecode() throws {
        let defaults = makeDefaults()
        let store = StateStore(defaults: defaults)
        var s = StoredState()
        s.settings.monthlySalary = 30000
        s.simEnabled = true
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(s)) as? [String: Any])
        json["simTime"] = 790_000_000
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "offyet.settings.v1")
        let loaded = store.load()
        #expect(loaded == s)
        #expect(loaded.simOffset == nil)
    }
}
