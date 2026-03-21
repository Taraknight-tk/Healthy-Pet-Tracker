//
//  CameraPickerView.swift
//  Healthy Pet Tracker
//
//  UIViewControllerRepresentable wrapper around UIImagePickerController
//  for camera capture. Returns a UIImage via the onCapture callback.
//  Call-sites are responsible for persisting the image to disk.
//

import SwiftUI
import UIKit

struct CameraPickerView: UIViewControllerRepresentable {

    /// Called on the main thread when the user confirms a captured photo.
    var onCapture: (UIImage) -> Void

    /// Called when the user cancels or after a photo is accepted.
    var onDismiss: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCapture: onCapture, onDismiss: onDismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onCapture: (UIImage) -> Void
        let onDismiss: () -> Void

        init(onCapture: @escaping (UIImage) -> Void, onDismiss: @escaping () -> Void) {
            self.onCapture = onCapture
            self.onDismiss = onDismiss
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            onDismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onDismiss()
        }
    }
}
