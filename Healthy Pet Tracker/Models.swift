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

    /// Breed name matched against breed_weights.json (e.g. "Golden Retriever").
    /// nil means unknown / not set.
    var breed: String?

    /// Biological sex, used for sex-specific healthy weight ranges.
    var sex: PetSex?

    /// File-system path for the pet's custom profile photo (Pro feature).
    /// Stored as a path string rather than raw data to keep the SwiftData
    /// store small; the actual JPEG lives in the app's Documents/pet_photos/ folder.
    var photoPath: String?
    
    @Relationship(deleteRule: .cascade, inverse: \WeightEntry.pet)
    var weightEntries: [WeightEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \PetNote.pet)
    var notes: [PetNote] = []

    @Relationship(deleteRule: .cascade, inverse: \PetDocument.pet)
    var documents: [PetDocument] = []

    @Relationship(deleteRule: .cascade, inverse: \PetReminder.pet)
    var reminders: [PetReminder] = []
    
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
            
            if abs(change) < 0.5 {
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
        case .gaining: return .accentInteractive
        case .losing: return .accentInteractive
        case .stable: return .accentInteractive
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

    /// File-system path for an optional photo attached to this entry (Pro feature).
    var photoPath: String?

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

// MARK: - Pet Sex

enum PetSex: String, Codable, CaseIterable {
    case male   = "male"
    case female = "female"

    var displayName: String {
        switch self {
        case .male:   return "Male"
        case .female: return "Female"
        }
    }

    var icon: String {
        switch self {
        case .male:   return "♂"
        case .female: return "♀"
        }
    }
}

// MARK: - Notes / Milestones

enum NoteType: String, Codable, CaseIterable {
    case general    = "general"
    case vetVisit   = "vetVisit"
    case milestone  = "milestone"
    case grooming   = "grooming"
    case medication = "medication"
    case photoOnly  = "photoOnly"

    var displayName: String {
        switch self {
        case .general:    return "Note"
        case .vetVisit:   return "Vet Visit"
        case .milestone:  return "Milestone"
        case .grooming:   return "Grooming"
        case .medication: return "Medication"
        case .photoOnly:  return "Photo"
        }
    }

    var icon: String {
        switch self {
        case .general:    return "note.text"
        case .vetVisit:   return "stethoscope"
        case .milestone:  return "star.fill"
        case .grooming:   return "scissors"
        case .medication: return "pill.fill"
        case .photoOnly:  return "camera.fill"
        }
    }

    var color: Color {
        switch self {
        case .general:    return .accentInteractive
        case .vetVisit:   return .blue
        case .milestone:  return .orange
        case .grooming:   return .purple
        case .medication: return .red
        case .photoOnly:  return .accentInteractive
        }
    }
}

@Model
final class PetNote {
    var id: UUID
    var date: Date
    var noteText: String
    var noteType: NoteType
    /// Optional photo (Pro feature — same pattern as WeightEntry.photoPath).
    var photoPath: String?
    var pet: Pet?

    init(date: Date = Date(), noteText: String = "", noteType: NoteType = .general) {
        self.id = UUID()
        self.date = date
        self.noteText = noteText
        self.noteType = noteType
    }
}

// MARK: - Documents (Pro Feature)

enum DocFileType: String, Codable {
    case pdf   = "pdf"
    case image = "image"

    var icon: String {
        switch self {
        case .pdf:   return "doc.fill"
        case .image: return "photo.fill"
        }
    }

    var color: Color {
        switch self {
        case .pdf:   return .red
        case .image: return .accentInteractive
        }
    }
}

@Model
final class PetDocument {
    var id: UUID
    var title: String
    var filePath: String
    var fileType: DocFileType
    var dateAdded: Date
    var pet: Pet?

    init(title: String, filePath: String, fileType: DocFileType) {
        self.id = UUID()
        self.title = title
        self.filePath = filePath
        self.fileType = fileType
        self.dateAdded = Date()
    }
}

// MARK: - Reminders (Pro Feature)

enum ReminderType: String, Codable, CaseIterable {
    case weightLogging = "weight"
    case vetAppointment = "vet"
    case medication = "medication"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .weightLogging:  return "Weight Check-In"
        case .vetAppointment: return "Vet Appointment"
        case .medication:     return "Medication"
        case .custom:         return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .weightLogging:  return "scalemass.fill"
        case .vetAppointment: return "stethoscope"
        case .medication:     return "pill.fill"
        case .custom:         return "bell.fill"
        }
    }

    /// Whether this type defaults to a one-time reminder (vet) vs recurring
    var defaultsToOneTime: Bool {
        self == .vetAppointment
    }
}

enum ReminderFrequency: String, Codable, CaseIterable {
    case once = "once"
    case weekly = "weekly"
    case monthly = "monthly"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .once:    return "One Time"
        case .weekly:  return "Weekly"
        case .monthly: return "Monthly"
        case .custom:  return "Custom Interval"
        }
    }
}

@Model
final class PetReminder {
    var id: UUID
    var pet: Pet?

    // What kind of reminder
    var reminderType: ReminderType
    var title: String
    var notes: String

    // Schedule
    var frequency: ReminderFrequency
    var dayOfWeek: Int?           // 1 = Sunday … 7 = Saturday (weekly)
    var dayOfMonth: Int?          // 1–28 (monthly)
    var customIntervalDays: Int?  // e.g. every 14 days (custom)
    var timeOfDay: Date           // only the hour + minute matter
    var specificDate: Date?       // full date for one-time reminders

    var isEnabled: Bool
    var createdAt: Date

    init(
        pet: Pet? = nil,
        reminderType: ReminderType,
        title: String,
        notes: String = "",
        frequency: ReminderFrequency,
        dayOfWeek: Int? = nil,
        dayOfMonth: Int? = nil,
        customIntervalDays: Int? = nil,
        timeOfDay: Date,
        specificDate: Date? = nil,
        isEnabled: Bool = true
    ) {
        self.id = UUID()
        self.pet = pet
        self.reminderType = reminderType
        self.title = title
        self.notes = notes
        self.frequency = frequency
        self.dayOfWeek = dayOfWeek
        self.dayOfMonth = dayOfMonth
        self.customIntervalDays = customIntervalDays
        self.timeOfDay = timeOfDay
        self.specificDate = specificDate
        self.isEnabled = isEnabled
        self.createdAt = Date()
    }

    /// Human-readable schedule summary, e.g. "Every Monday at 9:00 AM"
    var scheduleDescription: String {
        let timeStr = timeOfDay.formatted(date: .omitted, time: .shortened)

        switch frequency {
        case .once:
            if let date = specificDate {
                return "\(date.formatted(date: .abbreviated, time: .omitted)) at \(timeStr)"
            }
            return "One time at \(timeStr)"

        case .weekly:
            let weekdayName = dayOfWeek.flatMap { dayName(for: $0) } ?? "—"
            return "Every \(weekdayName) at \(timeStr)"

        case .monthly:
            if let day = dayOfMonth {
                return "\(ordinal(day)) of every month at \(timeStr)"
            }
            return "Monthly at \(timeStr)"

        case .custom:
            if let days = customIntervalDays {
                return "Every \(days) day\(days == 1 ? "" : "s") at \(timeStr)"
            }
            return "Custom interval at \(timeStr)"
        }
    }

    private func dayName(for weekday: Int) -> String {
        let formatter = DateFormatter()
        // weekdaySymbols: index 0 = Sunday
        guard weekday >= 1, weekday <= 7 else { return "—" }
        return formatter.weekdaySymbols[weekday - 1]
    }

    private func ordinal(_ n: Int) -> String {
        let suffix: String
        switch n {
        case 1, 21: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default:    suffix = "th"
        }
        return "\(n)\(suffix)"
    }
}
