import SwiftUI

struct StatusCardView: View {
    @EnvironmentObject private var store: OfficeStore
    @EnvironmentObject private var location: LocationMonitor

    @State private var range: RangeKind = .quarter
    @State private var monthCursor = Date()
    @State private var quickMarkType: DayType = .inOffice

    enum RangeKind: String, CaseIterable, Identifiable {
        case month
        case quarter

        var id: String { rawValue }
        var label: String { rawValue.capitalized }
    }

    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }

    private var today: Date { calendar.startOfDay(for: Date()) }

    private var fiscalQuarter: (name: String, start: Date, end: Date) {
        FlexLogic.fiscalQuarter(for: today, calendar: calendar)
    }
    
    private var fiscalQuarterLabel: String {
        FlexLogic.fiscalQuarterLabel(for: today, calendar: calendar)
    }

    /// Returns the FULL period dates (start to end of month/quarter, not capped to today)
    private var rangeDates: (start: Date, end: Date) {
        switch range {
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: monthCursor)
            let start = calendar.date(from: comps) ?? today
            let end = calendar.date(byAdding: .month, value: 1, to: start)
                .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) } ?? today
            return (start, end)
        case .quarter:
            return (fiscalQuarter.start, fiscalQuarter.end)
        }
    }

    private var summary: AttendanceSummary {
        FlexLogic.attendance(log: store.log, startDate: rangeDates.start, endDate: rangeDates.end, calendar: calendar)
    }

    private var plan: OfficeDayPlan {
        FlexLogic.officeDayPlan(
            log: store.log,
            startDate: rangeDates.start,
            endDate: rangeDates.end,
            fromDate: Date(),
            targetPct: store.config.targetPct,
            preferredWeekdays: store.config.preferredWeekdays,
            calendar: calendar
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            progressRow
            Divider()
            calendarSection
            Divider()
            recommendationsSection
            Divider()
            footerActions
        }
    }

    // Month summary (for selected month)
    private var monthSummary: AttendanceSummary {
        let comps = calendar.dateComponents([.year, .month], from: monthCursor)
        let monthStart = calendar.date(from: comps) ?? today
        let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart)
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) } ?? today
        return FlexLogic.attendance(log: store.log, startDate: monthStart, endDate: monthEnd, calendar: calendar)
    }
    
    // Quarter-to-date summary (from quarter start to end of current month being viewed)
    private var quarterToDateSummary: AttendanceSummary {
        let comps = calendar.dateComponents([.year, .month], from: monthCursor)
        let monthEnd = calendar.date(from: comps)
            .flatMap { calendar.date(byAdding: .month, value: 1, to: $0) }
            .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) } ?? today
        return FlexLogic.attendance(log: store.log, startDate: fiscalQuarter.start, endDate: monthEnd, calendar: calendar)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text("Office Check‑In")
                .font(.headline)
                .lineLimit(1)
            Spacer()
            Picker("", selection: $range) {
                ForEach(RangeKind.allCases) { r in
                    Text(r.label).tag(r)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()
        }
    }

    private var progressRow: some View {
        VStack(spacing: 12) {
            // Main progress (based on selected range)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(range == .month ? "This Month" : "Full Quarter")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(summary.attendancePct, specifier: "%.1f")%")
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(summary.attendancePct >= store.config.targetPct ? .green : .primary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Office / Eligible")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("\(summary.officeDays) / \(summary.eligibleWorkingDays)")
                        .font(.title3)
                        .monospacedDigit()
                }
            }
            
            // Secondary: month vs quarter-to-date (when in quarter mode)
            if range == .quarter {
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Text("This month:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(monthSummary.attendancePct, specifier: "%.1f")%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    HStack(spacing: 6) {
                        Text("Quarter to date:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("\(quarterToDateSummary.attendancePct, specifier: "%.1f")%")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    Spacer()
                }
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(monthCursor.formatted(.dateTime.month(.wide).year()))
                        .font(.headline)
                    if range == .quarter {
                        Text(fiscalQuarterLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button { navigateMonth(delta: -1) } label: { 
                    Image(systemName: "chevron.left")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
                Button { navigateMonth(delta: 1) } label: { 
                    Image(systemName: "chevron.right")
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.bordered)
            }

            MonthGridView(
                month: monthCursor,
                log: store.log,
                onSetType: { date, type in store.set(type, for: date, calendar: calendar) },
                validRange: validCalendarRangeForCursor()
            )
        }
    }

    /// Valid range for marking days: full month in month mode, full quarter in quarter mode
    private func validCalendarRangeForCursor() -> ClosedRange<Date> {
        let start: Date
        let end: Date

        switch range {
        case .month:
            let comps = calendar.dateComponents([.year, .month], from: monthCursor)
            let monthStart = calendar.date(from: comps) ?? today
            let monthEnd = calendar
                .date(byAdding: .month, value: 1, to: monthStart)
                .flatMap { calendar.date(byAdding: .day, value: -1, to: $0) } ?? today
            start = monthStart
            end = monthEnd
        case .quarter:
            start = fiscalQuarter.start
            end = fiscalQuarter.end
        }

        return calendar.startOfDay(for: start)...calendar.startOfDay(for: end)
    }

    private func navigateMonth(delta: Int) {
        guard let next = calendar.date(byAdding: .month, value: delta, to: monthCursor) else { return }
        let nextStart = calendar.date(from: calendar.dateComponents([.year, .month], from: next)) ?? next

        switch range {
        case .month:
            // Allow navigating to any month (past or future)
            monthCursor = nextStart
        case .quarter:
            // Constrain to months within the fiscal quarter
            if nextStart < fiscalQuarter.start { return }
            if nextStart > fiscalQuarter.end { return }
            monthCursor = nextStart
        }
    }

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recommended office days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Need \(plan.remainingOfficeDaysNeeded)")
                    .foregroundStyle(.secondary)
            }

            if plan.remainingOfficeDaysNeeded == 0 {
                Text("You’re on track for \(store.config.targetPct, specifier: "%.0f")%+.")
                    .foregroundStyle(.secondary)
            } else if plan.recommendedDates.isEmpty {
                Text("No eligible days left in this range.")
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(plan.recommendedDates.prefix(6), id: \.self) { d in
                        HStack {
                            Text(d.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(calendar.shortWeekdaySymbols[calendar.component(.weekday, from: d) - 1])
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var footerActions: some View {
        HStack {
            Menu {
                ForEach(DayType.allCases) { t in
                    Button(t.displayName) { quickMarkType = t }
                }
            } label: {
                Text("Quick mark: \(quickMarkType.displayName)")
            }

            Spacer()

            Button("Mark Yesterday") {
                if let y = calendar.date(byAdding: .day, value: -1, to: Date()) {
                    store.set(quickMarkType, for: y, calendar: calendar)
                }
            }

            Button("Settings") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .controlSize(.small)
    }
}

