import UserNotifications

enum NotificationManager {
    static func requestAuthorizationIfNeeded() {
        let center = UNUserNotificationCenter.current()

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }

            center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
                // If permission is denied, deadlines will still work, just without alerts.
            }
        }
    }
}
