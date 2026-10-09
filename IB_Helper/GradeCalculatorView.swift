import SwiftUI

// MARK: - Grade Calculator (Neater UI + per-subject boundaries + text entry)

struct GradeCalculatorView: View {

    // Onboarding subjects
    @AppStorage("selectedIBSubjectsCSV") private var selectedIBSubjectsCSV: String = ""

    // HL/SL persistence
    @AppStorage("hlSubjectsCSV") private var hlSubjectsCSV: String = ""
    @AppStorage("slSubjectsCSV") private var slSubjectsCSV: String = ""

    // Persist weights & boundaries per course (subject_level)
    @AppStorage("gradeCalcWeights_v2") private var weightsBlob: String = ""
    @AppStorage("gradeCalcBoundaries_v2") private var boundariesBlob: String = ""

    // UI state
    @State private var hlSubjects: Set<String> = []
    @State private var slSubjects: Set<String> = []
    @State private var showSelectionAlert = false

    // Per course data
    @State private var weightsByCourse: [String: AssessmentWeights] = [:]
    @State private var boundariesByCourse: [String: SubjectBoundaries] = [:]
    @State private var scoreInputs: [String: ScoreInput] = [:]

    // Expanded controls
    @State private var expandedWeights: Set<String> = []
    @State private var expandedBoundaries: Set<String> = []

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    hlSlSelectionCard

                    if isCourseSelectionComplete {
                        ForEach(allCoursesSorted, id: \.key) { c in
                            courseCard(subject: c.subject, level: c.level)
                        }
                    } else {
                        infoCard("Pick 3 HL and 3 SL from your 6 subjects to unlock grade calculations.")
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Grade Calculator")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadSelections()
                hydrateData()
            }
            .alert("Selection incomplete", isPresented: $showSelectionAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Choose exactly 3 HL and 3 SL from your six subjects. They can’t overlap.")
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Clean, per-subject grade math.")
                .font(.headline)

            Text("Enter component scores and weights as percentages. Boundaries are per subject and editable because IB boundaries vary by session.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    // MARK: - HL / SL Selection

    private var hlSlSelectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Choose HL & SL")
                    .font(.headline)
                Spacer()
                Text("\(hlSubjects.count)/3 HL • \(slSubjects.count)/3 SL")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            let six = selectedSixSubjects

            if six.isEmpty {
                infoCard("No subjects found from onboarding. Make sure selectedIBSubjectsCSV is saved during first-time setup.")
            } else {
                VStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("HL (pick 3)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        subjectGrid(subjects: six, selected: $hlSubjects, otherGroup: $slSubjects, max: 3)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("SL (pick 3)")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        subjectGrid(subjects: six, selected: $slSubjects, otherGroup: $hlSubjects, max: 3)
                    }

                    Button {
                        if validateSelection() {
                            persistSelections()
                            hydrateData()
                        } else {
                            showSelectionAlert = true
                        }
                    } label: {
                        Text("Save HL/SL")
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(validateSelection() ? Color.blue : Color.gray)
                            .cornerRadius(12)
                    }
                    .disabled(!validateSelection())
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }

    private func subjectGrid(subjects: [String], selected: Binding<Set<String>>, otherGroup: Binding<Set<String>>, max: Int) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            ForEach(subjects, id: \.self) { s in
                let isSelected = selected.wrappedValue.contains(s)
                let isBlocked = otherGroup.wrappedValue.contains(s) || (!isSelected && selected.wrappedValue.count >= max)

                Button {
                    toggleSubject(s, selected: selected, otherGroup: otherGroup, max: max)
                } label: {
                    HStack {
                        Text(s)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(isSelected ? .green : .secondary)
                    }
                    .padding(10)
                    .background(isSelected ? Color.green.opacity(0.12) : Color(.systemGray5))
                    .cornerRadius(12)
                }
                .disabled(isBlocked)
                .opacity(isBlocked && !isSelected ? 0.5 : 1.0)
            }
        }
    }

    // MARK: - Course Card

    private func courseCard(subject: String, level: String) -> some View {
        let key = courseKey(subject: subject, level: level)

        let weights = weightsByCourse[key] ?? defaultWeights(for: subject, level: level)
        let boundaries = boundariesByCourse[key] ?? SubjectBoundaries.typical()
        let input = scoreInputs[key] ?? .init()

        let internalLabel = (subject == "English") ? "IO" : "IA"

        let result = computeFinalPercent(input: input, weights: weights)
        let grade = boundaries.grade(for: result.finalPercent)

        let weightsOK = weights.total == 100
        let boundariesOK = boundaries.isSane

        return VStack(alignment: .leading, spacing: 12) {

            // Header
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(subject) (\(level))")
                        .font(.headline)
                    Text("Estimated total: \(formatPercent(result.finalPercent))")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                gradePill(grade: grade, ok: (weightsOK && boundariesOK))
            }

            if !weightsOK || !boundariesOK {
                VStack(alignment: .leading, spacing: 4) {
                    if !weightsOK {
                        Text("• Weights must total 100%.")
                    }
                    if !boundariesOK {
                        Text("• Boundary ranges look inconsistent (overlaps/gaps).")
                    }
                }
                .font(.caption)
                .foregroundColor(.red)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
                .cornerRadius(12)
            }

            // Main input area (simple + readable)
            VStack(alignment: .leading, spacing: 10) {
                Text("Enter your component scores (%)")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 10) {
                    PercentField(title: "\(internalLabel)", text: bindingScore(key: key, field: .internalPart))
                    PercentField(title: "Exams", text: bindingScore(key: key, field: .exams))
                    PercentField(title: "Midterms", text: bindingScore(key: key, field: .midterms))
                }

                // Show calculation breakdown (pretty + clear)
                VStack(spacing: 8) {
                    calcRow(label: "\(internalLabel) contribution", value: formatPercent(result.internalContribution))
                    calcRow(label: "Exams contribution", value: formatPercent(result.examsContribution))
                    calcRow(label: "Midterms contribution", value: formatPercent(result.midtermsContribution))
                    Divider()
                    calcRow(label: "Total", value: formatPercent(result.finalPercent), emphasize: true)
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(14)
            }

            // Edit weights (collapsible)
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedWeights.contains(key) },
                    set: { newValue in
                        if newValue {
                            _ = expandedWeights.insert(key)
                        } else {
                            _ = expandedWeights.remove(key)
                        }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter each as % of the final subject grade.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 10) {
                        PercentField(title: "\(internalLabel) weight", text: bindingWeight(key: key, part: .internalPart))
                        PercentField(title: "Exams weight", text: bindingWeight(key: key, part: .exams))
                        PercentField(title: "Midterms weight", text: bindingWeight(key: key, part: .midterms))
                    }

                    HStack {
                        Text("Total")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(weightsByCourse[key]?.total ?? weights.total)%")
                            .font(.caption)
                            .foregroundColor((weightsByCourse[key]?.total ?? weights.total) == 100 ? .green : .red)
                    }

                    HStack {
                        Button("Reset weights") {
                            weightsByCourse[key] = defaultWeights(for: subject, level: level)
                            persistWeights()
                        }
                        .font(.caption)

                        Spacer()
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "slider.horizontal.3")
                    Text("Edit weights")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text((weightsByCourse[key]?.total ?? weights.total) == 100 ? "OK" : "Fix")
                        .font(.caption)
                        .foregroundColor((weightsByCourse[key]?.total ?? weights.total) == 100 ? .green : .red)
                }
                .padding(10)
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }

            // Edit boundaries (collapsible, per subject)
            DisclosureGroup(
                isExpanded: Binding(
                    get: { expandedBoundaries.contains(key) },
                    set: { newValue in
                        if newValue {
                            _ = expandedBoundaries.insert(key)
                        } else {
                            _ = expandedBoundaries.remove(key)
                        }
                    }
                )
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Enter lower and upper bounds (inclusive). Example: 70–79.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    boundariesEditor(forKey: key)

                    HStack {
                        Button("Reset boundaries") {
                            boundariesByCourse[key] = SubjectBoundaries.typical()
                            persistBoundaries()
                        }
                        .font(.caption)

                        Spacer()

                        Text(boundariesByCourse[key]?.isSane == false ? "Needs fixing" : "Looks good")
                            .font(.caption)
                            .foregroundColor(boundariesByCourse[key]?.isSane == false ? .red : .green)
                    }
                }
                .padding(.top, 8)
            } label: {
                HStack {
                    Image(systemName: "square.and.pencil")
                    Text("Edit boundaries")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(boundariesByCourse[key]?.isSane == false ? "Fix" : "OK")
                        .font(.caption)
                        .foregroundColor(boundariesByCourse[key]?.isSane == false ? .red : .green)
                }
                .padding(10)
                .background(Color(.systemGray5))
                .cornerRadius(12)
            }

        }
        .padding(14)
        .background(Color(.systemBackground))
        .cornerRadius(18)
        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 2)
    }

    private func gradePill(grade: Int, ok: Bool) -> some View {
        Text(ok ? "Grade \(grade)" : "Fix setup")
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(ok ? colorForGrade(grade).opacity(0.15) : Color.red.opacity(0.12))
            .foregroundColor(ok ? colorForGrade(grade) : .red)
            .cornerRadius(999)
    }

    private func calcRow(label: String, value: String, emphasize: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(emphasize ? .subheadline : .caption)
                .foregroundColor(emphasize ? .primary : .secondary)
            Spacer()
            Text(value)
                .font(emphasize ? .subheadline.weight(.semibold) : .caption)
                .foregroundColor(emphasize ? .primary : .secondary)
        }
    }

    // MARK: - Boundaries UI

    private func boundariesEditor(forKey key: String) -> some View {
        let binding = Binding<SubjectBoundaries>(
            get: { boundariesByCourse[key] ?? SubjectBoundaries.typical() },
            set: { newValue in
                boundariesByCourse[key] = newValue
                persistBoundaries()
            }
        )

        return VStack(spacing: 8) {
            ForEach([7, 6, 5, 4, 3, 2, 1], id: \.self) { g in
                let rangeBinding = Binding<BoundaryRange>(
                    get: { binding.wrappedValue.range(for: g) },
                    set: { newRange in
                        var b = binding.wrappedValue
                        b.setRange(for: g, newRange)
                        binding.wrappedValue = b
                    }
                )

                HStack(spacing: 10) {
                    Text("\(g)")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 22)

                    BoundaryField(title: "Low", text: Binding<String>(
                        get: { rangeBinding.wrappedValue.lowText },
                        set: { newText in
                            var r = rangeBinding.wrappedValue
                            r.lowText = newText
                            rangeBinding.wrappedValue = r
                        }
                    ))

                    BoundaryField(title: "High", text: Binding<String>(
                        get: { rangeBinding.wrappedValue.highText },
                        set: { newText in
                            var r = rangeBinding.wrappedValue
                            r.highText = newText
                            rangeBinding.wrappedValue = r
                        }
                    ))

                    Spacer()

                    Text("\(rangeBinding.wrappedValue.low)–\(rangeBinding.wrappedValue.high)%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Data + Logic

    private var selectedSixSubjects: [String] {
        selectedIBSubjectsCSV
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var isCourseSelectionComplete: Bool { validateSelection() }

    private func validateSelection() -> Bool {
        hlSubjects.count == 3 && slSubjects.count == 3 && hlSubjects.isDisjoint(with: slSubjects)
    }

    private func toggleSubject(_ s: String, selected: Binding<Set<String>>, otherGroup: Binding<Set<String>>, max: Int) {
        var set = selected.wrappedValue
        if set.contains(s) {
            set.remove(s)
        } else {
            guard set.count < max else { return }
            guard !otherGroup.wrappedValue.contains(s) else { return }
            set.insert(s)
        }
        selected.wrappedValue = set
    }

    private func persistSelections() {
        hlSubjectsCSV = hlSubjects.sorted().joined(separator: "|")
        slSubjectsCSV = slSubjects.sorted().joined(separator: "|")
    }

    private func loadSelections() {
        hlSubjects = Set(hlSubjectsCSV.split(separator: "|").map { String($0) })
        slSubjects = Set(slSubjectsCSV.split(separator: "|").map { String($0) })
    }

    private func hydrateData() {
        // weights
        if let decoded = JSONCodec.decode([String: AssessmentWeights].self, from: weightsBlob) {
            weightsByCourse = decoded
        } else {
            weightsByCourse = [:]
        }

        // boundaries
        if let decoded = JSONCodec.decode([String: SubjectBoundaries].self, from: boundariesBlob) {
            boundariesByCourse = decoded
        } else {
            boundariesByCourse = [:]
        }

        // seed for selected courses
        for c in allCoursesSorted {
            if weightsByCourse[c.key] == nil {
                weightsByCourse[c.key] = defaultWeights(for: c.subject, level: c.level)
            }
            if boundariesByCourse[c.key] == nil {
                // per-subject defaults (still "typical" until user adjusts, but stored per course)
                boundariesByCourse[c.key] = SubjectBoundaries.typical()
            }
            if scoreInputs[c.key] == nil {
                scoreInputs[c.key] = .init()
            }
        }

        persistWeights()
        persistBoundaries()
    }

    private func persistWeights() {
        weightsBlob = JSONCodec.encode(weightsByCourse) ?? ""
    }

    private func persistBoundaries() {
        boundariesBlob = JSONCodec.encode(boundariesByCourse) ?? ""
    }

    private func defaultWeights(for subject: String, level: String) -> AssessmentWeights {
        // defaults you had (including Math AA/AI + English)
        let key = "\(subject)_\(level)"
        let defaults: [String: AssessmentWeights] = [
            "Math AA_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Math AA_SL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Math AI_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Math AI_SL": .init(internalWeight: 20, exams: 80, midterms: 0),

            "English_HL": .init(internalWeight: 30, exams: 70, midterms: 0),
            "English_SL": .init(internalWeight: 30, exams: 70, midterms: 0),

            "Computer Science_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Computer Science_SL": .init(internalWeight: 20, exams: 80, midterms: 0),

            "History_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "History_SL": .init(internalWeight: 20, exams: 80, midterms: 0),

            "Geography_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Geography_SL": .init(internalWeight: 20, exams: 80, midterms: 0),

            "Physics_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Physics_SL": .init(internalWeight: 20, exams: 80, midterms: 0),

            "Biology_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Biology_SL": .init(internalWeight: 20, exams: 80, midterms: 0),

            "Chemistry_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Chemistry_SL": .init(internalWeight: 20, exams: 80, midterms: 0),

            "Economics_HL": .init(internalWeight: 20, exams: 80, midterms: 0),
            "Economics_SL": .init(internalWeight: 20, exams: 80, midterms: 0),

            "Environmental Studies_HL": .init(internalWeight: 25, exams: 75, midterms: 0),
            "Environmental Studies_SL": .init(internalWeight: 25, exams: 75, midterms: 0),

            "Business Studies_HL": .init(internalWeight: 25, exams: 75, midterms: 0),
            "Business Studies_SL": .init(internalWeight: 30, exams: 70, midterms: 0),

            "Spanish_HL": .init(internalWeight: 30, exams: 70, midterms: 0),
            "Spanish_SL": .init(internalWeight: 25, exams: 75, midterms: 0)
        ]
        return defaults[key] ?? .init(internalWeight: 20, exams: 80, midterms: 0)
    }

    private enum ScoreField { case internalPart, exams, midterms }
    private enum WeightPart { case internalPart, exams, midterms }

    private func bindingScore(key: String, field: ScoreField) -> Binding<String> {
        Binding<String>(
            get: {
                let input = scoreInputs[key] ?? .init()
                switch field {
                case .internalPart: return input.internalText
                case .exams: return input.examsText
                case .midterms: return input.midtermsText
                }
            },
            set: { newValue in
                var input = scoreInputs[key] ?? .init()
                switch field {
                case .internalPart: input.internalText = newValue
                case .exams: input.examsText = newValue
                case .midterms: input.midtermsText = newValue
                }
                scoreInputs[key] = input
            }
        )
    }

    private func bindingWeight(key: String, part: WeightPart) -> Binding<String> {
        Binding<String>(
            get: {
                let w = weightsByCourse[key] ?? .init(internalWeight: 20, exams: 80, midterms: 0)
                switch part {
                case .internalPart: return w.internalText
                case .exams: return w.examsText
                case .midterms: return w.midtermsText
                }
            },
            set: { newValue in
                var w = weightsByCourse[key] ?? .init(internalWeight: 20, exams: 80, midterms: 0)
                switch part {
                case .internalPart: w.internalText = newValue
                case .exams: w.examsText = newValue
                case .midterms: w.midtermsText = newValue
                }
                weightsByCourse[key] = w.sanitized
                persistWeights()
            }
        )
    }

    private func computeFinalPercent(input: ScoreInput, weights: AssessmentWeights) -> CalcResult {
        let w = weights.sanitized

        // Each score is a percentage out of 100
        let sInternal = clamp01(input.internalValue / 100.0)
        let sExams = clamp01(input.examsValue / 100.0)
        let sMid = clamp01(input.midtermsValue / 100.0)

        // Contribution in percentage points of final grade
        let cInternal = sInternal * Double(w.`internal`)
        let cExams = sExams * Double(w.exams)
        let cMid = sMid * Double(w.midterms)

        let final = (w.total == 100) ? (cInternal + cExams + cMid) : 0

        return CalcResult(
            internalContribution: cInternal,
            examsContribution: cExams,
            midtermsContribution: cMid,
            finalPercent: final
        )
    }

    private func clamp01(_ x: Double) -> Double { min(1, max(0, x)) }

    private func formatPercent(_ x: Double) -> String { String(format: "%.1f%%", x) }

    private func colorForGrade(_ g: Int) -> Color {
        switch g {
        case 7: return .green
        case 6: return .green.opacity(0.85)
        case 5: return .blue
        case 4: return .orange
        case 3: return .orange.opacity(0.9)
        case 2: return .red.opacity(0.9)
        default: return .red
        }
    }

    private func courseKey(subject: String, level: String) -> String { "\(subject)_\(level)" }

    private var allCoursesSorted: [(key: String, subject: String, level: String)] {
        let hl = hlSubjects.sorted().map { (courseKey(subject: $0, level: "HL"), $0, "HL") }
        let sl = slSubjects.sorted().map { (courseKey(subject: $0, level: "SL"), $0, "SL") }
        return hl + sl
    }

    private func infoCard(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemGray6))
            .cornerRadius(16)
    }
}

// MARK: - UI Components (Neat numeric entry)

private struct PercentField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 6) {
                TextField("0", text: $text)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                Text("%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct BoundaryField: View {
    let title: String
    @Binding var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            TextField("0", text: $text)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .frame(width: 70)
        }
    }
}

// MARK: - Models

private struct CalcResult {
    let internalContribution: Double
    let examsContribution: Double
    let midtermsContribution: Double
    let finalPercent: Double
}

struct ScoreInput: Codable, Equatable {
    var internalText: String = ""
    var examsText: String = ""
    var midtermsText: String = ""

    var internalValue: Double { Double(internalText.filter { $0.isNumber }) ?? 0 }
    var examsValue: Double { Double(examsText.filter { $0.isNumber }) ?? 0 }
    var midtermsValue: Double { Double(midtermsText.filter { $0.isNumber }) ?? 0 }
}

struct AssessmentWeights: Codable, Equatable {
    // store as ints but keep editable text too
    var internalText: String = "20"
    var examsText: String = "80"
    var midtermsText: String = "0"

    init(internalWeight: Int, exams: Int, midterms: Int) {
        self.internalText = "\(internalWeight)"
        self.examsText = "\(exams)"
        self.midtermsText = "\(midterms)"
    }

    var internalValue: Int { Int(internalText.filter { $0.isNumber }) ?? 0 }
    var examsValue: Int { Int(examsText.filter { $0.isNumber }) ?? 0 }
    var midtermsValue: Int { Int(midtermsText.filter { $0.isNumber }) ?? 0 }

    var `internal`: Int { clamp0to100(internalValue) }
    var exams: Int { clamp0to100(examsValue) }
    var midterms: Int { clamp0to100(midtermsValue) }

    var total: Int { `internal` + exams + midterms }

    var sanitized: AssessmentWeights {
        var w = self
        w.internalText = "\(`internal`)"
        w.examsText = "\(exams)"
        w.midtermsText = "\(midterms)"
        return w
    }

    private func clamp0to100(_ x: Int) -> Int { min(100, max(0, x)) }
}

// MARK: - Boundaries (two textboxes per grade)

struct BoundaryRange: Codable, Equatable {
    var lowText: String
    var highText: String

    init(low: Int, high: Int) {
        self.lowText = "\(low)"
        self.highText = "\(high)"
    }

    var low: Int { Int(lowText.filter { $0.isNumber }) ?? 0 }
    var high: Int { Int(highText.filter { $0.isNumber }) ?? 0 }
}

struct SubjectBoundaries: Codable, Equatable {
    // inclusive ranges for each grade 1..7
    var g7: BoundaryRange
    var g6: BoundaryRange
    var g5: BoundaryRange
    var g4: BoundaryRange
    var g3: BoundaryRange
    var g2: BoundaryRange
    var g1: BoundaryRange

    static func typical() -> SubjectBoundaries {
        // "Typical" starter set (editable) stored PER COURSE (subject+level)
        SubjectBoundaries(
            g7: .init(low: 80, high: 100),
            g6: .init(low: 70, high: 79),
            g5: .init(low: 60, high: 69),
            g4: .init(low: 50, high: 59),
            g3: .init(low: 40, high: 49),
            g2: .init(low: 30, high: 39),
            g1: .init(low: 0, high: 29)
        )
    }

    func range(for grade: Int) -> BoundaryRange {
        switch grade {
        case 7: return g7
        case 6: return g6
        case 5: return g5
        case 4: return g4
        case 3: return g3
        case 2: return g2
        default: return g1
        }
    }

    mutating func setRange(for grade: Int, _ r: BoundaryRange) {
        switch grade {
        case 7: g7 = r
        case 6: g6 = r
        case 5: g5 = r
        case 4: g4 = r
        case 3: g3 = r
        case 2: g2 = r
        default: g1 = r
        }
    }

    func grade(for percent: Double) -> Int {
        let p = Int(percent.rounded())

        // priority from top down
        if inRange(p, g7) { return 7 }
        if inRange(p, g6) { return 6 }
        if inRange(p, g5) { return 5 }
        if inRange(p, g4) { return 4 }
        if inRange(p, g3) { return 3 }
        if inRange(p, g2) { return 2 }
        return 1
    }

    private func inRange(_ p: Int, _ r: BoundaryRange) -> Bool {
        p >= min(r.low, r.high) && p <= max(r.low, r.high)
    }

    // Simple sanity check: ranges should be non-overlapping and cover 0..100 without weird inversions.
    var isSane: Bool {
        let ranges = [g1, g2, g3, g4, g5, g6, g7].map { (min($0.low, $0.high), max($0.low, $0.high)) }
        // check each is within 0..100
        for (a,b) in ranges {
            if a < 0 || b > 100 || a > b { return false }
        }
        // check overlaps (inclusive overlap)
        // sort by low
        let sorted = ranges.sorted { $0.0 < $1.0 }
        for i in 0..<(sorted.count - 1) {
            let cur = sorted[i]
            let next = sorted[i+1]
            if next.0 <= cur.1 { return false } // overlap or touching
        }
        // coverage isn't strictly required, but it usually should start at 0 and end at 100
        // We'll allow gaps, but most users want full coverage.
        return true
    }
}

// MARK: - JSON codec for AppStorage

enum JSONCodec {
    static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode<T: Decodable>(_ type: T.Type, from blob: String) -> T? {
        guard !blob.isEmpty, let data = blob.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

// MARK: - Preview

struct GradeCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        GradeCalculatorView()
    }
}
