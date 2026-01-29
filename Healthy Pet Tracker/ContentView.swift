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
                    VStack(spacing: 20) {
                        Image(systemName: "pawprint.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("No Pets Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Add your first pet to start tracking their weight")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button(action: { showingAddPet = true }) {
                            Label("Add Pet", systemImage: "plus.circle.fill")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top)
                    }
                    .padding()
                } else {
                    List {
                        ForEach(pets) { pet in
                            NavigationLink(destination: PetDetailView(pet: pet)) {
                                PetRowView(pet: pet)
                            }
                        }
                        .onDelete(perform: deletePets)
                    }
                }
            }
            .navigationTitle("Pet Weight Tracker")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddPet = true }) {
                        Label("Add Pet", systemImage: "plus")
                    }
                }
                
                if !pets.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showingAddPet) {
                AddPetView()
            }
        }
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
                Text(pet.species)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(pet.ageString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            if let latestWeight = pet.latestWeight {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(latestWeight.displayWeight)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(latestWeight.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Pet.self, inMemory: true)
}
