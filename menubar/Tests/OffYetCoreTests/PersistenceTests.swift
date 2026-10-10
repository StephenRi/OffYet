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
        s.simTime = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))
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
}
