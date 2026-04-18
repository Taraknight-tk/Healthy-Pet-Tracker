//
//  WeightEntryPhotoView.swift
//  Healthy Pet Tracker
//
//  Reusable camera/picker component for attaching a photo to a weight entry.
//  Uses a Binding<String?> so it works in both AddWeightView (State-backed)
//  and EditWeightView (@Bindable entry.photoPath).
//
//  Pro users: tapping the photo thumbnail shows a confirmation dialog for
//  Camera or Photo Library. Free users: tapping shows UpgradeView.
//
//  Tap target is limited to the thumbnail square via a transparent overlay.
//

import SwiftUI
import PhotosUI

struct WeightEntryPhotoView: View {
    @EnvironmentObject var entitlements: EntitlementService

    @Binding var photoPath: String?

    @State private var selectedItem: PhotosPickerItem?
    @State private var showUpgrade = false
    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false

    private let size: CGFloat = 64

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                photoArea
                badgeDecoration
            }
            // ── Precise tap target: only the thumbnail square ────────────────
            .overlay(alignment: .center) {
                Color.clear
                    .frame(width: size, height: size)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if entitlements.hasPremium {
                            showSourcePicker = true
                        } else {
                            showUpgrade = true
                        }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(entitlements.hasPremium
                        ? (photoPath != nil ? "Weight entry photo" : "No photo")
                        : "Photo locked")
                    .accessibilityHint(entitlements.hasPremium
                        ? (photoPath != nil ? "Double-tap to change photo" : "Double-tap to add photo")
                        : "Double-tap to upgrade to Pro")
            }
            // ── Source selection ─────────────────────────────────────────────
            .confirmationDialog(
                photoPath != nil ? "Change Photo" : "Add Photo",
                isPresented: $showSourcePicker,
                titleVisibility: .visible
            ) {
                if UIImagePickerController.isSourceTypeAvailable(.camera) {
                    Button("Take Photo") {
                        // Delay long enough for the confirmationDialog's UIAlertController
                        // dismiss animation to fully complete (~300 ms). Presenting a
                        // fullScreenCover while UIKit is still mid-dismiss crashes.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            showCamera = true
                        }
                    }
                }
                Button("Choose from Library") { showLibraryPicker = true }
                Button("Cancel", role: .cancel) { }
            }
            // ── Photo library picker ─────────────────────────────────────────
            .photosPicker(isPresented: $showLibraryPicker, selection: $selectedItem, matching: .images)
            .onChange(of: selectedItem) { _, item in
                guard let item else { return }
                Task { await loadAndSaveFromPicker(item) }
            }
            // ── Camera picker ────────────────────────────────────────────────
            .fullScreenCover(isPresented: $showCamera) {
                CameraPickerView(
                    onCapture: { image in
                        Task { await savePhoto(image) }
                    },
                    onDismiss: { showCamera = false }
                )
                .ignoresSafeArea()
            }
            // ── Upgrade sheet ────────────────────────────────────────────────
            .sheet(isPresented: $showUpgrade) {
                UpgradeView()
                    .environmentObject(EntitlementService.shared)
                    .environmentObject(StoreService.shared)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Add a photo")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .primaryText()
                Text("Track body condition changes over time")
                    .font(.caption)
                    .tertiaryText()
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Photo area (visual only)

    @ViewBuilder
    private var photoArea: some View {
        if let path = photoPath, let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.accentPrimary, lineWidth: 1.5)
                )
                .accessibilityLabel("Weight entry photo")
        } else {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.bgTertiary)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.borderSubtle, lineWidth: 1)
                )
                .overlay(
                    Image(systemName: "camera.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.textTertiary)
                        .accessibilityHidden(true)
                )
                .accessibilityLabel("No photo")
        }
    }

    // MARK: - Badge decoration (visual only — tap handled by overlay)

    private var badgeDecoration: some View {
        let systemName: String
        let color: Color
        if entitlements.hasPremium {
            systemName = photoPath != nil ? "pencil.circle.fill" : "camera.circle.fill"
            color = Color.accentPrimary
        } else {
            systemName = "lock.circle.fill"
            color = Color.accentPrimary
        }
        return Image(systemName: systemName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .font(.system(size: 20))
            .background(
                Circle()
                    .fill(Color.bgPrimary)
                    .frame(width: 16, height: 16)
            )
            .allowsHitTesting(false)
    }

    // MARK: - Photo handling

    private func loadAndSaveFromPicker(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else { return }
        await savePhoto(original)
        selectedItem = nil
    }

    private func savePhoto(_ image: UIImage) async {
        let resized = downscaled(image, maxDimension: 600)
        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { return }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("entry_photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Remove previous file before writing a new one
        if let oldPath = photoPath {
            try? FileManager.default.removeItem(atPath: oldPath)
        }

        let fileURL = dir.appendingPathComponent("entry_\(UUID().uuidString).jpg")
        try? jpegData.write(to: fileURL)

        await MainActor.run {
            photoPath = fileURL.path
        }
    }

    private func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }
        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
    }
}

#Preview {
    Form {
        Section("Photo") {
            WeightEntryPhotoView(photoPath: .constant(nil))
        }
    }
    .environmentObject(EntitlementService.shared)
}
