// CloudLibraryViewModelHomeProjection.swift
// Defines cloud library view model home projection for the CloudLibrary / Root surface.
//

import StratixCore
import StratixModels

@MainActor
extension CloudLibraryViewModel {
    func rebuildHomeProjection(
        using index: CloudLibraryDataSource.PreparedLibraryIndex,
        productDetails: [ProductID: CloudLibraryProductDetail],
        detailRevision: UInt64,
        homeRevision: UInt64,
        sceneContentRevision: UInt64,
        showsContinueBadge: Bool
    ) {
        var hasher = Hasher()
        hasher.combine(sceneContentRevision)
        hasher.combine(detailRevision)
        hasher.combine(homeRevision)
        hasher.combine(showsContinueBadge)
        let projectionToken = hasher.finalize()
        guard projectionToken != lastHomeProjectionToken else { return }
        lastHomeProjectionToken = projectionToken

        let newHomeState = CloudLibraryDataSource.homeState(
            index: index,
            productDetails: productDetails,
            showsContinueBadge: showsContinueBadge
        )
        if newHomeState != cachedHomeState {
            cachedHomeState = newHomeState
        }
        applyCachedHomeTileLookup(from: newHomeState)
    }

    private func applyCachedHomeTileLookup(from homeState: CloudLibraryHomeViewState) {
        var homeTilePairs: [(TitleID, CloudLibraryHomeScreen.TileLookupEntry)] = []
        homeTilePairs.reserveCapacity(
            homeState.sections.reduce(0) { $0 + $1.items.count }
        )
        for section in homeState.sections {
            for item in section.items {
                guard case .title(let titleItem) = item else { continue }
                homeTilePairs.append(
                    (
                        titleItem.tile.titleID,
                        CloudLibraryHomeScreen.TileLookupEntry(
                            sectionID: section.id,
                            tile: titleItem.tile,
                            titleID: titleItem.tile.titleID
                        )
                    )
                )
            }
        }
        let newHomeTileLookup = Dictionary(
            homeTilePairs,
            uniquingKeysWith: { current, _ in current }
        )
        if newHomeTileLookup != cachedHomeTileLookup {
            cachedHomeTileLookup = newHomeTileLookup
        }
    }
}