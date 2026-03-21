//
//  ContentView.swift
//  Pet Weight Tracker
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Pet.name) private var pets: [Pet]
    @State private var showingAddPet = false
    @State private var renamingPet: Pet? = nil
    @State private var draftName: String = ""
    @State private var deletingPet: Pet? = nil

    // Two flexible columns; adapts to any screen width
    private let gridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        NavigationStack {
            Group {
                if pets.isEmpty {
                    emptyStateView
                } else {
                    petGridView
                }
            }
            .navigationTitle("My Pets")
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .background(Color.bgPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddPet = true }) {
                        Label("Add Pet", systemImage: "plus")
                    }
                    .tint(.accentPrimary)
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
        }
        .tint(.accentPrimary)
        // ── Rename alert ────────────────────────────────────────────────────
        .alert("Rename Pet", isPresented: Binding(
            get: { renamingPet != nil },
            set: { if !$0 { renamingPet = nil } }
        )) {
            TextField("Pet name", text: $draftName)
            Button("Cancel", role: .cancel) { renamingPet = nil }
            Button("Save") {
                guard let pet = renamingPet else { return }
                let trimmed = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                pet.name = trimmed
                try? modelContext.save()
                renamingPet = nil
            }
        } message: {
            Text("Enter a new name for your pet.")
        }
        // ── Delete alert ─────────────────────────────────────────────────────
        .alert("Delete \(deletingPet?.name ?? "Pet")?", isPresented: Binding(
            get: { deletingPet != nil },
            set: { if !$0 { deletingPet = nil } }
        )) {
            Button("Cancel", role: .cancel) { deletingPet = nil }
            Button("Delete", role: .destructive) {
                if let pet = deletingPet {
                    withAnimation(reduceMotion ? nil : .default) { modelContext.delete(pet) }
                    deletingPet = nil
                    HapticManager.shared.notification(.success)
                }
            }
        } message: {
            Text("This will permanently delete \(deletingPet?.name ?? "this pet") and all their weight history. This cannot be undone.")
        }
    }

    // MARK: - Empty state

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentMuted)
                .accessibilityHidden(true)
            Text("No Pets Yet")
                .font(.title2)
                .fontWeight(.semibold)
                .primaryText()
            Text("Add your first pet to start tracking their weight")
                .secondaryText()
                .multilineTextAlignment(.center)
            Button(action: { showingAddPet = true }) {
                Label("Add Pet", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            .buttonStyle(.borderedProminent)
            .tint(.accentPrimary)
            .padding(.top)
        }
        .padding()
    }

    // MARK: - Pet grid

    private var petGridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 12) {
                ForEach(pets) { pet in
                    NavigationLink(destination: PetDetailView(pet: pet)) {
                        PetGridCard(pet: pet)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button {
                            draftName = pet.name
                            renamingPet = pet
                        } label: {
                            Label("Rename", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            deletingPet = pet
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 32)
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
    }
}

// MARK: - Pet Grid Card

struct PetGridCard: View {
    let pet: Pet

    private let photoHeight: CGFloat = 130

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // ── Photo / placeholder area ─────────────────────────────────
            photoArea
                .frame(height: photoHeight)
                .clipped()

            // ── Info area ────────────────────────────────────────────────
            VStack(alignment: .leading, spacing: 5) {
                Text(pet.name)
                    .font(.headline)
                    .primaryText()
                    .lineLimit(1)

                if let latest = pet.latestWeight {
                    Text(latest.displayWeight)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentActive)

                    HStack(spacing: 4) {
                        Image(systemName: pet.weightTrend.icon)
                            .font(.caption2)
                            .foregroundStyle(pet.weightTrend.color)
                            .accessibilityHidden(true)
                        Text(pet.weightTrend.description)
                            .font(.caption)
                            .foregroundStyle(pet.weightTrend.color)
                    }
                } else {
                    Text("No entries yet")
                        .font(.caption)
                        .tertiaryText()
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.bgTertiary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
        // Accessibility: reads as a single summary instead of fragments
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(cardAccessibilityLabel)
        .accessibilityHint("Double-tap to view details")
    }

    // MARK: - Photo area

    @ViewBuilder
    private var photoArea: some View {
        if let path = pet.photoPath,
           let uiImage = UIImage(contentsOfFile: path) {
            // Pro user with photo set
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
        } else {
            // Placeholder — species icon centred on brand background
            Rectangle()
                .fill(Color.bgPrimary)
                .overlay(
                    Image(systemName: speciesIcon(for: pet.species))
                        .font(.system(size: 44))
                        .foregroundStyle(Color.accentPrimary.opacity(0.35))
                        .accessibilityHidden(true)
                )
        }
    }

    // MARK: - Helpers

    private var cardAccessibilityLabel: String {
        var parts = ["\(pet.name), \(pet.species), \(pet.ageString)"]
        if let latest = pet.latestWeight {
            parts.append("\(latest.displayWeight), \(pet.weightTrend.description)")
        } else {
            parts.append("No weight entries yet")
        }
        return parts.joined(separator: ". ")
    }

    private func speciesIcon(for species: String) -> String {
        switch species.lowercased() {
        case "dog":                           return "dog.fill"
        case "cat":                           return "cat.fill"
        case "rabbit":                        return "hare.fill"
        case "bird":                          return "bird.fill"
        case "fish":                          return "fish.fill"
        case "tortoise", "turtle", "reptile": return "tortoise.fill"
        default:                              return "pawprint.fill"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Pet.self, inMemory: true)
}
