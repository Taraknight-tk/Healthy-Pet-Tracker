//
//  PhotoFullScreenView.swift
//  Healthy Pet Tracker
//
//  Full-screen photo viewer. Dismiss by tapping the X button or
//  dragging down. Used for both pet profile photos and entry photos.
//

import SwiftUI

struct PhotoFullScreenView: View {
    let imagePath: String
    @Environment(\.dismiss) private var dismiss

    @State private var dragOffset: CGFloat = 0
    private let dismissThreshold: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black
                .ignoresSafeArea()

            if let uiImage = UIImage(contentsOfFile: imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
                    .offset(y: dragOffset)
                    .opacity(opacityForDrag)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                // Only allow downward drag
                                if value.translation.height > 0 {
                                    dragOffset = value.translation.height
                                }
                            }
                            .onEnded { value in
                                if value.translation.height > dismissThreshold {
                                    dismiss()
                                } else {
                                    withAnimation(.spring(duration: 0.3)) {
                                        dragOffset = 0
                                    }
                                }
                            }
                    )
                    .accessibilityLabel("Weight entry photo")
                    .accessibilityHint("Tap X to close")
            }

            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(Color.primary, Color.secondary.opacity(0.4))
            }
            .padding()
            .accessibilityLabel("Close photo")
        }
        .ignoresSafeArea()
    }

    private var opacityForDrag: Double {
        guard dragOffset > 0 else { return 1 }
        return max(0.5, 1 - Double(dragOffset) / 300)
    }
}
