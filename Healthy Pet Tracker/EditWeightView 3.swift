//
//  EditWeightView.swift
//  Pet Weight Tracker
//

import SwiftUI
import SwiftData

struct EditWeightView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @Bindable var entry: WeightEntry
    
    @State private var weight: String
    @State private var date: Date
    @State private var selectedUnit: WeightUnit
    @State private var notes: String
    @State private var showingDeleteAlert = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    init(entry: WeightEntry) {
        self.entry = entry
        _weight = State(initialValue: String(format: "%.1f", entry.weight))
        _date = State(initialValue: entry.date)
        _selectedUnit = State(initialValue: entry.unit)
        _notes = State(initialValue: entry.notes)
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
                
                Section("Notes") {
                    TextField("Add notes about this weight entry", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                        .primaryText()
                }
                .themedSection()
                
                Section {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        HStack {
                            Spacer()
                            Label("Delete Entry", systemImage: "trash")
                                .foregroundStyle(.red)
                            Spacer()
                        }
                    }
                }
                .themedSection()
            }
            .navigationTitle("Edit Weight")
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
                        saveChanges()
                    }
                    .disabled(!isValid)
                    .tint(.accentPrimary)
                }
            }
            .alert("Delete Entry", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    deleteEntry()
                }
            } message: {
                Text("Are you sure you want to delete this weight entry? This action cannot be undone.")
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
    
    private func saveChanges() {
        guard isValid, let weightValue = Double(weight) else {
            errorMessage = "Please enter a valid weight."
            showingError = true
            return
        }
        
        entry.weight = weightValue
        entry.date = date
        entry.unit = selectedUnit
        entry.notes = notes.trimmingCharacters(in: .whitespaces)
        
        dismiss()
    }
    
    private func deleteEntry() {
        modelContext.delete(entry)
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

#Preview {
    let entry = WeightEntry(date: Date(), weight: 45.5, unit: .pounds, notes: "After morning walk")
    return EditWeightView(entry: entry)
        .modelContainer(for: WeightEntry.self, inMemory: true)
}
