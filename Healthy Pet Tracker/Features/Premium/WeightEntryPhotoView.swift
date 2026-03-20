//
//  WeightEntryPhotoView.swift
//  Healthy Pet Tracker
//
//  Reusable camera/picker component for attaching a photo to a weight entry.
//  Uses a Binding<String?> so it works in both AddWeightView (State-backed)
//  and EditWeightView (@Bindable entry.photoPath).
//
//  Pro users: tapping the badge opens PhotosPicker. The image is resized and
//  saved to Documents/entry_photos/. Selecting a new photo replaces the old file.
//  Free users: tapping the lock badge opens UpgradeView.
//

import SwiftUI
import PhotosUI

struct WeightEntryPhotoView: View {
    @EnvironmentObject var entitlements: EntitlementService

    @Binding var photoPath: String?

    @State private var selectedItem: PhotosPickerItem?
    @State private var showUpgrade = false

    private let size: CGFloat = 64

    var body: some View {
        HStack(spacing: 16) {
            ZStack(alignment: .bottomTrailing) {
                photoArea
                badgeButton
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
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task { await loadAndSavePhoto(from: item) }
        }
    }

    // MARK: - Photo area

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
                        .foregroundStyle(Color.accentMuted)
                        .accessibilityHidden(true)
                )
                .accessibilityLabel("No photo")
        }
    }

    // MARK: - Badge button

    @ViewBuilder
    private var badgeButton: some View {
        if entitlements.hasPremium {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                badgeIcon(
                    systemName: photoPath != nil ? "pencil.circle.fill" : "plus.circle.fill"
                )
            }
            .accessibilityLabel(photoPath != nil ? "Change photo" : "Add photo")
        } else {
            Button { showUpgrade = true } label: {
                badgeIcon(systemName: "lock.circle.fill", color: Color.accentMuted)
            }
            .accessibilityLabel("Upgrade to Pro to add entry photos")
        }
    }

    private func badgeIcon(systemName: String, color: Color = Color.accentPrimary) -> some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .font(.system(size: 20))
            .background(
                Circle()
                    .fill(Color.bgPrimary)
                    .frame(width: 16, height: 16)
            )
    }

    // MARK: - Photo handling

    private func loadAndSavePhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else { return }

        let resized = downscaled(original, maxDimension: 600)
        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { return }

        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("entry_photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Remove previous file for this entry before writing a new one
        if let oldPath = photoPath {
            try? FileManager.default.removeItem(atPath: oldPath)
        }

        let fileURL = dir.appendingPathComponent("entry_\(UUID().uuidString).jpg")
        try? jpegData.write(to: fileURL)

        photoPath = fileURL.path
        selectedItem = nil
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
