import SwiftUI

struct MonthGridView: View {
    let month: Date
    let log: DayLog
    let onSetType: (Date, DayType?) -> Void
    let validRange: ClosedRange<Date>

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    private var monthStart: Date {
        // Use a plain calendar for date math to avoid firstWeekday complications
        let plainCal = Calendar.current
        let year = plainCal.component(.year, from: month)
        let monthNum = plainCal.component(.month, from: month)
        var components = DateComponents()
        components.year = year
        components.month = monthNum
        components.day = 1
        components.hour = 12
        return plainCal.date(from: components) ?? month
    }

    private var daysInMonth: Int {
        Calendar.current.range(of: .day, in: .month, for: monthStart)?.count ?? 30
    }

    private var leadingBlanks: Int {
        // Use plain calendar to get weekday (1=Sunday, 2=Monday, ..., 7=Saturday)
        let weekday = Calendar.current.component(.weekday, from: monthStart)
        // For Monday-first calendar: Mon=0 blanks, Tue=1, Wed=2, Thu=3, Fri=4, Sat=5, Sun=6
        return (weekday - 2 + 7) % 7
    }

    // Reorder weekday symbols to start with Monday
    private var weekdaySymbols: [String] {
        let symbols = calendar.shortWeekdaySymbols
        // Rotate so Monday is first: [Mon, Tue, Wed, Thu, Fri, Sat, Sun]
        return Array(symbols[1...]) + [symbols[0]]
    }

    private let cols = Array(repeating: GridItem(.flexible(minimum: 50, maximum: 70), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 8) {
            // Weekday header
            HStack(spacing: 4) {
                ForEach(weekdaySymbols, id: \.self) { s in
                    Text(s)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

    // Day grid
    LazyVGrid(columns: cols, spacing: 4) {
        ForEach(Array(gridCells.enumerated()), id: \.offset) { _, day in
            if let day {
                let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) ?? monthStart
                let key = calendar.dayKey(for: date)
                DayCell(
                    date: date,
                    type: log.entries[key],
                    isGeofenced: log.geofencedDates.contains(key),
                    isEnabled: validRange.contains(calendar.startOfDay(for: date)),
                    onSetType: onSetType
                )
            } else {
                Color.clear.frame(height: 46)
            }
        }
    }
            
            // Legend
            HStack(spacing: 14) {
                ForEach(DayType.allCases) { t in
                    HStack(spacing: 4) {
                        Image(systemName: iconFor(t))
                            .font(.system(size: 12))
                            .foregroundStyle(colorFor(t))
                        Text(t.shortName)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.top, 6)
        }
    }
    
    private func colorFor(_ type: DayType) -> Color {
        switch type {
        case .inOffice: return .blue
        case .pto: return .orange
        case .sick: return .yellow
        case .exempt: return .purple
        case .publicHoliday: return .red
        }
    }
    
    private func iconFor(_ type: DayType) -> String {
        switch type {
        case .inOffice: return "checkmark.circle.fill"
        case .pto: return "airplane.circle.fill"
        case .sick: return "cross.circle.fill"
        case .exempt: return "minus.circle.fill"
        case .publicHoliday: return "flag.circle.fill"
        }
    }
}

private extension MonthGridView {
    var gridCells: [Int?] {
        var cells = [Int?](repeating: nil, count: leadingBlanks)
        cells.append(contentsOf: (1...daysInMonth).map { Optional($0) })
        return cells
    }
}

private struct DayCell: View {
    let date: Date
    let type: DayType?
    let isGeofenced: Bool
    let isEnabled: Bool
    let onSetType: (Date, DayType?) -> Void

    private var calendar: Calendar { .current }

    private var isToday: Bool {
        Calendar.current.isDateInToday(date)
    }
    
    private var isWeekend: Bool {
        let wd = calendar.component(.weekday, from: date)
        return wd == 1 || wd == 7
    }

    private var bgColor: Color {
        switch type {
        case .inOffice: return .blue
        case .pto: return .orange
        case .sick: return .yellow
        case .exempt: return .purple
        case .publicHoliday: return .red
        case .none: return Color(NSColor.controlBackgroundColor)
        }
    }
    
    private var iconColor: Color {
        switch type {
        case .inOffice: return .white
        case .pto: return .white
        case .sick: return .black.opacity(0.8)
        case .exempt: return .white
        case .publicHoliday: return .white
        case .none: return .clear
        }
    }

    private var icon: String? {
        switch type {
        case .inOffice: return "checkmark"
        case .pto: return "airplane"
        case .sick: return "cross"
        case .exempt: return "minus"
        case .publicHoliday: return "flag.fill"
        case .none: return nil
        }
    }

    private func cycleType() {
        guard isEnabled else { return }
        let allTypes = DayType.allCases
        if let current = type, let idx = allTypes.firstIndex(of: current) {
            let nextIdx = allTypes.index(after: idx)
            if nextIdx < allTypes.endIndex {
                onSetType(date, allTypes[nextIdx])
            } else {
                onSetType(date, nil) // Back to empty
            }
        } else {
            onSetType(date, allTypes.first) // Start with first type
        }
    }

    var body: some View {
        let day = calendar.component(.day, from: date)
        
        Button {
            cycleType()
        } label: {
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(type != nil ? bgColor.opacity(0.85) : bgColor)
                
                // Border for today
                if isToday {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.white, lineWidth: 2)
                }
                
                // Content
                VStack(spacing: 3) {
                    Text("\(day)")
                        .font(.system(size: 13, weight: isToday ? .bold : .medium, design: .rounded))
                        .foregroundStyle(type != nil ? iconColor : (isEnabled ? Color.primary : Color.secondary.opacity(0.5)))
                    
                    if let icon {
                        HStack(spacing: 2) {
                            Image(systemName: icon)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(iconColor)
                            if isGeofenced && type == .inOffice {
                                Image(systemName: "globe")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(iconColor.opacity(0.8))
                            }
                        }
                    }
                }
            }
            .frame(height: 46)
            .frame(maxWidth: .infinity)
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(.plain)
        .help(type?.displayName ?? (isWeekend ? "Weekend" : "Click to mark"))
    }
}

extension DayType {
    var shortName: String {
        switch self {
        case .inOffice: return "Office"
        case .pto: return "PTO"
        case .sick: return "Sick"
        case .exempt: return "Exempt"
        case .publicHoliday: return "Holiday"
        }
    }
}