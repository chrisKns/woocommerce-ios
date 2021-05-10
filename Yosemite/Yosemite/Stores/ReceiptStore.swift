import Storage
import Networking
import Hardware


// MARK: - ReceiptStore
//
public class ReceiptStore: Store {
    private let receiptPrinterService: PrinterService

    private lazy var sharedDerivedStorage: StorageType = {
        return storageManager.writerDerivedStorage
    }()

    public init(dispatcher: Dispatcher, storageManager: StorageManagerType, network: Network, receiptPrinterService: PrinterService) {
        self.receiptPrinterService = receiptPrinterService
        super.init(dispatcher: dispatcher, storageManager: storageManager, network: network)
    }

    /// Registers for supported Actions.
    ///
    override public func registerSupportedActions(in dispatcher: Dispatcher) {
        dispatcher.register(processor: self, for: ReceiptAction.self)
    }

    /// Receives and executes Actions.
    ///
    override public func onAction(_ action: Action) {
        guard let action = action as? ReceiptAction else {
            assertionFailure("ReceiptStore received an unsupported action")
            return
        }

        switch action {
        case .print(let order, let info):
            print(order: order, parameters: info)
        case .generateContent(let order, let info, let onContent):
            generateContent(order: order, parameters: info, onContent: onContent)
        }
    }
}


private extension ReceiptStore {
    func print(order: Order, parameters: CardPresentReceiptParameters) {
        let lineItems = order.items.map { ReceiptLineItem(title: $0.name, amount: $0.price.stringValue)}

        let content = ReceiptContent(parameters: parameters, lineItems: lineItems)
        receiptPrinterService.printReceipt(content: content)
    }

    func generateContent(order: Order, parameters: CardPresentReceiptParameters, onContent: @escaping (String) -> Void) {
        let lineItems = order.items.map { ReceiptLineItem(title: $0.name, amount: $0.price.stringValue)}

        let content = ReceiptContent(parameters: parameters, lineItems: lineItems)
        let renderer = ReceiptRenderer(content: content)
        onContent(renderer.htmlContent())
    }
}