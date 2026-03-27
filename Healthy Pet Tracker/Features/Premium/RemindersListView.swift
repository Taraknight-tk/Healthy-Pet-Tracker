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

    // Single sheet state — avoids the SwiftUI bug where two .sheet modifiers
    // on a Group with SwiftData @Model objects cause the sheet to immediately
    // dismiss on the first tap. Using one Bool + one optional reference
    // eliminates all identity-comparison issues.
    @State private var showSheet = false
    @State private var reminderToEdit: PetReminder?

    private var sortedReminders: [PetReminder] {
        pet.reminders.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        Group {
            if pet.reminders.isEmpty {
                emptyState
            } else {
                // The row's tap-to-edit and the Toggle must be SEPARATE controls.
                // Nesting a Toggle inside a Button causes both to fire on a
                // single tap — the Button presents the sheet while the Toggle's
                // model change triggers a re-render, producing the UIKit error
                // "Attempt to present while a presentation is in progress."
                //
                // Fix: the row is a plain HStack. The info area (icon + text)
                // is a Button that opens the sheet. The Toggle sits beside it,
                // outside the Button, so it only responds to direct taps on
                // the switch itself.
                ForEach(sortedReminders) { reminder in
                    HStack(spacing: 12) {
                        Button {
                            reminderToEdit = reminder
                            showSheet = true
                        } label: {
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
                            }
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { reminder.isEnabled },
                            set: { _ in toggleReminder(reminder) }
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
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteReminder(reminder)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }

                Button {
                    reminderToEdit = nil
                    showSheet = true
                } label: {
                    Label("Add Reminder", systemImage: "plus.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .tint(.accentPrimary)
            }
        }
        // Single sheet for both add and edit. When reminderToEdit is nil,
        // AddReminderView shows the "new reminder" form. When non-nil,
        // it populates from the existing reminder for editing.
        .sheet(isPresented: $showSheet, onDismiss: { reminderToEdit = nil }) {
            AddReminderView(pet: pet, existingReminder: reminderToEdit)
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
                reminderToEdit = nil
                showSheet = true
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

// ReminderRow is inlined in the ForEach above so that the Toggle
// sits outside the Button — preventing the dual-tap conflict.

#Preview {
    let pet = Pet(name: "Hope", birthday: Date(), species: "Dog", initialWeight: 22, unit: .pounds)
    List {
        Section("Reminders") {
            RemindersListView(pet: pet)
        }
    }
    .modelContainer(for: Pet.self, inMemory: true)
}
