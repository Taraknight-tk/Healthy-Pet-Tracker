//
//  PhotoPickerView.swift
//  Healthy Pet Tracker
//
//  Pro feature: custom pet profile photo.
//
//  • Pro users: tapping the badge opens PhotosPicker. The chosen image is
//    resized to a max of 400 × 400 px, saved as a JPEG in
//    Documents/pet_photos/, and the file path is stored on the Pet model.
//  • Free users: a lock badge is shown instead; tapping presents UpgradeView.
//
//  Drop-in replacement for the species SF Symbol icon in PetInfoCard.
//

import SwiftUI
import PhotosUI
import SwiftData

struct PetPhotoView: View {
    @EnvironmentObject var entitlements: EntitlementService
    @Bindable var pet: Pet

    @State private var selectedItem: PhotosPickerItem?
    @State private var showUpgrade = false

    private let photoSize: CGFloat = 80

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            photoCircle
            badgeButton
        }
        .sheet(isPresented: $showUpgrade) {
            // Sheets don't reliably inherit environment objects in SwiftUI,
            // so we pass the singletons explicitly here.
            UpgradeView()
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadAndSavePhoto(from: newItem) }
        }
    }

    // MARK: - Photo circle

    @ViewBuilder
    private var photoCircle: some View {
        if let path = pet.photoPath,
           let uiImage = UIImage(contentsOfFile: path) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: photoSize, height: photoSize)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.accentPrimary, lineWidth: 2))
                .accessibilityLabel("\(pet.name)'s photo")
        } else {
            Circle()
                .fill(Color.bgTertiary)
                .frame(width: photoSize, height: photoSize)
                .overlay(Circle().stroke(Color.borderSubtle, lineWidth: 1))
                .overlay(
                    Image(systemName: speciesIcon(for: pet.species))
                        .font(.system(size: 32))
                        .foregroundStyle(Color.accentPrimary)
                        .accessibilityHidden(true)
                )
                .accessibilityLabel("\(pet.name), \(pet.species)")
        }
    }

    // MARK: - Badge button (Pro vs locked)

    @ViewBuilder
    private var badgeButton: some View {
        if entitlements.hasPremium {
            PhotosPicker(selection: $selectedItem, matching: .images) {
                badgeIcon(systemName: pet.photoPath != nil ? "pencil.circle.fill" : "plus.circle.fill")
            }
            .accessibilityLabel(pet.photoPath != nil ? "Change photo" : "Add photo")
        } else {
            Button { showUpgrade = true } label: {
                badgeIcon(systemName: "lock.circle.fill", color: Color.accentMuted)
            }
            .accessibilityLabel("Upgrade to Pro to add a custom photo")
        }
    }

    private func badgeIcon(systemName: String, color: Color = Color.accentPrimary) -> some View {
        Image(systemName: systemName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .font(.system(size: 24))
            .background(
                Circle()
                    .fill(Color.bgPrimary)
                    .frame(width: 20, height: 20)
            )
    }

    // MARK: - Photo handling

    private func loadAndSavePhoto(from item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else {
            return
        }

        let resized = downscaled(original, maxDimension: 400)

        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { return }

        // Ensure the pet_photos directory exists
        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDir = documents.appendingPathComponent("pet_photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        // Each pet gets its own file, keyed by UUID — re-saving replaces the old one
        let fileURL = photosDir.appendingPathComponent("pet_\(pet.id.uuidString).jpg")
        try? jpegData.write(to: fileURL)

        // Update model — SwiftData picks up the change automatically
        pet.photoPath = fileURL.path
        selectedItem = nil
    }

    /// Downscales a UIImage so its longest edge is ≤ maxDimension.
    /// Returns the original image unchanged if it already fits.
    private func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxDimension else { return image }

        let scale = maxDimension / longest
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Species icon fallback

    private func speciesIcon(for species: String) -> String {
        switch species.lowercased() {
        case "dog":                         return "dog.fill"
        case "cat":                         return "cat.fill"
        case "rabbit":                      return "hare.fill"
        case "bird":                        return "bird.fill"
        case "fish":                        return "fish.fill"
        case "tortoise", "turtle", "reptile": return "tortoise.fill"
        default:                            return "pawprint.fill"
        }
    }
}

#Preview {
    PetPhotoView(pet: Pet(name: "Hope", birthday: Date(), species: "Dog", initialWeight: 22, unit: .pounds))
        .environmentObject(EntitlementService.shared)
        .padding()
}
