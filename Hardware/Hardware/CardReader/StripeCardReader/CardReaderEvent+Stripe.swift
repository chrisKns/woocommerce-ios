#if !targetEnvironment(macCatalyst)
import StripeTerminal

extension CardReaderEvent {
    /// Factory method
    /// - Parameter readerInputOptions: An instance of a StripeTerminal.ReaderInputOptions
    static func make(readerInputOptions: ReaderInputOptions) -> Self {
        .waitingForInput(Terminal.stringFromReaderInputOptions(readerInputOptions))
    }

    /// Factory method
    /// - Parameter readerInputOptions: An instance of a StripeTerminal.ReaderDisplayMessage
    static func make(displayMessage: ReaderDisplayMessage) -> Self {
        return .displayMessage(displayMessage.localizedMessage)
    }
}
#endif
