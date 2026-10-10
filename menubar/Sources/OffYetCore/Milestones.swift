import Foundation

public enum Milestones {
    public static func daysUntilWeekend(at date: Date, calendar: Calendar = .current) -> Int {
        let w = calendar.component(.weekday, from: date)
        let jsDay = w == 1 ? 0 : w - 1   // 对齐 JS getDay()：周日 0 … 周六 6
        if jsDay == 0 || jsDay == 6 { return 0 }
        return 6 - jsDay
    }

    /// 发薪日非法（非 0 哨兵且不在 1…31）→ nil
    public static func nextPayday(after date: Date, payDay: Int,
                                  calendar: Calendar = .current) -> Date? {
        if payDay != WorkSettings.payDayLastWorkday && (payDay < 1 || payDay > 31) { return nil }

        var y = calendar.component(.year, from: date)
        var m = calendar.component(.month, from: date)
        let d = calendar.component(.day, from: date)
        var target = paydayTargetDay(year: y, month: m, payDay: payDay, calendar: calendar)
        if d > target {
            m += 1
            if m > 12 { m = 1; y += 1 }
            target = paydayTargetDay(year: y, month: m, payDay: payDay, calendar: calendar)
        }
        return calendar.date(from: DateComponents(year: y, month: m, day: target))
    }

    public static func daysUntilPayday(at date: Date, payDay: Int,
                                       calendar: Calendar = .current) -> Int? {
        guard let target = nextPayday(after: date, payDay: payDay, calendar: calendar) else { return nil }
        return daysBetween(date, target, calendar: calendar)
    }

    public static func daysUntilRetirement(at date: Date, retirementDate: String,
                                           calendar: Calendar = .current) -> Int? {
        guard let r = parseDateOnly(retirementDate, calendar: calendar) else { return nil }
        return max(0, daysBetween(date, r, calendar: calendar))
    }

    // MARK: - 内部

    /// 闰月钳制 / 末工作日回退（末工作日只跳过周六日，与 web 一致）
    static func paydayTargetDay(year y: Int, month m: Int, payDay: Int, calendar: Calendar) -> Int {
        if payDay == WorkSettings.payDayLastWorkday { return lastWorkdayDay(y, m, calendar) }
        return min(payDay, daysInMonth(year: y, month: m, calendar: calendar))
    }

    static func daysInMonth(year y: Int, month m: Int, calendar: Calendar) -> Int {
        let first = calendar.date(from: DateComponents(year: y, month: m, day: 1))!
        return calendar.range(of: .day, in: .month, for: first)!.count
    }

    static func lastWorkdayDay(_ y: Int, _ m: Int, _ calendar: Calendar) -> Int {
        var d = daysInMonth(year: y, month: m, calendar: calendar)
        while true {
            let date = calendar.date(from: DateComponents(year: y, month: m, day: d))!
            let w = calendar.component(.weekday, from: date)
            if w != 1 && w != 7 { return d }
            d -= 1
        }
    }

    /// 年月日分量取本地零点再求天数差，避开夏令时 23/25 小时日（对齐 web 的 Date.UTC 技巧）
    static func daysBetween(_ a: Date, _ b: Date, calendar: Calendar) -> Int {
        let ca = calendar.dateComponents([.year, .month, .day], from: a)
        let cb = calendar.dateComponents([.year, .month, .day], from: b)
        let da = calendar.date(from: ca)!
        let db = calendar.date(from: cb)!
        return calendar.dateComponents([.day], from: da, to: db).day!
    }

    /// 严格 YYYY-MM-DD：正则级格式检查 + 分量范围 + Date 回验
    static func parseDateOnly(_ str: String, calendar: Calendar) -> Date? {
        let parts = str.split(separator: "-", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ $0.allSatisfy { ("0"..."9").contains($0) } }),
              let y = Int(parts[0]), let mo = Int(parts[1]), let d = Int(parts[2]),
              (1...12).contains(mo), (1...31).contains(d),
              let dt = calendar.date(from: DateComponents(year: y, month: mo, day: d))
        else { return nil }
        let back = calendar.dateComponents([.year, .month, .day], from: dt)
        guard back.year == y, back.month == mo, back.day == d else { return nil }
        return dt
    }

    public static func parseDateOnlyPublic(_ s: String) -> Date? {
        parseDateOnly(s, calendar: .current)
    }
}
