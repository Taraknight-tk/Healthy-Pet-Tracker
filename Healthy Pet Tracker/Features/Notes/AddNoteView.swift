//
//  AddNoteView.swift
//  Healthy Pet Tracker
//
//  Add or edit a PetNote (milestone / note entry without a weight measurement).
//  Pass `existingNote` to enter edit mode; leave nil to create a new note.
//
//  • All users: all note types + freeform text
//  • Pro users: can attach a photo to the note
//

import SwiftUI
import SwiftData

struct AddNoteView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var entitlements: EntitlementService

    let pet: Pet
    let existingNote: PetNote?

    @State private var noteType: NoteType
    @State private var date: Date
    @State private var noteText: String
    @State private var photoPath: String?

    private var isEditing: Bool { existingNote != nil }

    // MARK: - Init

    init(pet: Pet, existingNote: PetNote? = nil) {
        self.pet = pet
        self.existingNote = existingNote
        _noteType  = State(initialValue: existingNote?.noteType  ?? .general)
        _date      = State(initialValue: existingNote?.date      ?? Date())
        _noteText  = State(initialValue: existingNote?.noteText  ?? "")
        _photoPath = State(initialValue: existingNote?.photoPath)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ThemedForm {

                // ── Type + Date ──────────────────────────────────────────
                Section("Entry Details") {
                    DatePicker("Date", selection: $date, in: ...Date(), displayedComponents: .date)
                        .primaryText()

                    Picker("Type", selection: $noteType) {
                        ForEach(availableTypes, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type)
                        }
                    }
                    .primaryText()
                    .tint(.accentPrimary)
                }
                .themedSection()

                // ── Note text ────────────────────────────────────────────
                Section("Note") {
                    TextField(
                        notePlaceholder,
                        text: $noteText,
                        axis: .vertical
                    )
                    .lineLimit(3...8)
                    .primaryText()
                }
                .themedSection()

                // ── Photo (Pro) ──────────────────────────────────────────
                Section("Photo (Optional)") {
                    WeightEntryPhotoView(photoPath: $photoPath)
                }
                .themedSection()
            }
            .navigationTitle(isEditing ? "Edit Note" : "Add Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                        .tint(.accentPrimary)
                }
            }
        }
    }

    // MARK: - Helpers

    /// photoOnly type is only accessible for Pro users; filter it out for free.
    private var availableTypes: [NoteType] {
        NoteType.allCases.filter { type in
            type != .photoOnly || entitlements.hasPremium
        }
    }

    private var notePlaceholder: String {
        switch noteType {
        case .general:    return "What happened today?"
        case .vetVisit:   return "Vet visit notes, findings, next steps…"
        case .milestone:  return "Describe the milestone…"
        case .grooming:   return "Grooming notes…"
        case .medication: return "Medication name, dose, start date…"
        case .photoOnly:  return "Optional caption…"
        }
    }

    private var isValid: Bool {
        noteType == .photoOnly
            ? (photoPath != nil)                    // photo required for photo-only
            : !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func save() {
        if let note = existingNote {
            // Edit existing
            note.date      = date
            note.noteType  = noteType
            note.noteText  = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            note.photoPath = photoPath
        } else {
            // Create new
            let note = PetNote(
                date: min(date, Date()),
                noteText: noteText.trimmingCharacters(in: .whitespacesAndNewlines),
                noteType: noteType
            )
            note.photoPath = photoPath
            note.pet = pet
            modelContext.insert(note)
        }
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

#Preview {
    AddNoteView(pet: Pet(name: "Hope", birthday: Date(), species: "Dog", initialWeight: 22, unit: .pounds))
        .environmentObject(EntitlementService.shared)
        .environmentObject(StoreService.shared)
        .modelContainer(for: [Pet.self, PetNote.self], inMemory: true)
}
