import Foundation

struct AttendanceSummary {
    var officeDays: Int
    var eligibleWorkingDays: Int
    var attendancePct: Double
}

struct OfficeDayPlan {
    var targetPct: Double
    var totalEligibleWorkingDays: Int
    var requiredOfficeDays: Int
    var officeDaysSoFar: Int
    var remainingOfficeDaysNeeded: Int
    var recommendedDates: [Date]
}

enum FlexLogic {
    // MARK: - Workday Fiscal Quarters (Q1=Feb-Apr, Q2=May-Jul, Q3=Aug-Oct, Q4=Nov-Jan)
    
    static func fiscalQuarter(for date: Date, calendar: Calendar = .current) -> (name: String, start: Date, end: Date) {
        let month = calendar.component(.month, from: date)
        let year = calendar.component(.year, from: date)
        
        // Workday fiscal year starts Feb 1
        // Q1: Feb-Apr, Q2: May-Jul, Q3: Aug-Oct, Q4: Nov-Jan
        let (qName, startMonth, startYear, endMonth, endYear): (String, Int, Int, Int, Int)
        
        switch month {
        case 2, 3, 4:  // Q1: Feb-Apr
            qName = "Q1"
            startMonth = 2; startYear = year
            endMonth = 4; endYear = year
        case 5, 6, 7:  // Q2: May-Jul
            qName = "Q2"
            startMonth = 5; startYear = year
            endMonth = 7; endYear = year
        case 8, 9, 10: // Q3: Aug-Oct
            qName = "Q3"
            startMonth = 8; startYear = year
            endMonth = 10; endYear = year
        case 11, 12:   // Q4: Nov-Dec (part 1)
            qName = "Q4"
            startMonth = 11; startYear = year
            endMonth = 1; endYear = year + 1
        default:       // 1 (Jan) - Q4: Nov(prev year)-Jan
            qName = "Q4"
            startMonth = 11; startYear = year - 1
            endMonth = 1; endYear = year
        }
        
        let start = calendar.date(from: DateComponents(year: startYear, month: startMonth, day: 1))!
        // End of endMonth
        let endMonthStart = calendar.date(from: DateComponents(year: endYear, month: endMonth, day: 1))!
        let end = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: endMonthStart)!
        
        return (qName, start, end)
    }
    
    static func fiscalQuarterLabel(for date: Date, calendar: Calendar = .current) -> String {
        let q = fiscalQuarter(for: date, calendar: calendar)
        let fy = calendar.component(.year, from: q.end) // FY is the year the quarter ends
        return "\(q.name) FY\(fy)"
    }

    static func isWeekday(_ date: Date, calendar: Calendar = .current) -> Bool {
        let wd = calendar.component(.weekday, from: date) // 1..7 (Sun..Sat)
        return wd >= 2 && wd <= 6
    }

    static func listDays(from start: Date, to end: Date, calendar: Calendar = .current) -> [Date] {
        var out: [Date] = []
        var d = calendar.startOfDay(for: start)
        let e = calendar.startOfDay(for: end)
        while d <= e {
            out.append(d)
            guard let next = calendar.date(byAdding: .day, value: 1, to: d) else { break }
            d = next
        }
        return out
    }

    static func eligibleWorkingDays(
        log: DayLog,
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current
    ) -> [Date] {
        let days = listDays(from: startDate, to: endDate, calendar: calendar)
        return days.filter { day in
            guard isWeekday(day, calendar: calendar) else { return false }
            let key = calendar.dayKey(for: day)
            switch log.entries[key] {
            case .pto, .sick, .exempt, .publicHoliday:
                return false
            default:
                return true
            }
        }
    }

    /// Calculate attendance for the FULL period (not just elapsed days).
    /// officeDays = days marked .inOffice within the period
    /// eligibleWorkingDays = all weekdays in the period minus PTO/Sick/Exempt/Holiday
    static func attendance(
        log: DayLog,
        startDate: Date,
        endDate: Date,
        calendar: Calendar = .current
    ) -> AttendanceSummary {
        let eligible = eligibleWorkingDays(log: log, startDate: startDate, endDate: endDate, calendar: calendar)
        let eligibleCount = eligible.count

        let officeCount = eligible
            .map { calendar.dayKey(for: $0) }
            .filter { log.entries[$0] == .inOffice }
            .count

        let pct: Double
        if eligibleCount == 0 {
            pct = 0
        } else {
            pct = (Double(officeCount) * 100.0) / Double(eligibleCount)
        }

        return AttendanceSummary(officeDays: officeCount, eligibleWorkingDays: eligibleCount, attendancePct: pct)
    }

    /// Preferred weekdays use Swift's weekday integers: Sun=1 ... Sat=7.
    /// Default is Tue/Wed/Thu then Mon/Fri: [3,4,5,2,6]
    static func officeDayPlan(
        log: DayLog,
        startDate: Date,
        endDate: Date,
        fromDate: Date,
        targetPct: Double,
        preferredWeekdays: [Int] = [3, 4, 5, 2, 6],
        calendar: Calendar = .current
    ) -> OfficeDayPlan {
        let eligible = eligibleWorkingDays(log: log, startDate: startDate, endDate: endDate, calendar: calendar)
        let totalEligible = eligible.count
        let requiredOfficeDays = Int(ceil((targetPct / 100.0) * Double(totalEligible)))

        let officeSoFar = eligible
            .map { calendar.dayKey(for: $0) }
            .filter { log.entries[$0] == .inOffice }
            .count

        let remaining = max(0, requiredOfficeDays - officeSoFar)

        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        let from = max(calendar.startOfDay(for: fromDate), start)

        var cal = calendar
        cal.firstWeekday = 2 // Monday

        func weekStart(for d: Date) -> Date {
            let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: d)
            return cal.date(from: comps) ?? d
        }

        var recommended: [Date] = []
        var remainingToPick = remaining

        var ws = weekStart(for: from)
        while ws <= end, remainingToPick > 0 {
            for weekday in preferredWeekdays {
                guard remainingToPick > 0 else { break }
                let candidate = cal.nextDate(
                    after: ws.addingTimeInterval(-1),
                    matching: DateComponents(weekday: weekday),
                    matchingPolicy: .nextTimePreservingSmallerComponents
                ) ?? ws

                let c = cal.startOfDay(for: candidate)
                if c < from || c < start || c > end { continue }
                if !isWeekday(c, calendar: cal) { continue }

                let key = cal.dayKey(for: c)
                if log.entries[key] == .inOffice { continue }
                if let t = log.entries[key], t != .inOffice {
                    if t == .pto || t == .sick || t == .exempt || t == .publicHoliday { continue }
                }

                recommended.append(c)
                remainingToPick -= 1
            }

            guard let nextWeek = cal.date(byAdding: .day, value: 7, to: ws) else { break }
            ws = nextWeek
        }

        return OfficeDayPlan(
            targetPct: targetPct,
            totalEligibleWorkingDays: totalEligible,
            requiredOfficeDays: requiredOfficeDays,
            officeDaysSoFar: officeSoFar,
            remainingOfficeDaysNeeded: remaining,
            recommendedDates: recommended
        )
    }
}

