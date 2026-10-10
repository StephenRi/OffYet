import Testing
import Foundation
@testable import OffYetCore

struct SimClockTests {
    /// 固定基准时刻，避免当前时间与时区干扰
    private let base = Date(timeIntervalSinceReferenceDate: 800_000_000)

    @Test func effectiveDateDisabledIgnoresOffset() {
        var s = StoredState()
        s.simEnabled = false
        s.simOffset = 7200
        #expect(s.effectiveDate(fallback: base) == base)
    }

    @Test func effectiveDateEnabledWithoutOffsetUsesRealTime() {
        var s = StoredState()
        s.simEnabled = true
        s.simOffset = nil
        #expect(s.effectiveDate(fallback: base) == base)
    }

    @Test func effectiveDateEnabledShiftsByOffset() {
        var s = StoredState()
        s.simEnabled = true
        s.simOffset = 7200
        #expect(s.effectiveDate(fallback: base) == base.addingTimeInterval(7200))
    }

    @Test func effectiveDateHandlesNegativeOffset() {
        var s = StoredState()
        s.simEnabled = true
        s.simOffset = -3600
        #expect(s.effectiveDate(fallback: base) == base.addingTimeInterval(-3600))
    }

    @Test func effectiveDateFlowsOneToOneWithRealTime() {
        var s = StoredState()
        s.simEnabled = true
        s.simOffset = 3600
        let first = s.effectiveDate(fallback: base)
        let second = s.effectiveDate(fallback: base.addingTimeInterval(5))
        #expect(second.timeIntervalSince(first) == 5)
    }

    @Test func committedOffsetDisabledIsNil() {
        let offset = StoredState.committedSimOffset(
            enabled: false, pickedAt: base, pickedAtLoad: base,
            existing: 999, now: base.addingTimeInterval(60))
        #expect(offset == nil)
    }

    @Test func committedOffsetUntouchedKeepsExisting() {
        let offset = StoredState.committedSimOffset(
            enabled: true, pickedAt: base, pickedAtLoad: base,
            existing: 999, now: base.addingTimeInterval(60))
        #expect(offset == 999)
    }

    @Test func committedOffsetUntouchedWithoutExistingUsesPickedMoment() {
        let offset = StoredState.committedSimOffset(
            enabled: true, pickedAt: base, pickedAtLoad: base,
            existing: nil, now: base.addingTimeInterval(60))
        #expect(offset == -60)
    }

    @Test func committedOffsetTouchedRecomputes() {
        let picked = base.addingTimeInterval(86_400)
        let offset = StoredState.committedSimOffset(
            enabled: true, pickedAt: picked, pickedAtLoad: base,
            existing: 999, now: base.addingTimeInterval(60))
        let expected: TimeInterval = 86_400 - 60
        #expect(offset == expected)
    }
}
