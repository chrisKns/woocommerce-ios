import ScreenObject
import XCTest

public final class PrologueScreen: ScreenObject {

    public init(app: XCUIApplication = XCUIApplication()) throws {
        try super.init(
            expectedElementGetter: { $0.buttons[ElementStringIDs.continueButton] },
            app: app,
            waitTimeout: 7
        )
    }

    public func selectContinueWithWordPress() -> GetStartedScreen {
        app.buttons["Prologue Continue Button"].tap()

        return GetStartedScreen()
    }

    public func selectSiteAddress() -> LoginSiteAddressScreen {
        app.buttons["Prologue Self Hosted Button"].tap()

        return LoginSiteAddressScreen()
    }
}
