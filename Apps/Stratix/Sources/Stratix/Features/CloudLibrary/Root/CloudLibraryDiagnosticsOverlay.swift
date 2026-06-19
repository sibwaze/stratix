// CloudLibraryDiagnosticsOverlay.swift
// Defines cloud library diagnostics overlay for the CloudLibrary / Root surface.
//

import SwiftUI

struct CloudLibraryDiagnosticsOverlay: View {
    let browseRouteRawValue: String
    let homeLoadStateValue: String
    let routeRestoreStateValue: String
    let homeMerchandisingReady: Bool
    let homeMerchandisingStateValue: String

    var body: some View {
        Group {
            AccessibilityDiagnosticsMarker(
                identifier: "home_merchandising_state",
                value: homeMerchandisingStateValue
            )
            AccessibilityDiagnosticsMarker(
                identifier: "browse_route_state",
                value: browseRouteRawValue
            )
            AccessibilityDiagnosticsMarker(
                identifier: "home_load_state",
                value: homeLoadStateValue
            )
            AccessibilityDiagnosticsMarker(
                identifier: "route_restore_state",
                value: routeRestoreStateValue
            )
            if homeMerchandisingReady {
                AccessibilityDiagnosticsMarker(
                    identifier: "home_merchandising_ready",
                    value: "ready"
                )
            }
        }
    }
}

/// Hidden 1×1 accessibility marker used by shell UI tests and diagnostics overlays.
struct AccessibilityDiagnosticsMarker: View {
    let identifier: String
    let value: String

    var body: some View {
        Text(identifier)
            .font(.caption2)
            .foregroundStyle(.clear)
            .frame(width: 1, height: 1)
            .clipped()
            .allowsHitTesting(false)
            .accessibilityIdentifier(identifier)
            .accessibilityValue(value)
    }
}