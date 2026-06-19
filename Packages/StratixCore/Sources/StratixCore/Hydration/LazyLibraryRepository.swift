// LazyLibraryRepository.swift
// Defers SwiftData ModelContainer creation until the first repository access.
//

import Foundation
import StratixModels

/// Wraps `SwiftDataLibraryRepository` so cold start can build the controller graph
/// without opening the on-disk SwiftData store until hydration actually needs it.
actor LazyLibraryRepository: LibraryRepository {
    private let storeURL: URL?
    private let isStoredInMemoryOnly: Bool
    private var resolved: SwiftDataLibraryRepository?

    init(
        storeURL: URL?,
        isStoredInMemoryOnly: Bool = false
    ) {
        self.storeURL = storeURL
        self.isStoredInMemoryOnly = isStoredInMemoryOnly
    }

    func loadCachedSections() async -> [CloudLibrarySection] {
        await resolvedRepository().loadCachedSections()
    }

    func saveSections(_ sections: [CloudLibrarySection]) async {
        await resolvedRepository().saveSections(sections)
    }

    func loadCachedHomeMerchandising() async -> HomeMerchandisingSnapshot? {
        await resolvedRepository().loadCachedHomeMerchandising()
    }

    func saveHomeMerchandising(_ snapshot: HomeMerchandisingSnapshot) async {
        await resolvedRepository().saveHomeMerchandising(snapshot)
    }

    func loadUnifiedSectionsSnapshot() async -> DecodedLibrarySectionsCacheSnapshot? {
        await resolvedRepository().loadUnifiedSectionsSnapshot()
    }

    func saveUnifiedSectionsSnapshot(_ snapshot: LibrarySectionsDiskCacheSnapshot) async {
        await resolvedRepository().saveUnifiedSectionsSnapshot(snapshot)
    }

    func flushUnifiedSectionsCache() async {
        await resolvedRepository().flushUnifiedSectionsCache()
    }

    func clearUnifiedSectionsCache() async {
        await resolvedRepository().clearUnifiedSectionsCache()
    }

    private func resolvedRepository() -> SwiftDataLibraryRepository {
        if let resolved {
            return resolved
        }

        do {
            let repository = try SwiftDataLibraryRepository(
                storeURL: storeURL,
                isStoredInMemoryOnly: isStoredInMemoryOnly
            )
            resolved = repository
            return repository
        } catch {
            fatalError("Failed to initialize library repository: \(error)")
        }
    }
}