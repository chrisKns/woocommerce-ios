import SwiftUI

/// View showing a list of products to add to an order.
///
struct AddProduct: View {
    /// Defines whether the view is presented.
    ///
    @Binding var isPresented: Bool

    var body: some View {
        NavigationView {
            ScrollView {
                // TODO: Make the product list searchable
                LazyVStack {
                    // TODO: Add a product row for each non-variable product in the store
                    let viewModel = ProductRowViewModel(id: 1,
                                                        name: "Love Ficus",
                                                        sku: "123456",
                                                        price: "20",
                                                        stockStatusKey: "instock",
                                                        stockQuantity: 7,
                                                        manageStock: true,
                                                        canChangeQuantity: false) // Temporary view model with fake data
                    ProductRow(viewModel: viewModel)
                }
                .padding()
            }
            .navigationTitle(Localization.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(Localization.close) {
                        isPresented.toggle()
                    }
                }
            }
        }
        .wooNavigationBarStyle()
    }
}

private extension AddProduct {
    enum Localization {
        static let title = NSLocalizedString("Add Product", comment: "Title for the screen to add a product to an order")
        static let close = NSLocalizedString("Close", comment: "Text for the close button in the Add Product screen")
    }
}

struct AddProduct_Previews: PreviewProvider {
    static var previews: some View {
        AddProduct(isPresented: .constant(true))
    }
}
