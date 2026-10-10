import Foundation

public enum OffYetState: Equatable {
    case beforeWork
    case working
    case afterWork
    case restDay
    case invalid
}

public struct DaySnapshot: Equatable {
    public let state: OffYetState
    public let remainingSeconds: Int?
    public let earned: Double
    public let progress: Double
    public let dailySalary: Double

    public init(state: OffYetState, remainingSeconds: Int?,
                earned: Double, progress: Double, dailySalary: Double) {
        self.state = state
        self.remainingSeconds = remainingSeconds
        self.earned = earned
        self.progress = progress
        self.dailySalary = dailySalary
    }
}

public let version = "0.1.0"
