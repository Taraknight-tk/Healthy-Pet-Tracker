//
//  WeightChartView.swift
//  Pet Weight Tracker
//

import SwiftUI
import Charts

struct WeightChartView: View {
    let entries: [WeightEntry]
    let unit: WeightUnit
    
    private var chartData: [ChartDataPoint] {
        entries.map { entry in
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
            if entries.isEmpty {
                Text("No data to display")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if entries.count == 1 {
                VStack(spacing: 8) {
                    Text("Add more weight entries to see the trend")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Spacer()
                        VStack {
                            Text(String(format: "%.1f", chartData[0].weight))
                                .font(.title)
                                .fontWeight(.bold)
                            Text(unit.symbol)
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(.blue)
                    .symbolSize(60)
                    
                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value("Weight", dataPoint.weight)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: weightRange)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisValueLabel {
                            if let weight = value.as(Double.self) {
                                Text(String(format: "%.1f", weight))
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        AxisGridLine()
                    }
                }
                
                HStack {
                    Spacer()
                    Label(unit.symbol, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
}
