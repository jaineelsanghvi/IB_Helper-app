import SwiftUI

struct HomeView: View {
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // Deadlines (already stored via DeadlinesView)
    @State private var deadlines: [Deadline] = DeadlinesView.loadDeadlines()

    // Timetable storage used across your app
    @AppStorage("timetable_v2") private var timetableData: Data = Data()
    @AppStorage("timetable_periods_by_day") private var periodsByDayData: Data = Data()

    @State private var slots: [TimetableSlot] = []
    @State private var periodsByDay: [String: Int] = [:]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 14) {
                topHeader

                dangerStrip

                todayCard

                nextDeadlinesCard

                Spacer(minLength: 12)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .onReceive(timer) { now = $0 }
        .onAppear { refresh() }
    }

    // MARK: - Header

    private var topHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greeting(for: now))
                .font(.largeTitle.weight(.bold))

            HStack {
                Text(now, style: .date)
                    .foregroundColor(.secondary)
                Spacer()
                Text(now, style: .time)
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - “The game” strip: what’s about to hit me?

    private var dangerStrip: some View {
        let urgent = urgentDeadlines

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Incoming")
                    .font(.headline)
                Spacer()
                Text("\(activeDeadlines.count) active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if urgent.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal")
                        .foregroundColor(.green)
                    Text("No deadlines in the next 3 days.")
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .cornerRadius(14)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(urgent.prefix(2))) { d in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: d.isUrgent ? "flame.fill" : "clock")
                                .foregroundColor(d.isUrgent ? .red : .orange)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(d.subject) • due \(relativeDueText(d.dueDate))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.45))
        .cornerRadius(18)
    }

    // MARK: - Today timetable

    private var todayCard: some View {
        let dayKey = dayKeyForToday()
        let maxPeriods = max(1, periodsByDay[dayKey] ?? 8)

        let todaysSlots = slots
            .filter { $0.day == dayKey }
            .sorted { $0.period < $1.period }

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Today")
                    .font(.headline)
                Spacer()
                Text(dayKey)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(999)
            }

            if dayKey == "Sat" || dayKey == "Sun" {
                Text("Weekend. Your brain gets patch notes. 🔧")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(1...maxPeriods, id: \.self) { p in
                        let slot = todaysSlots.first(where: { $0.period == p })
                        periodRow(period: p, slot: slot)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func periodRow(period: Int, slot: TimetableSlot?) -> some View {
        let subject = slot?.subject.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let dueSoonForSubject = nextDeadline(for: subject)

        return HStack(spacing: 12) {
            Text("P\(period)")
                .font(.caption.weight(.bold))
                .frame(width: 36, height: 28)
                .background(Color(.systemGray6))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(subject.isEmpty ? "Empty" : subject)
                    .font(.subheadline.weight(subject.isEmpty ? .regular : .semibold))
                    .foregroundColor(subject.isEmpty ? .secondary : .primary)

                if let room = slot?.room, !room.isEmpty {
                    Text(room)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if !subject.isEmpty {
                    Text("No room")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let d = dueSoonForSubject {
                Text(relativeDueText(d.dueDate))
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(d.isUrgent ? Color.red.opacity(0.12) : Color.orange.opacity(0.12))
                    .foregroundColor(d.isUrgent ? .red : .orange)
                    .cornerRadius(999)
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.7))
        .cornerRadius(14)
    }

    // MARK: - Next deadlines

    private var nextDeadlinesCard: some View {
        let top = Array(activeDeadlines.prefix(5))

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Next deadlines")
                    .font(.headline)
                Spacer()
                Text(top.isEmpty ? "" : "Top \(min(5, top.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if top.isEmpty {
                Text("Nothing queued. Rare IB peace detected. 🕊️")
                    .foregroundColor(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 8) {
                    ForEach(top) { d in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(d.isUrgent ? Color.red : Color.orange)
                                .frame(width: 8, height: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(d.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text("\(d.subject) • \(d.dueDate, style: .date)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(relativeDueText(d.dueDate))
                                .font(.caption.weight(.semibold))
                                .foregroundColor(d.isUrgent ? .red : .secondary)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(14)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.45))
        .cornerRadius(18)
    }

    // MARK: - Data helpers

    private var activeDeadlines: [Deadline] {
        deadlines
            .filter { !$0.isDone }
            .sorted {
                if $0.isUrgent != $1.isUrgent { return $0.isUrgent && !$1.isUrgent }
                return $0.dueDate < $1.dueDate
            }
    }

    private var urgentDeadlines: [Deadline] {
        let threeDaysFromNow = Calendar.current.date(byAdding: .day, value: 3, to: now) ?? now
        return activeDeadlines.filter { $0.dueDate <= threeDaysFromNow }
    }

    private func nextDeadline(for subject: String) -> Deadline? {
        guard !subject.isEmpty else { return nil }
        return activeDeadlines.first(where: { $0.subject == subject })
    }

    private func refresh() {
        deadlines = DeadlinesView.loadDeadlines()

        if !timetableData.isEmpty,
           let decoded = try? JSONDecoder().decode([TimetableSlot].self, from: timetableData) {
            slots = decoded
        } else {
            slots = []
        }

        if !periodsByDayData.isEmpty,
           let decoded = try? JSONDecoder().decode([String: Int].self, from: periodsByDayData) {
            periodsByDay = decoded
        } else {
            periodsByDay = [:]
        }
    }

    private func dayKeyForToday() -> String {
        let weekday = Calendar.current.component(.weekday, from: Date())
        switch weekday {
        case 2: return "Mon"
        case 3: return "Tue"
        case 4: return "Wed"
        case 5: return "Thu"
        case 6: return "Fri"
        case 7: return "Sat"
        default: return "Sun"
        }
    }

    private func greeting(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 6..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Still awake"
        }
    }

    private func relativeDueText(_ due: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: now.startOfDay, to: due.startOfDay).day ?? 0
        if days < 0 { return "past due" }
        if days == 0 { return "today" }
        if days == 1 { return "tomorrow" }
        return "in \(days)d"
    }
}

// MARK: - Small Date helpers

private extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}
