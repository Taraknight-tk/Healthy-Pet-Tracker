//
//  PetDetailView.swift
//  Pet Weight Tracker
//

import SwiftUI
import SwiftData
import Charts
import PhotosUI

// MARK: - Scroll anchor IDs

private enum ScrollID: Hashable {
    case chart
    case stats
    case history
}

struct CSVExportData: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
}

// MARK: - Timeline item (weight entry or note — merged + sorted by date)

enum TimelineItem: Identifiable {
    case weight(WeightEntry)
    case note(PetNote)

    var id: UUID {
        switch self {
        case .weight(let e): return e.id
        case .note(let n):   return n.id
        }
    }
    var date: Date {
        switch self {
        case .weight(let e): return e.date
        case .note(let n):   return n.date
        }
    }
}

struct PetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var entitlements: EntitlementService
    @Bindable var pet: Pet

    @State private var showingAddWeight  = false
    @State private var showingAddNote    = false
    @State private var selectedEntry: WeightEntry?
    @State private var editingNote: PetNote?
    @State private var csvExport: CSVExportData?
    @State private var showingDeleteAlert = false
    @State private var showingUpgrade     = false

    // Merged, newest-first timeline
    private var timelineItems: [TimelineItem] {
        let weights = pet.sortedWeightEntries.map { TimelineItem.weight($0) }
        let notes   = pet.notes.map             { TimelineItem.note($0) }
        return (weights + notes).sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List {
                // ── Pet info card ─────────────────────────────────────────
                Section {
                    PetInfoCard(pet: pet)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

                // ── Weight-specific sections (only when entries exist) ─────
                if !pet.sortedWeightEntries.isEmpty {
                    Section {
                        WeightGoalCard(pet: pet)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Section {
                        WeightStatsCard(
                            pet: pet,
                            onTrendTap: {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(ScrollID.chart, anchor: .top)
                                }
                            },
                            onEntriesTap: {
                                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(ScrollID.history, anchor: .top)
                                }
                            }
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .id(ScrollID.stats)

                    Section("Weight Chart") {
                        WeightChartView(
                            entries: pet.sortedWeightEntries,
                            unit: pet.preferredUnit,
                            notes: pet.notes
                        )
                        .frame(height: 250)
                        .padding(.vertical, 8)
                    }
                    .themedSection()
                    .id(ScrollID.chart)

                    // Reminders (Pro)
                    Section("Reminders") {
                        if entitlements.hasPremium {
                            RemindersListView(pet: pet)
                        } else {
                            Button { showingUpgrade = true } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.accentInteractive)
                                        .frame(width: 28)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Reminders")
                                            .font(.subheadline).fontWeight(.medium).primaryText()
                                        Text("Upgrade to Pro for weight check-ins, vet alerts & more")
                                            .font(.caption).tertiaryText()
                                    }
                                    Spacer()
                                    Image(systemName: "lock.fill").font(.caption).foregroundStyle(Color.accentInteractive)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .themedSection()

                    // Breed Insights (Pro)
                    Section("Breed Insights") {
                        BreedInsightView(pet: pet)
                    }
                    .themedSection()
                }

                // ── Activity log (weight entries + notes merged) ──────────
                if !timelineItems.isEmpty {
                    Section("Activity Log") {
                        ForEach(timelineItems) { item in
                            switch item {
                            case .weight(let entry):
                                WeightEntryRow(entry: entry)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedEntry = entry }
                            case .note(let note):
                                PetNoteRow(note: note)
                                    .contentShape(Rectangle())
                                    .onTapGesture { editingNote = note }
                            }
                        }
                        .onDelete(perform: deleteTimelineItems)
                    }
                    .themedSection()
                    .id(ScrollID.history)
                } else {
                    Section {
                        Text("No entries yet. Tap + to add a weight entry or a note.")
                            .secondaryText()
                            .padding()
                    }
                    .themedSection()
                }

                // ── Documents (Pro) ───────────────────────────────────────
                Section("Documents") {
                    DocumentsSection(pet: pet)
                }
                .themedSection()
            }
            .scrollContentBackground(.hidden)
            .background(Color.background)
            .navigationTitle(pet.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.fillSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showingAddWeight = true }) {
                            Label("Add Weight Entry", systemImage: "scalemass")
                        }
                        Button(action: { showingAddNote = true }) {
                            Label("Add Note / Milestone", systemImage: "note.text.badge.plus")
                        }

                        if !pet.sortedWeightEntries.isEmpty {
                            Divider()
                            Button(action: {
                                let csvString = DataExporter.exportToCSV(pet: pet)
                                if let data = csvString.data(using: .utf8) {
                                    csvExport = CSVExportData(data: data, fileName: "\(pet.name)_weight_data.csv")
                                }
                            }) {
                                Label("Export Data", systemImage: "square.and.arrow.up")
                            }
                        }

                        Divider()
                        Button(role: .destructive, action: { showingDeleteAlert = true }) {
                            Label("Delete Pet", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("More options")
                    }
                    .tint(.accentInteractive)
                }
            }
        } // end ScrollViewReader
        .sheet(isPresented: $showingAddWeight) {
            AddWeightView(pet: pet)
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteView(pet: pet)
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        .sheet(item: $selectedEntry) { entry in
            EditWeightView(entry: entry)
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        .sheet(item: $editingNote) { note in
            AddNoteView(pet: pet, existingNote: note)
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        .sheet(item: $csvExport) { exportData in
            ShareSheet(items: [exportData.data], fileName: exportData.fileName)
        }
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        .alert("Delete \(pet.name)?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                modelContext.delete(pet)
                dismiss()
            }
        } message: {
            Text("This will permanently delete \(pet.name) and all their weight history. This cannot be undone.")
        }
    }

    // MARK: - Delete helpers

    private func deleteTimelineItems(_ offsets: IndexSet) {
        withAnimation(reduceMotion ? nil : .default) {
            for index in offsets {
                switch timelineItems[index] {
                case .weight(let entry): modelContext.delete(entry)
                case .note(let note):   modelContext.delete(note)
                }
            }
        }
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Pet Note Row

struct PetNoteRow: View {
    let note: PetNote
    @State private var showingPhoto = false

    var body: some View {
        HStack(spacing: 10) {
            // Type icon
            Image(systemName: note.noteType.icon)
                .font(.system(size: 18))
                .foregroundStyle(note.noteType.color)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(note.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.headline)
                        .primaryText()
                    Text(note.noteType.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(note.noteType.color)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(note.noteType.color.opacity(0.12))
                        .clipShape(Capsule())
                }
                if !note.noteText.isEmpty {
                    Text(note.noteText)
                        .font(.subheadline)
                        .secondaryText()
                        .lineLimit(2)
                }
            }

            Spacer()

            // Photo thumbnail
            if let path = note.photoPath, UIImage(contentsOfFile: path) != nil {
                Button { showingPhoto = true } label: {
                    EntryThumbnailView(path: path)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View photo")
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint("Double-tap to edit")
        .fullScreenCover(isPresented: $showingPhoto) {
            if let path = note.photoPath {
                PhotoFullScreenView(imagePath: path)
            }
        }
    }

    private var rowAccessibilityLabel: String {
        let dateStr = note.date.formatted(date: .abbreviated, time: .omitted)
        var parts = ["\(note.noteType.displayName) on \(dateStr)"]
        if !note.noteText.isEmpty { parts.append(note.noteText) }
        if note.photoPath != nil  { parts.append("Has photo") }
        return parts.joined(separator: ". ")
    }
}

// MARK: - PetInfoCard

struct PetInfoCard: View {
    @Bindable var pet: Pet

    // Inline name editing
    @State private var isEditingName = false
    @State private var draftName = ""

    // Inline birthday editing
    @State private var isEditingBirthday = false
    @State private var draftBirthday = Date()

    var body: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.species)
                        .font(.subheadline)
                        .secondaryText()

                    // ── Inline name ──────────────────────────────────────
                    if isEditingName {
                        HStack(spacing: 6) {
                            TextField("Pet name", text: $draftName)
                                .font(.title)
                                .fontWeight(.bold)
                                .primaryText()
                                .textFieldStyle(.plain)
                                .submitLabel(.done)
                                .onSubmit { commitName() }
                            Button(action: commitName) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentInteractive)
                                    .font(.title3)
                            }
                            .accessibilityLabel("Save name")
                        }
                    } else {
                        HStack(spacing: 5) {
                            Text(pet.name)
                                .font(.title)
                                .fontWeight(.bold)
                                .primaryText()
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundStyle(Color.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .onTapGesture {
                            draftName = pet.name
                            isEditingBirthday = false
                            isEditingName = true
                        }
                        .accessibilityLabel(pet.name)
                        .accessibilityHint("Double-tap to rename")
                        .accessibilityAddTraits(.isButton)
                    }

                    // ── Inline birthday ──────────────────────────────────
                    if isEditingBirthday {
                        VStack(alignment: .leading, spacing: 4) {
                            DatePicker(
                                "Birthday",
                                selection: $draftBirthday,
                                in: ...Date(),
                                displayedComponents: .date
                            )
                            .labelsHidden()
                            .datePickerStyle(.compact)
                            .tint(.accentInteractive)

                            Button("Done") { commitBirthday() }
                                .font(.caption)
                                .fontWeight(.medium)
                                .tint(.accentInteractive)
                        }
                    } else {
                        HStack(spacing: 5) {
                            Text("Born \(pet.birthday.formatted(date: .long, time: .omitted))")
                                .font(.subheadline)
                                .secondaryText()
                            Image(systemName: "pencil")
                                .font(.caption2)
                                .foregroundStyle(Color.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .onTapGesture {
                            draftBirthday = pet.birthday
                            isEditingName = false
                            isEditingBirthday = true
                        }
                        .accessibilityLabel("Born \(pet.birthday.formatted(date: .long, time: .omitted))")
                        .accessibilityHint("Double-tap to edit birthday")
                        .accessibilityAddTraits(.isButton)
                    }

                    if !isEditingBirthday {
                        Text(pet.ageString)
                            .font(.subheadline)
                            .secondaryText()
                    }
                }

                Spacer()

                PetPhotoView(pet: pet)
            }

            if let latest = pet.latestWeight {
                Divider()
                    .background(Color.borderSubtle)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Weight")
                            .font(.caption)
                            .tertiaryText()
                        Text(latest.displayWeight)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.accentInteractive)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last Updated")
                            .font(.caption)
                            .tertiaryText()
                        Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                            .secondaryText()
                    }
                }
            }

            Divider()
                .background(Color.borderSubtle)

            HStack {
                Text("Preferred Unit")
                    .font(.subheadline)
                    .secondaryText()
                Spacer()
                Picker("Unit", selection: $pet.preferredUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .tint(.accentInteractive)
            }
        }
        .padding()
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
        .padding()
        // Dismiss both editors if user taps elsewhere in the card
        .contentShape(Rectangle())
        .onTapGesture {
            if isEditingName { commitName() }
            if isEditingBirthday { commitBirthday() }
        }
    }

    // MARK: - Commit helpers

    private func commitName() {
        let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            pet.name = trimmed
        }
        isEditingName = false
        HapticManager.shared.impact(.light)
    }

    private func commitBirthday() {
        pet.birthday = draftBirthday
        isEditingBirthday = false
        HapticManager.shared.impact(.light)
    }
}

// MARK: - WeightEntryRow

struct WeightEntryRow: View {
    let entry: WeightEntry
    @State private var showingPhoto = false

    var body: some View {
        HStack(spacing: 10) {

            // Thumbnail — only rendered when a photo exists
            if let path = entry.photoPath, UIImage(contentsOfFile: path) != nil {
                Button { showingPhoto = true } label: {
                    EntryThumbnailView(path: path)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("View photo")
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                    .primaryText()
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .tertiaryText()
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(entry.displayWeight)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentInteractive)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(rowAccessibilityLabel)
        .accessibilityHint("Double-tap to edit")
        .fullScreenCover(isPresented: $showingPhoto) {
            if let path = entry.photoPath {
                PhotoFullScreenView(imagePath: path)
            }
        }
    }

    private var rowAccessibilityLabel: String {
        let dateStr = entry.date.formatted(date: .abbreviated, time: .omitted)
        var parts = ["\(entry.displayWeight) on \(dateStr)"]
        if !entry.notes.isEmpty { parts.append(entry.notes) }
        if entry.photoPath != nil { parts.append("Has photo") }
        return parts.joined(separator: ". ")
    }
}

/// Small thumbnail used in WeightEntryRow.
struct EntryThumbnailView: View {
    let path: String

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 7))
        }
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: Pet(name: "Max", birthday: Date(), species: "Dog", initialWeight: 45.5, unit: .pounds))
    }
    .modelContainer(for: Pet.self, inMemory: true)
}
