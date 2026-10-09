import SwiftUI
import Combine

@main
struct IBStudentAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @State private var isLoggedIn = false
    @State private var activeTab: String = "home"

    var body: some View {
        Group {
            if !isLoggedIn {
                LoginView(isLoggedIn: $isLoggedIn)
            } else {
                VStack {
                    Header()

                    TabView(selection: $activeTab) {
                        HomeView()
                            .tabItem { Label("Home", systemImage: "house") }
                            .tag("home")

                        DeadlinesView()
                            .tabItem { Label("Deadlines", systemImage: "alarm") }
                            .tag("deadlines")

                        TimetableView()
                            .tabItem { Label("Timetable", systemImage: "calendar") }
                            .tag("timetable")

                        GradeCalculatorView()
                            .tabItem { Label("Grades", systemImage: "percent") }
                            .tag("grades")

                        GameView()
                            .tabItem { Label("Game", systemImage: "gamecontroller") }
                            .tag("game")

                        ResourceLibraryView()
                            .tabItem { Label("Resources", systemImage: "book") }
                            .tag("resources")

                        EE_TOKView()
                           .tabItem { Label("Core", systemImage: "brain.head.profile") }
                           .tag("quiz")
                    }
                }
            }
        }
        .onAppear {
            // Local notifications will not fire unless the user grants permission.
            NotificationManager.requestAuthorizationIfNeeded()
        }
    }
}

struct LoginView: View {
    // Persisted flags/data (local to the device)
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
    @AppStorage("selectedIBSubjectsCSV") private var selectedIBSubjectsCSV: String = ""

    // Local UI state
    @State private var selectedSubjects: Set<String> = []
    @State private var showPickSixAlert = false

    @Binding var isLoggedIn: Bool

    // These match the section titles in ResourceLibraryView
    private let allSubjects: [String] = [
        "Math AA",
        "Math AI",
        "Computer Science",
        "History",
        "Geography",
        "Physics",
        "Biology",
        "Chemistry",
        "Economics",
        "Environmental Studies",
        "Business Studies",
        "Spanish",
        "English"
    ]

    private var selectedCount: Int { selectedSubjects.count }
    private var canContinue: Bool { selectedCount == 6 }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Text("IB Student Assistant")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Pick your 6 IB subjects to personalize the app.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(selectedCount)/6 selected")
                        .font(.headline)
                        .foregroundColor(selectedCount == 6 ? .green : .secondary)
                        .padding(.top, 2)
                }
                .padding(.top, 10)

                // Subject picker
                List {
                    ForEach(allSubjects, id: \.self) { subject in
                        Button {
                            toggle(subject)
                        } label: {
                            HStack {
                                Text(subject)
                                    .foregroundColor(.primary)

                                Spacer()

                                if selectedSubjects.contains(subject) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        // If they've already selected 6, prevent selecting more
                        .disabled(!selectedSubjects.contains(subject) && selectedSubjects.count >= 6)
                    }
                }
                .listStyle(.insetGrouped)

                // Continue button
                Button {
                    if canContinue {
                        saveAndFinish()
                    } else {
                        showPickSixAlert = true
                    }
                } label: {
                    Text(canContinue ? "Continue" : "Select 6 to Continue")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(canContinue ? Color.blue : Color.gray)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .padding(.horizontal, 8)
        }
        .onAppear {
            // If onboarding was already completed in a previous session,
            // skip this screen automatically.
            if hasCompletedOnboarding {
                isLoggedIn = true
                return
            }

            // If for any reason there's saved data, restore it into UI state.
            let restored = restoreSubjects(from: selectedIBSubjectsCSV)
            if !restored.isEmpty {
                selectedSubjects = restored
            }
        }
        .alert("Almost there", isPresented: $showPickSixAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Please select exactly 6 subjects to continue.")
        }
    }

    
    // MARK: - Helpers

    private func toggle(_ subject: String) {
        if selectedSubjects.contains(subject) {
            selectedSubjects.remove(subject)
        } else {
            // guard max 6
            if selectedSubjects.count < 6 {
                selectedSubjects.insert(subject)
            }
        }
    }

    private func saveAndFinish() {
        // Save deterministically (sorted) so it’s stable across runs
        let sorted = selectedSubjects.sorted()
        selectedIBSubjectsCSV = sorted.joined(separator: "|")
        hasCompletedOnboarding = true
        isLoggedIn = true
    }

    private func restoreSubjects(from csv: String) -> Set<String> {
        let parts = csv
            .split(separator: "|")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        // Only keep valid subjects (prevents junk data)
        let valid = Set(parts.filter { allSubjects.contains($0) })
        return valid
    }
}
struct Header: View {
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.indigo, .purple]), startPoint: .leading, endPoint: .trailing)
            Text("IB Student Assistant")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
        }
        .frame(height: 50)
    }
}

struct NavigationBar: View {
    @Binding var activeTab: String

    var body: some View {
        HStack {
            navButton(tab: "home", icon: "house")
            navButton(tab: "deadlines", icon: "alarm")
            navButton(tab: "timetable", icon: "calendar")
            navButton(tab: "grades", icon: "precentage")
            navButton(tab: "game", icon: "gamecontroller")
            navButton(tab: "resources", icon: "book")
            // Match the real TabView tag.
            navButton(tab: "core", icon: "brain.head.profile")
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -5)
    }

    func navButton(tab: String, icon: String) -> some View {
        Button(action: { activeTab = tab }) {
            Image(systemName: icon)
                .foregroundColor(activeTab == tab ? tabColor(for: tab) : .gray)
                .frame(maxWidth: .infinity)
        }
    }

    func tabColor(for tab: String) -> Color {
        switch tab {
        case "home": return .indigo
        case "deadlines": return .orange
        case "timetable": return .teal
        case "grades": return .blue
        case "game": return .red
        case "resources": return .purple
        case "core": return .green
        default: return .gray
        }
    }
}

struct ContentViewPreview: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
