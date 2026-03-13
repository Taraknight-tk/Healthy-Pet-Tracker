//
//  WeightStatsCard.swift
//  Pet Weight Tracker
//

import SwiftUI

struct WeightStatsCard: View {
    let pet: Pet
    
    var body: some View {
        VStack(spacing: 16) {
            Text("30-Day Stats")
                .font(.headline)
                .primaryText()
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                // Trend indicator
                StatItem(
                    title: "Trend",
                    value: pet.weightTrend.description,
                    icon: pet.weightTrend.icon,
                    color: pet.weightTrend.color
                )
                
                Divider()
                    .frame(height: 50)
                    .background(Color.borderSubtle)
                
                // Average weight
                if let avgWeight = pet.averageWeight(days: 30) {
                    StatItem(
                        title: "Average",
                        value: String(format: "%.1f %@", avgWeight, pet.preferredUnit.symbol),
                        icon: "chart.bar.fill",
                        color: .accentPrimary
                    )
                } else {
                    StatItem(
                        title: "Average",
                        value: "N/A",
                        icon: "chart.bar.fill",
                        color: .accentPrimary
                    )
                }
                
                Divider()
                    .frame(height: 50)
                    .background(Color.borderSubtle)
                
                // Total entries
                StatItem(
                    title: "Entries",
                    value: "\(pet.weightEntries.count)",
                    icon: "list.bullet",
                    color: .accentActive
                )
            }
            .frame(maxWidth: .infinity)
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
