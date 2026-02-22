//
//  ShareSheet.swift
//  Pet Weight Tracker
//

import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    let fileName: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create a temporary file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        // Write data to file if it's Data
        if let data = items.first as? Data {
            try? data.write(to: fileURL)
            let activityViewController = UIActivityViewController(
                activityItems: [fileURL],
                applicationActivities: nil
            )
            return activityViewController
        }
        
        // Fallback to regular items
        let activityViewController = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}
