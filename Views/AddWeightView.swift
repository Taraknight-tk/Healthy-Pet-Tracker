//
//  AddWeightView.swift
//  Pet Weight Tracker
//

import SwiftUI
import SwiftData

struct AddWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    let pet: Pet
    
    @State private var weight = ""
    @State private var date = Date()
    @State private var selectedUnit: WeightUnit
    @State private var notes = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(pet: Pet) {
        self.pet = pet
        _selectedUnit = State(initialValue: pet.preferredUnit)
    }
    
    var body: some View {
        NavigationStack {
            ThemedForm {
                Section("Weight Entry") {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                        .primaryText()
                    
                    HStack {
                        TextField("Weight", text: $weight)
                            .keyboardType(.decimalPad)
                            .primaryText()
                        
                        Picker("Unit", selection: $selectedUnit) {
                            ForEach(WeightUnit.allCases, id: \.self) { unit in
                                Text(unit.symbol).tag(unit)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }
                .themedSection()
                
                Section("Notes (Optional)") {
                    TextField("Add notes about this weight entry", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .primaryText()
                }
                .themedSection()
                
                if let previous = pet.latestWeight, date > previous.date {
                    Section {
                        WeightComparisonView(
                            currentWeight: Double(weight) ?? 0,
                            currentUnit: selectedUnit,
                            previousEntry: previous
                        )
                    }
                    .themedSection()
                }
            }
            .navigationTitle("Add Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
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
                        saveWeight()
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
        !weight.isEmpty &&
        Double(weight) != nil &&
        Double(weight)! > 0
    }
    
    private func saveWeight() {
        guard isValid, let weightValue = Double(weight) else {
            errorMessage = "Please enter a valid weight."
            showingError = true
            return
        }
        
        let newEntry = WeightEntry(
            date: date,
            weight: weightValue,
            unit: selectedUnit,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        newEntry.pet = pet
        
        modelContext.insert(newEntry)
        
        dismiss()
    }
    
    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(Color.bgSecondary)
        
        // Set title text color to dark brown
        appearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Color.textPrimary)
        ]
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor(Color.textPrimary)
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
    }
}

struct WeightComparisonView: View {
    let currentWeight: Double
    let currentUnit: WeightUnit
    let previousEntry: WeightEntry
    
    private var difference: Double {
        let current = normalizedWeight(currentWeight, unit: currentUnit)
        let previous = normalizedWeight(previousEntry.weight, unit: previousEntry.unit)
        return current - previous
    }
    
    private var percentageChange: Double {
        let previous = normalizedWeight(previousEntry.weight, unit: previousEntry.unit)
        guard previous > 0 else { return 0 }
        return (difference / previous) * 100
    }
    
    private var displayDifference: String {
        let absValue = abs(difference)
        let converted: Double
        
        switch currentUnit {
        case .pounds:
            converted = absValue / 0.453592 // Convert kg to lbs
        case .kilograms:
            converted = absValue
        case .ounces:
            converted = absValue / 0.0283495
        case .grams:
            converted = absValue / 1000
        }
        
        return String(format: "%.1f %@", converted, currentUnit.symbol)
    }
    
    var body: some View {
        HStack {
            Image(systemName: difference > 0 ? "arrow.up.circle.fill" : difference < 0 ? "arrow.down.circle.fill" : "equal.circle.fill")
                .foregroundStyle(difference > 0 ? Color.accentMuted : difference < 0 ? Color.accentActive : Color.accentPrimary)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Change from last entry")
                    .font(.caption)
                    .tertiaryText()
                
                if difference == 0 {
                    Text("No change")
                        .font(.headline)
                        .primaryText()
                } else {
                    Text("\(difference > 0 ? "+" : "")\(displayDifference)")
                        .font(.headline)
                        .primaryText()
                    Text("\(String(format: "%.1f", abs(percentageChange)))% \(difference > 0 ? "increase" : "decrease")")
                        .font(.caption)
                        .tertiaryText()
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func normalizedWeight(_ weight: Double, unit: WeightUnit) -> Double {
        // Normalize to kg for comparison
        switch unit {
        case .kilograms:
            return weight
        case .pounds:
            return weight * 0.45359237
        case .ounces:
            return weight * 0.028349523125
        case .grams:
            return weight * 0.001
        }
    }
}

#Preview {
    let pet = Pet(name: "Max", birthday: Date(), species: "Dog", initialWeight: 45.0, unit: .pounds)
    return AddWeightView(pet: pet)
        .modelContainer(for: Pet.self, inMemory: true)
}
