import SwiftUI

// MARK: - Models

enum CoreType: String, CaseIterable, Identifiable, Codable {
    case ee = "EE"
    case tok = "TOK"
    var id: String { rawValue }
}

struct CoreMilestone: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var dueDate: Date?
    var isDone: Bool = false
    var notes: String = ""
}

struct CoreTrackerData: Codable, Equatable {
    var eeTopic: String = ""
    var eeSubject: String = ""
    var eeSupervisor: String = ""
    var eeWordCount: Int = 0

    var tokPrompt: String = ""
    var tokTheme: String = ""
    var tokTeacher: String = ""

    var milestonesEE: [CoreMilestone] = [
        .init(title: "Choose subject + supervisor"),
        .init(title: "Finalize research question"),
        .init(title: "Outline + sources"),
        .init(title: "First draft"),
        .init(title: "Final draft + reflections"),
    ]

    var milestonesTOK: [CoreMilestone] = [
        .init(title: "Pick exhibition prompt"),
        .init(title: "Choose 3 objects"),
        .init(title: "Draft exhibition commentary"),
        .init(title: "Essay outline"),
        .init(title: "Final essay + citations"),
    ]
}

// MARK: - Persistence

private struct Store {
    static func encode<T: Encodable>(_ value: T) -> String {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys]
        guard let data = try? enc.encode(value) else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func decode<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard !string.isEmpty, let data = string.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Main View

struct EE_TOKView: View {
    @AppStorage("core_tracker_v1") private var savedJSON: String = ""

    @State private var core: CoreTrackerData = CoreTrackerData()
    @State private var selected: CoreType = .ee

    @State private var showingAdd = false
    @State private var editingMilestone: CoreMilestone? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    topSwitcher
                    progressCard

                    if selected == .ee {
                        eeInfoCard
                        milestonesCard(title: "EE Milestones", milestones: $core.milestonesEE)
                    } else {
                        tokInfoCard
                        milestonesCard(title: "TOK Milestones", milestones: $core.milestonesTOK)
                    }

                    Spacer(minLength: 24)
                }
                .padding()
            }
            .navigationTitle("EE/TOK")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAdd = true } label: { Image(systemName: "plus") }
                }
            }
            .onAppear { load() }
            .onChange(of: core) { _ in save() }
            .sheet(isPresented: $showingAdd) {
                MilestoneEditorSheet(
                    title: "Add Milestone",
                    initial: CoreMilestone(title: ""),
                    onSave: { newItem in addMilestone(newItem) }
                )
            }
            .sheet(item: $editingMilestone) { item in
                MilestoneEditorSheet(
                    title: "Edit Milestone",
                    initial: item,
                    onSave: { updated in updateMilestone(updated) }
                )
            }
        }
    }

    // MARK: - UI

    private var topSwitcher: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("Core", selection: $selected) {
                ForEach(CoreType.allCases) { c in
                    Text(c.rawValue).tag(c)
                }
            }
            .pickerStyle(.segmented)

            Text(selected == .ee ? "Extended Essay tracker" : "Theory of Knowledge tracker")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var progressCard: some View {
        let list = (selected == .ee) ? core.milestonesEE : core.milestonesTOK
        let done = list.filter { $0.isDone }.count
        let total = max(list.count, 1)
        let progress = Double(done) / Double(total)
        let nextUp = nextMilestone(from: list)

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress").font(.headline)
                    Text("\(done) of \(total) complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }

            ProgressView(value: progress).tint(.accentColor)

            VStack(alignment: .leading, spacing: 4) {
                Text("Next up").font(.subheadline).bold()
                if let nextUp {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(nextUp.title).font(.subheadline)
                            if let due = nextUp.dueDate {
                                Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("No due date set")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    Text("All milestones done. Endgame mode 🏁")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var eeInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EE Details").font(.headline)

            LabeledField(label: "Subject", text: $core.eeSubject, placeholder: "e.g., Biology")
            LabeledField(label: "Topic / RQ", text: $core.eeTopic, placeholder: "e.g., How does X affect Y?")
            LabeledField(label: "Supervisor", text: $core.eeSupervisor, placeholder: "Name")

            HStack {
                Text("Word count").font(.subheadline).bold()
                Spacer()
                TextField("0", value: $core.eeWordCount, formatter: NumberFormatter.intOnly)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 110)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Keep milestones small: “Draft intro”, “Fix citations”… it makes progress feel real.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var tokInfoCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TOK Details").font(.headline)

            LabeledField(label: "Theme", text: $core.tokTheme, placeholder: "e.g., Knowledge & technology")
            LabeledField(label: "Exhibition prompt / essay title", text: $core.tokPrompt, placeholder: "Paste your prompt here")
            LabeledField(label: "Teacher", text: $core.tokTeacher, placeholder: "Name")

            Text("Add milestones like “Object 1 chosen” to avoid last-minute chaos.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func milestonesCard(title: String, milestones: Binding<[CoreMilestone]>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title).font(.headline)
                Spacer()
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }

            if milestones.wrappedValue.isEmpty {
                Text("No milestones yet. Add one with +.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(milestones.wrappedValue) { m in
                    milestoneRow(m, milestones: milestones)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func milestoneRow(_ m: CoreMilestone, milestones: Binding<[CoreMilestone]>) -> some View {
        Button { editingMilestone = m } label: {
            HStack(spacing: 12) {
                Button {
                    toggleDone(m, milestones: milestones)
                } label: {
                    Image(systemName: m.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 2) {
                    Text(m.title)
                        .font(.subheadline)
                        .strikethrough(m.isDone)
                        .foregroundStyle(m.isDone ? .secondary : .primary)

                    if let due = m.dueDate {
                        Text("Due \(due.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !m.notes.isEmpty {
                        Text(m.notes)
                            .lineLimit(1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No due date")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Menu {
                    Button { editingMilestone = m } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        deleteMilestone(m, milestones: milestones)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.secondary)
                        .padding(6)
                }
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logic

    private func nextMilestone(from list: [CoreMilestone]) -> CoreMilestone? {
        let undone = list.filter { !$0.isDone }
        if undone.isEmpty { return nil }

        let withDue = undone.compactMap { m -> (CoreMilestone, Date)? in
            guard let d = m.dueDate else { return nil }
            return (m, d)
        }.sorted { $0.1 < $1.1 }

        if let first = withDue.first { return first.0 }
        return undone.first
    }

    private func addMilestone(_ newItem: CoreMilestone) {
        let trimmed = newItem.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var item = newItem
        item.title = trimmed

        if selected == .ee {
            core.milestonesEE.insert(item, at: 0)
        } else {
            core.milestonesTOK.insert(item, at: 0)
        }
    }

    private func updateMilestone(_ updated: CoreMilestone) {
        if selected == .ee {
            if let idx = core.milestonesEE.firstIndex(where: { $0.id == updated.id }) {
                core.milestonesEE[idx] = updated
            }
        } else {
            if let idx = core.milestonesTOK.firstIndex(where: { $0.id == updated.id }) {
                core.milestonesTOK[idx] = updated
            }
        }
    }

    private func toggleDone(_ m: CoreMilestone, milestones: Binding<[CoreMilestone]>) {
        var list = milestones.wrappedValue
        guard let idx = list.firstIndex(where: { $0.id == m.id }) else { return }
        list[idx].isDone.toggle()
        milestones.wrappedValue = list

        if selected == .ee { core.milestonesEE = milestones.wrappedValue }
        else { core.milestonesTOK = milestones.wrappedValue }
    }

    private func deleteMilestone(_ m: CoreMilestone, milestones: Binding<[CoreMilestone]>) {
        milestones.wrappedValue.removeAll { $0.id == m.id }
        if selected == .ee { core.milestonesEE = milestones.wrappedValue }
        else { core.milestonesTOK = milestones.wrappedValue }
    }

    // MARK: - Persistence

    private func load() {
        if let decoded: CoreTrackerData = Store.decode(CoreTrackerData.self, from: savedJSON) {
            core = decoded
        } else {
            core = CoreTrackerData()
        }
    }

    private func save() {
        savedJSON = Store.encode(core)
    }
}

// MARK: - Editor Sheet (THIS fixes your error)

private struct MilestoneEditorSheet: View {
    let title: String
    let initial: CoreMilestone
    let onSave: (CoreMilestone) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var milestone: CoreMilestone
    @State private var hasDueDate: Bool

    init(title: String, initial: CoreMilestone, onSave: @escaping (CoreMilestone) -> Void) {
        self.title = title
        self.initial = initial
        self.onSave = onSave
        _milestone = State(initialValue: initial)
        _hasDueDate = State(initialValue: initial.dueDate != nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Milestone") {
                    TextField("Title", text: $milestone.title)
                    TextField("Notes (optional)", text: $milestone.notes, axis: .vertical)
                        .lineLimit(2...6)
                }

                Section("Due date") {
                    Toggle("Set due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker(
                            "Due",
                            selection: Binding(
                                get: { milestone.dueDate ?? Date() },
                                set: { milestone.dueDate = $0 }
                            ),
                            displayedComponents: [.date]
                        )
                    }
                }

                Section {
                    Toggle("Mark as done", isOn: $milestone.isDone)
                }
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let t = milestone.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        milestone.title = t
                        if !hasDueDate { milestone.dueDate = nil }
                        guard !t.isEmpty else { return }
                        onSave(milestone)
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Components

private struct LabeledField: View {
    let label: String
    @Binding var text: String
    var placeholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.subheadline).bold()
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...3)
                .textFieldStyle(.roundedBorder)
        }
    }
}

private extension NumberFormatter {
    static var intOnly: NumberFormatter {
        let nf = NumberFormatter()
        nf.numberStyle = .none
        nf.maximumFractionDigits = 0
        return nf
    }
}
