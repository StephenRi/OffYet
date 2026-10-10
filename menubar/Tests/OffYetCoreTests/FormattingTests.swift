import Testing
import Foundation
@testable import OffYetCore

struct FormattingTests {
    @Test func money() {
        #expect(Formatting.money(1000) == "¥1,000.00")
        #expect(Formatting.money(333.33) == "¥333.33")
        #expect(Formatting.money(0) == "¥0.00")
        #expect(Formatting.money(0.5) == "¥0.50")
        #expect(Formatting.money(919.54) == "¥919.54")
        #expect(Formatting.money(1234567.891) == "¥1,234,567.89")
    }

    @Test func countdownFormat() {
        #expect(Formatting.formatCountdown(9 * 3600) == "9时 0分")
        #expect(Formatting.formatCountdown(6 * 3600) == "6时 0分")
        #expect(Formatting.formatCountdown(3 * 3600 + 25 * 60 + 19) == "3时 25分")
        #expect(Formatting.formatCountdown(3600) == "1时 0分")
        #expect(Formatting.formatCountdown(3599) == "59分")
        #expect(Formatting.formatCountdown(61) == "1分")
        #expect(Formatting.formatCountdown(45) == "1分")
        #expect(Formatting.formatCountdown(5) == "1分")
        #expect(Formatting.formatCountdown(0) == "0分")
    }

    @Test func countdownPartsSplit() {
        #expect(Formatting.countdownParts(3 * 3600 + 25 * 60 + 19) ==
                [Formatting.CountdownPart(value: 3, unit: "时"),
                 Formatting.CountdownPart(value: 25, unit: "分")])
        #expect(Formatting.countdownParts(25 * 60 + 19) ==
                [Formatting.CountdownPart(value: 25, unit: "分")])
        #expect(Formatting.countdownParts(45) == [Formatting.CountdownPart(value: 1, unit: "分")])
        #expect(Formatting.countdownParts(5) == [Formatting.CountdownPart(value: 1, unit: "分")])
        #expect(Formatting.countdownParts(0) == [Formatting.CountdownPart(value: 0, unit: "分")])
        #expect(Formatting.countdownParts(3600) ==
                [Formatting.CountdownPart(value: 1, unit: "时"),
                 Formatting.CountdownPart(value: 0, unit: "分")])
    }

    @Test func headDateAndHHMM() {
        let d = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 9, hour: 12))!
        // 2026-10-09 周五
        #expect(Formatting.headDate(d) == "10月9日 · 周五")
        #expect(Formatting.hhmm(540) == "09:00")
        #expect(Formatting.hhmm(1080) == "18:00")
        #expect(Formatting.hhmm(0) == "00:00")
    }
}
