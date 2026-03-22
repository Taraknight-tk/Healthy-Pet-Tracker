//
//  PhotoPickerView.swift
//  Healthy Pet Tracker
//
//  Pro feature: custom pet profile photo.
//
//  • Pro users: tapping the photo circle shows a confirmation dialog offering
//    Camera or Photo Library. The chosen image is resized to 400×400 max,
//    saved as a JPEG in Documents/pet_photos/, and the path stored on Pet.
//  • Free users: tapping the circle presents UpgradeView.
//
//  Tap-target is intentionally limited to the 80×80 photo circle via an
//  invisible overlay so that nothing outside that area is accidentally hit.
//

import SwiftUI
import PhotosUI
import SwiftData

struct PetPhotoView: View {
    @EnvironmentObject var entitlements: EntitlementService
    @Bindable var pet: Pet

    @State private var selectedItem: PhotosPickerItem?
    @State private var showUpgrade = false
    @State private var showSourcePicker = false
    @State private var showCamera = false
    @State private var showLibraryPicker = false

    private let photoSize: CGFloat = 80

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            photoCircle
            badgeDecoration
        }
        // ── Precise tap target: only the circle itself is hittable ──────────
        .overlay(alignment: .center) {
            Color.clear
                .frame(width: photoSize, height: photoSize)
                .contentShape(Circle())
                .onTapGesture {
                    if entitlements.hasPremium {
                        showSourcePicker = true
                    } else {
                        showUpgrade = true
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(entitlements.hasPremium
                    ? (pet.photoPath != nil ? "\(pet.name)'s photo" : "\(pet.name), \(pet.species)")
                    : "Profile photo locked")
                .accessibilityHint(entitlements.hasPremium
                    ? (pet.photoPath != nil ? "Double-tap to change photo" : "Double-tap to add photo")
                    : "Double-tap to upgrade to Pro")
        }
        // ── Source selection ─────────────────────────────────────────────────
        .confirmationDialog(
            pet.photoPath != nil ? "Change Photo" : "Add Photo",
            isPresented: $showSourcePicker,
            titleVisibility: .visible
        ) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("Take Photo") { DispatchQueue.main.async { showCamera = true } }
            }
            Button("Choose from Library") { showLibraryPicker = true }
            Button("Cancel", role: .cancel) { }
        }
        // ── Photo library picker (out-of-process, no permission prompt) ──────
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, newItem in
            guard let newItem else { return }
            Task { await loadAndSavePhotoFromPicker(newItem) }
        }
        // ── Camera picker ────────────────────────────────────────────────────
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(
                onCapture: { image in
                    Task { await savePhoto(image) }
                },
                onDismiss: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        // ── Upgrade sheet ────────────────────────────────────────────────────
        .sheet(isPresented: $showUpgrade) {
            UpgradeView()
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
        // Auto-dismiss paywall when user purchases
        .onChange(of: entitlements.hasPremium) { _, isPro in
            if isPro { showUpgrade = false }
        }
    }

    // MARK: - Photo circle (purely visual)

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

    // MARK: - Badge decoration (visual only — tap is handled by the overlay above)

    private var badgeDecoration: some View {
        let systemName: String
        let color: Color
        if entitlements.hasPremium {
            systemName = pet.photoPath != nil ? "pencil.circle.fill" : "camera.circle.fill"
            color = Color.accentPrimary
        } else {
            systemName = "lock.circle.fill"
            color = Color.accentMuted
        }
        return Image(systemName: systemName)
            .symbolRenderingMode(.palette)
            .foregroundStyle(.white, color)
            .font(.system(size: 24))
            .background(
                Circle()
                    .fill(Color.bgPrimary)
                    .frame(width: 20, height: 20)
            )
            .allowsHitTesting(false)  // all taps fall through to the overlay
    }

    // MARK: - Photo handling

    private func loadAndSavePhotoFromPicker(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let original = UIImage(data: data) else { return }
        await savePhoto(original)
        selectedItem = nil
    }

    private func savePhoto(_ image: UIImage) async {
        let resized = downscaled(image, maxDimension: 400)
        guard let jpegData = resized.jpegData(compressionQuality: 0.8) else { return }

        let documents = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        let photosDir = documents.appendingPathComponent("pet_photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: photosDir, withIntermediateDirectories: true)

        let fileURL = photosDir.appendingPathComponent("pet_\(pet.id.uuidString).jpg")
        try? jpegData.write(to: fileURL)

        await MainActor.run {
            pet.photoPath = fileURL.path
        }
    }

    /// Downscales a UIImage so its longest edge is ≤ maxDimension.
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
        case "dog":                           return "dog.fill"
        case "cat":                           return "cat.fill"
        case "rabbit":                        return "hare.fill"
        case "bird":                          return "bird.fill"
        case "fish":                          return "fish.fill"
        case "tortoise", "turtle", "reptile": return "tortoise.fill"
        default:                              return "pawprint.fill"
        }
    }
}

#Preview {
    PetPhotoView(pet: Pet(name: "Hope", birthday: Date(), species: "Dog", initialWeight: 22, unit: .pounds))
        .environmentObject(EntitlementService.shared)
        .padding()
}
