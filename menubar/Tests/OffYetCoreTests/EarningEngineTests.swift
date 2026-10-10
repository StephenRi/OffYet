import Testing
import Foundation
@testable import OffYetCore

struct EarningEngineTests {
    // 设计文档 §5 示例配置：日薪 1000.00，全天 540 分钟
    private let example = WorkSettings(startMin: 540, endMin: 1080,
                                       monthlySalary: 21750, workDaysPerMonth: 21.75)

    // 2026-10-05 为周一；本地时间构造，与机器时区无关（同 web 测试约定）
    private func at(_ day: Int, _ h: Int = 0, _ m: Int = 0, _ s: Int = 0) -> Date {
        Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: day,
                                                   hour: h, minute: m, second: s))!
    }

    @Test func weekdayAssumptions() {
        // Swift weekday：1=周日 … 2=周一 … 7=周六
        #expect(Calendar.current.component(.weekday, from: at(5)) == 2)
        #expect(Calendar.current.component(.weekday, from: at(10)) == 7)
        #expect(Calendar.current.component(.weekday, from: at(11)) == 1)
    }

    @Test func monday0859BeforeWork() {
        let snap = EarningEngine.snapshot(at: at(5, 8, 59), settings: example)
        #expect(snap.state == .beforeWork)
        #expect(snap.earned == 0)
        #expect(snap.progress == 0)
        #expect(snap.remainingSeconds == 60)
        #expect(snap.dailySalary == 1000)
    }

    @Test func monday085959OneSecondLeft() {
        let snap = EarningEngine.snapshot(at: at(5, 8, 59, 59), settings: example)
        #expect(snap.state == .beforeWork)
        #expect(snap.remainingSeconds == 1)
    }

    @Test func monday0900WorkStartsAtZero() {
        let snap = EarningEngine.snapshot(at: at(5, 9), settings: example)
        #expect(snap.state == .working)
        #expect(snap.earned == 0)
        #expect(snap.progress == 0)
        #expect(snap.remainingSeconds == 9 * 3600)
    }

    @Test func monday1200OneThird() {
        let snap = EarningEngine.snapshot(at: at(5, 12), settings: example)
        #expect(snap.state == .working)
        #expect(snap.earned == 333.33)
        #expect(snap.progress == 180.0 / 540.0)
        #expect(snap.remainingSeconds == 6 * 3600)
    }

    @Test func secondLevelAccumulation() {
        let snap = EarningEngine.snapshot(at: at(5, 12, 0, 30), settings: example)
        #expect(snap.earned == 334.26)
        #expect(snap.progress == 10830.0 / 32400.0)
    }

    @Test func secondLevelAtWorkStart() {
        let snap = EarningEngine.snapshot(at: at(5, 9, 0, 30), settings: example)
        #expect(snap.earned == 0.93)
        #expect(snap.progress == 30.0 / 32400.0)
    }

    @Test func millisecondsCount() {
        let d = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 5,
                                                           hour: 9, minute: 0, second: 0,
                                                           nanosecond: 500_000_000))!
        let snap = EarningEngine.snapshot(at: d, settings: example)
        #expect(snap.earned == 0.02)
        #expect(snap.progress == 0.5 / 32400.0)
    }

    @Test func monday1759LastMinute() {
        let snap = EarningEngine.snapshot(at: at(5, 17, 59), settings: example)
        #expect(snap.state == .working)
        #expect(snap.earned == 998.15)
        #expect(snap.remainingSeconds == 60)
    }

    @Test func monday1800FullSalary() {
        let snap = EarningEngine.snapshot(at: at(5, 18), settings: example)
        #expect(snap.state == .afterWork)
        #expect(snap.earned == 1000)
        #expect(snap.progress == 1)
        #expect(snap.remainingSeconds == nil)
    }

    @Test func monday1801StaysFull() {
        let snap = EarningEngine.snapshot(at: at(5, 18, 1), settings: example)
        #expect(snap.state == .afterWork)
        #expect(snap.earned == 1000)
    }

    @Test func saturdayAllDayRest() {
        for h in [0, 10, 23] {
            let snap = EarningEngine.snapshot(at: at(10, h), settings: example)
            #expect(snap.state == .restDay)
            #expect(snap.earned == 0)
            #expect(snap.progress == 0)
            #expect(snap.remainingSeconds == nil)
        }
    }

    @Test func sunday2359ThenMonday0000() {
        let sun = EarningEngine.snapshot(at: at(11, 23, 59), settings: example)
        #expect(sun.state == .restDay)
        #expect(sun.earned == 0)

        let mon = EarningEngine.snapshot(at: at(12, 0), settings: example)
        #expect(mon.state == .beforeWork)
        #expect(mon.earned == 0)
        #expect(mon.remainingSeconds == 9 * 3600)
    }

    @Test func dailySalaryExactDivision() {
        let snap = EarningEngine.snapshot(at: at(5, 18),
            settings: WorkSettings(startMin: 540, endMin: 1080,
                                   monthlySalary: 21750, workDaysPerMonth: 21.75))
        #expect(snap.dailySalary == 1000)
        #expect(snap.earned == 1000)
    }

    @Test func customWorkDays() {
        let snap = EarningEngine.snapshot(at: at(5, 18),
            settings: WorkSettings(startMin: 540, endMin: 1080,
                                   monthlySalary: 20000, workDaysPerMonth: 20))
        #expect(snap.dailySalary == 1000)
        #expect(snap.earned == 1000)
    }

    @Test func roundedDailySalary() {
        let snap = EarningEngine.snapshot(at: at(5, 18),
            settings: WorkSettings(startMin: 540, endMin: 1080,
                                   monthlySalary: 20000, workDaysPerMonth: 21.75))
        #expect(snap.earned == 919.54)
    }

    @Test func invalidEndConfig() {
        for s in [WorkSettings(startMin: 1080, endMin: 540),
                  WorkSettings(startMin: 540, endMin: 540)] {
            let snap = EarningEngine.snapshot(at: at(5, 12), settings: s)
            #expect(snap.state == .invalid)
            #expect(snap.earned == 0)
            #expect(snap.progress == 0)
            #expect(snap.remainingSeconds == nil)
            #expect(snap.dailySalary.isFinite)
        }
    }

    @Test func invalidSalary() {
        for salary in [0.0, -100.0] {
            var s = WorkSettings.standard
            s.monthlySalary = salary
            let snap = EarningEngine.snapshot(at: at(5, 12), settings: s)
            #expect(snap.state == .invalid)
            #expect(snap.earned == 0)
        }
    }

    @Test func invalidWorkDays() {
        for days in [0.0, -1.0] {
            var s = WorkSettings.standard
            s.workDaysPerMonth = days
            let snap = EarningEngine.snapshot(at: at(5, 12), settings: s)
            #expect(snap.state == .invalid)
        }
    }

    @Test func nanSalaryInvalidNotNaNOut() {
        var s = WorkSettings.standard
        s.monthlySalary = Double.nan
        let snap = EarningEngine.snapshot(at: at(5, 12), settings: s)
        #expect(snap.state == .invalid)
        #expect(snap.earned == 0)
        #expect(!snap.earned.isNaN)
        #expect(!snap.progress.isNaN)
    }
}
