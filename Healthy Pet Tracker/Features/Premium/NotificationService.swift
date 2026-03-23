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
    /// Removes any existing notification with the same ID first, then adds
    /// the new one using async/await for proper error propagation.
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
            print("⚠️ Could not build trigger for reminder \(reminder.id) [\(reminder.frequency)]")
            return
        }

        let id = reminder.id.uuidString
        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: trigger
        )

        // Always clear existing notification before adding the new one.
        // This avoids stale entries that could block a fresh schedule.
        center.removePendingNotificationRequests(withIdentifiers: [id])

        // Use async/await instead of the callback-based add() to ensure
        // proper actor isolation and error surfacing on @MainActor.
        Task {
            do {
                try await center.add(request)
            } catch {
                print("❌ Failed to schedule notification [\(id)]: \(error)")
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
            // Compute the exact target date (N days from now at the chosen time)
            // and use UNTimeIntervalNotificationTrigger with the precise number
            // of seconds until that moment. One-shot (repeats:false) — the
            // scenePhase .active handler reschedules the next occurrence.
            let calendar = Calendar.current
            let timeComps = calendar.dateComponents([.hour, .minute], from: reminder.timeOfDay)
            guard
                let nextDay     = calendar.date(byAdding: .day, value: days, to: Date()),
                let nextFiring  = calendar.date(
                    bySettingHour:   timeComps.hour   ?? 9,
                    minute:          timeComps.minute ?? 0,
                    second:          0,
                    of:              nextDay
                )
            else { return nil }
            let interval = nextFiring.timeIntervalSinceNow
            guard interval > 0 else { return nil }
            return UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        }
    }

    // MARK: - Custom-interval rescheduling

    /// For custom-interval reminders only: checks whether the previous
    /// notification has already fired (no pending request for this ID)
    /// and, if so, schedules the next occurrence. Call this from the
    /// scenePhase .active handler so the chain of one-shot triggers never
    /// silently goes dead after delivery.
    func rescheduleCustomIfExpired(_ reminder: PetReminder) {
        // Only proceed for enabled, custom-frequency reminders
        guard reminder.isEnabled, reminder.frequency == .custom else { return }
        guard let days = reminder.customIntervalDays, days > 0 else { return }

        // Extract plain Sendable values before crossing the async boundary.
        // PetReminder is a SwiftData @Model (non-Sendable) and cannot be
        // captured inside a Task or @Sendable closure.
        let idString  = reminder.id.uuidString
        let title     = reminder.title
        let notes     = reminder.notes
        let timeOfDay = reminder.timeOfDay

        // Use async/await instead of callback to avoid Sendable capture issues
        // with the getPendingNotificationRequests completion handler.
        Task { @MainActor [weak self] in
            guard let self else { return }
            let pending = await self.center.pendingNotificationRequests()
            let stillPending = pending.contains { $0.identifier == idString }
            guard !stillPending else { return }   // next occurrence already queued
            self.scheduleCustom(
                id:        idString,
                title:     title,
                notes:     notes,
                timeOfDay: timeOfDay,
                days:      days
            )
        }
    }

    /// Schedules a one-shot custom-interval notification from plain Sendable values.
    /// This avoids capturing the non-Sendable PetReminder @Model across async boundaries.
    private func scheduleCustom(id: String, title: String, notes: String,
                                timeOfDay: Date, days: Int) {
        let content = UNMutableNotificationContent()
        content.title = title
        if !notes.isEmpty { content.body = notes }
        content.sound = .default

        let calendar  = Calendar.current
        let timeComps = calendar.dateComponents([.hour, .minute], from: timeOfDay)
        guard
            let nextDay    = calendar.date(byAdding: .day, value: days, to: Date()),
            let nextFiring = calendar.date(
                bySettingHour: timeComps.hour   ?? 9,
                minute:        timeComps.minute ?? 0,
                second:        0,
                of:            nextDay
            )
        else { return }

        // Use UNTimeIntervalNotificationTrigger with the exact number of seconds
        // until the target date. This is more reliable than calendar-matching for
        // one-shot triggers because it avoids potential edge cases with
        // UNCalendarNotificationTrigger date component matching.
        let interval = nextFiring.timeIntervalSinceNow
        guard interval > 0 else { return }
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.removePendingNotificationRequests(withIdentifiers: [id])

        Task {
            do {
                try await center.add(request)
            } catch {
                print("❌ Failed to reschedule custom notification [\(id)]: \(error)")
            }
        }
    }
}

