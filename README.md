# IB Student Assistant

IB Student Assistant is a SwiftUI application designed to help International Baccalaureate students organize their academic work, review course material, and take short study breaks. The app combines planning, study, and wellness tools in one simple interface.

## Purpose

IB students often manage demanding coursework, projects, core requirements, extracurricular activities, and overlapping deadlines. This project was created to make that workload easier to manage by providing a single place to track deadlines, build a timetable, access learning resources, review subjects, and briefly unwind.

## Features

- **Deadline tracker:** Add deadlines by subject and title, select a due date and time, mark work as complete, restore completed items, and remove individual or selected deadlines.
- **Deadline reminders:** Schedule local notifications one day before a deadline and again five hours before it is due.
- **Weekly timetable:** Create and save a Monday-through-Friday schedule across six class periods.
- **Resource library:** Open curated learning links for subjects including mathematics, computer science, history, geography, physics, biology, chemistry, economics, environmental studies, business studies, and Spanish.
- **Knowledge Quest quizzes:** Select a subject and subtopic, answer multiple-choice questions, view immediate answer feedback, track progress, and receive a final score.
- **Study assistant:** Ask supported academic questions and receive answers through a local question-and-answer collection with Jaro-Winkler fuzzy matching.
- **Snake game:** Take a short study break with swipe controls, three difficulty levels, scoring, and a saved high score.
- **Persistent local data:** Deadlines, timetable selections, and game high scores are stored locally using `UserDefaults`.

## Built With

- Swift
- SwiftUI
- Xcode
- Combine
- UserNotifications
- UserDefaults and Codable

The project uses SwiftUI state management and reusable views to keep the interface responsive and organized.

## Getting Started

### Requirements

- A Mac with Xcode installed
- An iOS Simulator or compatible Apple device

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/jaineelsanghvi/IB_Helper-app.git
   ```

2. Enter the project directory:

   ```bash
   cd IB_Helper-app
   ```

3. Open the Xcode project:

   ```bash
   open IB_Helper.xcodeproj
   ```

4. Select an available simulator or connected device in Xcode.
5. Press the Run button or use `Command + R`.
6. Allow notifications when prompted if you want deadline reminders.

## Demo Login

The current login screen is intended for demonstration purposes and uses local, hard-coded credentials:

```text
Username: student
Password: 1234
```

This is not production authentication and should be replaced with secure account management before publishing the app for real users.

## How the App Stores Data

The app works primarily with local data:

- Deadlines are encoded as JSON and stored in `UserDefaults`.
- Timetable selections are encoded and restored between launches.
- The Snake game high score is saved locally.
- The study assistant uses a built-in question-and-answer collection and does not call an external generative AI service.

Because the data is stored locally, deleting the app or clearing its application data may remove saved information.

## Project Structure

```text
IB_Helper-app/
├── IB_Helper/             # Main SwiftUI application source
├── IB_HelperTests/        # Unit tests
├── IB_HelperUITests/      # User-interface tests
├── IB_Helper.xcodeproj/   # Xcode project configuration
└── README.md
```

## Design and Development

The application was developed from client interviews and iterative design feedback. The main goals were to make academic organization straightforward, keep navigation clear, add engaging colors and visual feedback, and balance productivity with a short recreational activity.

The implementation demonstrates techniques including:

- Codable data models and JSON encoding
- Array searching, grouping, sorting, and nested data structures
- Observable state with SwiftUI and Combine
- Local notification scheduling and cancellation
- Reusable SwiftUI components
- Fuzzy string matching with the Jaro-Winkler algorithm
- A timer-driven game loop and gesture handling

## Future Improvements

- Replace the demonstration login with secure authentication.
- Allow students to upload and organize their own study resources.
- Add collaboration or messaging between students.
- Expand the quiz bank and study-assistant knowledge base.
- Add stronger progress tracking with badges and achievements.
- Add cloud synchronization across devices.
- Expand automated unit and user-interface testing.

## Author

Created by [Jaineel Sanghvi](https://github.com/jaineelsanghvi).

## Academic Context

This project was developed as an IB Computer Science internal assessment based on the needs and feedback of an IB student client.
