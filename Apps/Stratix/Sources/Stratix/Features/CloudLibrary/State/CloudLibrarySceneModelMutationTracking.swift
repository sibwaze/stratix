// CloudLibrarySceneModelMutationTracking.swift
// Defines cloud library scene model mutation tracking for the Features / CloudLibrary surface.
//

import StratixCore
import StratixModels

struct CloudLibrarySceneMutationState {
    var lastSceneMutationSignature: Int?
    var lastHydrationMarker: Date?
}

@MainActor
extension CloudLibrarySceneModel {
    func noteHydrationMarker(_ marker: Date?) {
        mutationState.lastHydrationMarker = marker
    }

    func isMajorLibraryRefresh(
        oldSections: [CloudLibrarySection],
        newSections: [CloudLibrarySection],
        currentHydratedAt: Date?
    ) -> Bool {
        guard !oldSections.isEmpty else {
            mutationState.lastHydrationMarker = currentHydratedAt
            return false
        }
        defer { mutationState.lastHydrationMarker = currentHydratedAt }
        if currentHydratedAt != mutationState.lastHydrationMarker {
            return true
        }

        let oldTitleIDs = CloudLibraryDataSource.allLibraryTitleIDs(from: oldSections)
        var matchedOldCount = 0
        var newOnlyCount = 0
        for titleID in CloudLibraryDataSource.allLibraryTitleIDs(from: newSections) {
            if oldTitleIDs.contains(titleID) {
                matchedOldCount += 1
            } else {
                newOnlyCount += 1
            }
        }
        let symmetricDifferenceCount = newOnlyCount + (oldTitleIDs.count - matchedOldCount)
        return symmetricDifferenceCount >= max(8, oldTitleIDs.count / 3)
    }

    func sceneMutationTaskID(
        libraryStateInputs: CloudLibraryStateSnapshot,
        queryState: LibraryQueryState,
        showsContinueBadge: Bool
    ) -> Int {
        sceneMutationSignature(
            catalogRevision: libraryStateInputs.catalogRevision,
            detailRevision: libraryStateInputs.detailRevision,
            homeRevision: libraryStateInputs.homeRevision,
            sceneContentRevision: libraryStateInputs.sceneContentRevision,
            queryState: queryState,
            showsContinueBadge: showsContinueBadge
        )
    }

    func applySceneMutation(
        libraryStateInputs: CloudLibraryStateSnapshot,
        queryState: LibraryQueryState,
        showsContinueBadge: Bool,
        viewModel: CloudLibraryViewModel
    ) {
        let signature = sceneMutationSignature(
            catalogRevision: libraryStateInputs.catalogRevision,
            detailRevision: libraryStateInputs.detailRevision,
            homeRevision: libraryStateInputs.homeRevision,
            sceneContentRevision: libraryStateInputs.sceneContentRevision,
            queryState: queryState,
            showsContinueBadge: showsContinueBadge
        )
        guard signature != mutationState.lastSceneMutationSignature else { return }
        mutationState.lastSceneMutationSignature = signature

        viewModel.applySceneMutation(
            inputs: CloudLibrarySceneInputs(
                library: libraryStateInputs,
                queryState: queryState,
                showsContinueBadge: showsContinueBadge
            )
        )
    }

    func sceneMutationSignature(
        catalogRevision: UInt64,
        detailRevision: UInt64,
        homeRevision: UInt64,
        sceneContentRevision: UInt64,
        queryState: LibraryQueryState,
        showsContinueBadge: Bool
    ) -> Int {
        var hasher = Hasher()
        hasher.combine(catalogRevision)
        hasher.combine(detailRevision)
        hasher.combine(homeRevision)
        hasher.combine(sceneContentRevision)
        hasher.combine(queryState.mutationToken(includingLibrarySearchActive: false))
        hasher.combine(showsContinueBadge)
        return hasher.finalize()
    }
}
