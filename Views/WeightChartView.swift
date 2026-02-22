//
//  WeightChartView.swift
//  Pet Weight Tracker
//

import SwiftUI
import Charts

struct WeightChartView: View {
    let entries: [WeightEntry]
    let unit: WeightUnit
    
    @State private var selectedRange: DateRange = .all
    
    enum DateRange: String, CaseIterable, Identifiable {
        case all
        case oneMonth
        case threeMonths
        case sixMonths
        case oneYear
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .all: return "All"
            case .oneMonth: return "1M"
            case .threeMonths: return "3M"
            case .sixMonths: return "6M"
            case .oneYear: return "1Y"
            }
        }
        
        func startDate(from reference: Date) -> Date? {
            switch self {
            case .all:
                return nil
            case .oneMonth:
                return Calendar.current.date(byAdding: .month, value: -1, to: reference)
            case .threeMonths:
                return Calendar.current.date(byAdding: .month, value: -3, to: reference)
            case .sixMonths:
                return Calendar.current.date(byAdding: .month, value: -6, to: reference)
            case .oneYear:
                return Calendar.current.date(byAdding: .year, value: -1, to: reference)
            }
        }
    }
    
    private var filteredEntries: [WeightEntry] {
        guard !entries.isEmpty else { return [] }
        // Use the latest entry date as the reference for ranges
        let latestDate = entries.map { $0.date }.max() ?? Date()
        if let start = selectedRange.startDate(from: latestDate) {
            return entries.filter { $0.date >= start && $0.date <= latestDate }
        } else {
            return entries
        }
    }
    
    private var chartData: [ChartDataPoint] {
        filteredEntries.map { entry in
            let weight: Double
            // Convert all weights to the preferred unit for consistent display
            if entry.unit == unit {
                weight = entry.weight
            } else {
                // Convert between units
                switch (entry.unit, unit) {
                case (.pounds, .kilograms):
                    weight = entry.weight * 0.453592
                case (.kilograms, .pounds):
                    weight = entry.weight / 0.453592
                default:
                    weight = entry.weight
                }
            }
            return ChartDataPoint(date: entry.date, weight: weight)
        }
    }
    
    private var weightRange: ClosedRange<Double> {
        let weights = chartData.map { $0.weight }
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return 0...100
        }
        
        let padding = (maxWeight - minWeight) * 0.1
        let lower = Swift.max(0, minWeight - padding)
        let upper = maxWeight + padding
        
        return lower...upper
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Range", selection: $selectedRange) {
                ForEach(DateRange.allCases) { range in
                    Text(range.title).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .padding(.bottom, 4)
            
            if filteredEntries.isEmpty {
                Text("No data to display")
                    .secondaryText()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredEntries.count == 1 {
                VStack(spacing: 8) {
                    Text("Add more weight entries to see the trend")
                        .font(.subheadline)
                        .secondaryText()
                    
                    HStack {
                        Spacer()
                        VStack {
                            Text(String(format: "%.1f", chartData[0].weight))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(Color.accentActive)
                            Text(unit.symbol)
                                .font(.caption)
                                .tertiaryText()
                        }
                        Spacer()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Chart(chartData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(Color.accentPrimary)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(Color.accentActive)
                    .symbolSize(60)
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentPrimary.opacity(0.3), Color.accentMuted.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: weightRange)
                .chartXScale(domain: (chartData.map { $0.date }.min() ?? Date())...(chartData.map { $0.date }.max() ?? Date()))
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text(String(format: "%.1f", weight))
                                    .font(.caption)
                                    .secondaryText()
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.borderSubtle)
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date, format: .dateTime.month(.abbreviated).day())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        AxisGridLine()
                            .foregroundStyle(Color.borderSubtle)
                    }
                }
                
                HStack {
                    Spacer()
                    Label(unit.symbol, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .tertiaryText()
                }
            }
        }
    }
}

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let weight: Double
}

#Preview {
    let sampleEntries = [
        WeightEntry(date: Date().addingTimeInterval(-86400 * 30), weight: 45.0, unit: .pounds),
        WeightEntry(date: Date().addingTimeInterval(-86400 * 20), weight: 46.5, unit: .pounds),
        WeightEntry(date: Date().addingTimeInterval(-86400 * 10), weight: 47.2, unit: .pounds),
        WeightEntry(date: Date(), weight: 48.0, unit: .pounds)
    ]
    
    return WeightChartView(entries: sampleEntries, unit: .pounds)
        .padding()
        .frame(height: 250)
        .background(Color.bgTertiary)
}

