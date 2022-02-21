import Foundation
import Yosemite
import protocol Storage.StorageManagerType

/// View Model logic for the Bulk Variations Update
final class BulkUpdateViewModel {

    /// Represents possible states for syncing product variations.
    enum SyncState: Equatable {
        case syncing
        case syncedResults
        case syncingError
        case notStarted
    }

    private let storageManager: StorageManagerType
    private let storesManager: StoresManager
    private let siteID: Int64
    private let productID: Int64

    /// The state of synching all variations
    private(set) var syncState: SyncState {
        didSet {
            observeSyncState?(syncState)
        }
    }

    /// Called when syncing state changes
    var observeSyncState: ((SyncState) -> Void)?

    init(siteID: Int64,
         productID: Int64,
         storageManager: StorageManagerType = ServiceLocator.storageManager,
         storesManager: StoresManager = ServiceLocator.stores) {
        self.siteID = siteID
        self.productID = productID
        self.storageManager = storageManager
        self.storesManager = storesManager
        syncState = .notStarted
    }

    /// This is the main activation method for this view model.
    ///
    /// This should only be called when the corresponding view was loaded.
    /// 
    func activate() {
        synchAllProductVariations()
    }

    /// Start synching all product variations.
    ///
    func synchAllProductVariations() {
        syncState = .syncing

        let numberOfObjects = Constants.numberOfObjects
        // There is a limitof 100 objects for bulk update API, so we fetch 101 so see if user has more that 100.
        let pageNumber = Constants.pageNumber
        let action = ProductVariationAction
            .synchronizeProductVariations(siteID: siteID, productID: productID, pageNumber: pageNumber, pageSize: numberOfObjects) { [weak self] error in
                guard let self = self else {
                    return
                }

                if let error = error {
                    self.syncState = .syncingError

                    DDLogError("⛔️ Error synchronizing product variations: \(error)")
                } else {
                    self.syncState = .syncedResults
                }
            }

        storesManager.dispatch(action)
    }
}

extension BulkUpdateViewModel {

    private enum Constants {

        /// The page to be syched
        static let pageNumber = 1

        /// The bulk update API limits the objects to be update to 100. 100 is also the page limit.
        static let numberOfObjects = 100
    }
}
