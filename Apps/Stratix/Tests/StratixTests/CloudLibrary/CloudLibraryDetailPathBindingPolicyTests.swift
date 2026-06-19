// CloudLibraryDetailPathBindingPolicyTests.swift
// Verifies detail navigation cannot pop while a stream session is active.
//

import XCTest
import StratixModels
@testable import Stratix

final class CloudLibraryDetailPathBindingPolicyTests: XCTestCase {
    func testResolvedPath_blocksPopWhileStreamPresentationActive() {
        let titleID = TitleID(rawValue: "forza-title")

        let resolved = CloudLibraryDetailPathBindingPolicy.resolvedPath(
            currentPath: [titleID],
            proposedPath: [],
            isStreamPresentationActive: true
        )

        XCTAssertEqual(resolved, [titleID])
    }

    func testResolvedPath_allowsPopWhenStreamPresentationInactive() {
        let titleID = TitleID(rawValue: "forza-title")

        let resolved = CloudLibraryDetailPathBindingPolicy.resolvedPath(
            currentPath: [titleID],
            proposedPath: [],
            isStreamPresentationActive: false
        )

        XCTAssertTrue(resolved.isEmpty)
    }
}