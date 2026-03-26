//
//  RemindersListView.swift
//  Healthy Pet Tracker
//
//  Shows all reminders for a given pet with enable/disable toggles,
//  swipe-to-delete, and an add button. Gated behind Pro in PetDetailView;
//  this view assumes the user already has Pro access.
//
//  NOTE: This view is embedded inside a Section in PetDetailView's List,
//  so its body returns ForEach / rows directly (no wrapping VStack)
//  to keep swipe-actions and list styling working correctly.
//

import SwiftUI
import SwiftData

struct RemindersListView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var pet: Pet

    @State private var showingAddReminder = false
    @State private var showingEditReminder = false
    @State private var reminderToEdit: PetReminder?

    private var sortedReminders: [PetReminder] {
        pet.reminders.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Group {
            if pet.reminders.isEmpty {
                emptyState
            } else {
                ForEach(sortedReminders) { reminder in
                    ReminderRow(reminder: reminder, onToggle: { toggleReminder(reminder) })
                        .contentShape(Rectangle())
                        .onTapGesture {
                            reminderToEdit = reminder
                            showingEditReminder = true
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteReminder(reminder)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }

                Button {
                    showingAddReminder = true
                } label: {
                    Label("Add Reminder", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .tint(.accentPrimary)
            }
        }
        .sheet(isPresented: $showingAddReminder) {
            AddReminderView(pet: pet)
        }
        // Use isPresented (not sheet(item:)) to avoid a SwiftUI bug where
        // SwiftData @Model identity changes during re-renders cause the
        // sheet to immediately dismiss on the first tap.
        .sheet(isPresented: $showingEditReminder, onDismiss: { reminderToEdit = nil }) {
            if let reminder = reminderToEdit {
                AddReminderView(pet: pet, existingReminder: reminder)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bell.slash")
                .font(.system(size: 28))
                .foregroundStyle(Color.accentMuted)
                .accessibilityHidden(true)

            Text("No reminders yet")
                .font(.subheadline)
                .secondaryText()

            Button {
                showingAddReminder = true
            } label: {
                Label("Add Reminder", systemImage: "plus.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .tint(.accentPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    // MARK: - Actions

    private func toggleReminder(_ reminder: PetReminder) {
        reminder.isEnabled.toggle()
        if reminder.isEnabled {
            NotificationService.shared.schedule(reminder)
        } else {
            NotificationService.shared.cancel(reminder)
        }
        HapticManager.shared.impact(.light)
    }

    private func deleteReminder(_ reminder: PetReminder) {
        NotificationService.shared.cancel(reminder)
        modelContext.delete(reminder)
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Reminder Row

struct ReminderRow: View {
    @Bindable var reminder: PetReminder
    var onToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: reminder.reminderType.icon)
                .font(.system(size: 18))
                .foregroundStyle(reminder.isEnabled ? Color.accentPrimary : Color.accentMuted)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(reminder.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .primaryText()
                    .lineLimit(1)

                Text(reminder.scheduleDescription)
                    .font(.caption)
                    .tertiaryText()
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { reminder.isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(.accentPrimary)
        }
        .padding(.vertical, 4)
        .opacity(reminder.isEnabled ? 1.0 : 0.6)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(reminder.title), \(reminder.scheduleDescription)")
        .accessibilityValue(reminder.isEnabled ? "Enabled" : "Disabled")
        .accessibilityHint("Double-tap to edit, use toggle to enable or disable")
    }
}

#Preview {
    let pet = Pet(name: "Hope", birthday: Date(), species: "Dog", initialWeight: 22, unit: .pounds)
    List {
        Section("Reminders") {
            RemindersListView(pet: pet)
        }
    }
    .modelContainer(for: Pet.self, inMemory: true)
}
