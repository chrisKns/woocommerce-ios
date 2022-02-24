import SwiftUI

/// View to add/edit a single fee line in an order, with the option to remove it.
///
struct FeeLineDetails: View {

    /// View model to drive the view content
    ///
    @ObservedObject private var viewModel: FeeLineDetailsViewModel

    /// Defines if the amount input text field should be focused. Defaults to `true`
    ///
    @State private var focusAmountInput: Bool = true

    @Environment(\.presentationMode) var presentation

    @Environment(\.safeAreaInsets) var safeAreaInsets: EdgeInsets

    init(viewModel: FeeLineDetailsViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: .zero) {
                    Section {
                        Picker("", selection: $viewModel.feeType) {
                            Text(viewModel.percentSymbol).tag(FeeLineDetailsViewModel.FeeType.percentage)
                            Text(viewModel.storeCurrencySymbol).tag(FeeLineDetailsViewModel.FeeType.fixed)
                        }
                        .pickerStyle(.segmented)
                        .padding()

                        ZStack(alignment: .center) {
                            // Hidden input text field
                            BindableTextfield("", text: $viewModel.amount, focus: $focusAmountInput)
                                .keyboardType(.decimalPad)
                                .opacity(0)

                            // Visible & formatted field
                            switch viewModel.feeType {
                            case .fixed:
                                inputFixedField
                            case .percentage:
                                inputPercentageField
                            }
                        }
                        .background(Color(.listForeground))
                        .fixedSize(horizontal: false, vertical: true)
                        .onTapGesture {
                            focusAmountInput = true
                        }
                        .padding(.horizontal, insets: safeAreaInsets)
                    }
                    .background(Color(.listForeground))
                    .addingTopAndBottomDividers()

                    Spacer(minLength: Layout.sectionSpacing)

                    if viewModel.isExistingFeeLine {
                        Section {
                            Button(Localization.remove) {
                                viewModel.didSelectSave(nil)
                                presentation.wrappedValue.dismiss()
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .foregroundColor(Color(.error))
                            .padding(.horizontal, insets: safeAreaInsets)
                            .addingTopAndBottomDividers()
                        }
                        .background(Color(.listForeground))
                    }
                }
            }
            .background(Color(.listBackground))
            .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
            .navigationTitle(viewModel.isExistingFeeLine ? Localization.fee : Localization.addFee)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Localization.close) {
                        presentation.wrappedValue.dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(Localization.done) {
                        viewModel.saveData()
                        presentation.wrappedValue.dismiss()
                    }
                    .disabled(viewModel.shouldDisableDoneButton)
                }
            }
        }
        .wooNavigationBarStyle()
    }

    private var inputFixedField: some View {
        TitleAndTextFieldRow(title: String.localizedStringWithFormat(Localization.amountField, viewModel.storeCurrencySymbol),
                             placeholder: "",
                             text: .constant(viewModel.formattedAmount),
                             symbol: nil,
                             keyboardType: .decimalPad)
            .foregroundColor(Color(viewModel.amountTextColor))
            .disabled(true)
    }

    private var inputPercentageField: some View {
        TitleAndTextFieldRow(title: String.localizedStringWithFormat(Localization.amountField, viewModel.percentSymbol),
                             placeholder: "0",
                             text: .constant(viewModel.amount),
                             symbol: nil,
                             keyboardType: .decimalPad)
            .foregroundColor(Color(viewModel.amountTextColor))
            .disabled(true)
    }
}

// MARK: Constants
private extension FeeLineDetails {
    enum Layout {
        static let sectionSpacing: CGFloat = 16.0
        static let dividerPadding: CGFloat = 16.0
    }

    enum Localization {
        static let addFee = NSLocalizedString("Add Fee", comment: "Title for the Fee screen during order creation")
        static let fee = NSLocalizedString("Fee", comment: "Title for the Fee Details screen during order creation")

        static let amountField = NSLocalizedString("Amount (%1$@)", comment: "Title for the amount field on the Fee Details screen during order creation"
                                                   + "Parameters: %1$@ - fee type (percent sign or currency symbol)")

        static let close = NSLocalizedString("Close", comment: "Text for the close button in the Fee Details screen")
        static let done = NSLocalizedString("Done", comment: "Text for the done button in the Fee Details screen")
        static let remove = NSLocalizedString("Remove Fee from Order",
                                              comment: "Text for the button to remove a fee from the order during order creation")
    }
}

struct FeeLineDetails_Previews: PreviewProvider {
    static var previews: some View {
        let viewModel = NewOrderViewModel.PaymentDataViewModel(shouldShowFees: true,
                                                               feesBaseAmountForPercentage: 200,
                                                               feesTotal: "10")
        FeeLineDetails(viewModel: .init(inputData: viewModel, didSelectSave: { _ in }))
    }
}