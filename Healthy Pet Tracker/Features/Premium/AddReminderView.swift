//
//  AddReminderView.swift
//  Healthy Pet Tracker
//
//  Form for creating or editing a pet reminder.
//  Adapts its fields dynamically based on the selected reminder type
//  and frequency.
//

import SwiftUI
import SwiftData

struct AddReminderView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let pet: Pet
    /// Non-nil when editing an existing reminder
    var existingReminder: PetReminder?

    // MARK: - Form state

    @State private var reminderType: ReminderType = .weightLogging
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var frequency: ReminderFrequency = .monthly
    @State private var dayOfWeek: Int = 2          // Monday
    @State private var dayOfMonth: Int = 1         // 1st
    @State private var customIntervalDays: Int = 14
    @State private var timeOfDay: Date = defaultTime()
    @State private var specificDate: Date = Date()

    @State private var showingPermissionAlert = false

    private var isEditing: Bool { existingReminder != nil }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ThemedForm {
                typeSection
                detailsSection
                scheduleSection
            }
            .navigationTitle(isEditing ? "Edit Reminder" : "New Reminder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.fillSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { saveReminder() }
                        .disabled(!isValid)
                        .tint(.accentInteractive)
                }
            }
            .alert("Notifications Disabled", isPresented: $showingPermissionAlert) {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Reminders need notification permission. Please enable notifications in Settings.")
            }
            .onAppear { populateFromExisting() }
        }
    }

    // MARK: - Sections

    private var typeSection: some View {
        Section("Reminder Type") {
            Picker("Type", selection: $reminderType) {
                ForEach(ReminderType.allCases, id: \.self) { type in
                    Label(type.displayName, systemImage: type.icon)
                        .tag(type)
                }
            }
            .pickerStyle(.menu)
            .primaryText()
            .onChange(of: reminderType) { _, newType in
                // Auto-set sensible defaults when the type changes
                if newType.defaultsToOneTime {
                    frequency = .once
                } else if frequency == .once {
                    frequency = .monthly
                }
                if title.isEmpty || isAutoTitle(title) {
                    title = defaultTitle(for: newType)
                }
            }
        }
        .themedSection()
    }

    private var detailsSection: some View {
        Section("Details") {
            TextField("Title", text: $title)
                .primaryText()
            TextField("Notes (optional)", text: $notes)
                .primaryText()
        }
        .themedSection()
    }

    private var scheduleSection: some View {
        Section("Schedule") {
            // Frequency picker — hide for vet appointments which default to one-time
            if !reminderType.defaultsToOneTime {
                Picker("Frequency", selection: $frequency) {
                    ForEach(ReminderFrequency.allCases, id: \.self) { freq in
                        Text(freq.displayName).tag(freq)
                    }
                }
                .primaryText()
            }

            // Dynamic schedule fields
            switch frequency {
            case .once:
                DatePicker("Date", selection: $specificDate, in: Date()..., displayedComponents: .date)
                    .primaryText()

            case .weekly:
                Picker("Day", selection: $dayOfWeek) {
                    ForEach(weekdays, id: \.value) { day in
                        Text(day.name).tag(day.value)
                    }
                }
                .primaryText()

            case .monthly:
                Picker("Day of Month", selection: $dayOfMonth) {
                    ForEach(1...28, id: \.self) { day in
                        Text(ordinal(day)).tag(day)
                    }
                }
                .primaryText()

            case .custom:
                Stepper("Every \(customIntervalDays) day\(customIntervalDays == 1 ? "" : "s")",
                        value: $customIntervalDays, in: 1...365)
                    .primaryText()
            }

            DatePicker("Time", selection: $timeOfDay, displayedComponents: .hourAndMinute)
                .primaryText()
        }
        .themedSection()
    }

    // MARK: - Validation

    private var isValid: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Save

    private func saveReminder() {
        Task {
            // Ensure we have notification permission
            let authorized = await NotificationService.shared.requestPermission()
            guard authorized else {
                showingPermissionAlert = true
                return
            }

            if let existing = existingReminder {
                // Update in place
                existing.reminderType = reminderType
                existing.title = title.trimmingCharacters(in: .whitespaces)
                existing.notes = notes.trimmingCharacters(in: .whitespaces)
                existing.frequency = frequency
                existing.dayOfWeek = frequency == .weekly ? dayOfWeek : nil
                existing.dayOfMonth = frequency == .monthly ? dayOfMonth : nil
                existing.customIntervalDays = frequency == .custom ? customIntervalDays : nil
                existing.timeOfDay = timeOfDay
                existing.specificDate = frequency == .once ? specificDate : nil

                NotificationService.shared.schedule(existing)
            } else {
                let reminder = PetReminder(
                    pet: pet,
                    reminderType: reminderType,
                    title: title.trimmingCharacters(in: .whitespaces),
                    notes: notes.trimmingCharacters(in: .whitespaces),
                    frequency: frequency,
                    dayOfWeek: frequency == .weekly ? dayOfWeek : nil,
                    dayOfMonth: frequency == .monthly ? dayOfMonth : nil,
                    customIntervalDays: frequency == .custom ? customIntervalDays : nil,
                    timeOfDay: timeOfDay,
                    specificDate: frequency == .once ? specificDate : nil
                )
                pet.reminders.append(reminder)
                modelContext.insert(reminder)

                NotificationService.shared.schedule(reminder)
            }

            HapticManager.shared.notification(.success)
            dismiss()
        }
    }

    // MARK: - Populate for editing

    private func populateFromExisting() {
        guard let r = existingReminder else {
            // New reminder — set a default title
            title = defaultTitle(for: reminderType)
            return
        }
        reminderType = r.reminderType
        title = r.title
        notes = r.notes
        frequency = r.frequency
        dayOfWeek = r.dayOfWeek ?? 2
        dayOfMonth = r.dayOfMonth ?? 1
        customIntervalDays = r.customIntervalDays ?? 14
        timeOfDay = r.timeOfDay
        specificDate = r.specificDate ?? Date()
    }

    // MARK: - Helpers

    private func defaultTitle(for type: ReminderType) -> String {
        switch type {
        case .weightLogging:  return "Time to weigh \(pet.name)!"
        case .vetAppointment: return "\(pet.name)'s vet appointment"
        case .medication:     return "\(pet.name)'s medication"
        case .custom:         return ""
        }
    }

    /// Returns true if the title matches one of the auto-generated defaults
    private func isAutoTitle(_ text: String) -> Bool {
        ReminderType.allCases.contains { defaultTitle(for: $0) == text }
    }

    private static func defaultTime() -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private var weekdays: [(name: String, value: Int)] {
        let formatter = DateFormatter()
        return (1...7).map { (name: formatter.weekdaySymbols[$0 - 1], value: $0) }
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n {
        case 1, 21: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default:    suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}

#Preview {
    AddReminderView(pet: Pet(name: "Hope", birthday: Date(), species: "Dog", initialWeight: 22, unit: .pounds))
        .modelContainer(for: Pet.self, inMemory: true)
}
