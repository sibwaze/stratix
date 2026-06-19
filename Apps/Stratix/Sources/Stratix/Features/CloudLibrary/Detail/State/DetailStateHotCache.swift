// DetailStateHotCache.swift
// Defines detail state hot cache for the CloudLibrary / Detail surface.
//

import StratixModels

struct DetailStateCacheEntry {
    var state: CloudLibraryTitleDetailViewState
    var inputSignature: String
    var accessToken: UInt64
}

struct DetailStateHotCache {
    private(set) var capacity: Int
    private var entries: [TitleID: DetailStateCacheEntry] = [:]
    private var accessCounter: UInt64 = 0

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    var keys: [TitleID] {
        Array(entries.keys)
    }

    var isEmpty: Bool {
        entries.isEmpty
    }

    func peek(_ titleID: TitleID) -> DetailStateCacheEntry? {
        entries[titleID]
    }

    mutating func touch(_ titleID: TitleID) {
        guard var entry = entries[titleID] else { return }
        accessCounter &+= 1
        entry.accessToken = accessCounter
        entries[titleID] = entry
    }

    mutating func insert(
        state: CloudLibraryTitleDetailViewState,
        for titleID: TitleID,
        inputSignature: String
    ) {
        accessCounter &+= 1
        entries[titleID] = DetailStateCacheEntry(
            state: state,
            inputSignature: inputSignature,
            accessToken: accessCounter
        )
        evictIfNeeded()
    }

    mutating func remove(_ titleID: TitleID) {
        entries.removeValue(forKey: titleID)
    }

    mutating func removeAll() {
        entries.removeAll(keepingCapacity: true)
    }

    mutating func prune(validTitleIDs: Set<TitleID>) {
        guard !entries.isEmpty else { return }
        entries = entries.filter { validTitleIDs.contains($0.key) }
    }

    mutating func invalidateChangedEntries(signature: (TitleID) -> String?) -> [TitleID] {
        guard !entries.isEmpty else { return [] }

        var invalidated: [TitleID] = []
        var staleKeys: [TitleID] = []
        invalidated.reserveCapacity(min(entries.count, 4))
        staleKeys.reserveCapacity(min(entries.count, 4))
        for (titleID, entry) in entries {
            if let current = signature(titleID),
               !current.isEmpty,
               current == entry.inputSignature {
                continue
            }
            invalidated.append(titleID)
            staleKeys.append(titleID)
        }
        for titleID in staleKeys {
            entries.removeValue(forKey: titleID)
        }
        return invalidated
    }

    private mutating func evictIfNeeded() {
        guard entries.count > capacity else { return }
        guard let evictionKey = entries.min(by: { $0.value.accessToken < $1.value.accessToken })?.key else {
            return
        }
        entries.removeValue(forKey: evictionKey)
    }
}
