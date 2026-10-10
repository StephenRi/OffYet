import Testing
@testable import OffYetCore

struct SettingsValidationTests {
    // web engine.test.js：默认配置含发薪日 20 号、退休日期 2050-01-01
    @Test func standardDefaults() {
        let s = WorkSettings.standard
        #expect(s.startMin == 540)
        #expect(s.endMin == 1080)
        #expect(s.monthlySalary == 20000)
        #expect(s.workDaysPerMonth == 21.75)
        #expect(s.payDay == 20)
        #expect(s.retirementDate == "2050-01-01")
        #expect(s.isValid)
    }

    @Test func sentinelIsZero() {
        #expect(WorkSettings.payDayLastWorkday == 0)
    }

    @Test func endNotAfterStartIsInvalid() {
        var s = WorkSettings.standard
        s.startMin = 1080; s.endMin = 540
        #expect(!s.isValid)
        s.endMin = 540
        #expect(!s.isValid)   // end == start 同样非法
    }

    @Test func salaryAndDaysMustBePositive() {
        var s = WorkSettings.standard
        s.monthlySalary = 0
        #expect(!s.isValid)
        s.monthlySalary = -100
        #expect(!s.isValid)
        s.monthlySalary = 20000
        s.workDaysPerMonth = 0
        #expect(!s.isValid)
        s.workDaysPerMonth = -1
        #expect(!s.isValid)
        s.workDaysPerMonth = 21.75
        #expect(s.isValid)
    }

    @Test func nanIsInvalid() {
        var s = WorkSettings.standard
        s.monthlySalary = Double.nan
        #expect(!s.isValid)
    }
}
