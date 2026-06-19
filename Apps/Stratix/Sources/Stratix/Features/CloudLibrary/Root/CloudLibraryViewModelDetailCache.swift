// CloudLibraryViewModelDetailCache.swift
// Defines cloud library view model detail cache for the CloudLibrary / Root surface.
//

import Foundation
import StratixCore
import StratixModels

@MainActor
extension CloudLibraryViewModel {
    func prewarmDetailState(
        titleID: TitleID,
        snapshot: CloudLibraryDataSource.DetailStateSnapshot
    ) {
        let inputSignature = detailInputSignature(for: snapshot)
        if let entry = detailStateCache.peek(titleID),
           entry.inputSignature == inputSignature {
            detailStateCache.touch(titleID)
            detailHydrationInFlightTitleIDs.remove(titleID)
            return
        }

        let detailState = CloudLibraryDataSource.detailState(from: snapshot)
        detailStateCache.insert(state: detailState, for: titleID, inputSignature: inputSignature)
        detailHydrationInFlightTitleIDs.remove(titleID)
    }

    func detailInputSignature(for snapshot: CloudLibraryDataSource.DetailStateSnapshot) -> String {
        CloudLibraryDataSource.detailInputSignature(for: snapshot)
    }
}
