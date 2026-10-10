import Foundation

public enum EarningEngine {
    /// 与 web/engine.js 的 round2 完全一致：Math.round((x + EPSILON) * 100) / 100
    static func round2(_ x: Double) -> Double {
        ((x + Double.ulpOfOne) * 100).rounded() / 100
    }

    public static func snapshot(at date: Date, settings: WorkSettings,
                                calendar: Calendar = .current) -> DaySnapshot {
        guard settings.isValid else {
            return DaySnapshot(state: .invalid, remainingSeconds: nil,
                               earned: 0, progress: 0, dailySalary: 0)
        }

        let workSeconds = Double((settings.endMin - settings.startMin) * 60)
        let dailySalary = settings.monthlySalary / settings.workDaysPerMonth

        let weekday = calendar.component(.weekday, from: date)
        if weekday == 1 || weekday == 7 {
            return DaySnapshot(state: .restDay, remainingSeconds: nil,
                               earned: 0, progress: 0, dailySalary: dailySalary)
        }

        let c = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
        let nowSec = Double(c.hour!) * 3600 + Double(c.minute!) * 60
            + Double(c.second!) + Double(c.nanosecond!) / 1_000_000_000
        let startSec = Double(settings.startMin * 60)
        let endSec = Double(settings.endMin * 60)

        if nowSec < startSec {
            return DaySnapshot(state: .beforeWork,
                               remainingSeconds: Int(ceil(startSec - nowSec)),
                               earned: 0, progress: 0, dailySalary: dailySalary)
        }
        if nowSec < endSec {
            let workedSec = nowSec - startSec
            return DaySnapshot(state: .working,
                               remainingSeconds: Int(ceil(endSec - nowSec)),
                               earned: round2(dailySalary * workedSec / workSeconds),
                               progress: workedSec / workSeconds,
                               dailySalary: dailySalary)
        }
        return DaySnapshot(state: .afterWork, remainingSeconds: nil,
                           earned: round2(dailySalary), progress: 1, dailySalary: dailySalary)
    }
}
