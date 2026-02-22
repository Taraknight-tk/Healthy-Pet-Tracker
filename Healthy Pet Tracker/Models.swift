//
//  Models.swift
//  Pet Weight Tracker
//

import Foundation
import SwiftData
import SwiftUI

@Model
final class Pet {
    var id: UUID
    var name: String
    var birthday: Date
    var species: String
    var preferredUnit: WeightUnit
    var targetWeight: Double?
    var targetWeightUnit: WeightUnit?
    
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
        // More efficient: use max instead of sorting entire array
        weightEntries.max(by: { $0.date < $1.date })
    }
    
    var hasWeightGoal: Bool {
        targetWeight != nil && targetWeightUnit != nil
    }
    
    var targetWeightInKg: Double? {
        guard let target = targetWeight, let unit = targetWeightUnit else { return nil }
        
        switch unit {
        case .pounds:
            return target * 0.453592
        case .kilograms:
            return target
        case .ounces:
            return target / 35.274
        case .grams:
            return target / 1000
        }
    }
    
    var weightGoalProgress: Double? {
        guard let latest = latestWeight,
              let targetKg = targetWeightInKg else { return nil }
        
        let currentKg = latest.weightInKg
        let distance = abs(targetKg - currentKg)
        
        // If we're within 5% of target, consider it achieved
        if distance / targetKg < 0.05 {
            return 1.0
        }
        
        // Find first entry to calculate progress
        guard let firstEntry = sortedWeightEntries.first else { return 0 }
        let startKg = firstEntry.weightInKg
        let totalDistance = abs(targetKg - startKg)
        
        guard totalDistance > 0 else { return 1.0 }
        
        let progress = 1.0 - (distance / totalDistance)
        return max(0, min(1.0, progress))
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
    
    // Weight trend over last 30 days
    var weightTrend: WeightTrend {
        let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        let recentEntries = weightEntries.filter { $0.date >= thirtyDaysAgo }.sorted { $0.date < $1.date }
        
        guard recentEntries.count >= 2 else { return .stable }
        
        if let first = recentEntries.first, let last = recentEntries.last {
            let change = ((last.weightInKg - first.weightInKg) / first.weightInKg) * 100
            
            if abs(change) < 2.0 {
                return .stable
            } else if change > 0 {
                return .gaining
            } else {
                return .losing
            }
        }
        
        return .stable
    }
    
    // Average weight over specified period (in preferred unit)
    func averageWeight(days: Int = 30) -> Double? {
        let startDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let recentEntries = weightEntries.filter { $0.date >= startDate }
        
        guard !recentEntries.isEmpty else { return nil }
        
        let totalKg = recentEntries.reduce(0.0) { $0 + $1.weightInKg }
        let avgKg = totalKg / Double(recentEntries.count)
        
        // Convert to preferred unit
        switch preferredUnit {
        case .kilograms:
            return avgKg
        case .pounds:
            return avgKg / 0.453592
        case .ounces:
            return avgKg * 35.274
        case .grams:
            return avgKg * 1000
        }
    }
}

enum WeightTrend {
    case gaining
    case losing
    case stable
    
    var icon: String {
        switch self {
        case .gaining: return "arrow.up.right"
        case .losing: return "arrow.down.right"
        case .stable: return "arrow.right"
        }
    }
    
    var color: Color {
        switch self {
        case .gaining: return .accentMuted
        case .losing: return .accentActive
        case .stable: return .accentPrimary
        }
    }
    
    var description: String {
        switch self {
        case .gaining: return "Gaining"
        case .losing: return "Losing"
        case .stable: return "Stable"
        }
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
        case .ounces:
            return weight / 35.274
        case .grams:
            return weight / 1000
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable {
    case pounds = "lbs"
    case kilograms = "kg"
    case ounces = "oz"
    case grams = "g"
    
    var symbol: String {
        self.rawValue
    }
    
    var displayName: String {
        switch self {
        case .pounds: return "Pounds"
        case .kilograms: return "Kilograms"
        case .ounces: return "Ounces"
        case .grams: return "Grams"
        }
    }
}
