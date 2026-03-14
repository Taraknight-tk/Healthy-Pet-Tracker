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
    @State private var customSpecies = ""
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
                        TextField("e.g. Ferret, Hedgehog…", text: $customSpecies)
                            .primaryText()
                            .autocorrectionDisabled()
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
            .onAppear {
                configureNavigationBarAppearance()
            }
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
        (species != "Other" || !customSpecies.trimmingCharacters(in: .whitespaces).isEmpty) &&
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
        
        let actualSpecies = species == "Other"
            ? customSpecies.trimmingCharacters(in: .whitespaces)
            : species

        let newPet = Pet(
            name: name.trimmingCharacters(in: .whitespaces),
            birthday: birthday,
            species: actualSpecies,
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

        HapticManager.shared.notification(.success)
        dismiss()
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        // UIColor(named:) reads from the asset catalog and automatically
        // resolves the correct light / dark / high-contrast variant.
        appearance.backgroundColor = UIColor.named("bgSecondary")
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.named("textPrimary")]
        appearance.titleTextAttributes      = [.foregroundColor: UIColor.named("textPrimary")]

        UINavigationBar.appearance().standardAppearance   = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance    = appearance
    }
}

#Preview {
    AddPetView()
        .modelContainer(for: Pet.self, inMemory: true)
}
