//
//  DataExporter.swift
//  Pet Weight Tracker
//

import Foundation

struct DataExporter {
    static func exportToCSV(pet: Pet) -> String {
        var csv = "Date,Weight,Unit,Notes\n"
        
        let sortedEntries = pet.sortedWeightEntries
        for entry in sortedEntries {
            let dateString = entry.date.formatted(date: .numeric, time: .omitted)
            let weightString = String(format: "%.2f", entry.weight)
            let notesEscaped = entry.notes.replacingOccurrences(of: "\"", with: "\"\"")
            csv += "\(dateString),\(weightString),\(entry.unit.symbol),\"\(notesEscaped)\"\n"
        }
        
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
