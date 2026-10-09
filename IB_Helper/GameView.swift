import SwiftUI
import Combine

// MARK: - Procrastination Roulette (Upgraded + Ready-to-Go)

struct GameView: View {
    // Optional integration: read onboarding subjects CSV if you have it
    @AppStorage("selectedIBSubjectsCSV") private var selectedIBSubjectsCSV: String = ""

    // Persistence
    @AppStorage("prroulette_xp") private var xpStorage: Int = 0
    @AppStorage("prroulette_highscore") private var highscoreStorage: Int = 0
    @AppStorage("prroulette_streak") private var streakStorage: Int = 0
    @AppStorage("prroulette_lastDayKey") private var lastDayKeyStorage: String = ""

    // Daily mechanics
    @AppStorage("prroulette_swapsLeft") private var swapsLeftStorage: Int = 2
    @AppStorage("prroulette_shields") private var shieldsStorage: Int = 0
    @AppStorage("prroulette_doubleRewardTokens") private var doubleRewardTokensStorage: Int = 0
    @AppStorage("prroulette_extraSwapsPurchasedToday") private var extraSwapsPurchasedTodayStorage: Int = 0

    // Wheel setup / loadout
    @AppStorage("prroulette_enabledTypes") private var enabledTypesStorage: String = TaskType.allCases.map { $0.rawValue }.joined(separator: ",")
    @AppStorage("prroulette_chaos") private var chaosStorage: Double = 0.35 // 0 = focused, 1 = spicy

    // UI State
    @State private var rotation: Angle = .zero
    @State private var isSpinning = false

    @State private var segments: [WheelSegment] = []
    @State private var activeSegment: WheelSegment? = nil

    // Reveal sheet + flows
    @State private var showReveal = false
    @State private var showHistory = false
    @State private var showSetup = false
    @State private var showShop = false

    // History
    @AppStorage("prroulette_history") private var historyStorage: String = "" // newline-separated
    @State private var history: [String] = []

    // Focus Run (Pomodoro / Timed)
    @State private var showFocusRun = false
    @State private var focusConfig: FocusConfig? = nil

    // Toast (simple)
    @State private var toastText: String? = nil

    // MARK: - Computed
    private var xp: Int { xpStorage }
    private var streak: Int { streakStorage }
    private var swapsLeft: Int { swapsLeftStorage }
    private var chaos: Double { chaosStorage.clamped(to: 0...1) }

    private var dayKey: String {
        // local day identity
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(comps.year ?? 0)-\(comps.month ?? 0)-\(comps.day ?? 0)"
    }

    private var enabledTypes: Set<TaskType> {
        let parts = enabledTypesStorage.split(separator: ",").map { String($0) }
        let types = parts.compactMap(TaskType.init(rawValue:))
        return Set(types.isEmpty ? TaskType.allCases : types)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                topBar

                wheelStage

                bottomHintRow
            }
            .padding()
            .navigationTitle("Roulette")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showSetup = true
                        } label: {
                            Label("Wheel Setup", systemImage: "slider.horizontal.3")
                        }

                        Button {
                            showShop = true
                        } label: {
                            Label("Shop", systemImage: "bag")
                        }

                        Button {
                            showHistory = true
                        } label: {
                            Label("History", systemImage: "clock.arrow.circlepath")
                        }

                        Divider()

                        Button(role: .destructive) {
                            resetXPAndStreak()
                        } label: {
                            Label("Reset XP & Streak", systemImage: "trash")
                        }

                        Button(role: .destructive) {
                            highscoreStorage = 0
                            toast("Highscore reset")
                        } label: {
                            Label("Reset Highscore", systemImage: "trophy")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                rolloverIfNeeded()
                loadHistory()
                rebuildWheel()
            }
            .sheet(isPresented: $showReveal) {
                if let seg = activeSegment {
                    SpinRevealSheet(
                        segment: seg,
                        swapsLeft: swapsLeft,
                        shields: shieldsStorage,
                        doubleTokens: doubleRewardTokensStorage,
                        onStart: { start(seg) },
                        onSwap: { swap(seg) },
                        onSkip: { skip(seg) },
                        onDismiss: { showReveal = false }
                    )
                    .presentationDetents([.fraction(0.45), .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showHistory) {
                HistorySheet(
                    history: history,
                    onClear: { clearHistory() }
                )
            }
            .sheet(isPresented: $showSetup) {
                WheelSetupSheet(
                    subjectsCSV: selectedIBSubjectsCSV,
                    enabledTypes: enabledTypes,
                    chaos: chaosStorage,
                    onSave: { newEnabled, newChaos in
                        enabledTypesStorage = newEnabled.map { $0.rawValue }.sorted().joined(separator: ",")
                        chaosStorage = newChaos
                        rebuildWheel()
                        toast("Wheel updated")
                    }
                )
            }
            .sheet(isPresented: $showShop) {
                ShopSheet(
                    xp: xp,
                    swapsLeft: swapsLeft,
                    shields: shieldsStorage,
                    doubleTokens: doubleRewardTokensStorage,
                    canBuyExtraSwapToday: extraSwapsPurchasedTodayStorage == 0,
                    onBuyExtraSwap: { buyExtraSwap() },
                    onBuyShield: { buyShield() },
                    onBuyDoubleToken: { buyDoubleToken() }
                )
            }
            .fullScreenCover(isPresented: $showFocusRun) {
                if let cfg = focusConfig {
                    FocusRunView(
                        config: cfg,
                        onCancel: {
                            showFocusRun = false
                            focusConfig = nil
                            toast("Run cancelled")
                        },
                        onComplete: { completed in
                            showFocusRun = false
                            let seg = cfg.segment
                            focusConfig = nil
                            if completed {
                                complete(segment: seg, usedDoubleToken: cfg.useDoubleToken)
                            } else {
                                toast("No reward this time")
                            }
                        }
                    )
                }
            }
            .overlay(alignment: .top) {
                if let toastText {
                    ToastView(text: toastText)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.35) {
                                withAnimation(.easeInOut) { self.toastText = nil }
                            }
                        }
                        .padding(.top, 6)
                }
            }
        }
    }

    // MARK: - UI

    private var topBar: some View {
        VStack(spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("XP")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(xp) XP")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text("Streak")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(streak) 🔥")
                        .font(.system(size: 22, weight: .semibold, design: .rounded))
                }
            }

            HStack {
                ProgressView(value: min(Double(xp % 200) / 200.0, 1.0))
                    .tint(.green)

                Spacer(minLength: 12)

                HStack(spacing: 10) {
                    Label("\(swapsLeft)", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(shieldsStorage)", systemImage: "shield.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Label("\(doubleRewardTokensStorage)", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("Highscore: \(highscoreStorage) XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(dailyQuestText)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var wheelStage: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 8)
                    .frame(height: 360)

                VStack(spacing: 10) {
                    ZStack {
                        WheelView(segments: segments, rotation: rotation)
                            .frame(width: 290, height: 290)
                            .padding(.top, 6)

                        VStack {
                            Image(systemName: "arrowtriangle.down.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.tint)
                                .shadow(radius: 3)
                                .offset(y: -150)
                            Spacer()
                        }
                    }

                    HStack(spacing: 12) {
                        Button {
                            spin(style: .normal)
                        } label: {
                            Label(isSpinning ? "Spinning..." : "Spin", systemImage: "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isSpinning || segments.isEmpty)
                        .buttonStyle(.borderedProminent)

                        Button {
                            spin(style: .quick)
                        } label: {
                            Label("Quick", systemImage: "bolt.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .disabled(isSpinning || segments.isEmpty)
                        .buttonStyle(.bordered)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
                }
            }
        }
    }

    private var bottomHintRow: some View {
        HStack {
            Text("Spin. Reveal. Start a run. Earn power-ups. Repeat. 🎡")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Button {
                showHistory = true
            } label: {
                Label("History", systemImage: "clock")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Daily Quest (tiny loop)
    private var dailyQuestText: String {
        // lightweight quest: complete 2 runs today
        // We’ll infer “today completions” from history lines with dayKey and "[DONE]"
        let todayDone = history.filter { $0.contains(dayKey) && $0.contains("[DONE]") }.count
        if todayDone >= 2 { return "Daily Quest: Done ✅" }
        return "Daily Quest: \(todayDone)/2 completed"
    }

    // MARK: - Actions

    private enum SpinStyle { case normal, quick }

    private func spin(style: SpinStyle) {
        rolloverIfNeeded()
        guard !isSpinning else { return }
        guard !segments.isEmpty else { toast("No tasks enabled"); return }

        isSpinning = true
        activeSegment = nil

        let segmentCount = segments.count
        let targetIndex = Int.random(in: 0..<segmentCount)

        let spins: Double = (style == .normal) ? Double(Int.random(in: 3...6)) : 1.0
        let degreesPer = 360.0 / Double(segmentCount)
        let final = spins * 360.0 + Double(targetIndex) * degreesPer + (style == .normal ? degreesPer * 0.45 : degreesPer * 0.15)

        let duration: Double = (style == .normal) ? 1.15 : 0.75
        let anim: Animation = (style == .normal)
            ? .interpolatingSpring(stiffness: 120, damping: 18)
            : .easeOut(duration: duration)

        withAnimation(anim) {
            rotation += .degrees(final)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            isSpinning = false
            let normalized = (rotation.degrees.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
            let landed = Int((normalized / (360.0 / Double(segmentCount))).rounded(.toNearestOrAwayFromZero)) % segmentCount
            let finalIndex = (segmentCount - landed) % segmentCount
            if let seg = segments[safe: finalIndex] {
                activeSegment = seg
                addHistory("[\(dayKey)] \(seg.title) (\(seg.type.rawValue), \(seg.difficulty.rawValue)) \(seg.modifier.badgeText)")
                haptic(.heavy)
                withAnimation(.easeInOut) { showReveal = true }
            }
        }
    }

    private func start(_ seg: WheelSegment) {
        // Start can be a focus run (pomodoro/timed) OR instant “short” accept.
        showReveal = false
        haptic(.medium)

        // If user has double token, allow using it only on completion runs, not instant rewards.
        switch seg.modifier.kind {
        case .pomodoro:
            focusConfig = FocusConfig(segment: seg, seconds: 25 * 60, useDoubleToken: false)
            showFocusRun = true
            toast("Focus Run started")
        case .timedChallenge:
            focusConfig = FocusConfig(segment: seg, seconds: 10 * 60, useDoubleToken: false)
            showFocusRun = true
            toast("Timed Run started")
        case .shortTask:
            // quick accept: award smaller but immediate
            let award = computeAward(for: seg, completed: true, usedDoubleToken: false, instant: true)
            gainXP(award)
            markDone(seg)
            toast("+\(award) XP (quick win)")
            activeSegment = nil
        case .doubleXP:
            // make doubleXP meaningful: encourage a run, but still let user proceed
            focusConfig = FocusConfig(segment: seg, seconds: 25 * 60, useDoubleToken: false)
            showFocusRun = true
            toast("Double reward run")
        case .none:
            // Let user choose: we’ll start a short 15-min run to keep gameplay snappy
            focusConfig = FocusConfig(segment: seg, seconds: 15 * 60, useDoubleToken: false)
            showFocusRun = true
            toast("Study sprint started")
        case .bonusSkip:
            // treat as “free candy”: instant small award on start
            let award = computeAward(for: seg, completed: true, usedDoubleToken: false, instant: true)
            gainXP(award)
            markDone(seg)
            toast("+\(award) XP")
            activeSegment = nil
        }
    }

    private func swap(_ seg: WheelSegment) {
        rolloverIfNeeded()
        guard swapsLeftStorage > 0 else {
            // allow buying swap with XP as a fallback: 10 XP
            if xpStorage >= 10 {
                xpStorage -= 10
                swapsLeftStorage = 1
                toast("Bought 1 swap (-10 XP)")
            } else {
                toast("No swaps left")
                return
            }
            return
        }

        swapsLeftStorage -= 1
        toast("Swap used (\(swapsLeftStorage) left)")
        haptic(.light)

        // Reroll by just spinning quickly and replacing active
        withAnimation(.easeInOut) { showReveal = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            spin(style: .quick)
        }
    }

    private func skip(_ seg: WheelSegment) {
        // Skipping gives small XP but risks streak unless shield.
        showReveal = false

        let skipXP = seg.difficulty.skipXP
        gainXP(skipXP)
        toast("+\(skipXP) XP (skip)")

        if shieldsStorage > 0 {
            shieldsStorage -= 1
            toast("Shield saved your streak 🛡️")
        } else {
            // streak penalty
            streakStorage = max(0, streakStorage - 1)
        }

        activeSegment = nil
        haptic(.light)
    }

    private func complete(segment seg: WheelSegment, usedDoubleToken: Bool) {
        let award = computeAward(for: seg, completed: true, usedDoubleToken: usedDoubleToken, instant: false)
        gainXP(award)

        // streak up
        streakStorage += 1

        // daily quest bonus when hitting 2 completions
        let todayDone = history.filter { $0.contains(dayKey) && $0.contains("[DONE]") }.count
        if todayDone == 1 { // about to become 2 (we’ll markDone next)
            // grant quest bonus after marking done (but before toast)
        }

        markDone(seg)

        // quest check after adding done entry
        let updatedTodayDone = history.filter { $0.contains(dayKey) && $0.contains("[DONE]") }.count
        if updatedTodayDone == 2 {
            gainXP(25)
            toast("Daily Quest complete! +25 XP ✅")
            haptic(.heavy)
        }

        toast("+\(award) XP")
        activeSegment = nil
        haptic(.heavy)
    }

    // MARK: - XP / Rewards

    private func computeAward(for seg: WheelSegment, completed: Bool, usedDoubleToken: Bool, instant: Bool) -> Int {
        // Base depends on difficulty
        let base = seg.difficulty.baseXP

        // Small streak multiplier (caps gently)
        let streakMult = 1.0 + min(Double(streakStorage), 20) * 0.01 // up to +20%
        var mult = streakMult

        // Modifier power-ups (rarer now)
        switch seg.modifier.kind {
        case .doubleXP:
            mult *= 1.35
        case .pomodoro:
            mult *= 1.25
        case .timedChallenge:
            mult *= 1.20
        case .shortTask:
            mult *= 0.85
        case .bonusSkip:
            mult *= 1.05
        case .none:
            mult *= 1.0
        }

        // Chaos adds spicy random rewards a bit
        if chaos > 0.65 && !instant {
            mult *= 1.05
        }

        // Double-token is a true multiplier but costs token
        if usedDoubleToken {
            mult *= 2.0
        }

        // Instant awards should be smaller (already “easy dopamine”)
        if instant {
            mult *= 0.7
        }

        let award = Int(round(Double(base) * mult))
        return max(5, award)
    }

    private func gainXP(_ amount: Int) {
        xpStorage += amount
        if xpStorage > highscoreStorage { highscoreStorage = xpStorage }
    }

    private func resetXPAndStreak() {
        xpStorage = 0
        streakStorage = 0
        swapsLeftStorage = 2
        shieldsStorage = 0
        doubleRewardTokensStorage = 0
        extraSwapsPurchasedTodayStorage = 0
        toast("Reset complete")
    }

    // MARK: - Shop

    private func buyExtraSwap() {
        rolloverIfNeeded()
        guard extraSwapsPurchasedTodayStorage == 0 else { toast("Already bought today"); return }
        let cost = 40
        guard xpStorage >= cost else { toast("Need \(cost) XP"); return }
        xpStorage -= cost
        swapsLeftStorage += 1
        extraSwapsPurchasedTodayStorage = 1
        toast("+1 swap (today)")
        haptic(.light)
    }

    private func buyShield() {
        let cost = 35
        guard xpStorage >= cost else { toast("Need \(cost) XP"); return }
        xpStorage -= cost
        shieldsStorage += 1
        toast("Shield bought 🛡️")
        haptic(.light)
    }

    private func buyDoubleToken() {
        let cost = 70
        guard xpStorage >= cost else { toast("Need \(cost) XP"); return }
        xpStorage -= cost
        doubleRewardTokensStorage += 1
        toast("Double token bought ✨")
        haptic(.light)
    }

    // MARK: - History

    private func loadHistory() {
        history = historyStorage
            .split(separator: "\n")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    private func addHistory(_ line: String) {
        history.append(line)
        if history.count > 60 { history.removeFirst(history.count - 60) }
        historyStorage = history.joined(separator: "\n")
    }

    private func markDone(_ seg: WheelSegment) {
        addHistory("[\(dayKey)] [DONE] \(seg.title)")
    }

    private func clearHistory() {
        history = []
        historyStorage = ""
        toast("History cleared")
    }

    // MARK: - Daily rollover

    private func rolloverIfNeeded() {
        if lastDayKeyStorage != dayKey {
            lastDayKeyStorage = dayKey
            swapsLeftStorage = 2
            extraSwapsPurchasedTodayStorage = 0
            // Small decay to keep things gentle
            streakStorage = max(0, streakStorage - 1)
            toast("New day: swaps refilled")
        }
    }

    // MARK: - Wheel build

    private func rebuildWheel() {
        segments = buildSegments(
            subjectsCSV: selectedIBSubjectsCSV,
            enabledTypes: enabledTypes,
            chaos: chaos
        )
    }

    private func buildSegments(subjectsCSV: String, enabledTypes: Set<TaskType>, chaos: Double) -> [WheelSegment] {
        let subjects = subjectsCSV
            .split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let usedSubjects = subjects.isEmpty ? ["Math", "Biology", "English", "History", "Chemistry"] : subjects

        // Templates by type (more intentional)
        let templates: [TaskType: [String]] = [
            .recall: [
                "Flashcards: %s (15m)",
                "Teach-back: %s (10m)",
                "Key terms sprint: %s (12m)"
            ],
            .practice: [
                "Past paper: %s (30m)",
                "Problem set: %s (25m)",
                "Exam Qs: %s (20m)"
            ],
            .write: [
                "Mini-essay: %s (25m)",
                "Outline + intro: %s (20m)",
                "Explain a concept: %s (15m)"
            ],
            .review: [
                "Revise notes: %s (20m)",
                "Summarise: %s (18m)",
                "Mindmap: %s (15m)"
            ],
            .organize: [
                "Organize notes (10m)",
                "Plan next study block (8m)",
                "Clean desk + prep (6m)"
            ]
        ]

        var tasks: [WheelSegment] = []

        // Focused vs Spicy: focused prefers subject tasks; spicy adds more generic
        let subjectWeight = 1.0 - chaos
        let genericWeight = chaos

        // Build subject tasks
        for sub in usedSubjects {
            let chosenTypes = enabledTypes.isEmpty ? Set(TaskType.allCases) : enabledTypes
            let sampleCount = max(1, Int(round(2.0 * subjectWeight + 1.0)))
            let types = Array(chosenTypes).shuffled().prefix(sampleCount)

            for t in types {
                guard let pool = templates[t] else { continue }
                let temp = pool.randomElement() ?? "%s"
                let label = temp.contains("%s") ? temp.replacingOccurrences(of: "%s", with: sub) : temp
                let diff = Difficulty.random(weightedBy: t)
                let mod = Modifier.roll(chaos: chaos) // rarer power-ups
                tasks.append(WheelSegment(
                    id: UUID(),
                    title: label,
                    detail: "Type: \(t.rawValue) • Difficulty: \(diff.rawValue)",
                    type: t,
                    difficulty: diff,
                    modifier: mod
                ))
            }
        }

        // Add generic tasks if chaos
        let genericCount = Int(round(4.0 * genericWeight))
        if genericCount > 0 {
            for _ in 0..<genericCount {
                let t = TaskType.organize
                let pool = templates[t] ?? ["Organize notes (10m)"]
                let label = pool.randomElement() ?? "Organize notes (10m)"
                let diff = Difficulty.easy
                let mod = Modifier.roll(chaos: chaos)
                tasks.append(WheelSegment(
                    id: UUID(),
                    title: label,
                    detail: "Type: \(t.rawValue) • Difficulty: \(diff.rawValue)",
                    type: t,
                    difficulty: diff,
                    modifier: mod
                ))
            }
        }

        // Ensure good visual count
        if tasks.count < 9 {
            while tasks.count < 9 { tasks += tasks.shuffled().prefix(min(3, tasks.count)) }
        }

        tasks.shuffle()
        return Array(tasks.prefix(11))
    }

    // MARK: - Haptics / Toast

    private func toast(_ text: String) {
        withAnimation(.easeInOut) { toastText = text }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        #endif
        print("[Roulette] \(text)")
    }

    private enum HapticStrength { case light, medium, heavy }
    private func haptic(_ strength: HapticStrength) {
        #if canImport(UIKit)
        let style: UIImpactFeedbackGenerator.FeedbackStyle = {
            switch strength {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            }
        }()
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        #endif
    }
}

// MARK: - Spin Reveal Sheet

private struct SpinRevealSheet: View {
    let segment: WheelSegment
    let swapsLeft: Int
    let shields: Int
    let doubleTokens: Int

    var onStart: () -> Void
    var onSwap: () -> Void
    var onSkip: () -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                Text("Your roll")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(segment.title)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 8) {
                    Chip(text: segment.type.rawValue, systemImage: "tag")
                    Chip(text: segment.difficulty.rawValue, systemImage: "flame")
                    if segment.modifier.kind != .none {
                        Chip(text: segment.modifier.badgeText, systemImage: segment.modifier.icon)
                    }
                }

                Text(segment.detail)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 10) {
                StatPill(label: "Swaps", value: "\(swapsLeft)", icon: "arrow.triangle.2.circlepath")
                StatPill(label: "Shields", value: "\(shields)", icon: "shield.fill")
                StatPill(label: "Double", value: "\(doubleTokens)", icon: "sparkles")
            }

            HStack(spacing: 10) {
                Button(action: onStart) {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)

                Button(action: onSwap) {
                    Label("Swap", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(role: .destructive, action: onSkip) {
                    Label("Skip", systemImage: "forward.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button("Close", action: onDismiss)
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 4)

            Spacer(minLength: 0)
        }
        .padding()
    }
}

// MARK: - Focus Run View (Full Screen)

private struct FocusConfig {
    let segment: WheelSegment
    let seconds: Int
    var useDoubleToken: Bool
}

private struct FocusRunView: View {
    let config: FocusConfig
    var onCancel: () -> Void
    var onComplete: (_ completed: Bool) -> Void

    @State private var remaining: Int = 0
    @State private var running = true
    @State private var timerCancellable: AnyCancellable? = nil

    var body: some View {
        ZStack {
            LinearGradient(colors: [.blue.opacity(0.25), .purple.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                HStack {
                    Button(action: {
                        stop()
                        onCancel()
                    }) {
                        Label("Cancel", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Focus Run")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(config.segment.title)
                        .font(.title3.bold())
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        Chip(text: config.segment.type.rawValue, systemImage: "tag")
                        Chip(text: config.segment.difficulty.rawValue, systemImage: "flame")
                        if config.segment.modifier.kind != .none {
                            Chip(text: config.segment.modifier.badgeText, systemImage: config.segment.modifier.icon)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Text(formatTime(remaining))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .padding(.vertical, 10)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tiny wins")
                        .font(.headline)
                    TinyWinRow(text: "Open your notebook / doc")
                    TinyWinRow(text: "Do the first 2 minutes")
                    TinyWinRow(text: "Finish one chunk, not everything")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                HStack(spacing: 12) {
                    Button(action: toggleRun) {
                        Label(running ? "Pause" : "Resume", systemImage: running ? "pause.fill" : "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: {
                        stop()
                        onComplete(true)
                    }) {
                        Label("Finish Early", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Spacer()
            }
            .padding()
        }
        .onAppear {
            remaining = max(10, config.seconds)
            start()
        }
        .onDisappear { stop() }
    }

    private func start() {
        stop()
        running = true
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                guard running else { return }
                remaining -= 1
                if remaining <= 0 {
                    stop()
                    onComplete(true)
                }
            }
    }

    private func stop() {
        timerCancellable?.cancel()
        timerCancellable = nil
        running = false
    }

    private func toggleRun() {
        running.toggle()
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%02d:%02d", max(0, s) / 60, max(0, s) % 60)
    }
}

private struct TinyWinRow: View {
    let text: String
    @State private var checked = false

    var body: some View {
        Button {
            checked.toggle()
            #if canImport(UIKit)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            #endif
        } label: {
            HStack {
                Image(systemName: checked ? "checkmark.circle.fill" : "circle")
                Text(text)
                Spacer()
            }
            .foregroundColor(.primary)
            .padding(10)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Setup Sheet

private struct WheelSetupSheet: View {
    let subjectsCSV: String
    let enabledTypes: Set<TaskType>
    let chaos: Double
    var onSave: (_ enabled: Set<TaskType>, _ chaos: Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localEnabled: Set<TaskType> = []
    @State private var localChaos: Double = 0.35

    var body: some View {
        NavigationStack {
            Form {
                Section("Subjects") {
                    Text(subjectsCSV.isEmpty ? "Using defaults (Math, Biology, English, History, Chemistry)" : subjectsCSV)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }

                Section("Wheel Content") {
                    ForEach(TaskType.allCases, id: \.self) { t in
                        Toggle(t.rawValue, isOn: Binding(
                            get: { localEnabled.contains(t) },
                            set: { on in
                                if on { localEnabled.insert(t) } else { localEnabled.remove(t) }
                            }
                        ))
                    }
                }

                Section("Chaos") {
                    VStack(alignment: .leading, spacing: 10) {
                        Slider(value: $localChaos, in: 0...1)
                        HStack {
                            Text("Focused")
                            Spacer()
                            Text("Spicy")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Wheel Setup")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let final = localEnabled.isEmpty ? Set(TaskType.allCases) : localEnabled
                        onSave(final, localChaos)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                localEnabled = enabledTypes.isEmpty ? Set(TaskType.allCases) : enabledTypes
                localChaos = chaos
            }
        }
    }
}

// MARK: - History Sheet

private struct HistorySheet: View {
    let history: [String]
    var onClear: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty {
                    Text("No history yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(history.indices.reversed(), id: \.self) { i in
                        Text(history[i])
                            .font(.footnote)
                            .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Close") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear", role: .destructive) { onClear() }
                }
            }
        }
    }
}

// MARK: - Shop Sheet

private struct ShopSheet: View {
    let xp: Int
    let swapsLeft: Int
    let shields: Int
    let doubleTokens: Int
    let canBuyExtraSwapToday: Bool

    var onBuyExtraSwap: () -> Void
    var onBuyShield: () -> Void
    var onBuyDoubleToken: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Wallet") {
                    HStack {
                        Text("XP")
                        Spacer()
                        Text("\(xp)")
                            .fontWeight(.semibold)
                    }
                    HStack {
                        Text("Swaps")
                        Spacer()
                        Text("\(swapsLeft)")
                    }
                    HStack {
                        Text("Shields")
                        Spacer()
                        Text("\(shields)")
                    }
                    HStack {
                        Text("Double Tokens")
                        Spacer()
                        Text("\(doubleTokens)")
                    }
                }

                Section("Power-ups") {
                    ShopRow(
                        title: "Extra Swap (today)",
                        subtitle: canBuyExtraSwapToday ? "Adds +1 swap to today" : "Already bought today",
                        price: "40 XP",
                        icon: "arrow.triangle.2.circlepath",
                        enabled: canBuyExtraSwapToday
                    ) { onBuyExtraSwap() }

                    ShopRow(
                        title: "Shield",
                        subtitle: "Skip without losing streak (consumed on use)",
                        price: "35 XP",
                        icon: "shield.fill",
                        enabled: true
                    ) { onBuyShield() }

                    ShopRow(
                        title: "Double Token",
                        subtitle: "Future completion reward x2",
                        price: "70 XP",
                        icon: "sparkles",
                        enabled: true
                    ) { onBuyDoubleToken() }
                }
            }
            .navigationTitle("Shop")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

private struct ShopRow: View {
    let title: String
    let subtitle: String
    let price: String
    let icon: String
    let enabled: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle).font(.caption).foregroundColor(.secondary)
                }

                Spacer()
                Text(price)
                    .font(.subheadline).fontWeight(.semibold)
            }
            .padding(.vertical, 4)
        }
        .disabled(!enabled)
    }
}

// MARK: - Wheel (stable labels)

private struct WheelView: View {
    let segments: [WheelSegment]
    let rotation: Angle

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            ZStack {
                ForEach(Array(segments.enumerated()), id: \.element.id) { idx, seg in
                    let count = max(segments.count, 1)
                    let start = Angle(degrees: Double(idx) / Double(count) * 360.0)
                    let end = Angle(degrees: Double(idx + 1) / Double(count) * 360.0)

                    SegmentShape(startAngle: start, endAngle: end)
                        .fill(LinearGradient(colors: gradientColors(for: idx), startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: size, height: size)
                        .overlay(
                            Text(short(seg.title))
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(width: size * 0.35)
                                .offset(x: size * 0.19, y: 0)
                                .rotationEffect(Angle(degrees: (start.degrees + end.degrees) / 2))
                        )
                }

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: size * 0.28, height: size * 0.28)
                    .overlay(
                        VStack(spacing: 2) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text("SPIN")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(.primary)
                        }
                    )
            }
            .rotationEffect(rotation)
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    private func gradientColors(for idx: Int) -> [Color] {
        let palette: [Color] = [.pink, .purple, .blue, .green, .orange, .teal, .indigo, .cyan]
        let c1 = palette[idx % palette.count].opacity(0.95)
        let c2 = palette[(idx + 2) % palette.count].opacity(0.75)
        return [c1, c2]
    }

    private func short(_ s: String) -> String {
        if s.count <= 22 { return s }
        let words = s.split(separator: " ")
        return words.prefix(3).joined(separator: " ")
    }
}

private struct SegmentShape: Shape {
    var startAngle: Angle
    var endAngle: Angle

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let r = min(rect.width, rect.height) / 2
        p.move(to: center)
        p.addArc(
            center: center,
            radius: r,
            startAngle: startAngle - Angle(degrees: 90),
            endAngle: endAngle - Angle(degrees: 90),
            clockwise: false
        )
        p.closeSubpath()
        return p
    }
}

// MARK: - Models

private struct WheelSegment: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let type: TaskType
    let difficulty: Difficulty
    let modifier: Modifier
}

private enum TaskType: String, CaseIterable, Hashable {
    case recall = "Recall"
    case practice = "Practice"
    case write = "Write"
    case review = "Review"
    case organize = "Organize"
}

private enum Difficulty: String, CaseIterable {
    case easy = "Easy"
    case medium = "Medium"
    case hard = "Hard"

    var baseXP: Int {
        switch self {
        case .easy: return 18
        case .medium: return 24
        case .hard: return 30
        }
    }

    var skipXP: Int {
        switch self {
        case .easy: return 6
        case .medium: return 8
        case .hard: return 10
        }
    }

    static func random(weightedBy type: TaskType) -> Difficulty {
        // Writing/practice tends to be heavier, organize lighter
        let roll = Double.random(in: 0...1)
        switch type {
        case .organize:
            return roll < 0.75 ? .easy : .medium
        case .recall:
            return roll < 0.55 ? .easy : (roll < 0.90 ? .medium : .hard)
        case .review:
            return roll < 0.45 ? .easy : (roll < 0.85 ? .medium : .hard)
        case .practice:
            return roll < 0.20 ? .easy : (roll < 0.70 ? .medium : .hard)
        case .write:
            return roll < 0.15 ? .easy : (roll < 0.65 ? .medium : .hard)
        }
    }
}

private struct Modifier: Equatable {
    enum Kind: String {
        case none
        case doubleXP
        case pomodoro
        case timedChallenge
        case shortTask
        case bonusSkip
    }

    let kind: Kind

    var badgeText: String {
        switch kind {
        case .none: return ""
        case .doubleXP: return "Boost"
        case .pomodoro: return "Pomodoro"
        case .timedChallenge: return "Timed"
        case .shortTask: return "Quick"
        case .bonusSkip: return "Lucky"
        }
    }

    var icon: String {
        switch kind {
        case .none: return "circle"
        case .doubleXP: return "sparkles"
        case .pomodoro: return "timer"
        case .timedChallenge: return "stopwatch"
        case .shortTask: return "hare.fill"
        case .bonusSkip: return "gift.fill"
        }
    }

    static func roll(chaos: Double) -> Modifier {
        // Rarer power-ups; chaos increases odds slightly
        let r = Double.random(in: 0...1)
        let spice = 0.08 * chaos // up to +0.08 probability budget

        // Overall: ~70% none, ~30% something (slightly more with chaos)
        if r < (0.70 - spice) { return Modifier(kind: .none) }

        let r2 = Double.random(in: 0...1)
        if r2 < 0.20 { return Modifier(kind: .shortTask) }
        if r2 < 0.40 { return Modifier(kind: .bonusSkip) }
        if r2 < 0.60 { return Modifier(kind: .timedChallenge) }
        if r2 < 0.82 { return Modifier(kind: .pomodoro) }
        return Modifier(kind: .doubleXP)
    }
}

// MARK: - Small Components

private struct Chip: View {
    let text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 999, style: .continuous))
    }
}

private struct StatPill: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption2).foregroundColor(.secondary)
                Text(value).font(.caption).fontWeight(.semibold)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct ToastView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(radius: 10)
            .padding(.top, 4)
    }
}

// MARK: - Helpers

private extension Array {
    subscript(safe idx: Int) -> Element? {
        (idx >= 0 && idx < count) ? self[idx] : nil
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
