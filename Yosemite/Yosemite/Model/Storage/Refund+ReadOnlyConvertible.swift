import Foundation
import Storage


// MARK: - Storage.Refund: ReadOnlyConvertible
//
extension Storage.Refund: ReadOnlyConvertible {

    /// Updates the Storage.Refund with the ReadOnly.
    ///
    public func update(with fullRefund: Yosemite.Refund) {
        refundID = fullRefund.refundID
        orderID = fullRefund.orderID
        siteID = fullRefund.siteID
        dateCreated = fullRefund.dateCreated
        amount = fullRefund.amount
        reason = fullRefund.reason
        byUserID = fullRefund.refundedByUserID
        supportShippingRefunds = fullRefund.shippingLines != nil

        if let automated = fullRefund.isAutomated {
            isAutomated = automated
        }

        if let createRefund = fullRefund.createAutomated {
            createAutomated = createRefund
        }
    }

    /// Returns a ReadOnly version of the receiver.
    ///
    public func toReadOnly() -> Yosemite.Refund {
        let orderItems = items?.map { $0.toReadOnly() } ?? [Yosemite.OrderItemRefund]()

        // Assign nil if the refund does not support shipping information
        let readOnlyShippingLines: [ShippingLine]? = {
            guard supportShippingRefunds else {
                return nil
            }
            return shippingLines?.map { $0.toReadOnly() }
        }()

        return Refund(refundID: refundID,
                      orderID: orderID,
                      siteID: siteID,
                      dateCreated: dateCreated ?? Date(),
                      amount: amount ?? "",
                      reason: reason ?? "",
                      refundedByUserID: byUserID,
                      isAutomated: isAutomated,
                      createAutomated: createAutomated,
                      items: orderItems,
                      shippingLines: readOnlyShippingLines)
    }
}
