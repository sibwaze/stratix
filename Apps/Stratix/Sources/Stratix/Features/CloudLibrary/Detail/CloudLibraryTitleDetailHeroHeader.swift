// CloudLibraryTitleDetailHeroHeader.swift
// Defines cloud library title detail hero header for the CloudLibrary / Detail surface.
//

import SwiftUI

extension CloudLibraryTitleDetailScreen {
    var heroHeader: some View {
        let leadingInset = StratixTheme.Detail.browseAlignedLeadingInset
        let trailingInset = StratixTheme.Detail.heroInnerPadding
        let interItemSpacing = StratixTheme.Detail.heroInterItemSpacing

        return heroInfo(
            panelWidth: 1_920,
            textMaxWidth: max(1_920 - leadingInset - trailingInset - heroPosterWidth - interItemSpacing, 360)
        )
        .padding(.leading, leadingInset)
        .padding(.trailing, trailingInset)
        .padding(.vertical, 50)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: heroHeight, alignment: .topLeading)
    }

    func inlineActionBar(maxWidth: CGFloat) -> some View {
        Group {
            if !allActions.isEmpty {
                ActionButtonBar(
                    actions: allActions,
                    onSelect: handle,
                    defaultFocusActionID: state.primaryAction.id,
                    defaultFocusNamespace: detailPrimaryActionNamespace
                )
                .focusScope(detailPrimaryActionNamespace)
                .frame(maxWidth: maxWidth, alignment: .leading)
            }
        }
    }

    var allActions: [CloudLibraryActionViewState] {
        [state.primaryAction]
    }

    func handle(_ action: CloudLibraryActionViewState) {
        guard action.id != state.primaryAction.id else {
            onPrimaryAction()
            return
        }
        onSecondaryAction(action)
    }

    func heroInfo(panelWidth: CGFloat, textMaxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 22) {
                poster

                VStack(alignment: .leading, spacing: 12) {
                    if let contextLabel = state.contextLabel, !contextLabel.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text(contextLabel)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                    }

                    Text(state.title)
                        .font(.system(size: 50, weight: .heavy, design: .rounded))
                        .foregroundStyle(StratixTheme.Colors.textPrimary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: textMaxWidth, alignment: .leading)

                    if let subtitle = state.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(StratixTheme.Colors.textSecondary)
                            .lineLimit(2)
                            .frame(maxWidth: textMaxWidth, alignment: .leading)
                    }

                    if let descriptionText = state.descriptionText, !descriptionText.isEmpty {
                        Text(descriptionText)
                            .font(.system(size: 17, weight: .medium, design: .rounded))
                            .foregroundStyle(StratixTheme.Colors.textSecondary)
                            .lineLimit(3)
                            .frame(maxWidth: textMaxWidth, alignment: .leading)
                    }

                    if !state.capabilityChips.isEmpty {
                        ChipGroupView(chips: state.capabilityChips)
                            .frame(width: textMaxWidth, alignment: .leading)
                    }

                    if let gallerySummaryText {
                        HStack(spacing: 10) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 13, weight: .bold))
                            Text(gallerySummaryText)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                    }

                    if let achievementSummaryText {
                        HStack(spacing: 10) {
                            Image(systemName: "rosette")
                                .font(.system(size: 13, weight: .bold))
                            Text(achievementSummaryText)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .lineLimit(1)
                        }
                        .foregroundStyle(StratixTheme.Colors.textMuted)
                    }

                    ratingPanel
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(maxWidth: min(max(panelWidth - 60, 420), 560), alignment: .leading)
                        .padding(.top, 2)

                    inlineActionBar(maxWidth: textMaxWidth)
                        .padding(.top, 6)
                }
                .layoutPriority(1)
                .frame(maxWidth: textMaxWidth, alignment: .leading)
            }
        }
        .focusSection()
    }

    var poster: some View {
        let posterURL = state.posterImageURL ?? state.heroImageURL

        return CachedRemoteImage(
            url: posterURL,
            kind: .poster,
            maxPixelSize: 900,
            onImageLoaded: {
                if let posterURL {
                    markMediaReady(mediaReadinessKey(.poster(posterURL)))
                }
            }
        ) {
            ZStack {
                Color.white.opacity(0.08)
                Image(systemName: "gamecontroller.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(StratixTheme.Colors.textMuted)
            }
        }
        .frame(width: heroPosterWidth, height: heroPosterHeight)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    var ratingPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Rating & info")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(StratixTheme.Colors.textPrimary)

            if let rating = state.ratingText, !rating.isEmpty {
                Text(rating)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textSecondary)
            }

            if let legal = state.legalText, !legal.isEmpty {
                Text(legal)
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(StratixTheme.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var gallerySummaryText: String? {
        let screenshotCount = state.gallery.filter { $0.kind == .image }.count
        let trailerCount = state.gallery.filter { $0.kind == .video }.count
        var parts: [String] = []

        if screenshotCount > 0 {
            parts.append("\(screenshotCount) screenshot\(screenshotCount == 1 ? "" : "s")")
        }
        if trailerCount > 0 {
            parts.append("\(trailerCount) trailer\(trailerCount == 1 ? "" : "s")")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    var achievementSummaryText: String? {
        if let summary = state.achievementSummary {
            return "\(summary.unlockedAchievements)/\(summary.totalAchievements) achievements • \(summary.unlockPercent)%"
        }
        if let error = state.achievementErrorText, !error.isEmpty {
            return error
        }
        return nil
    }
}