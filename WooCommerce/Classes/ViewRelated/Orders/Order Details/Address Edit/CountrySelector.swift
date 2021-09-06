import SwiftUI

/// Country Selector View
///
struct CountrySelector: View {

    /// View model to drive the view content
    ///
    @ObservedObject private(set) var viewModel: CountrySelectorViewModel

    var body: some View {
        VStack(spacing: 0) {
            SearchHeader(filterText: $viewModel.searchTerm)
                .background(Color(.listForeground))

            ListSelector(command: viewModel.command, tableStyle: .plain)
        }
        .navigationTitle(Localization.title)
    }
}

/// Search Header View
///
private struct SearchHeader: View {

    // Tracks the scale of the view due to accessibility changes
    @ScaledMetric private var scale: CGFloat = 1

    /// Filter search term
    ///
    @Binding var filterText: String

    var body: some View {
        HStack(spacing: 0) {
            // Search Icon
            Image(uiImage: .searchBarButtonItemImage)
                .renderingMode(.template)
                .resizable()
                .frame(width: Layout.iconSize.width * scale, height: Layout.iconSize.height * scale)
                .foregroundColor(Color(.listSmallIcon))
                .padding([.leading, .trailing], Layout.internalPadding)

            // TextField
            TextField(Localization.placeholder, text: $filterText)
                .padding([.bottom, .top], Layout.internalPadding)
        }
        .background(Color(.searchBarBackground))
        .cornerRadius(Layout.cornerRadius)
        .padding(Layout.externalPadding)
    }
}

// MARK: Constants

private extension CountrySelector {
    enum Localization {
        static let title = NSLocalizedString("Country", comment: "Title to select country from the edit address screen")
    }
}

private extension SearchHeader {
    enum Layout {
        static let iconSize = CGSize(width: 16, height: 16)
        static let internalPadding: CGFloat = 8
        static let cornerRadius: CGFloat = 10
        static let externalPadding = EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16)
    }

    enum Localization {
        static let placeholder = NSLocalizedString("Filter Countries", comment: "Placeholder on the search field to search for a specific country")
    }
}

struct CountrySelector_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CountrySelector(viewModel: CountrySelectorViewModel())
        }
    }
}