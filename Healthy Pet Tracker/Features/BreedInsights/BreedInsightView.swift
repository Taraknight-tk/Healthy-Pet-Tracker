//
//  BreedInsightView.swift
//  Healthy Pet Tracker
//
//  Pro-gated breed-specific healthy weight insight card shown in PetDetailView.
//  Shows the healthy weight range for the pet's breed and how the current
//  weight compares. Free users see a locked teaser that opens the paywall.
//

import SwiftUI

// MARK: - Main card (use this in PetDetailView)

struct BreedInsightView: View {
    let pet: Pet
    @EnvironmentObject var entitlements: EntitlementService
    @EnvironmentObject var store: StoreService
    @State private var showingUpgrade = false
    @State private var showingBreedPicker = false

    var body: some View {
        Group {
            if entitlements.hasPremium {
                proContent
            } else {
                lockedTeaser
            }
        }
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
                .environmentObject(entitlements)
                .environmentObject(store)
        }
        .sheet(isPresented: $showingBreedPicker) {
            BreedPickerView(pet: pet)
                .environmentObject(entitlements)
                .environmentObject(store)
        }
    }

    // MARK: - Pro content

    @ViewBuilder
    private var proContent: some View {
        if let breed = pet.breed,
           let range = BreedService.shared.weightRange(breed: breed, sex: pet.sex) {
            BreedRangeCard(pet: pet, breed: breed, range: range) {
                showingBreedPicker = true
            }
        } else {
            // Breed not set yet — prompt to add
            Button {
                showingBreedPicker = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "pawprint.fill")
                        .foregroundStyle(.tint)
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Add Breed for Insights")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text("See healthy weight ranges for \(pet.name)'s breed")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Locked teaser (free users)

    private var lockedTeaser: some View {
        Button {
            showingUpgrade = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.tint)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Breed-Specific Insights")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.primary)
                    Text("Unlock healthy weight ranges for your pet's breed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text("Pro")
                    .font(.caption2).fontWeight(.semibold)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.tint.opacity(0.15))
                    .foregroundStyle(.tint)
                    .clipShape(Capsule())
            }
            .padding(.vertical, 4)
        }
    }
}

// MARK: - Range card (shown when breed + range are available)

private struct BreedRangeCard: View {
    let pet: Pet
    let breed: String
    let range: BreedWeightRange
    let onChangeTap: () -> Void

    private var currentWeightLbs: Double? {
        guard let latest = pet.latestWeight else { return nil }
        // Convert latest weight to lbs for comparison
        switch latest.unit {
        case .pounds:     return latest.weight
        case .kilograms:  return latest.weight / 0.453592
        case .ounces:     return latest.weight / 16
        case .grams:      return latest.weight / 453.592
        }
    }

    private var status: BreedWeightStatus? {
        guard let lbs = currentWeightLbs else { return nil }
        return range.status(forWeightLbs: lbs)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // Header row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(breed)
                        .font(.subheadline).fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    if let sex = pet.sex {
                        Text("\(sex.displayName) · Healthy range")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Healthy range")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button(action: onChangeTap) {
                    Text("Change")
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
            }

            // Weight range bar
            WeightRangeBar(range: range, currentLbs: currentWeightLbs)

            // Status pill
            if let status {
                HStack(spacing: 6) {
                    Image(systemName: status.sfSymbol)
                    Text(status.label)
                        .font(.caption).fontWeight(.medium)
                }
                .foregroundStyle(statusColor(status))
                .font(.caption)
            }

            // Disclaimer
            Text("Ranges reflect AKC/CFA breed standards. Always consult your veterinarian for personalized guidance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }

    private func statusColor(_ status: BreedWeightStatus) -> Color {
        switch status {
        case .healthy:     return .accentActive
        case .underweight: return .accentMuted
        case .overweight:  return .accentMuted
        }
    }
}

// MARK: - Range bar

private struct WeightRangeBar: View {
    let range: BreedWeightRange
    let currentLbs: Double?

    /// How wide the viewing window is around the range (20% padding each side)
    private var windowMin: Double { range.minLbs * 0.80 }
    private var windowMax: Double { range.maxLbs * 1.20 }
    private var windowSpan: Double { windowMax - windowMin }

    private func fraction(for lbs: Double) -> Double {
        max(0, min(1, (lbs - windowMin) / windowSpan))
    }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                    .frame(height: 8)

                // Healthy range highlight
                let startX = fraction(for: range.minLbs) * w
                let endX   = fraction(for: range.maxLbs) * w
                Capsule()
                    .fill(Color.accentActive.opacity(0.35))
                    .frame(width: max(0, endX - startX), height: 8)
                    .offset(x: startX)

                // Current weight marker
                if let lbs = currentLbs {
                    let markerX = fraction(for: lbs) * w
                    Circle()
                        .fill(markerColor(lbs: lbs))
                        .frame(width: 14, height: 14)
                        .offset(x: markerX - 7, y: 0)
                        .shadow(radius: 1)
                }
            }
            .frame(height: 14)
        }
        .frame(height: 14)

        // Labels below bar
        HStack {
            Text("\(Int(range.minLbs)) lbs")
                .font(.caption2).foregroundStyle(.secondary)
            Spacer()
            Text("Healthy range")
                .font(.caption2).foregroundStyle(.tint)
            Spacer()
            Text("\(Int(range.maxLbs)) lbs")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func markerColor(lbs: Double) -> Color {
        switch range.status(forWeightLbs: lbs) {
        case .healthy:     return .accentActive
        case .underweight: return .accentMuted
        case .overweight:  return .accentMuted
        }
    }
}

