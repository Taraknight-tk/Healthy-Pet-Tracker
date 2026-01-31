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
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: { showingAddWeight = true }) {
                    Label("Add Weight", systemImage: "plus")
                }
                .tint(.accentPrimary)
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
                
                Image(systemName: speciesIcon(for: pet.species))
                    .font(.system(size: 50))
                    .foregroundStyle(Color.accentPrimary)
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
    }
}

#Preview {
    NavigationStack {
        PetDetailView(pet: Pet(name: "Max", birthday: Date(), species: "Dog", initialWeight: 45.5, unit: .pounds))
    }
    .modelContainer(for: Pet.self, inMemory: true)
}
