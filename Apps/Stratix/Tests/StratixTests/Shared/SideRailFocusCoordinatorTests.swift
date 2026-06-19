// SideRailFocusCoordinatorTests.swift
// Exercises side rail focus coordinator behavior.
//

import XCTest

#if canImport(Stratix)
@testable import Stratix
#endif

final class SideRailFocusCoordinatorTests: XCTestCase {
    func testTrailingActions_doesNotInjectDefaultSettingsAction() {
        XCTAssertTrue(SideRailFocusCoordinator.trailingActions(from: []).isEmpty)
    }

    func testPreferredEntryTarget_alwaysFocusesLibraryNavItem() {
        XCTAssertEqual(
            SideRailFocusCoordinator.preferredEntryTarget(
                activeUtilityRoute: .settings,
                trailingActions: [.init(id: "settings", systemImage: "gearshape", accessibilityLabel: "Settings")],
                selectedNavID: .home
            ),
            .nav(.library)
        )
    }

    func testIsCollapsedFocusable_onlyAllowsSelectedNavWhenEnabled() {
        XCTAssertTrue(
            SideRailFocusCoordinator.isCollapsedFocusable(
                .nav(.library),
                selectedNavID: .library,
                collapsedSelectedNavFocusable: true
            )
        )
        XCTAssertFalse(
            SideRailFocusCoordinator.isCollapsedFocusable(
                .nav(.home),
                selectedNavID: .library,
                collapsedSelectedNavFocusable: true
            )
        )
    }
}
