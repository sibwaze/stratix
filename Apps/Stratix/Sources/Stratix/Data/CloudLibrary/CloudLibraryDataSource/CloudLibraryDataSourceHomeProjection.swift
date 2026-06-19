// CloudLibraryDataSourceHomeProjection.swift
// Defines cloud library data source home projection for the CloudLibrary / CloudLibraryDataSource surface.
//

import Foundation
import DiagnosticsKit
import StratixCore
import StratixModels

extension CloudLibraryDataSource {
    /// Builds the home-screen projection directly from sections and merchandising when no prepared index is being reused.
    static func homeState(
        sections: [CloudLibrarySection],
        merchandising: HomeMerchandisingSnapshot?,
        productDetails: [ProductID: CloudLibraryProductDetail] = [:],
        showsContinueBadge: Bool = true
    ) -> CloudLibraryHomeViewState {
        homeState(
            index: prepareIndex(sections: sections, merchandising: merchandising),
            productDetails: productDetails,
            showsContinueBadge: showsContinueBadge
        )
    }

    /// Builds the home-screen projection from the prepared index plus optional rich product details.
    static func homeState(
        index: PreparedLibraryIndex,
        productDetails: [ProductID: CloudLibraryProductDetail] = [:],
        showsContinueBadge: Bool = true
    ) -> CloudLibraryHomeViewState {
        let mruItems = index.mruItems
        let allItems = index.allItems
        let recentlyAddedItems = index.merchandising?.recentlyAddedItems ?? []
        let merchandisingRows = index.merchandising?.rows ?? []
        logHomeProjection(
            "input libraryTitles=\(allItems.count) mru=\(mruItems.count) merchRows=\(merchandisingRows.count) recent=\(recentlyAddedItems.count) sections=[\(sectionSummary(index.sections))] recentSample=[\(itemSample(recentlyAddedItems))] mruSample=[\(itemSample(mruItems))]"
        )
        let featuredItem = recentlyAddedItems.first ?? index.featuredItem
        let carouselSource = recentlyAddedItems.prefix(5)
        var carouselItems: [CloudLibraryHomeCarouselItemViewState] = []
        carouselItems.reserveCapacity(carouselSource.count)
        for item in carouselSource {
            let richDetail = productDetails[item.typedProductID]
            let creatorLine = firstNonEmptyTrimmed(
                richDetail?.developerName,
                richDetail?.publisherName,
                item.publisherName
            )
            let category = firstGenreCategoryLabel(
                genreLabels: richDetail?.genreLabels ?? [],
                fallbackGenre: primaryGenre(for: item)
            )
            carouselItems.append(
                CloudLibraryHomeCarouselItemViewState(
                    id: "carousel:\(item.titleId)",
                    titleID: item.typedTitleID,
                    title: item.name,
                    subtitle: creatorLine,
                    categoryLabel: category,
                    ratingBadgeText: nil,
                    description: item.shortDescription,
                    heroBackgroundURL: item.heroImageURL ?? item.artURL,
                    artworkURL: item.posterImageURL ?? item.artURL ?? item.heroImageURL
                )
            )
        }

        var railSections: [CloudLibraryRailSectionViewState] = []
        railSections.reserveCapacity((mruItems.isEmpty ? 0 : 1) + merchandisingRows.count)
        if !mruItems.isEmpty {
            railSections.append(
                CloudLibraryRailSectionViewState(
                    id: "mru",
                    alias: "mru",
                    title: "Jump back in",
                    subtitle: "Recently played cloud titles",
                    items: mruItems.map { item in
                        .title(
                            CloudLibraryHomeTitleRailItemViewState(
                                id: "home-mru:\(item.titleId)",
                                tile: tileState(
                                    for: item,
                                    aspect: .portrait,
                                    idPrefix: "home-mru",
                                    showsContinueBadge: showsContinueBadge
                                ),
                                action: .launchStream(source: "home_mru")
                            )
                        )
                    }
                )
            )
        }

        for row in merchandisingRows {
            let visibleItemCount = min(10, row.items.count)
            var railItems: [CloudLibraryHomeRailItemViewState] = []
            railItems.reserveCapacity(visibleItemCount + (row.items.count > 10 ? 1 : 0))
            railItems.append(contentsOf: row.items.prefix(10).map { item in
                .title(
                    CloudLibraryHomeTitleRailItemViewState(
                        id: "home-sigl:\(row.alias):\(item.titleId)",
                        tile: tileState(
                            for: item,
                            aspect: .portrait,
                            idPrefix: "home-sigl-\(row.alias)",
                            showsContinueBadge: showsContinueBadge
                        ),
                        action: .openDetail
                    )
                )
            })
            if row.items.count > 10 {
                railItems.append(
                    .showAll(
                        CloudLibraryHomeShowAllCardViewState(
                            id: "home-show-all:\(row.alias)",
                            alias: row.alias,
                            label: row.label,
                            totalCount: row.items.count
                        )
                    )
                )
            }

            railSections.append(
                CloudLibraryRailSectionViewState(
                    id: "sigl-\(row.alias)",
                    alias: row.alias,
                    title: row.label,
                    subtitle: "\(row.items.count) games",
                    items: railItems
                )
            )
        }

        let state = CloudLibraryHomeViewState(
            heroBackgroundURL: carouselItems.first?.heroBackgroundURL ?? featuredItem?.heroImageURL ?? featuredItem?.artURL,
            carouselItems: carouselItems,
            sections: railSections
        )
        logHomeProjection(
            "output hero=\(state.carouselItems.first?.titleID.rawValue ?? featuredItem?.titleId ?? "none") carousel=\(state.carouselItems.count) rails=\(state.sections.count) carouselSample=[\(carouselSample(state.carouselItems))] railSummary=[\(railSummary(state.sections))]"
        )
        return state
    }

    /// Chooses the best genre label to drive home fallback grouping for one title.
    static func primaryGenre(for item: CloudLibraryItem) -> String {
        guard let genre = item.attributes
            .map(\.localizedName)
            .first(where: { isLikelyGenreAttribute($0) }) else {
            return "More games"
        }
        return genre
    }

    private static let nonGenreAttributeFragments = [
        "xbox", "cloud", "save", "achieve", "club", "play anywhere",
        "optimized", "series x", "series s", "ultra hd", "4k", "hdr",
        "fps boost", "smart delivery", "dolby", "spatial sound", "touch"
    ]

    /// Filters out attribute labels that look like platform/capability metadata rather than a real genre.
    static func isLikelyGenreAttribute(_ value: String) -> Bool {
        let lowercased = value.lowercased()
        return !nonGenreAttributeFragments.contains(where: { lowercased.contains($0) })
    }

    private static func firstNonEmptyTrimmed(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            return trimmed
        }
        return nil
    }

    private static func firstGenreCategoryLabel(genreLabels: [String], fallbackGenre: String) -> String? {
        var seen = Set<String>()
        for value in genreLabels {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            guard trimmed != "More games" else { continue }
            return trimmed
        }

        let fallback = fallbackGenre.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fallback.isEmpty, fallback != "More games" else { return nil }
        return fallback
    }

    private static func logHomeProjection(_ message: @autoclosure () -> String) {
        guard GLogger.isEnabled else { return }
        logger.info("Home projection datasource: \(message())")
    }

    private static func itemSample(_ items: [CloudLibraryItem], limit: Int = 5) -> String {
        items.prefix(limit)
            .map { "\($0.titleId)|\($0.productId)|\($0.name.replacingOccurrences(of: "\"", with: "'"))" }
            .joined(separator: ", ")
    }

    private static func carouselSample(_ items: [CloudLibraryHomeCarouselItemViewState], limit: Int = 5) -> String {
        items.prefix(limit)
            .map { "\($0.titleID.rawValue)|\($0.title.replacingOccurrences(of: "\"", with: "'"))" }
            .joined(separator: ", ")
    }

    private static func sectionSummary(_ sections: [CloudLibrarySection], limit: Int = 6) -> String {
        sections.prefix(limit)
            .map { "\($0.id):\($0.items.count)" }
            .joined(separator: ", ")
    }

    private static func railSummary(_ sections: [CloudLibraryRailSectionViewState], limit: Int = 8) -> String {
        sections.prefix(limit)
            .map { "\($0.alias ?? $0.id):\($0.items.count)" }
            .joined(separator: ", ")
    }
}
