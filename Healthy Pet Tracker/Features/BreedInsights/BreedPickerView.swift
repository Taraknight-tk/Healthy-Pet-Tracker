//
//  BreedPickerView.swift
//  Healthy Pet Tracker
//
//  Sheet that lets users search and select their pet's breed + sex.
//  Filters the breed list by the pet's existing species field.
//  Mixed breeds appear at the bottom of the list.
//

import SwiftUI

struct BreedPickerView: View {
    @Bindable var pet: Pet
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var entitlements: EntitlementService
    @EnvironmentObject var store: StoreService

    @State private var searchText = ""
    @State private var selectedBreed: String?
    @State private var selectedSex: PetSex?

    private var allBreeds: [String] {
        BreedService.shared.breedNames(for: pet.species)
    }

    private var filteredBreeds: [String] {
        guard !searchText.isEmpty else { return allBreeds }
        return allBreeds.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    // Separate mixed-breed entries so they always appear at the bottom
    private var regularBreeds: [String] {
        filteredBreeds.filter { !$0.hasPrefix("Mixed Breed") && !$0.hasPrefix("Domestic") }
    }
    private var mixedBreeds: [String] {
        filteredBreeds.filter { $0.hasPrefix("Mixed Breed") || $0.hasPrefix("Domestic") }
    }

    var body: some View {
        NavigationStack {
            List {
                // Sex picker — top of sheet
                Section("Sex") {
                    Picker("Sex", selection: $selectedSex) {
                        Text("Unknown").tag(Optional<PetSex>(nil))
                        ForEach(PetSex.allCases, id: \.self) { sex in
                            Text(sex.displayName).tag(Optional(sex))
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                // Breed list
                if !regularBreeds.isEmpty {
                    Section("Breeds") {
                        ForEach(regularBreeds, id: \.self) { breed in
                            BreedRow(breed: breed, isSelected: selectedBreed == breed) {
                                selectedBreed = breed
                            }
                        }
                    }
                }

                if !mixedBreeds.isEmpty {
                    Section("Mixed / Unknown") {
                        ForEach(mixedBreeds, id: \.self) { breed in
                            BreedRow(breed: breed, isSelected: selectedBreed == breed) {
                                selectedBreed = breed
                            }
                        }
                    }
                }

                if filteredBreeds.isEmpty {
                    Section {
                        ContentUnavailableView.search(text: searchText)
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search breeds…")
            .navigationTitle("Select Breed")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        pet.breed = selectedBreed
                        pet.sex   = selectedSex
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedBreed == nil)
                }
            }
            .onAppear {
                selectedBreed = pet.breed
                selectedSex   = pet.sex
            }
        }
    }
}

// MARK: - Row

private struct BreedRow: View {
    let breed: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                Text(breed)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.tint)
                        .fontWeight(.semibold)
                }
            }
        }
    }
}
