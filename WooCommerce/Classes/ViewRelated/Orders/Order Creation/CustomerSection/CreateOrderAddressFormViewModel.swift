import Combine
import Yosemite
import protocol Storage.StorageManagerType

final class CreateOrderAddressFormViewModel: AddressFormViewModel, AddressFormViewModelProtocol {

    struct NewOrderAddressData {
        let billingAddress: Address?
        let shippingAddress: Address?
    }

    /// Address update callback
    ///
    private let onAddressUpdate: ((NewOrderAddressData) -> Void)?

    init(siteID: Int64,
         addressData: NewOrderAddressData,
         onAddressUpdate: ((NewOrderAddressData) -> Void)?,
         storageManager: StorageManagerType = ServiceLocator.storageManager,
         stores: StoresManager = ServiceLocator.stores,
         analytics: Analytics = ServiceLocator.analytics) {
        self.onAddressUpdate = onAddressUpdate

        super.init(siteID: siteID,
                   address: addressData.billingAddress ?? .empty,
                   secondaryAddress: addressData.shippingAddress ?? .empty,
                   storageManager: storageManager,
                   stores: stores,
                   analytics: analytics)

        if addressData.billingAddress != addressData.shippingAddress {
            showDifferentAddressForm = true
        }
    }

    // MARK: - Protocol conformance

    var showEmailField: Bool {
        true
    }

    var viewTitle: String {
        Localization.newCustomerTitle
    }

    var sectionTitle: String {
        if showDifferentAddressForm {
            return Localization.billingAddressSection
        } else {
            return Localization.addressSection
        }
    }

    var secondarySectionTitle: String {
        Localization.shippingAddressSection
    }

    var showAlternativeUsageToggle: Bool {
        false
    }

    var alternativeUsageToggleTitle: String? {
        nil
    }

    var showDifferentAddressToggle: Bool {
        true
    }

    var differentAddressToggleTitle: String? {
        Localization.differentAddressToggleTitle
    }

    func saveAddress(onFinish: @escaping (Bool) -> Void) {
        if showDifferentAddressForm {
            onAddressUpdate?(.init(billingAddress: fields.toAddress(),
                                   shippingAddress: secondaryFields.toAddress()))
        } else {
            onAddressUpdate?(.init(billingAddress: fields.toAddress(),
                                   shippingAddress: fields.toAddress()))
        }
        onFinish(true)
    }

    override func trackOnLoad() { }

    func userDidCancelFlow() { }
}

private extension CreateOrderAddressFormViewModel {

    // MARK: Constants
    enum Localization {
        static let newCustomerTitle = NSLocalizedString("New Customer", comment: "Title for the Shipping Address Form for New Customer")

        static let shippingTitle = NSLocalizedString("Shipping Address", comment: "Title for the Edit Shipping Address Form")
        static let billingTitle = NSLocalizedString("Billing Address", comment: "Title for the Edit Billing Address Form")

        static let addressSection = NSLocalizedString("ADDRESS", comment: "Details section title in the Edit Address Form")

        static let shippingAddressSection = NSLocalizedString("SHIPPING ADDRESS", comment: "Details section title in the Edit Address Form")
        static let billingAddressSection = NSLocalizedString("BILLING ADDRESS", comment: "Details section title in the Edit Address Form")

        static let differentAddressToggleTitle = NSLocalizedString("Add a different shipping address",
                                                                   comment: "Title for the Add a Different Address switch in the Address form")
    }
}
