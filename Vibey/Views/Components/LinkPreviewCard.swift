//
//  LinkPreviewCard.swift
//  Vibey
//
//  Renders a link preview card that can be embedded in the rich text editor
//

import SwiftUI
import AppKit

// MARK: - Link Preview Card View

struct LinkPreviewCardView: View {
    let preview: LinkPreviewData
    let thumbnail: NSImage?
    let maxWidth: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Thumbnail image
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: maxWidth, maxHeight: 160)
                    .clipped()
            }

            // Content area
            VStack(alignment: .leading, spacing: 6) {
                // Title
                if let title = preview.title, !title.isEmpty {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                }

                // Description
                if let description = preview.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }

                // Domain
                Text(preview.domain)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(12)
            .frame(maxWidth: maxWidth, alignment: .leading)
        }
        .background(Color(hex: "2A2D32"))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Link Preview Card Renderer

class LinkPreviewCardRenderer {
    /// Render a link preview card to an NSImage
    static func renderToImage(preview: LinkPreviewData, thumbnail: NSImage?, maxWidth: CGFloat = 400) -> NSImage {
        let view = LinkPreviewCardView(preview: preview, thumbnail: thumbnail, maxWidth: maxWidth)

        // Create hosting view
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: maxWidth, height: 300)

        // Calculate proper size
        let fittingSize = hostingView.fittingSize
        hostingView.frame = CGRect(origin: .zero, size: fittingSize)

        // Render to image
        let image = NSImage(size: fittingSize)
        image.lockFocus()

        if let context = NSGraphicsContext.current?.cgContext {
            // Flip coordinates for proper rendering
            context.translateBy(x: 0, y: fittingSize.height)
            context.scaleBy(x: 1, y: -1)
        }

        hostingView.layer?.render(in: NSGraphicsContext.current!.cgContext)
        image.unlockFocus()

        return image
    }

    /// Alternative render method using bitmap representation
    static func renderToImageBitmap(preview: LinkPreviewData, thumbnail: NSImage?, maxWidth: CGFloat = 400) -> NSImage? {
        let view = LinkPreviewCardView(preview: preview, thumbnail: thumbnail, maxWidth: maxWidth)

        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true

        // Set initial frame and get fitting size
        hostingView.frame = CGRect(x: 0, y: 0, width: maxWidth, height: 400)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = CGRect(origin: .zero, size: fittingSize)

        // Force layout
        hostingView.layoutSubtreeIfNeeded()

        // Create bitmap representation
        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        let image = NSImage(size: fittingSize)
        image.addRepresentation(bitmapRep)
        return image
    }
}

// MARK: - Preview

struct LinkPreviewCard_Previews: PreviewProvider {
    static var previews: some View {
        LinkPreviewCardView(
            preview: LinkPreviewData(
                url: "https://nike.com",
                title: "Nike. Just Do It",
                description: "Inspiring the world's athletes, Nike delivers innovative products, experiences and services.",
                imageURL: nil,
                siteName: "Nike"
            ),
            thumbnail: nil,
            maxWidth: 350
        )
        .padding()
        .background(Color.vibeyBackground)
    }
}
