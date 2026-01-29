//
//  PetDetailView.swift
//  Pet Weight Tracker
//

import SwiftUI
import SwiftData
import Charts

struct PetDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var pet: Pet
    @State private var showingAddWeight = false
    @State private var selectedEntry: WeightEntry?
    
    var body: some View {
        List {
            Section {
                PetInfoCard(pet: pet)
            }
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
            if !pet.sortedWeightEntries.isEmpty {
                Section("Weight Chart") {
                    WeightChartView(entries: pet.sortedWeightEntries, unit: pet.preferredUnit)
                        .frame(height: 250)
                        .padding(.vertical, 8)
                }
                
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
            } else {
                Section {
                    Text("No weight entries yet. Add your first weight entry to start tracking!")
                        .foregroundStyle(.secondary)
                        .padding()
                }
            }
        }
        .navigationTitle(pet.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddWeight = true }) {
                    Label("Add Weight", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddWeight) {
            AddWeightView(pet: pet)
        }
        .sheet(item: $selectedEntry) { entry in
            EditWeightView(entry: entry)
        }
    }
    
    private func deleteEntries(offsets: IndexSet) {
        withAnimation {
            let sortedEntries = pet.sortedWeightEntries.reversed()
            for index in offsets {
                let entry = Array(sortedEntries)[index]
                modelContext.delete(entry)
            }
        }
    }
}

struct PetInfoCard: View {
    @Bindable var pet: Pet
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(pet.species)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(pet.name)
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Born \(pet.birthday.formatted(date: .long, time: .omitted))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(pet.ageString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: speciesIcon(for: pet.species))
                    .font(.system(size: 50))
                    .foregroundStyle(.blue)
            }
            
            if let latest = pet.latestWeight {
                Divider()
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current Weight")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(latest.displayWeight)
                            .font(.title2)
                            .fontWeight(.semibold)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("Last Updated")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(latest.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.subheadline)
                    }
                }
            }
            
            Divider()
            
            HStack {
                Text("Preferred Unit")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("Unit", selection: $pet.preferredUnit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.displayName).tag(unit)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding()
    }
    
    private func speciesIcon(for species: String) -> String {
        switch species.lowercased() {
        case "dog": return "dog.fill"
        case "cat": return "cat.fill"
        case "rabbit": return "hare.fill"
        case "bird": return "bird.fill"
        case "fish": return "fish.fill"
        case "tortoise", "turtle", "reptile": return "tortoise.fill"
        default: return "pawprint.fill"
        }
    }
}

struct WeightEntryRow: View {
    let entry: WeightEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.headline)
                if !entry.notes.isEmpty {
                    Text(entry.notes)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Text(entry.displayWeight)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: Pet(name: "Max", birthday: Date(), species: "Dog", initialWeight: 45.5, unit: .pounds))
    }
    .modelContainer(for: Pet.self, inMemory: true)
}
