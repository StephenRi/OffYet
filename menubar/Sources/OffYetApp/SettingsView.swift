import SwiftUI
import OffYetCore

struct SettingsView: View {
    @ObservedObject var store: AppStore
    let onBack: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    @State private var draft = StoredState()
    @State private var startAt = Date()
    @State private var endAt = Date()
    @State private var retireAt = Date()
    @State private var salaryText = ""
    @State private var daysText = ""
    @State private var simAt = Date()
    @State private var loadedSimAt = Date()

    private var p: Palette { Palette.palette(colorScheme == .dark) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { onBack() } label: {
                    Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                }
                .buttonStyle(.plain)
                Text("设置").font(.system(size: 15, weight: .semibold))
                Spacer()
                saveButton
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field("上班时间") { DatePicker("", selection: $startAt, displayedComponents: .hourAndMinute).labelsHidden() }
                    field("下班时间") { DatePicker("", selection: $endAt, displayedComponents: .hourAndMinute).labelsHidden() }
                    field("月薪（元）") { TextField("20000", text: $salaryText).textFieldStyle(.roundedBorder) }
                    field("每月工作日数") { TextField("21.75", text: $daysText).textFieldStyle(.roundedBorder) }
                    field("发薪日") {
                        Picker("", selection: $draft.settings.payDay) {
                            Text("每月最后一个工作日").tag(WorkSettings.payDayLastWorkday)
                            ForEach(1...31, id: \.self) { d in Text("每月 \(d) 号").tag(d) }
                        }.labelsHidden()
                    }
                    field("退休日期") { DatePicker("", selection: $retireAt, displayedComponents: .date).labelsHidden() }
                    field("菜单栏显示") {
                        Picker("", selection: $draft.menuBarMode) {
                            Text("今日已赚（实时）").tag(MenuBarMode.money)
                            Text("下班倒计时").tag(MenuBarMode.countdown)
                            Text("图标").tag(MenuBarMode.icon)
                        }.labelsHidden()
                    }
                    Toggle("开机自启", isOn: $draft.launchAtLogin)
                    Toggle("模拟时间（调试）", isOn: $draft.simEnabled)
                    if draft.simEnabled {
                        DatePicker("模拟时刻", selection: $simAt)
                            .font(.system(size: 12))
                    }
                    if !canSave {
                        Text("下班时间需晚于上班时间；月薪与工作日数需为大于 0 的数字")
                            .font(.system(size: 11)).foregroundColor(p.error)
                    }
                }
            }
        }
        .padding(14)
        .background(p.bgGradient.ignoresSafeArea())
        .onAppear(perform: load)
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11)).foregroundColor(p.text2)
            content()
        }
    }

    private var canSave: Bool {
        guard let salary = Double(salaryText), salary > 0,
              let days = Double(daysText), days > 0 else { return false }
        var s = draft.settings
        s.startMin = minutesFrom(startAt)
        s.endMin = minutesFrom(endAt)
        s.monthlySalary = salary
        s.workDaysPerMonth = days
        s.retirementDate = yyyyMMdd(retireAt)
        return s.isValid
    }

    private var saveButton: some View {
        Button("保存") { save() }
            .buttonStyle(.borderedProminent)
            .disabled(!canSave)
    }

    private func load() {
        draft = store.state
        let cal = Calendar.current
        startAt = dateFrom(minutes: draft.settings.startMin, calendar: cal)
        endAt = dateFrom(minutes: draft.settings.endMin, calendar: cal)
        simAt = draft.simOffset.map { Date().addingTimeInterval($0) } ?? Date()
        loadedSimAt = simAt
        salaryText = trimDouble(draft.settings.monthlySalary)
        daysText = trimDouble(draft.settings.workDaysPerMonth)
        var comps = cal.dateComponents([.year, .month, .day], from: cal.startOfDay(for: Date()))
        if let r = Milestones.parseDateOnlyPublic(draft.settings.retirementDate) {
            let rc = cal.dateComponents([.year, .month, .day], from: r)
            comps = rc
        }
        retireAt = cal.date(from: comps) ?? Date()
    }

    private func save() {
        var s = draft
        s.settings.startMin = minutesFrom(startAt)
        s.settings.endMin = minutesFrom(endAt)
        s.settings.monthlySalary = Double(salaryText) ?? 0
        s.settings.workDaysPerMonth = Double(daysText) ?? 0
        s.settings.retirementDate = yyyyMMdd(retireAt)
        s.simEnabled = draft.simEnabled
        s.simOffset = StoredState.committedSimOffset(
            enabled: draft.simEnabled,
            pickedAt: simAt,
            pickedAtLoad: loadedSimAt,
            existing: draft.simOffset,
            now: Date())
        guard s.settings.isValid else { return }
        store.apply(s)
        onBack()
    }

    // MARK: - 转换工具

    private func minutesFrom(_ d: Date, calendar: Calendar = .current) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return c.hour! * 60 + c.minute!
    }

    private func dateFrom(minutes: Int, calendar: Calendar) -> Date {
        var c = calendar.dateComponents([.year, .month, .day], from: Date())
        c.hour = minutes / 60
        c.minute = minutes % 60
        return calendar.date(from: c)!
    }

    private func yyyyMMdd(_ d: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// 20000 → "20000"，21.75 → "21.75"
    private func trimDouble(_ v: Double) -> String {
        v == v.rounded() && abs(v) < 1e15 ? String(Int(v)) : "\(v)"
    }
}
