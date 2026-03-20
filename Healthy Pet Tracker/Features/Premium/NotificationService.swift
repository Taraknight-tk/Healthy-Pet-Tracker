//
//  NotificationService.swift
//  Healthy Pet Tracker
//
//  Wraps UNUserNotificationCenter to schedule, cancel, and reschedule
//  local notifications for PetReminder objects.
//

import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationService: ObservableObject {
    
    static let shared = NotificationService()

    @Published private(set) var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    private init() {}

    // MARK: - Permission

    /// Request notification permission. Returns true if granted.
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            isAuthorized = granted
            return granted
        } catch {
            print("Notification permission error: \(error)")
            isAuthorized = false
            return false
        }
    }

    /// Check current authorization without prompting.
    func checkPermission() async {
        let settings = await center.notificationSettings()
        isAuthorized = settings.authorizationStatus == .authorized
    }

    // MARK: - Scheduling

    /// Schedule (or reschedule) a notification for the given reminder.
    /// Cancels any existing notification with the same ID first.
    func schedule(_ reminder: PetReminder) {
        guard reminder.isEnabled else {
            cancel(reminder)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = reminder.title
        if !reminder.notes.isEmpty {
            content.body = reminder.notes
        }
        content.sound = .default

        guard let trigger = buildTrigger(for: reminder) else {
            print("Could not build trigger for reminder \(reminder.id)")
            return
        }

        let request = UNNotificationRequest(
            identifier: reminder.id.uuidString,
            content: content,
            trigger: trigger
        )

        center.add(request) { error in
            if let error {
                print("Failed to schedule notification: \(error)")
            }
        }
    }

    /// Cancel the notification for a specific reminder.
    func cancel(_ reminder: PetReminder) {
        center.removePendingNotificationRequests(
            withIdentifiers: [reminder.id.uuidString]
        )
    }

    /// Cancel all notifications for a pet (e.g., when the pet is deleted).
    func cancelAll(for pet: Pet) {
        let ids = pet.reminders.map { $0.id.uuidString }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Reschedule every enabled reminder for a pet.
    func rescheduleAll(for pet: Pet) {
        cancelAll(for: pet)
        for reminder in pet.reminders where reminder.isEnabled {
            schedule(reminder)
        }
    }

    // MARK: - Trigger builders

    private func buildTrigger(for reminder: PetReminder) -> UNNotificationTrigger? {
        let timeComponents = Calendar.current.dateComponents([.hour, .minute], from: reminder.timeOfDay)

        switch reminder.frequency {
        case .once:
            guard let date = reminder.specificDate else { return nil }
            var components = Calendar.current.dateComponents(
                [.year, .month, .day], from: date
            )
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        case .weekly:
            guard let weekday = reminder.dayOfWeek else { return nil }
            var components = DateComponents()
            components.weekday = weekday
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        case .monthly:
            guard let day = reminder.dayOfMonth else { return nil }
            var components = DateComponents()
            components.day = day
            components.hour = timeComponents.hour
            components.minute = timeComponents.minute
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        case .custom:
            guard let days = reminder.customIntervalDays, days > 0 else { return nil }
            let interval = TimeInterval(days * 86_400) // seconds in a day
            return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
        }
    }
}

