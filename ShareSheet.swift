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
        var itemsToShare: [Any] = []
        
        // Create a temporary file URL
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        // Write data to file if it's Data
        if let data = items.first as? Data {
            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                }
                
                // Write the data to the file
                try data.write(to: fileURL, options: .atomic)
                
                // Verify the file was created and has content
                if FileManager.default.fileExists(atPath: fileURL.path),
                   let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                   let fileSize = attributes[.size] as? Int,
                   fileSize > 0 {
                    itemsToShare = [fileURL]
                } else {
                    // If file creation failed, fall back to sharing the string directly
                    if let csvString = String(data: data, encoding: .utf8) {
                        itemsToShare = [csvString]
                    }
                }
            } catch {
                print("Error writing CSV file: \(error)")
                // If file creation failed, fall back to sharing the string directly
                if let csvString = String(data: data, encoding: .utf8) {
                    itemsToShare = [csvString]
                }
            }
        } else {
            itemsToShare = items
        }
        
        let activityViewController = UIActivityViewController(
            activityItems: itemsToShare,
            applicationActivities: nil
        )
        
        // Exclude some activities that don't make sense for CSV files
        activityViewController.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToFacebook,
            .postToTwitter,
            .postToWeibo,
            .postToVimeo,
            .postToFlickr,
            .postToTencentWeibo
        ]
        
        return activityViewController
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}
