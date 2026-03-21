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

struct PetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject var entitlements: EntitlementService
    @Bindable var pet: Pet
    @State private var showingAddWeight = false
    @State private var selectedEntry: WeightEntry?
    @State private var csvExport: CSVExportData?
    @State private var showingDeleteAlert = false
    @State private var showingUpgrade = false

    var body: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    PetInfoCard(pet: pet)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

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
                                // Trend chip tapped → scroll to chart
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(ScrollID.chart, anchor: .top)
                                }
                            },
                            onEntriesTap: {
                                // Entries chip tapped → scroll to weight history
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(ScrollID.history, anchor: .top)
                                }
                            }
                        )
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .id(ScrollID.stats)

                    Section("Weight Chart") {
                        WeightChartView(entries: pet.sortedWeightEntries, unit: pet.preferredUnit)
                            .frame(height: 250)
                            .padding(.vertical, 8)
                    }
                    .themedSection()
                    .id(ScrollID.chart)

                    // MARK: - Reminders (Pro Feature)
                    Section("Reminders") {
                        if entitlements.hasPremium {
                            RemindersListView(pet: pet)
                        } else {
                            Button {
                                showingUpgrade = true
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "bell.badge.fill")
                                        .font(.system(size: 22))
                                        .foregroundStyle(Color.accentMuted)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Reminders")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .primaryText()
                                        Text("Upgrade to Pro for weight check-ins, vet alerts & more")
                                            .font(.caption)
                                            .tertiaryText()
                                    }

                                    Spacer()

                                    Image(systemName: "lock.fill")
                                        .font(.caption)
                                        .foregroundStyle(Color.accentMuted)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    .themedSection()

                    // MARK: - Breed Insights (Pro Feature)
                    Section("Breed Insights") {
                        BreedInsightView(pet: pet)
                    }
                    .themedSection()

                    Section("Weight History") {
                        ForEach(pet.sortedWeightEntries.reversed()) { entry in
                            WeightEntryRow(entry: entry)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedEntry = entry
                                }
                        }
                        .onDelete(perform: deleteEntries)
                    }
                    .themedSection()
                    .id(ScrollID.history)

                } else {
                    Section {
                        Text("No weight entries yet. Add your first weight entry to start tracking!")
                            .secondaryText()
                            .padding()
                    }
                    .themedSection()
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgPrimary)
            .navigationTitle(pet.name)
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showingAddWeight = true }) {
                            Label("Add Weight", systemImage: "plus")
                        }

                        if !pet.sortedWeightEntries.isEmpty {
                            Button(action: {
                                let csvString = DataExporter.exportToCSV(pet: pet)
                                if let data = csvString.data(using: .utf8) {
                                    csvExport = CSVExportData(
                                        data: data,
                                        fileName: "\(pet.name)_weight_data.csv"
                                    )
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
                    .tint(.accentPrimary)
                }
            }
        } // end ScrollViewReader
        .sheet(isPresented: $showingAddWeight) {
            AddWeightView(pet: pet)
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        .sheet(item: $selectedEntry) { entry in
            EditWeightView(entry: entry)
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

    private func deleteEntries(offsets: IndexSet) {
        withAnimation(reduceMotion ? nil : .default) {
            let sortedEntries = pet.sortedWeightEntries.reversed()
            for index in offsets {
                let entry = Array(sortedEntries)[index]
                modelContext.delete(entry)
            }
        }
        HapticManager.shared.notification(.success)
    }
}

// MARK: - PetInfoCard

struct PetInfoCard: View {
    @Bindable var pet: Pet

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.species)
                        .font(.subheadline)
                        .secondaryText()
                    Text(pet.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .primaryText()
                    Text("Born \(pet.birthday.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .secondaryText()
                    Text(pet.ageString)
                        .font(.subheadline)
                        .secondaryText()
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
                            .foregroundStyle(Color.accentActive)
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
                .tint(.accentPrimary)
            }
        }
        .padding()
        .background(Color.bgTertiary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
        .padding()
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
                .foregroundStyle(Color.accentActive)
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
