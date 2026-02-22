//
//  HapticManager.swift
//  Pet Weight Tracker
//

import UIKit

final class HapticManager {
    static let shared = HapticManager()
    
    private let impactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let selectionGenerator = UISelectionFeedbackGenerator()
    
    private init() {
        // Prepare generators for better performance
        impactGenerator.prepare()
        notificationGenerator.prepare()
        selectionGenerator.prepare()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        // If a different style is requested, create a new generator
        if style != .medium {
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred()
        } else {
            impactGenerator.impactOccurred()
            // Re-prepare for next use
            impactGenerator.prepare()
        }
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationGenerator.notificationOccurred(type)
        // Re-prepare for next use
        notificationGenerator.prepare()
    }
    
    func selection() {
        selectionGenerator.selectionChanged()
        // Re-prepare for next use
        selectionGenerator.prepare()
    }
}
