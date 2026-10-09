import SwiftUI
import UserNotifications
import UIKit

// MARK: - Model

struct Deadline: Identifiable, Codable, Equatable {
    var id = UUID()
    var subject: String
    var title: String
    var dueDate: Date
    var isDone: Bool = false
    var isUrgent: Bool = false

    func scheduleNotifications() {
        guard !isDone else { return }

        if let oneDayBefore = Calendar.current.date(byAdding: .day, value: -1, to: dueDate) {
            let content = UNMutableNotificationContent()
            content.title = "Deadline Reminder"
            content.body = "\(title) (\(subject)) is due tomorrow."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: oneDayBefore),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "\(id.uuidString)_1DayBefore",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }

        if let fiveHoursBefore = Calendar.current.date(byAdding: .hour, value: -5, to: dueDate) {
            let content = UNMutableNotificationContent()
            content.title = "Upcoming Deadline"
            content.body = "\(title) is due in 5 hours."
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fiveHoursBefore),
                repeats: false
            )

            let request = UNNotificationRequest(
                identifier: "\(id.uuidString)_5HoursBefore",
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request)
        }
    }

    static func removeNotifications(for id: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [
                "\(id.uuidString)_1DayBefore",
                "\(id.uuidString)_5HoursBefore"
            ]
        )
    }
}

// MARK: - Main View

struct DeadlinesView: View {
    @State private var deadlines: [Deadline] = DeadlinesView.loadDeadlines()

    @State private var showingAddDeadline = false
    @State private var editingDeadline: Deadline? = nil

    @State private var selectedDeadlines: Set<UUID> = []
    @State private var isEditingMode = false
    @State private var showCompletedDeadlines = false

    @State private var notificationDenied = false

    // Sort: urgent first, then earliest due date
    private var activeDeadlines: [Deadline] {
        deadlines
            .filter { !$0.isDone }
            .sorted {
                if $0.isUrgent != $1.isUrgent { return $0.isUrgent && !$1.isUrgent }
                return $0.dueDate < $1.dueDate
            }
    }

    private var completedDeadlines: [Deadline] {
        deadlines
            .filter { $0.isDone }
            .sorted { $0.dueDate < $1.dueDate }
    }

    private var activeSubjects: [String] {
        Array(Set(activeDeadlines.map { $0.subject })).sorted()
    }

    private var completedSubjects: [String] {
        Array(Set(completedDeadlines.map { $0.subject })).sorted()
    }

    var body: some View {
        NavigationView {
            List {
                if notificationDenied {
                    NotificationStatusBanner()
                        .listRowBackground(Color.clear)
                }

                ForEach(activeSubjects, id: \.self) { subject in
                    let items = activeDeadlines.filter { $0.subject == subject }

                    Section(header: Text(subject)) {
                        ForEach(items) { deadline in
                            DeadlineRow(
                                deadline: deadline,
                                isEditingMode: isEditingMode,
                                isSelected: selectedDeadlines.contains(deadline.id),
                                toggleSelection: { toggleSelection(for: deadline.id) },
                                markToggle: { markAsDone(deadline) },
                                edit: { editingDeadline = deadline }
                            )
                        }
                        .onDelete { offsets in
                            deleteFrom(items: items, at: offsets)
                        }
                    }
                }

                DisclosureGroup("Completed Deadlines", isExpanded: $showCompletedDeadlines) {
                    ForEach(completedSubjects, id: \.self) { subject in
                        let items = completedDeadlines.filter { $0.subject == subject }

                        Section(header: Text(subject)) {
                            ForEach(items) { deadline in
                                DeadlineRow(
                                    deadline: deadline,
                                    isEditingMode: isEditingMode,
                                    isSelected: selectedDeadlines.contains(deadline.id),
                                    toggleSelection: { toggleSelection(for: deadline.id) },
                                    markToggle: { markAsUndone(deadline) },
                                    edit: { editingDeadline = deadline }
                                )
                                .foregroundColor(.secondary)
                                .strikethrough(true)
                            }
                            .onDelete { offsets in
                                deleteFrom(items: items, at: offsets)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Deadlines")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditingMode {
                        Button(role: .destructive, action: deleteSelectedDeadlines) {
                            Image(systemName: "trash")
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button(isEditingMode ? "Cancel" : "Edit") {
                            if isEditingMode {
                                selectedDeadlines.removeAll()
                                isEditingMode = false
                            } else {
                                isEditingMode = true
                            }
                        }

                        Button {
                            showingAddDeadline = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddDeadline) {
                AddEditDeadlineView(deadlines: $deadlines, editingDeadline: nil)
            }
            .sheet(item: $editingDeadline) { deadline in
                AddEditDeadlineView(deadlines: $deadlines, editingDeadline: deadline)
            }
            .onAppear {
                checkNotificationStatus()
                deadlines = DeadlinesView.loadDeadlines()
            }
        }
    }

    // MARK: - Actions

    private func toggleSelection(for id: UUID) {
        if selectedDeadlines.contains(id) {
            selectedDeadlines.remove(id)
        } else {
            selectedDeadlines.insert(id)
        }
    }

    private func markAsDone(_ deadline: Deadline) {
        guard let idx = deadlines.firstIndex(where: { $0.id == deadline.id }) else { return }
        deadlines[idx].isDone = true
        Deadline.removeNotifications(for: deadline.id)
        saveDeadlines()
    }

    private func markAsUndone(_ deadline: Deadline) {
        guard let idx = deadlines.firstIndex(where: { $0.id == deadline.id }) else { return }
        deadlines[idx].isDone = false
        Deadline.removeNotifications(for: deadline.id)
        deadlines[idx].scheduleNotifications()
        saveDeadlines()
    }

    private func deleteFrom(items: [Deadline], at offsets: IndexSet) {
        for i in offsets {
            deleteDeadline(items[i])
        }
    }

    private func deleteDeadline(_ deadline: Deadline) {
        Deadline.removeNotifications(for: deadline.id)
        deadlines.removeAll { $0.id == deadline.id }
        saveDeadlines()
    }

    private func deleteSelectedDeadlines() {
        for id in selectedDeadlines {
            Deadline.removeNotifications(for: id)
        }
        deadlines.removeAll { selectedDeadlines.contains($0.id) }
        selectedDeadlines.removeAll()
        isEditingMode = false
        saveDeadlines()
    }

    private func saveDeadlines() {
        for d in deadlines where !d.isDone {
            Deadline.removeNotifications(for: d.id)
            d.scheduleNotifications()
        }

        if let encoded = try? JSONEncoder().encode(deadlines) {
            UserDefaults.standard.set(encoded, forKey: "Deadlines")
        }
    }

    private func checkNotificationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                notificationDenied = (settings.authorizationStatus == .denied)
            }
        }
    }

    static func loadDeadlines() -> [Deadline] {
        if let saved = UserDefaults.standard.data(forKey: "Deadlines"),
           let decoded = try? JSONDecoder().decode([Deadline].self, from: saved) {
            return decoded
        }
        return []
    }
}

// MARK: - Row (Countdown + stronger urgency)

struct DeadlineRow: View {
    let deadline: Deadline
    let isEditingMode: Bool
    let isSelected: Bool
    let toggleSelection: () -> Void
    let markToggle: () -> Void
    let edit: () -> Void

    @State private var pulse = false
    @State private var wiggle = false

    // thresholds
    private let redThreshold: TimeInterval = 24 * 3600
    private let intenseThreshold: TimeInterval = 6 * 3600

    var body: some View {
        TimelineView(.periodic(from: Date(), by: 1)) { timeline in
            let now = timeline.date
            let secondsLeft = deadline.dueDate.timeIntervalSince(now)

            let isOverdue = secondsLeft < 0
            let isClose = secondsLeft <= redThreshold
            let isVeryClose = secondsLeft <= intenseThreshold

            let urgentVisual = deadline.isUrgent || isClose || isOverdue
            let intenseVisual = deadline.isUrgent || isVeryClose || isOverdue

            HStack(spacing: 12) {
                if isEditingMode {
                    Button(action: toggleSelection) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .green : .gray)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if urgentVisual && !deadline.isDone {
                            Image(systemName: "exclamationmark.circle.fill")
                                .foregroundColor(.red)
                        }

                        Text(deadline.title)
                            .font(.headline)

                        if deadline.isUrgent && !deadline.isDone {
                            Text("URGENT")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red.opacity(0.18))
                                .foregroundColor(.red)
                                .cornerRadius(8)
                        }
                    }

                    Text(deadline.subject)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(countdownText(secondsLeft: secondsLeft))
                        .font(.caption2)
                        .foregroundColor(isOverdue ? .red : .secondary)
                }

                Spacer()

                if !isEditingMode {
                    Button(action: markToggle) {
                        Image(systemName: deadline.isDone ? "arrow.uturn.backward.circle.fill" : "checkmark.circle")
                            .foregroundColor(deadline.isDone ? .blue : .green)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(backgroundFor(urgent: urgentVisual, intense: intenseVisual))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(urgentVisual ? Color.red.opacity(0.35) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(14)
            // pulse
            .scaleEffect(intenseVisual && !deadline.isDone ? (pulse ? 1.02 : 0.98) : 1.0)
            .opacity(intenseVisual && !deadline.isDone ? (pulse ? 1.0 : 0.94) : 1.0)
            // wiggle (tiny shake)
            .rotationEffect(intenseVisual && !deadline.isDone ? Angle(degrees: wiggle ? 0.6 : -0.6) : .zero)
            .animation(
                (intenseVisual && !deadline.isDone)
                ? .easeInOut(duration: 0.85).repeatForever(autoreverses: true)
                : .default,
                value: pulse
            )
            .animation(
                (intenseVisual && !deadline.isDone)
                ? .easeInOut(duration: 0.18).repeatForever(autoreverses: true)
                : .default,
                value: wiggle
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if !isEditingMode { edit() }
                else { toggleSelection() }
            }
            .onAppear {
                let shouldAnimate = intenseVisual && !deadline.isDone
                pulse = shouldAnimate
                wiggle = shouldAnimate
            }
            .onChange(of: intenseVisual) { _, newValue in
                let shouldAnimate = newValue && !deadline.isDone
                pulse = shouldAnimate
                wiggle = shouldAnimate
            }
        }
    }

    private func backgroundFor(urgent: Bool, intense: Bool) -> Color {
        if urgent && intense { return Color.red.opacity(0.18) }
        if urgent { return Color.red.opacity(0.11) }
        return Color(.systemGray6)
    }

    private func countdownText(secondsLeft: TimeInterval) -> String {
        if secondsLeft < 0 {
            return "Overdue by \(formatSeconds(Int(abs(secondsLeft))))"
        }
        return "Due in \(formatSeconds(Int(secondsLeft)))"
    }

    private func formatSeconds(_ total: Int) -> String {
        let days = total / 86400
        let hours = (total % 86400) / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60

        if days > 0 { return "\(days)d \(hours)h \(mins)m" }
        if hours > 0 { return "\(hours)h \(mins)m \(secs)s" }
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }
}

// MARK: - Add/Edit (urgent toggle + haptic)

struct AddEditDeadlineView: View {
    @Binding var deadlines: [Deadline]
    let editingDeadline: Deadline?

    @Environment(\.dismiss) private var dismiss

    @State private var subject: String = ""
    @State private var title: String = ""
    @State private var dueDate: Date = Date()
    @State private var isUrgent: Bool = false

    private var isEditing: Bool { editingDeadline != nil }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Details")) {
                    TextField("Subject", text: $subject)
                    TextField("Title", text: $title)
                }

                Section(header: Text("Priority")) {
                    Toggle("Mark as urgent", isOn: $isUrgent)
                        .onChange(of: isUrgent) { _, _ in
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                }

                Section(header: Text("Due")) {
                    DatePicker("Due Date & Time", selection: $dueDate)
                }
            }
            .navigationTitle(isEditing ? "Edit Deadline" : "New Deadline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let d = editingDeadline {
                    subject = d.subject
                    title = d.title
                    dueDate = d.dueDate
                    isUrgent = d.isUrgent
                }
            }
        }
    }

    private func save() {
        let cleanSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        if let editing = editingDeadline,
           let idx = deadlines.firstIndex(where: { $0.id == editing.id }) {

            Deadline.removeNotifications(for: deadlines[idx].id)

            deadlines[idx].subject = cleanSubject
            deadlines[idx].title = cleanTitle
            deadlines[idx].dueDate = dueDate
            deadlines[idx].isDone = false
            deadlines[idx].isUrgent = isUrgent

            deadlines[idx].scheduleNotifications()
        } else {
            let newDeadline = Deadline(
                subject: cleanSubject,
                title: cleanTitle,
                dueDate: dueDate,
                isDone: false,
                isUrgent: isUrgent
            )
            deadlines.append(newDeadline)
            newDeadline.scheduleNotifications()
        }

        for d in deadlines where !d.isDone {
            Deadline.removeNotifications(for: d.id)
            d.scheduleNotifications()
        }

        if let encoded = try? JSONEncoder().encode(deadlines) {
            UserDefaults.standard.set(encoded, forKey: "Deadlines")
        }
    }
}

// MARK: - Banner

struct NotificationStatusBanner: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text("Notifications are disabled")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("Enable them in Settings to get deadline reminders.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.caption)
        }
        .padding(12)
        .background(Color.yellow.opacity(0.15))
        .cornerRadius(12)
    }
}
