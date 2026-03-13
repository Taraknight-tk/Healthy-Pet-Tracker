//
//  WeightStatsCard.swift
//  Pet Weight Tracker
//

import SwiftUI

struct WeightStatsCard: View {
    let pet: Pet

    // Computed once and shared by both layout branches
    private var avgWeightValue: String {
        if let avg = pet.averageWeight(days: 30) {
            return String(format: "%.1f %@", avg, pet.preferredUnit.symbol)
        }
        return "N/A"
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("30-Day Stats")
                .font(.headline)
                .primaryText()
                .frame(maxWidth: .infinity, alignment: .leading)

            // ViewThatFits tries the HStack first; if text is too large to fit
            // horizontally it automatically falls back to the VStack.
            ViewThatFits(in: .horizontal) {
                // Default: side-by-side columns
                HStack(spacing: 12) {
                    StatItem(title: "Trend",   value: pet.weightTrend.description, icon: pet.weightTrend.icon,   color: pet.weightTrend.color)
                    Divider().frame(height: 50).background(Color.borderSubtle)
                    StatItem(title: "Average", value: avgWeightValue,               icon: "chart.bar.fill",        color: .accentPrimary)
                    Divider().frame(height: 50).background(Color.borderSubtle)
                    StatItem(title: "Entries", value: "\(pet.weightEntries.count)", icon: "list.bullet",           color: .accentActive)
                }
                .frame(maxWidth: .infinity)

                // Fallback: stacked rows for large Dynamic Type sizes
                VStack(spacing: 12) {
                    StatItem(title: "Trend",   value: pet.weightTrend.description, icon: pet.weightTrend.icon,   color: pet.weightTrend.color)
                    Divider().background(Color.borderSubtle)
                    StatItem(title: "Average", value: avgWeightValue,               icon: "chart.bar.fill",        color: .accentPrimary)
                    Divider().background(Color.borderSubtle)
                    StatItem(title: "Entries", value: "\(pet.weightEntries.count)", icon: "list.bullet",           color: .accentActive)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.bgTertiary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
    }
}

struct StatItem: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .accessibilityHidden(true)  // decorative — title + value carry the meaning

            Text(value)
                .font(.headline)
                .primaryText()

            Text(title)
                .font(.caption)
                .tertiaryText()
        }
        .frame(maxWidth: .infinity)
        // Reads as e.g. "Trend: Gaining" instead of three separate elements
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    let pet = Pet(name: "Max", birthday: Date(), species: "Dog", initialWeight: 45.0, unit: .pounds)
    return WeightStatsCard(pet: pet)
        .padding()
        .background(Color.bgPrimary)
}
