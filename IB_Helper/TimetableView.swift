import SwiftUI

// MARK: - Model

struct TimetableSlot: Identifiable, Codable, Hashable {
    var id = UUID()
    var day: String
    var period: Int
    var subject: String
    var room: String
}

// MARK: - Timetable View

struct TimetableView: View {
    private let days = ["Mon", "Tue", "Wed", "Thu", "Fri"]

    @AppStorage("timetable_v2") private var storedData: Data = Data()

    // NEW: periods per day (stored as JSON dictionary)
    @AppStorage("timetable_periods_by_day") private var periodsByDayData: Data = Data()

    @State private var slots: [TimetableSlot] = []
    @State private var periodsByDay: [String: Int] = [:]

    @State private var showingEditor = false
    @State private var editingSlot: TimetableSlot? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                header

                // Per-day period controls
                periodsControlCard

                ForEach(days, id: \.self) { day in
                    dayCard(for: day)
                }

                Spacer(minLength: 20)
            }
            .padding()
        }
        .background(Color(.systemBackground))
        .navigationTitle("Timetable")
        .onAppear {
            slots = loadSlots()
            periodsByDay = loadPeriodsByDay()
            ensureDefaults()
            trimSlotsAbovePeriodCounts()
            persistPeriodsByDay()
        }
        .sheet(item: $editingSlot) { slot in
            TimetableEditor(
                slot: slot,
                onSave: { updated in
                    upsert(updated)
                    persistSlots()
                }
            )
        }
        .sheet(isPresented: $showingEditor) {
            TimetableEditor(
                slot: TimetableSlot(day: "Mon", period: 1, subject: "", room: ""),
                onSave: { newSlot in
                    upsert(newSlot)
                    persistSlots()
                }
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Week")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Set period counts per day, then tap a slot to edit.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                showingEditor = true
            } label: {
                Image(systemName: "plus")
                    .font(.headline)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Period Control Card

    private var periodsControlCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Periods per day")
                .font(.headline)

            ForEach(days, id: \.self) { day in
                HStack {
                    Text(day)
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Spacer()

                    Stepper(
                        value: Binding(
                            get: { max(1, periodsByDay[day, default: 8]) },
                            set: { newValue in
                                periodsByDay[day] = max(1, newValue)
                                trimSlotsAbovePeriodCounts()
                                persistPeriodsByDay()
                                persistSlots()
                            }
                        ),
                        in: 1...20
                    ) {
                        Text("\(periodsByDay[day, default: 8])")
                            .font(.headline)
                            .frame(width: 40, alignment: .trailing)
                    }
                }
                .padding(.vertical, 4)
            }

            Text("Minimum is 1 period per day.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - Day Card

    private func dayCard(for day: String) -> some View {
        let maxPeriods = max(1, periodsByDay[day, default: 8])
        let periods = Array(1...maxPeriods)

        return VStack(alignment: .leading, spacing: 10) {
            Text(day)
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(periods, id: \.self) { p in
                    let slot = slotFor(day: day, period: p)
                    timetableCell(day: day, period: p, slot: slot)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func timetableCell(day: String, period: Int, slot: TimetableSlot?) -> some View {
        Button {
            editingSlot = slot ?? TimetableSlot(day: day, period: period, subject: "", room: "")
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("P\(period)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray5))
                        .cornerRadius(10)

                    Spacer()

                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if let slot = slot, !slot.subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(slot.subject)
                        .font(.headline)
                        .lineLimit(1)

                    if !slot.room.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(slot.room)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    } else {
                        Text("No room set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Empty")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Tap to add")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 92, alignment: .topLeading)
            .background(Color(.systemBackground))
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Slot Helpers

    private func slotFor(day: String, period: Int) -> TimetableSlot? {
        slots.first(where: { $0.day == day && $0.period == period })
    }

    private func upsert(_ slot: TimetableSlot) {
        if let idx = slots.firstIndex(where: { $0.day == slot.day && $0.period == slot.period }) {
            slots[idx] = slot
        } else {
            slots.append(slot)
        }
    }

    // If a day’s period count is lowered, delete slots above it (keeps storage clean)
    private func trimSlotsAbovePeriodCounts() {
        slots.removeAll { slot in
            let maxPeriods = max(1, periodsByDay[slot.day, default: 8])
            return slot.period > maxPeriods
        }
    }

    // MARK: - Persistence: Slots

    private func persistSlots() {
        if let data = try? JSONEncoder().encode(slots) {
            storedData = data
        }
    }

    private func loadSlots() -> [TimetableSlot] {
        guard !storedData.isEmpty,
              let decoded = try? JSONDecoder().decode([TimetableSlot].self, from: storedData)
        else { return [] }
        return decoded
    }

    // MARK: - Persistence: Periods by day

    private func ensureDefaults() {
        // default to 8 if missing, but enforce min 1
        for day in days {
            periodsByDay[day] = max(1, periodsByDay[day] ?? 8)
        }
    }

    private func persistPeriodsByDay() {
        if let data = try? JSONEncoder().encode(periodsByDay) {
            periodsByDayData = data
        }
    }

    private func loadPeriodsByDay() -> [String: Int] {
        guard !periodsByDayData.isEmpty,
              let decoded = try? JSONDecoder().decode([String: Int].self, from: periodsByDayData)
        else { return [:] }
        return decoded
    }
}

// MARK: - Editor

struct TimetableEditor: View {
    @Environment(\.dismiss) private var dismiss

    @State var slot: TimetableSlot
    let onSave: (TimetableSlot) -> Void

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Slot")) {
                    Text("Day: \(slot.day)")
                    Text("Period: \(slot.period)")
                }

                Section(header: Text("Class")) {
                    TextField("Subject", text: $slot.subject)
                    TextField("Room", text: $slot.room)
                }

                Section {
                    Button(role: .destructive) {
                        slot.subject = ""
                        slot.room = ""
                        onSave(slot)
                        dismiss()
                    } label: {
                        Text("Clear this slot")
                    }
                }
            }
            .navigationTitle("Edit Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(slot)
                        dismiss()
                    }
                }
            }
        }
    }
}
