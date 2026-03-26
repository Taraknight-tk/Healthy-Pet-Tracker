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

    /// Number of future occurrences to pre-schedule for custom-interval
    /// reminders. This means the reminder keeps firing even if the user
    /// doesn't open the app for up to (batchSize × interval) days.
    private let customBatchSize = 10

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
    /// For weekly/monthly/once, schedules a single (possibly repeating) trigger.
    /// For custom intervals, pre-schedules the next `customBatchSize` occurrences
    /// so the reminder keeps firing even if the user doesn't open the app.
    func schedule(_ reminder: PetReminder) {
        guard reminder.isEnabled else {
            cancel(reminder)
            return
        }

        // Custom intervals use a batch of one-shot triggers (see below).
        if reminder.frequency == .custom {
            scheduleCustomBatch(reminder)
            return
        }

        // Weekly / monthly / once — single trigger
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        if !reminder.notes.isEmpty {
            content.body = reminder.notes
        }
        content.sound = .default

        guard let trigger = buildTrigger(for: reminder) else {
            print("⚠️ Could not build trigger for reminder \(reminder.id) [\(reminder.frequency)]")
            return
        }

        let id = reminder.id.uuidString
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [id])

        Task {
            do {
                try await center.add(request)
            } catch {
                print("❌ Failed to schedule notification [\(id)]: \(error)")
            }
        }
    }

    // MARK: - Custom-interval batch scheduling

    /// Pre-schedules the next `customBatchSize` occurrences for a custom-interval
    /// reminder. Each occurrence gets its own one-shot trigger with a unique ID
    /// ({uuid}_1 … {uuid}_10). This means the reminder keeps firing for up to
    /// batchSize × intervalDays even if the user never opens the app.
    /// The scenePhase .active handler calls this again to "top up" the batch
    /// whenever the app comes to the foreground.
    private func scheduleCustomBatch(_ reminder: PetReminder) {
        guard let days = reminder.customIntervalDays, days > 0 else { return }

        let baseId    = reminder.id.uuidString
        let calendar  = Calendar.current
        let timeComps = calendar.dateComponents([.hour, .minute], from: reminder.timeOfDay)

        // Build shared notification content (center.add copies it internally)
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        if !reminder.notes.isEmpty { content.body = reminder.notes }
        content.sound = .default

        // Clear every existing notification for this reminder (base + batch IDs)
        let allIds = [baseId] + (1...customBatchSize).map { "\(baseId)_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIds)

        // Schedule the next N occurrences
        Task {
            for i in 1...customBatchSize {
                guard
                    let targetDay = calendar.date(byAdding: .day, value: days * i, to: Date()),
                    let targetFiring = calendar.date(
                        bySettingHour: timeComps.hour   ?? 9,
                        minute:        timeComps.minute ?? 0,
                        second:        0,
                        of:            targetDay
                    )
                else { continue }

                let interval = targetFiring.timeIntervalSinceNow
                guard interval > 0 else { continue }

                let trigger = UNTimeIntervalNotificationTrigger(
                    timeInterval: interval, repeats: false
                )
                let request = UNNotificationRequest(
                    identifier: "\(baseId)_\(i)",
                    content: content,
                    trigger: trigger
                )

                do {
                    try await center.add(request)
                } catch {
                    print("❌ Failed to schedule [\(baseId)_\(i)]: \(error)")
                }
            }
        }
    }

    /// Cancel the notification(s) for a specific reminder.
    /// Clears both the single-trigger ID and any batch IDs for custom intervals.
    func cancel(_ reminder: PetReminder) {
        let baseId = reminder.id.uuidString
        let ids = [baseId] + (1...customBatchSize).map { "\(baseId)_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    /// Cancel all notifications for a pet (e.g., when the pet is deleted).
    func cancelAll(for pet: Pet) {
        var ids: [String] = []
        for reminder in pet.reminders {
            let baseId = reminder.id.uuidString
            ids.append(baseId)
            ids += (1...customBatchSize).map { "\(baseId)_\($0)" }
        }
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
            // Custom intervals are handled by scheduleCustomBatch() which
            // pre-schedules multiple one-shot triggers. This case should
            // never be reached from schedule(), but return nil as a safety net.
            return nil
        }
    }

    // MARK: - Custom-interval top-up

    /// Called from the scenePhase .active handler. Re-schedules the full batch
    /// of future occurrences so the notification chain stays alive even if
    /// older ones have already fired while the app was closed.
    func rescheduleCustomIfExpired(_ reminder: PetReminder) {
        guard reminder.isEnabled, reminder.frequency == .custom else { return }
        scheduleCustomBatch(reminder)
    }
}

