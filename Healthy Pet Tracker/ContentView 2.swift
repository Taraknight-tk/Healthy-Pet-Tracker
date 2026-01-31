//
//  ContentView.swift
//  Pet Weight Tracker
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pet.name) private var pets: [Pet]
    @State private var showingAddPet = false
    
    var body: some View {
        NavigationStack {
            Group {
                if pets.isEmpty {
                    emptyStateView
                } else {
                    petListView
                }
            }
            .navigationTitle("Pet Weight Tracker")
            .toolbarBackground(Color.bgSecondary, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .background(Color.bgPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddPet = true }) {
                        Label("Add Pet", systemImage: "plus")
                    }
                    .tint(.accentPrimary)
                }
                
                if !pets.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                            .tint(.accentPrimary)
                    }
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
        }
        .tint(.accentPrimary)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "pawprint.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentMuted)
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
    
    private var petListView: some View {
        List {
            ForEach(pets) { pet in
                NavigationLink(destination: PetDetailView(pet: pet)) {
                    PetRowView(pet: pet)
                }
                .listRowBackground(Color.bgTertiary)
            }
            .onDelete(perform: deletePets)
            .listRowSeparatorTint(Color.borderSubtle)
        }
        .scrollContentBackground(.hidden)
        .background(Color.bgPrimary)
    }
    
    private func deletePets(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(pets[index])
            }
        }
    }
}

struct PetRowView: View {
    let pet: Pet
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(pet.name)
                    .font(.headline)
                    .primaryText()
                Text(pet.species)
                    .font(.subheadline)
                    .secondaryText()
                Text(pet.ageString)
                    .font(.caption)
                    .tertiaryText()
            }
            
            Spacer()
            
            if let latestWeight = pet.latestWeight {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(latestWeight.displayWeight)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentActive)
                    Text(latestWeight.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .tertiaryText()
                }
            } else {
                Text("No entries")
                    .font(.caption)
                    .tertiaryText()
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Pet.self, inMemory: true)
}
