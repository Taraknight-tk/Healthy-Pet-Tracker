//
//  BreedService.swift
//  Healthy Pet Tracker
//
//  Loads breed_weights.json from the app bundle and provides lightweight
//  lookup for healthy weight ranges by species, breed name, and sex.
//

import Foundation

// MARK: - Data models (mirrors breed_weights.json)

struct BreedDatabase: Codable {
    let version: String
    let dogs: [BreedWeightEntry]
    let cats: [BreedWeightEntry]
}

struct BreedWeightEntry: Codable, Identifiable {
    var id: String { breed }
    let breed: String
    let maleLbs: [Double]      // [min, max]
    let femaleLbs: [Double]    // [min, max]
    let isMixed: Bool?

    var isMixedBreed: Bool { isMixed == true }
}

// MARK: - Lookup result

struct BreedWeightRange {
    let breed: String
    let minLbs: Double
    let maxLbs: Double
    let isMixed: Bool

    /// Midpoint of the healthy range, useful for progress indicators.
    var midpointLbs: Double { (minLbs + maxLbs) / 2 }

    /// Human-readable string, e.g. "55 – 70 lbs"
    var displayRange: String {
        "\(Int(minLbs)) – \(Int(maxLbs)) lbs"
    }

    /// Status relative to a given weight in lbs.
    func status(forWeightLbs weightLbs: Double) -> BreedWeightStatus {
        if weightLbs < minLbs { return .underweight }
        if weightLbs > maxLbs { return .overweight }
        return .healthy
    }
}

enum BreedWeightStatus {
    case underweight, healthy, overweight

    var label: String {
        switch self {
        case .underweight: return "Below Range"
        case .healthy:     return "Healthy Range"
        case .overweight:  return "Above Range"
        }
    }

    var sfSymbol: String {
        switch self {
        case .underweight: return "arrow.down.circle.fill"
        case .healthy:     return "checkmark.circle.fill"
        case .overweight:  return "arrow.up.circle.fill"
        }
    }

    var colorName: String {
        switch self {
        case .underweight: return "accentLight"
        case .healthy:     return "accentActive"
        case .overweight:  return "accentLight"
        }
    }
}

// MARK: - Service

final class BreedService {

    static let shared = BreedService()
    private init() { load() }

    private(set) var dogs: [BreedWeightEntry] = []
    private(set) var cats: [BreedWeightEntry] = []

    // MARK: - Public API

    /// All breed names for a given species ("dog" or "cat"), mixed breeds last.
    func breedNames(for species: String) -> [String] {
        entries(for: species)
            .sorted { lhs, rhs in
                // Push mixed breeds to the bottom
                if lhs.isMixedBreed != rhs.isMixedBreed {
                    return !lhs.isMixedBreed
                }
                return lhs.breed < rhs.breed
            }
            .map(\.breed)
    }

    /// Look up the healthy weight range for a specific breed + sex combo.
    /// Returns nil if the breed is not found in the database.
    func weightRange(breed: String, sex: PetSex?) -> BreedWeightRange? {
        let allEntries = dogs + cats
        guard let entry = allEntries.first(where: {
            $0.breed.lowercased() == breed.lowercased()
        }) else { return nil }

        let range: [Double]
        switch sex {
        case .female: range = entry.femaleLbs
        default:      range = entry.maleLbs   // male or unknown → use male (wider)
        }

        guard range.count == 2 else { return nil }
        return BreedWeightRange(
            breed: entry.breed,
            minLbs: range[0],
            maxLbs: range[1],
            isMixed: entry.isMixedBreed
        )
    }

    // MARK: - Private

    private func entries(for species: String) -> [BreedWeightEntry] {
        switch species.lowercased() {
        case "dog", "dogs": return dogs
        case "cat", "cats": return cats
        default:            return dogs + cats
        }
    }

    private func load() {
        guard let url = Bundle.main.url(forResource: "breed_weights", withExtension: "json") else {
            print("BreedService: breed_weights.json not found in bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            let db = try JSONDecoder().decode(BreedDatabase.self, from: data)
            dogs = db.dogs
            cats = db.cats
        } catch {
            print("BreedService: failed to parse breed_weights.json — \(error)")
        }
    }
}
