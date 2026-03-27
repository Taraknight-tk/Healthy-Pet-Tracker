//
//  NotificationService.swift
//  Healthy Pet Tracker
//
//  Wraps UNUserNotificationCenter to schedule, cancel, and reschedule
//  local notifications for PetReminder objects.
//
//  Also acts as UNUserNotificationCenterDelegate so notifications are
//  displayed as banners even when the app is in the foreground.
//

import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationService: NSObject, ObservableObject, UNUserNotificationCenterDelegate {

    static let shared = NotificationService()

    @Published private(set) var isAuthorized = false

    private let center = UNUserNotificationCenter.current()

    /// Number of future occurrences to pre-schedule for custom-interval
    /// reminders. This means the reminder keeps firing even if the user
    /// doesn't open the app for up to (batchSize × interval) days.
    private let customBatchSize = 10

    private override init() {
        super.init()
        // Register as delegate so we can show banners while the app
        // is in the foreground (iOS suppresses them by default).
        center.delegate = self
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show notification banners + play sound even when the app is active.
    /// Without this, notifications that fire while the user is inside the
    /// app are silently swallowed — which makes it look like scheduling failed.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Called when the user taps a delivered notification.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        completionHandler()
    }

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
        print("🔔 schedule() called: frequency=\(reminder.frequency.rawValue), enabled=\(reminder.isEnabled), customDays=\(reminder.customIntervalDays as Any)")

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

        // Remove-then-add with the synchronous callback API.
        // Using the callback version avoids any Task / actor-hop delays
        // that could allow the calling view to dismiss before the request
        // is registered with the notification center.
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.add(request) { error in
            if let error {
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
        guard let days = reminder.customIntervalDays, days > 0 else {
            print("⚠️ scheduleCustomBatch: skipped — customIntervalDays is \(reminder.customIntervalDays as Any)")
            return
        }

        let baseId    = reminder.id.uuidString
        let calendar  = Calendar.current
        let timeComps = calendar.dateComponents([.hour, .minute], from: reminder.timeOfDay)
        let hour      = timeComps.hour   ?? 9
        let minute    = timeComps.minute ?? 0

        print("🔔 scheduleCustomBatch: interval=\(days)d, time=\(hour):\(String(format: "%02d", minute)), batchSize=\(customBatchSize)")

        // Clear every existing notification for this reminder (base + batch IDs)
        let allIds = [baseId] + (1...customBatchSize).map { "\(baseId)_\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: allIds)

        // Find the NEXT valid firing time. If today's target time hasn't
        // passed yet, the first notification fires later today. Otherwise
        // it fires `days` days from now. This ensures the user gets a
        // notification as early as possible instead of always waiting a
        // full interval for the first one.
        let now = Date()
        guard let todayFiring = calendar.date(
            bySettingHour: hour, minute: minute, second: 0, of: now
        ) else { return }

        let firstFiring: Date
        if todayFiring > now {
            // Today's time hasn't passed — fire later today
            firstFiring = todayFiring
        } else {
            // Today's time already passed — first firing is `days` days out
            guard let next = calendar.date(byAdding: .day, value: days, to: todayFiring) else { return }
            firstFiring = next
        }

        // Schedule the next N occurrences using UNCalendarNotificationTrigger
        // (the same trigger type that works for .once / .weekly / .monthly).
        for i in 0..<customBatchSize {
            guard let targetFiring = calendar.date(byAdding: .day, value: days * i, to: firstFiring)
            else { continue }

            let components = calendar.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: targetFiring
            )

            let content = UNMutableNotificationContent()
            content.title = reminder.title
            if !reminder.notes.isEmpty { content.body = reminder.notes }
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: components, repeats: false
            )
            let batchId = "\(baseId)_\(i + 1)"
            let request = UNNotificationRequest(
                identifier: batchId,
                content: content,
                trigger: trigger
            )

            let firingStr = targetFiring.formatted(date: .abbreviated, time: .shortened)
            center.add(request) { error in
                if let error {
                    print("❌ Failed to schedule [\(batchId)]: \(error)")
                } else {
                    print("✅ Scheduled [\(batchId)] for \(firingStr)")
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
