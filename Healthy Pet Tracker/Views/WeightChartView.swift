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
    @State private var selectedDate: Date?
    
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
                return Calendar.current.date(byAdding: .month, value: -12, to: reference)
            }
        }
    }
    
    // Compute expensive calculations once
    private var filteredAndConvertedData: [ChartDataPoint] {
        guard !entries.isEmpty else { return [] }
        
        // Use the latest entry date as the reference for ranges
        let latestDate = entries.map { $0.date }.max() ?? Date()
        
        // Filter by date range
        let filtered: [WeightEntry]
        if let start = selectedRange.startDate(from: latestDate) {
            filtered = entries.filter { $0.date >= start && $0.date <= latestDate }
        } else {
            filtered = entries
        }
        
        // Convert units
        return filtered.map { entry in
            let weight: Double
            if entry.unit == unit {
                weight = entry.weight
            } else {
                // Convert to kg first, then to target unit
                let weightInKg = entry.weightInKg
                switch unit {
                case .kilograms:
                    weight = weightInKg
                case .pounds:
                    weight = weightInKg / 0.453592
                case .ounces:
                    weight = weightInKg * 35.274
                case .grams:
                    weight = weightInKg * 1000
                }
            }
            return ChartDataPoint(date: entry.date, weight: weight)
        }
    }
    
    private var weightRange: ClosedRange<Double> {
        let weights = filteredAndConvertedData.map { $0.weight }
        guard let minWeight = weights.min(), let maxWeight = weights.max() else {
            return 0...100
        }
        
        let padding = (maxWeight - minWeight) * 0.1
        let lower = Swift.max(0, minWeight - padding)
        let upper = maxWeight + padding
        
        return lower...upper
    }
    
    // Total months spanned by the currently visible data
    private var dataSpanMonths: Int {
        let dates = filteredAndConvertedData.map { $0.date }
        guard let minDate = dates.min(), let maxDate = dates.max() else { return 0 }
        return max(1, Calendar.current.dateComponents([.month], from: minDate, to: maxDate).month ?? 0)
    }

    // Axis tick unit — always weeks for 1M so we get ~4 clean labels;
    // months for everything else (count controls the spacing).
    private var xAxisStride: Calendar.Component {
        switch selectedRange {
        case .oneMonth:
            return .weekOfYear
        case .threeMonths, .sixMonths, .oneYear, .all:
            return .month
        }
    }

    // How many stride units to skip between labels — keeps tick count to ~4–6
    // regardless of how much data exists.
    private var xAxisCount: Int {
        switch selectedRange {
        case .oneMonth:
            return 1                   // every week → ~4 labels
        case .threeMonths:
            return 1                   // every month → 3 labels
        case .sixMonths:
            return 2                   // every 2 months → 3 labels
        case .oneYear:
            return 2                   // every 2 months → ~6 labels
        case .all:
            let m = dataSpanMonths
            if m > 48 { return 12 }    // >4 yrs  → yearly
            if m > 24 { return 6  }    // 2–4 yrs → every 6 months
            if m > 12 { return 3  }    // 1–2 yrs → quarterly
            if m > 6  { return 2  }    // 6–12 mo → every 2 months
            return 1                   // ≤6 mo   → monthly
        }
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
            
            if filteredAndConvertedData.isEmpty {
                Text("No data to display")
                    .secondaryText()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if filteredAndConvertedData.count == 1 {
                VStack(spacing: 8) {
                    Text("Add more weight entries to see the trend")
                        .font(.subheadline)
                        .secondaryText()
                    
                    HStack {
                        Spacer()
                        VStack {
                            Text(String(format: "%.1f", filteredAndConvertedData[0].weight))
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
                VStack(spacing: 8) {
                    if let selectedDate = selectedDate,
                       let selectedPoint = filteredAndConvertedData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selectedPoint.date, format: .dateTime.month().day().year())
                                    .font(.caption)
                                    .tertiaryText()
                                Text(String(format: "%.1f %@", selectedPoint.weight, unit.symbol))
                                    .font(.headline)
                                    .primaryText()
                            }
                            
                            Spacer()
                            
                            Button(action: { self.selectedDate = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.bgSecondary)
                        .cornerRadius(8)
                    }
                    
                    Chart(filteredAndConvertedData) { dataPoint in
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
                    .chartXScale(domain: (filteredAndConvertedData.map { $0.date }.min() ?? Date())...(filteredAndConvertedData.map { $0.date }.max() ?? Date()))
                    .chartXSelection(value: $selectedDate)
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
                        AxisMarks(values: .stride(by: xAxisStride, count: xAxisCount)) { value in
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    switch selectedRange {
                                    case .all where dataSpanMonths > 24:
                                        // Many years of data — just show the year
                                        Text(date, format: .dateTime.year())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    case .oneYear, .all:
                                        Text(date, format: .dateTime.month(.abbreviated).year())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    case .sixMonths, .threeMonths, .oneMonth:
                                        Text(date, format: .dateTime.month(.abbreviated).day())
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
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
    
    struct WeightChartView_Previews: PreviewProvider {
        static var previews: some View {
            let sampleEntries = [
                WeightEntry(date: Date().addingTimeInterval(-86400 * 30), weight: 45.0, unit: .pounds),
                WeightEntry(date: Date().addingTimeInterval(-86400 * 20), weight: 46.5, unit: .pounds),
                WeightEntry(date: Date().addingTimeInterval(-86400 * 10), weight: 47.2, unit: .pounds),
                WeightEntry(date: Date(), weight: 48.0, unit: .pounds)
            ]
            
            WeightChartView(entries: sampleEntries, unit: .pounds)
                .padding()
                .frame(height: 250)
                .background(Color.bgTertiary)
        }
    }
    
}
