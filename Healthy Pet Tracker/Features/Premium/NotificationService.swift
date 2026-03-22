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
            // UNTimeIntervalNotificationTrigger ignores timeOfDay completely —
            // it fires N*86400 seconds after scheduling, not at the user's
            // chosen time. Worse, repeats:true compounds the drift so every
            // subsequent firing lands at a different time of day.
            //
            // Fix: use a one-shot UNCalendarNotificationTrigger for the next
            // occurrence at the correct time. PetWeightTrackerApp reschedules
            // on foreground (via rescheduleCustomIfExpired) to keep the chain
            // going after each delivery.
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
            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: nextFiring
            )
            return UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
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

        // Extract plain Sendable values before crossing the async/Sendable boundary.
        // PetReminder is a SwiftData @Model (non-Sendable), so we cannot capture it
        // directly inside a @Sendable closure — only primitive copies are safe here.
        let idString  = reminder.id.uuidString
        let title     = reminder.title
        let notes     = reminder.notes
        let timeOfDay = reminder.timeOfDay

        center.getPendingNotificationRequests { [weak self] pending in
            let stillPending = pending.contains { $0.identifier == idString }
            guard !stillPending else { return }   // next occurrence already queued

            DispatchQueue.main.async { [weak self] in
                self?.scheduleCustom(
                    id:        idString,
                    title:     title,
                    notes:     notes,
                    timeOfDay: timeOfDay,
                    days:      days
                )
            }
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

        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: nextFiring
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        center.add(request) { error in
            if let error { print("Failed to reschedule custom notification: \(error)") }
        }
    }
}

