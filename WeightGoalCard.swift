//
//  WeightGoalCard.swift
//  Pet Weight Tracker
//

import SwiftUI

struct WeightGoalCard: View {
    @Bindable var pet: Pet
    @State private var showingGoalEditor = false
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Weight Goal")
                    .font(.headline)
                    .primaryText()
                
                Spacer()
                
                Button(action: { showingGoalEditor = true }) {
                    Image(systemName: pet.hasWeightGoal ? "pencil.circle.fill" : "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.accentPrimary)
                }
                .accessibilityLabel(pet.hasWeightGoal ? "Edit weight goal" : "Add weight goal")
            }
            
            if pet.hasWeightGoal, 
               let target = pet.targetWeight,
               let unit = pet.targetWeightUnit,
               let progress = pet.weightGoalProgress {
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Target")
                                .font(.caption)
                                .tertiaryText()
                            Text(String(format: "%.1f %@", target, unit.symbol))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .primaryText()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Progress")
                                .font(.caption)
                                .tertiaryText()
                            Text(String(format: "%.0f%%", progress * 100))
                                .font(.title3)
                                .fontWeight(.semibold)
                                .foregroundStyle(progressColor(progress))
                            // Stage label so status isn't conveyed by color alone
                            Text(progressStageLabel(progress))
                                .font(.caption2)
                                .foregroundStyle(progressColor(progress))
                        }
                    }
                    
                    ProgressView(value: progress)
                        .tint(progressColor(progress))
                        .scaleEffect(y: 1.5)
                    
                    if progress >= 1.0 {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Goal achieved! 🎉")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.green)
                        }
                    }
                }
            } else {
                Button(action: { showingGoalEditor = true }) {
                    HStack {
                        Image(systemName: "target")
                            .foregroundStyle(Color.accentMuted)
                        Text("Set a weight goal")
                            .secondaryText()
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .tertiaryText()
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
        .background(Color.bgTertiary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
        .sheet(isPresented: $showingGoalEditor) {
            WeightGoalEditorView(pet: pet)
        }
    }
    
    private func progressColor(_ progress: Double) -> Color {
        if progress >= 1.0 {
            return .green
        } else if progress >= 0.5 {
            return .accentPrimary
        } else {
            return .accentMuted
        }
    }

    private func progressStageLabel(_ progress: Double) -> String {
        if progress >= 1.0  { return "Goal achieved!" }
        if progress >= 0.75 { return "Almost there" }
        if progress >= 0.5  { return "On track" }
        return "Just getting started"
    }
}

struct WeightGoalEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var pet: Pet
    
    @State private var targetWeight: String
    @State private var selectedUnit: WeightUnit
    
    init(pet: Pet) {
        self.pet = pet
        _targetWeight = State(initialValue: pet.targetWeight != nil ? String(format: "%.1f", pet.targetWeight!) : "")
        _selectedUnit = State(initialValue: pet.targetWeightUnit ?? pet.preferredUnit)
    }
    
    var body: some View {
        NavigationStack {
            ThemedForm {
                Section("Target Weight") {
                    HStack {
                        TextField("Weight", text: $targetWeight)
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
                
                if pet.hasWeightGoal {
                    Section {
                        Button(role: .destructive, action: removeGoal) {
                            HStack {
                                Spacer()
                                Text("Remove Goal")
                                Spacer()
                            }
                        }
                    }
                    .themedSection()
                }
            }
            .navigationTitle("Weight Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .tint(.textSecondary)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveGoal()
                    }
                    .disabled(!isValid)
                    .tint(.accentPrimary)
                }
            }
        }
    }
    
    private var isValid: Bool {
        guard let weight = Double(targetWeight), weight > 0 else { return false }
        return true
    }
    
    private func saveGoal() {
        guard let weight = Double(targetWeight) else { return }
        pet.targetWeight = weight
        pet.targetWeightUnit = selectedUnit
        dismiss()
    }
    
    private func removeGoal() {
        pet.targetWeight = nil
        pet.targetWeightUnit = nil
        dismiss()
    }
}

#Preview {
    let pet = Pet(name: "Max", birthday: Date(), species: "Dog", initialWeight: 45.0, unit: .pounds)
    pet.targetWeight = 50.0
    pet.targetWeightUnit = .pounds
    return WeightGoalCard(pet: pet)
        .padding()
        .background(Color.bgPrimary)
}
