import Testing
import Foundation
@testable import OffYetCore

struct MilestoneTests {
    private func at(_ day: Int, _ h: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day, hour: h))!
    }
    private func atDate(_ y: Int, _ mo: Int, _ d: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: y, month: mo, day: d, hour: 12))!
    }

    /* ---------- 距离周末 ---------- */

    @Test func weekendMondayAndThursday() {
        #expect(Milestones.daysUntilWeekend(at: at(5, 12)) == 5)
        #expect(Milestones.daysUntilWeekend(at: at(8, 12)) == 2)
    }

    @Test func weekendFridaySaturdaySunday() {
        #expect(Milestones.daysUntilWeekend(at: at(9, 12)) == 1)
        #expect(Milestones.daysUntilWeekend(at: at(10, 12)) == 0)
        #expect(Milestones.daysUntilWeekend(at: at(11, 12)) == 0)
    }

    /* ---------- 距离发薪：固定日 ---------- */

    @Test func paydayOct8To20() {
        #expect(Milestones.daysUntilPayday(at: at(8, 12), payDay: 20) == 12)
    }

    @Test func paydayToday() {
        #expect(Milestones.daysUntilPayday(at: at(20, 12), payDay: 20) == 0)
    }

    @Test func paydayRollsToNextMonth() {
        #expect(Milestones.daysUntilPayday(at: at(25, 12), payDay: 20) == 26)
    }

    @Test func payday31ClampedToMonthEnd() {
        #expect(Milestones.daysUntilPayday(at: atDate(2026, 4, 1), payDay: 31) == 29)
        #expect(Milestones.daysUntilPayday(at: atDate(2027, 2, 1), payDay: 31) == 27)
        #expect(Milestones.daysUntilPayday(at: atDate(2028, 2, 1), payDay: 31) == 28)
    }

    @Test func paydayOnClampedDay() {
        #expect(Milestones.daysUntilPayday(at: atDate(2026, 4, 30), payDay: 31) == 0)
        #expect(Milestones.daysUntilPayday(at: atDate(2027, 2, 28), payDay: 31) == 0)
    }

    @Test func paydayInvalid() {
        // Int 类型天然排除 1.5/NaN/字符串；-1 与 32 必须返回 nil
        for pd in [-1, 32] {
            #expect(Milestones.daysUntilPayday(at: at(8, 12), payDay: pd) == nil)
        }
    }

    /* ---------- 距离发薪：末工作日（哨兵 0） ---------- */

    @Test func lastWorkdayWeekdayAssumptions() {
        // 2026-10-31 周六、2027-02-28 周日、2028-12-31 周日
        #expect(Calendar.current.component(.weekday, from: atDate(2026, 10, 31)) == 7)
        #expect(Calendar.current.component(.weekday, from: atDate(2027, 2, 28)) == 1)
        #expect(Calendar.current.component(.weekday, from: atDate(2028, 12, 31)) == 1)
    }

    @Test func lastWorkdaySaturdayRollback() {
        // 2026-10 月末逢周六 → 回退到 30 日（周五）；10-08 → 22 天
        #expect(Milestones.daysUntilPayday(at: at(8, 12), payDay: WorkSettings.payDayLastWorkday) == 22)
    }

    @Test func lastWorkdayToday() {
        #expect(Milestones.daysUntilPayday(at: atDate(2026, 10, 30),
                                           payDay: WorkSettings.payDayLastWorkday) == 0)
    }

    @Test func lastWorkdayJustPassedRollsOver() {
        // 10-31 周六刚过末工作日 → 顺延 11-30 周一，30 天
        #expect(Milestones.daysUntilPayday(at: atDate(2026, 10, 31),
                                           payDay: WorkSettings.payDayLastWorkday) == 30)
    }

    @Test func lastWorkdaySundayRollback() {
        // 2027-02-28 周日 → 02-26 周五；02-01 → 25 天
        #expect(Milestones.daysUntilPayday(at: atDate(2027, 2, 1),
                                           payDay: WorkSettings.payDayLastWorkday) == 25)
    }

    @Test func lastWorkdayLeapFeb29() {
        // 2028-02-29 本身是工作日 → 按 29 日；02-01 → 28 天
        #expect(Milestones.daysUntilPayday(at: atDate(2028, 2, 1),
                                           payDay: WorkSettings.payDayLastWorkday) == 28)
    }

    @Test func lastWorkdayCrossYear() {
        // 2028-12-31 周日 → 2029-01-31 周三，31 天
        #expect(Milestones.daysUntilPayday(at: atDate(2028, 12, 31),
                                           payDay: WorkSettings.payDayLastWorkday) == 31)
    }

    /* ---------- 距离退休 ---------- */

    @Test func retirement8486Days() {
        #expect(Milestones.daysUntilRetirement(at: at(8, 12), retirementDate: "2050-01-01") == 8486)
    }

    @Test func retirementClampedToZero() {
        #expect(Milestones.daysUntilRetirement(at: at(8, 12), retirementDate: "2026-10-08") == 0)
        #expect(Milestones.daysUntilRetirement(at: at(8, 12), retirementDate: "2026-10-01") == 0)
    }

    @Test func retirementInvalidDates() {
        for d in ["", "2050-1-1", "2050/01/01", "abc", "2050-13-01", "2050-02-30"] {
            #expect(Milestones.daysUntilRetirement(at: at(8, 12), retirementDate: d) == nil)
        }
    }

    /* ---------- 时区注入（web 做不到、Swift 端补充） ---------- */

    @Test func injectedNonLocalTimezone() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(secondsFromGMT: 0)!
        let instant = utc.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 15))!

        var tokyo = Calendar(identifier: .gregorian)
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 东京 2026-10-12 00:00 周一 → beforeWork，距上班 9h
        let tk = EarningEngine.snapshot(at: instant, settings: .standard, calendar: tokyo)
        #expect(tk.state == .beforeWork)
        #expect(tk.remainingSeconds == 9 * 3600)

        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        // 纽约 2026-10-11 11:00 周日（仍在 EDT）→ restDay
        let us = EarningEngine.snapshot(at: instant, settings: .standard, calendar: ny)
        #expect(us.state == .restDay)
    }
}
