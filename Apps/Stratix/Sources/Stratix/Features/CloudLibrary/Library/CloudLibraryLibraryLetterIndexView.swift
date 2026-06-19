// CloudLibraryLibraryLetterIndexView.swift
// Shows the active alphabetical index position while browsing the library grid.
//

import SwiftUI

struct CloudLibraryLibraryLetterIndexView<FocusValue: Hashable>: View {
    let sections: [String]
    var sectionIndexByLetter: [String: Int] = [:]
    let positionLetter: String?
    var focusedTarget: FocusState<FocusValue?>.Binding
    let letterFocusValue: (String) -> FocusValue
    let onSelectLetter: (String) -> Void
    var onMoveFromLetterIndex: ((MoveCommandDirection) -> Void)? = nil
    var isFocusEnabled: Bool = true
    var letterIndexEngaged: Bool = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        GeometryReader { proxy in
            let sectionCount = max(sections.count, 1)
            let slotHeight = proxy.size.height / CGFloat(sectionCount)
            let inactiveSize = min(max(slotHeight * 0.70, 15), 21)
            let activeSize = min(max(slotHeight * 0.88, 19), 30)

            VStack(spacing: 0) {
                ForEach(sections, id: \.self) { letter in
                    LetterIndexRow(
                        letter: letter,
                        isPositionMarker: letter == positionLetter,
                        showsRailFocus: showsRailFocus(for: letter),
                        slotHeight: slotHeight,
                        inactiveSize: inactiveSize,
                        activeSize: activeSize,
                        dynamicTypeSize: dynamicTypeSize,
                        onSelect: { onSelectLetter(letter) },
                        onMove: { direction in
                            handleMoveCommand(from: letter, direction: direction)
                        }
                    )
                    .focused(focusedTarget, equals: letterFocusValue(letter))
                    .focusable(isFocusEnabled)
                    .accessibilityLabel("Section \(letter)")
                    .accessibilityAddTraits(letter == positionLetter ? .isSelected : [])
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
        }
        .frame(width: StratixTheme.Library.letterIndexWidth)
        .padding(.vertical, StratixTheme.Library.letterIndexVerticalInset)
        .focusSection()
        .gamePassDisableSystemFocusEffect()
        .accessibilityIdentifier("library_letter_index")
    }

    private func showsRailFocus(for letter: String) -> Bool {
        letterIndexEngaged && focusedTarget.wrappedValue == letterFocusValue(letter)
    }

    private func handleMoveCommand(from letter: String, direction: MoveCommandDirection) {
        switch direction {
        case .up:
            moveLetterFocus(from: letter, offset: -1)
        case .down:
            moveLetterFocus(from: letter, offset: 1)
        case .left:
            onMoveFromLetterIndex?(.left)
        default:
            break
        }
    }

    private func moveLetterFocus(from letter: String, offset: Int) {
        guard let index = sectionIndexByLetter[letter] else { return }
        let nextIndex = index + offset
        guard sections.indices.contains(nextIndex) else { return }
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            focusedTarget.wrappedValue = letterFocusValue(sections[nextIndex])
        }
    }
}

private struct LetterIndexRow: View {
    let letter: String
    let isPositionMarker: Bool
    let showsRailFocus: Bool
    let slotHeight: CGFloat
    let inactiveSize: CGFloat
    let activeSize: CGFloat
    let dynamicTypeSize: DynamicTypeSize
    let onSelect: () -> Void
    var onMove: ((MoveCommandDirection) -> Void)?

    var body: some View {
        Button(action: onSelect) {
            Text(letter)
                .font(
                    StratixTypography.rounded(
                        isPositionMarker ? activeSize : inactiveSize,
                        weight: isPositionMarker ? .bold : .semibold,
                        dynamicTypeSize: dynamicTypeSize
                    )
                )
                .foregroundStyle(
                    isPositionMarker
                        ? StratixTheme.Colors.focusTint
                        : StratixTheme.Colors.textMuted.opacity(0.58)
                )
                .scaleEffect(isPositionMarker ? 1.10 : 1.0)
                .frame(maxWidth: .infinity, minHeight: slotHeight, maxHeight: slotHeight)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.white.opacity(showsRailFocus ? 0.10 : 0.0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(showsRailFocus ? 0.22 : 0.0), lineWidth: 1)
                )
        }
        .buttonStyle(CloudLibraryTVButtonStyle())
        .gamePassDisableSystemFocusEffect()
        .onMoveCommand { direction in
            onMove?(direction)
        }
    }
}

enum CloudLibraryLibraryLetterIndexSupport {
    static func indexLetter(for title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "#" }
        let letter = String(first).uppercased()
        return letter.first?.isLetter == true ? letter : "#"
    }

}