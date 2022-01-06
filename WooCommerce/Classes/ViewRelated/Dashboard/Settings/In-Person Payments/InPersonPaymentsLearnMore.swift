import SwiftUI

struct InPersonPaymentsLearnMore: View {
    @Environment(\.customOpenURL) var customOpenURL

    var body: some View {
        HStack(spacing: 16) {
            Image(uiImage: .infoOutlineImage)
                .resizable()
                .foregroundColor(Color(.neutral(.shade60)))
                .frame(width: iconSize, height: iconSize)
            AttributedText(learnMoreAttributedString)
                .font(.footnote)
        }
            .padding(.vertical, Constants.verticalPadding)
            .onTapGesture {
                ServiceLocator.analytics.track(.cardPresentOnboardingLearnMoreTapped)
                customOpenURL?(Constants.learnMoreURL!)
            }
    }

    var iconSize: CGFloat {
        UIFontMetrics(forTextStyle: .subheadline).scaledValue(for: 20)
    }

    private var learnMoreAttributedString: NSAttributedString {
        return NSAttributedString.init(format: Localization.learnMoreText)
    }
}

private enum Constants {
    static let verticalPadding: CGFloat = 8
    static let learnMoreURL = URL(string: "https://woocommerce.com/payments")
}

private enum Localization {
    static let unavailable = NSLocalizedString(
        "In-Person Payments is currently unavailable",
        comment: "Title for the error screen when In-Person Payments is unavailable"
    )

    static let acceptCash = NSLocalizedString(
        "You can still accept in-person cash payments by enabling the “Cash on Delivery” payment method on your store.",
        comment: "Generic error message when In-Person Payments is unavailable"
    )

    static let learnMoreText = NSLocalizedString(
        "<a href=\"https://duckduckgo.com\">Learn more</a> about accepting payments with your mobile device and ordering card readers",
        comment: "A label prompting users to learn more about card readers with an embedded hyperlink"
    )
}

struct InPersonPaymentsLearnMore_Previews: PreviewProvider {
    static var previews: some View {
        InPersonPaymentsLearnMore()
            .padding()
    }
}
