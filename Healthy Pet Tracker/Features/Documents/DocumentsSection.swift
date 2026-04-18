//
//  DocumentsSection.swift
//  Healthy Pet Tracker
//
//  Pro feature: per-pet document library for vet records, vaccination cards,
//  lab results, X-rays, etc.
//
//  • Pro users: import PDFs and images from the Files app. Tap any document
//    to view it full-screen via Quick Look. Swipe to delete.
//  • Free users: see a lock teaser → upgrade paywall.
//
//  Files are copied from the security-scoped URL into
//  Documents/pet_docs/<petID>/ so they persist across launches.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct DocumentsSection: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var entitlements: EntitlementService
    @Bindable var pet: Pet

    @State private var showingFilePicker = false
    @State private var showingUpgrade    = false
    @State private var previewURL: URL?
    @State private var importError: String?
    @State private var showingImportError = false

    private var sortedDocs: [PetDocument] {
        pet.documents.sorted { $0.dateAdded > $1.dateAdded }
    }

    var body: some View {
        if entitlements.hasPremium {
            proContent
        } else {
            lockedTeaser
        }
    }

    // MARK: - Pro content

    private var proContent: some View {
        Group {
            if sortedDocs.isEmpty {
                emptyState
            } else {
                ForEach(sortedDocs) { doc in
                    documentRow(doc)
                        .contentShape(Rectangle())
                        .onTapGesture { previewURL = URL(fileURLWithPath: doc.filePath) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) { deleteDocument(doc) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }

            // Always show the + Add button for Pro users
            Button(action: { showingFilePicker = true }) {
                Label("Add Document", systemImage: "plus.circle")
                    .foregroundStyle(Color.accentInteractive)
            }
        }
        // ── File picker ──────────────────────────────────────────────────
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
        // ── Quick Look viewer ────────────────────────────────────────────
        .fullScreenCover(item: $previewURL) { url in
            QuickLookView(fileURL: url) { previewURL = nil }
                .ignoresSafeArea()
        }
        // ── Import error ─────────────────────────────────────────────────
        .alert("Couldn't Import File", isPresented: $showingImportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(importError ?? "An unknown error occurred.")
        }
    }

    // MARK: - Document row

    private func documentRow(_ doc: PetDocument) -> some View {
        HStack(spacing: 12) {
            Image(systemName: doc.fileType.icon)
                .font(.system(size: 22))
                .foregroundStyle(doc.fileType.color)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .primaryText()
                    .lineLimit(1)
                Text(doc.dateAdded.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .tertiaryText()
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 4)
        .accessibilityLabel("\(doc.title). Added \(doc.dateAdded.formatted(date: .abbreviated, time: .omitted))")
        .accessibilityHint("Double-tap to view")
    }

    // MARK: - Empty state

    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 22))
                .foregroundStyle(Color.textTertiary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("No Documents Yet")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .primaryText()
                Text("Store vet records, vaccination cards & more")
                    .font(.caption)
                    .tertiaryText()
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Locked teaser (free users)

    private var lockedTeaser: some View {
        Button { showingUpgrade = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 22))
                    .foregroundStyle(Color.accentInteractive)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Document Storage")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .primaryText()
                    Text("Upgrade to Pro to store vet records, lab results & more")
                        .font(.caption)
                        .tertiaryText()
                }
                Spacer()
                Image(systemName: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(Color.accentInteractive)
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showingUpgrade) {
            UpgradeView()
                .environmentObject(EntitlementService.shared)
                .environmentObject(StoreService.shared)
        }
    }

    // MARK: - File import

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = error.localizedDescription
            showingImportError = true

        case .success(let urls):
            guard let sourceURL = urls.first else { return }

            // Security-scoped access required for Files-picker URLs
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

            do {
                // Destination: Documents/pet_docs/<petID>/
                let docs    = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                let petDir  = docs
                    .appendingPathComponent("pet_docs", isDirectory: true)
                    .appendingPathComponent(pet.id.uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: petDir, withIntermediateDirectories: true)

                let destURL = petDir.appendingPathComponent(sourceURL.lastPathComponent)

                // Overwrite if a file with the same name already exists
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)

                // Detect type
                let ext      = sourceURL.pathExtension.lowercased()
                let fileType: DocFileType = (ext == "pdf") ? .pdf : .image

                // Save record
                let document = PetDocument(
                    title:    sourceURL.deletingPathExtension().lastPathComponent,
                    filePath: destURL.path,
                    fileType: fileType
                )
                document.pet = pet
                modelContext.insert(document)
                HapticManager.shared.notification(.success)

            } catch {
                importError = error.localizedDescription
                showingImportError = true
            }
        }
    }

    // MARK: - Delete

    private func deleteDocument(_ doc: PetDocument) {
        // Remove the file from disk first
        try? FileManager.default.removeItem(atPath: doc.filePath)
        modelContext.delete(doc)
        HapticManager.shared.notification(.success)
    }
}

// MARK: - URL Identifiable conformance (needed for .fullScreenCover(item:))

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
