// CachedRemoteImage.swift
// Defines cached remote image for the Shared / Components surface.
//

import SwiftUI
import UIKit
import StratixCore

@MainActor
enum RemoteImageDisplayCache {
    private static let storage: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 72
        cache.totalCostLimit = 64 * 1_024 * 1_024
        return cache
    }()

    static func image(for key: String) -> UIImage? {
        storage.object(forKey: key as NSString)
    }

    static func store(_ image: UIImage, for key: String) {
        storage.setObject(image, forKey: key as NSString, cost: imageCostBytes(image))
    }

    private static func imageCostBytes(_ image: UIImage) -> Int {
        guard let cgImage = image.cgImage else { return 0 }
        return cgImage.bytesPerRow * cgImage.height
    }
}

/// Shared SwiftUI image view that bridges view-driven artwork identity to the actor-backed
/// remote image pipeline and only updates displayed artwork when the cache identity changes.
struct CachedRemoteImage<Placeholder: View>: View {
    let url: URL?
    var kind: ArtworkKind = .poster
    var priority: ArtworkPriority = .normal
    var maxPixelSize: CGFloat? = nil
    var contentMode: ContentMode = .fill
    var onImageLoaded: (() -> Void)? = nil
    let placeholder: () -> Placeholder
    private let cacheIdentity: String

    @State private var image: UIImage?
    @State private var displayKey: String?

    init(
        url: URL?,
        kind: ArtworkKind = .poster,
        priority: ArtworkPriority = .normal,
        maxPixelSize: CGFloat? = nil,
        contentMode: ContentMode = .fill,
        onImageLoaded: (() -> Void)? = nil,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.kind = kind
        self.priority = priority
        self.maxPixelSize = maxPixelSize
        self.contentMode = contentMode
        self.onImageLoaded = onImageLoaded
        self.placeholder = placeholder

        let identity = Self.makeCacheIdentity(url: url, kind: kind, maxPixelSize: maxPixelSize)
        self.cacheIdentity = identity
        let cached = RemoteImageDisplayCache.image(for: identity)
        _image = State(initialValue: cached)
        _displayKey = State(initialValue: cached == nil ? nil : identity)
    }

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .onAppear {
                        onImageLoaded?()
                    }
            } else {
                placeholder()
            }
        }
        .task(id: cacheIdentity) {
            await loadImage()
        }
    }

    private static func makeCacheIdentity(
        url: URL?,
        kind: ArtworkKind,
        maxPixelSize: CGFloat?
    ) -> String {
        "\(url?.absoluteString ?? "nil")|\(kind.rawValue)|\(maxPixelSize.map { String(Int($0)) } ?? "full")"
    }

    /// Clears stale displayed artwork before awaiting a replacement so reused SwiftUI cells do
    /// not briefly show the wrong remote image.
    @MainActor
    private func loadImage() async {
        guard let url else {
            clearImage()
            return
        }
        let cacheKey = cacheIdentity
        if displayKey == cacheKey, image != nil {
            return
        }
        if let cached = RemoteImageDisplayCache.image(for: cacheKey) {
            displayImage(cached, for: cacheKey)
            return
        }
        if let cached = await RemoteImagePipeline.shared.cachedImage(for: cacheKey) {
            displayImage(cached, for: cacheKey)
            return
        }

        clearImageIfDisplayingDifferentKey(cacheKey)

        guard let loaded = await RemoteImagePipeline.shared.image(
            for: ArtworkRequest(url: url, kind: kind, priority: priority),
            cacheKey: cacheKey,
            maxPixelSize: maxPixelSize
        ) else {
            return
        }

        displayImage(loaded, for: cacheKey)
    }

    @MainActor
    private func clearImage() {
        image = nil
        displayKey = nil
    }

    @MainActor
    private func clearImageIfDisplayingDifferentKey(_ cacheKey: String) {
        guard displayKey != cacheKey else { return }
        image = nil
    }

    @MainActor
    private func displayImage(_ image: UIImage, for cacheKey: String) {
        let shouldStore = displayKey != cacheKey || self.image !== image
        self.image = image
        displayKey = cacheKey
        if shouldStore {
            RemoteImageDisplayCache.store(image, for: cacheKey)
        }
    }
}
