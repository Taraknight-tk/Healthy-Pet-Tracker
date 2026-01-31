//
//  Models.swift
//  Pet Weight Tracker
//

import Foundation
import SwiftData

@Model
final class Pet {
    var id: UUID
    var name: String
    var birthday: Date
    var species: String
    var preferredUnit: WeightUnit
    
    @Relationship(deleteRule: .cascade, inverse: \WeightEntry.pet)
    var weightEntries: [WeightEntry] = []
    
    init(name: String, birthday: Date, species: String, initialWeight: Double, unit: WeightUnit) {
        self.id = UUID()
        self.name = name
        self.birthday = birthday
        self.species = species
        self.preferredUnit = unit
    }
    
    var sortedWeightEntries: [WeightEntry] {
        weightEntries.sorted { $0.date < $1.date }
    }
    
    var latestWeight: WeightEntry? {
        weightEntries.sorted { $0.date > $1.date }.first
    }
    
    var ageString: String {
        let components = Calendar.current.dateComponents([.year, .month], from: birthday, to: Date())
        if let years = components.year, years > 0 {
            return "\(years) year\(years == 1 ? "" : "s") old"
        } else if let months = components.month, months > 0 {
            return "\(months) month\(months == 1 ? "" : "s") old"
        }
        return "Just born"
    }
}

@Model
final class WeightEntry {
    var id: UUID
    var date: Date
    var weight: Double
    var unit: WeightUnit
    var notes: String
    
    var pet: Pet?
    
    init(date: Date, weight: Double, unit: WeightUnit, notes: String = "") {
        self.id = UUID()
        self.date = date
        self.weight = weight
        self.unit = unit
        self.notes = notes
    }
    
    var displayWeight: String {
        String(format: "%.1f %@", weight, unit.symbol)
    }
    
    // Convert weight to a standard unit for comparison
    var weightInKg: Double {
        switch unit {
        case .pounds:
            return weight * 0.453592
        case .kilograms:
            return weight
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable {
    case pounds = "lbs"
    case kilograms = "kg"
    
    var symbol: String {
        self.rawValue
    }
    
    var displayName: String {
        switch self {
        case .pounds: return "Pounds"
        case .kilograms: return "Kilograms"
        }
    }
}
