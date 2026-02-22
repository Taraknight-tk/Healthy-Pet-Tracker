//
//  DataExporter.swift
//  Pet Weight Tracker
//

import Foundation
import SwiftData

struct DataExporter {
    static func exportToCSV(pet: Pet) -> String {
        var csv = "Date,Weight,Unit,Notes\n"
        
        let sortedEntries = pet.sortedWeightEntries
        
        print("DEBUG: Exporting for pet: \(pet.name)")
        print("DEBUG: Total weight entries: \(pet.weightEntries.count)")
        print("DEBUG: Sorted weight entries: \(sortedEntries.count)")
        
        for (index, entry) in sortedEntries.enumerated() {
            let dateString = entry.date.formatted(date: .numeric, time: .omitted)
            let weightString = String(format: "%.2f", entry.weight)
            let notesEscaped = entry.notes.replacingOccurrences(of: "\"", with: "\"\"")
            let line = "\(dateString),\(weightString),\(entry.unit.symbol),\"\(notesEscaped)\"\n"
            csv += line
            print("DEBUG: Entry \(index + 1): \(line.trimmingCharacters(in: .newlines))")
        }
        
        if sortedEntries.isEmpty {
            print("DEBUG: No entries found, adding placeholder")
            csv += "No weight entries found\n"
        }
        
        print("DEBUG: Final CSV length: \(csv.count) characters")
        
        return csv
    }
    
    static func exportAllPetsToCSV(pets: [Pet]) -> String {
        var csv = "Pet Name,Species,Birthday,Date,Weight,Unit,Notes\n"
        
        for pet in pets {
            let sortedEntries = pet.sortedWeightEntries
            for entry in sortedEntries {
                let birthdayString = pet.birthday.formatted(date: .numeric, time: .omitted)
                let dateString = entry.date.formatted(date: .numeric, time: .omitted)
                let weightString = String(format: "%.2f", entry.weight)
                let notesEscaped = entry.notes.replacingOccurrences(of: "\"", with: "\"\"")
                csv += "\"\(pet.name)\",\"\(pet.species)\",\(birthdayString),\(dateString),\(weightString),\(entry.unit.symbol),\"\(notesEscaped)\"\n"
            }
        }
        
        return csv
    }
}
