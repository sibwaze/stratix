// CloudLibraryTitleDetailFullscreenMedia.swift
// Defines cloud library title detail fullscreen media for the CloudLibrary / Detail surface.
//

import AVKit
import SwiftUI
import UIKit

struct GalleryFullscreenViewer: View {
    let mediaItems: [CloudLibraryGalleryItemViewState]

    @Environment(\.dismiss) private var dismiss
    @State private var selection: Int
    @FocusState private var gallerySurfaceFocused: Bool

    init(mediaItems: [CloudLibraryGalleryItemViewState], initialIndex: Int) {
        self.mediaItems = mediaItems
        let maxIndex = max(mediaItems.count - 1, 0)
        _selection = State(initialValue: min(max(initialIndex, 0), maxIndex))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if !mediaItems.isEmpty {
                TabView(selection: $selection) {
                    ForEach(mediaItems.indices, id: \.self) { index in
                        let item = mediaItems[index]
                        ZStack {
                            Color.black.ignoresSafeArea()

                            switch item.kind {
                            case .image:
                                GalleryFullscreenImageView(url: item.mediaURL)
                            case .video:
                                TrailerVideoSurface(
                                    streamURL: item.mediaURL,
                                    posterURL: item.thumbnailURL,
                                    isActive: selection == index
                                )
                            }
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()
            }

            if !mediaItems.isEmpty {
                VStack {
                    Spacer()
                    galleryPositionOverlay
                        .padding(.bottom, 72)
                }
                .ignoresSafeArea()
            }
        }
        .background(Color.black.ignoresSafeArea())
        .overlay {
            Color.clear
                .focusable(true)
                .focused($gallerySurfaceFocused)
                .gamePassDisableSystemFocusEffect()
        }
        .onExitCommand {
            dismiss()
        }
        .onMoveCommand(perform: handleMoveCommand)
        .onAppear {
            gallerySurfaceFocused = true
        }
    }

    private var galleryPositionOverlay: some View {
        VStack(spacing: 14) {
            Text("\(selection + 1) / \(mediaItems.count)")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textPrimary)
                .monospacedDigit()

            HStack(spacing: 8) {
                ForEach(mediaItems.indices, id: \.self) { index in
                    Circle()
                        .fill(
                            index == selection
                                ? StratixTheme.Colors.focusTint
                                : Color.white.opacity(0.28)
                        )
                        .frame(width: index == selection ? 10 : 7, height: index == selection ? 10 : 7)
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.42))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .allowsHitTesting(false)
    }

    private func handleMoveCommand(_ direction: MoveCommandDirection) {
        guard !mediaItems.isEmpty else { return }

        switch direction {
        case .left:
            selection = max(selection - 1, 0)
        case .right:
            selection = min(selection + 1, mediaItems.count - 1)
        default:
            break
        }
    }
}

private struct GalleryFullscreenImageView: View {
    let url: URL?

    var body: some View {
        GeometryReader { proxy in
            CachedRemoteImage(
                url: url,
                kind: .gallery,
                maxPixelSize: 2_560,
                contentMode: .fill
            ) {
                ProgressView()
                    .controlSize(.large)
                    .tint(StratixTheme.Colors.focusTint)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }
}

private struct TrailerVideoSurface: View {
    let streamURL: URL
    let posterURL: URL?
    let isActive: Bool

    @State private var player: AVPlayer?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let posterURL {
                    CachedRemoteImage(url: posterURL, kind: .trailer, maxPixelSize: 2_560, contentMode: .fill) {
                        Color.black
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                }

                if let player {
                    TrailerInlinePlayerView(player: player)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .tint(StratixTheme.Colors.focusTint)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.black)
        }
        .ignoresSafeArea()
        .onAppear {
            configurePlayerIfNeeded()
            updatePlaybackState()
        }
        .onDisappear {
            player?.pause()
        }
        .onChange(of: isActive) { _, _ in
            updatePlaybackState()
        }
    }

    private func configurePlayerIfNeeded() {
        guard player == nil else { return }

        let player = AVPlayer(url: streamURL)
        player.actionAtItemEnd = .pause
        self.player = player

        if isActive {
            player.seek(to: .zero)
            player.play()
        }
    }

    private func updatePlaybackState() {
        guard let player else { return }

        if isActive {
            player.seek(to: .zero)
            player.play()
        } else {
            player.pause()
        }
    }
}

private struct TrailerInlinePlayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> TrailerPlayerContainerView {
        let view = TrailerPlayerContainerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: TrailerPlayerContainerView, context: Context) {
        uiView.playerLayer.player = player
        uiView.playerLayer.videoGravity = .resizeAspectFill
    }
}

private final class TrailerPlayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}