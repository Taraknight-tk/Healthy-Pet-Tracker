//
//  QuickLookView.swift
//  Healthy Pet Tracker
//
//  UIViewControllerRepresentable wrapper around QLPreviewController.
//  Handles PDFs, images, and most other file types the OS understands.
//

import SwiftUI
import QuickLook

struct QuickLookView: UIViewControllerRepresentable {
    let fileURL: URL
    var onDismiss: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.delegate   = context.coordinator
        // Wrap in nav controller so the native Done / Share toolbar appears
        return UINavigationController(rootViewController: preview)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        let parent: QuickLookView

        init(_ parent: QuickLookView) {
            self.parent = parent
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            parent.fileURL as NSURL
        }

        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            parent.onDismiss()
        }
    }
}
