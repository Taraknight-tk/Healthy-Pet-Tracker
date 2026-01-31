//
//  AddPetView.swift
//  Pet Weight Tracker
//

import SwiftUI
import SwiftData

struct AddPetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var birthday = Date()
    @State private var species = ""
    @State private var initialWeight = ""
    @State private var selectedUnit = WeightUnit.pounds
    @State private var showingError = false
    @State private var errorMessage = ""
    
    let commonSpecies = ["Dog", "Cat", "Rabbit", "Guinea Pig", "Hamster", "Bird", "Reptile", "Other"]
    
    var body: some View {
        NavigationStack {
            ThemedForm {
                Section("Pet Information") {
                    TextField("Name", text: $name)
                        .primaryText()
                    
                    DatePicker("Birthday", selection: $birthday, displayedComponents: .date)
                        .primaryText()
                    
                    Picker("Species", selection: $species) {
                        Text("Select Species").tag("").secondaryText()
                        ForEach(commonSpecies, id: \.self) { species in
                            Text(species).tag(species).primaryText()
                        }
                    }
                    .primaryText()
                    
                    if species == "Other" {
                        TextField("Specify Species", text: $species)
                            .primaryText()
                    }
                }
                .themedSection()
                
                Section("Initial Weight") {
                    HStack {
                        TextField("Weight", text: $initialWeight)
                            .keyboardType(.decimalPad)
                            .primaryText()
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.symbol).tag(unit).primaryText()
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }
                .themedSection()
                
                Section {
                    Text("You can change the preferred unit for this pet later in their detail view.")
                        .font(.caption)
                        .tertiaryText()
                }
                .themedSection()
            }
            .navigationTitle("Add New Pet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        savePet()
                    }
                    .disabled(!isValid)
                    .tint(.accentPrimary)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !species.isEmpty &&
        species != "Select Species" &&
        !initialWeight.isEmpty &&
        Double(initialWeight) != nil &&
        Double(initialWeight)! > 0
    }
    
    private func savePet() {
        guard isValid,
              let weight = Double(initialWeight) else {
            errorMessage = "Please fill in all fields correctly."
            showingError = true
            return
        }
        
        let newPet = Pet(
            name: name.trimmingCharacters(in: .whitespaces),
            birthday: birthday,
            species: species,
            initialWeight: weight,
            unit: selectedUnit
        )
        
        // Add initial weight entry
        let initialEntry = WeightEntry(
            date: Date(),
            weight: weight,
            unit: selectedUnit,
            notes: "Initial weight"
        )
        initialEntry.pet = newPet
        newPet.weightEntries.append(initialEntry)
        
        modelContext.insert(newPet)
        modelContext.insert(initialEntry)
        
        dismiss()
    }
}

#Preview {
    AddPetView()
        .modelContainer(for: Pet.self, inMemory: true)
}
