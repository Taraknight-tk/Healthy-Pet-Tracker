//
//  WeightStatsCard.swift
//  Pet Weight Tracker
//

import SwiftUI

struct WeightStatsCard: View {
    let pet: Pet

    /// Optional callback invoked when the user taps the Trend chip.
    /// PetDetailView wires this to scroll to the weight chart section.
    var onTrendTap: (() -> Void)? = nil

    /// Optional callback invoked when the user taps the Entries chip.
    /// PetDetailView wires this to scroll to the weight history section.
    var onEntriesTap: (() -> Void)? = nil

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
                    trendItem
                    Divider().frame(height: 50).background(Color.borderSubtle)
                    StatItem(title: "Average", value: avgWeightValue, icon: "chart.bar.fill", color: .accentInteractive)
                    Divider().frame(height: 50).background(Color.borderSubtle)
                    entriesItem
                }
                .frame(maxWidth: .infinity)

                // Fallback: stacked rows for large Dynamic Type sizes
                VStack(spacing: 12) {
                    trendItem
                    Divider().background(Color.borderSubtle)
                    StatItem(title: "Average", value: avgWeightValue, icon: "chart.bar.fill", color: .accentInteractive)
                    Divider().background(Color.borderSubtle)
                    entriesItem
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderSubtle, lineWidth: 1)
        )
    }

    // MARK: - Trend chip (tappable shortcut to chart)

    @ViewBuilder
    private var trendItem: some View {
        if let callback = onTrendTap {
            Button(action: callback) {
                StatItem(
                    title: "Trend",
                    value: pet.weightTrend.description,
                    icon: pet.weightTrend.icon,
                    color: pet.weightTrend.color
                )
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "chevron.down.circle")
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
            .accessibilityHint("Double-tap to scroll to the weight chart")
        } else {
            StatItem(
                title: "Trend",
                value: pet.weightTrend.description,
                icon: pet.weightTrend.icon,
                color: pet.weightTrend.color
            )
        }
    }

    // MARK: - Entries chip (tappable shortcut to weight history)

    @ViewBuilder
    private var entriesItem: some View {
        if let callback = onEntriesTap {
            Button(action: callback) {
                StatItem(
                    title: "Entries",
                    value: "\(pet.weightEntries.count)",
                    icon: "list.bullet",
                    color: .accentInteractive
                )
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "chevron.down.circle")
                    .font(.caption2)
                    .foregroundStyle(Color.textTertiary)
                    .offset(x: 4, y: -4)
                    .accessibilityHidden(true)
            }
            .accessibilityHint("Double-tap to scroll to weight history")
        } else {
            StatItem(
                title: "Entries",
                value: "\(pet.weightEntries.count)",
                icon: "list.bullet",
                color: .accentInteractive
            )
        }
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
                .accessibilityHidden(true)

            Text(value)
                .font(.headline)
                .primaryText()

            Text(title)
                .font(.caption)
                .tertiaryText()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
    }
}

#Preview {
    let pet = Pet(name: "Max", birthday: Date(), species: "Dog", initialWeight: 45.0, unit: .pounds)
    return WeightStatsCard(pet: pet, onTrendTap: { print("scroll to chart") })
        .padding()
        .background(Color.background)
}
