// CloudLibrarySettingsPaneTests.swift
// Exercises cloud library settings pane behavior.
//

import XCTest

#if canImport(Stratix)
@testable import Stratix
#endif

final class CloudLibrarySettingsPaneTests: XCTestCase {
    func testResolvedPane_restoresStoredVisiblePane() {
        XCTAssertEqual(
            CloudLibrarySettingsBindings.resolvedPane(
                currentPane: .stream,
                storedRawValue: CloudLibrarySettingsPane.diagnostics.rawValue,
                isAdvancedMode: true,
                restoreStoredSelection: true
            ),
            .diagnostics
        )
    }

    func testResolvedPane_fallsBackToStreamWhenStoredPaneIsHiddenInBasicMode() {
        XCTAssertEqual(
            CloudLibrarySettingsBindings.resolvedPane(
                currentPane: .diagnostics,
                storedRawValue: CloudLibrarySettingsPane.controller.rawValue,
                isAdvancedMode: false,
                restoreStoredSelection: true
            ),
            .stream
        )
    }

    func testFromStoredRawValue_migratesRetiredOverviewPane() {
        XCTAssertEqual(CloudLibrarySettingsPane.fromStoredRawValue("overview"), .stream)
    }
}
