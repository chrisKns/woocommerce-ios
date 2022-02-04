import Foundation
import UIKit
import UserNotifications
import WordPressUI


/// NoticePresenter: Coordinates Notice rendering, in both, FG and BG execution modes.
///
class DefaultNoticePresenter: NoticePresenter {

    /// UIKit Feedback Gen!
    ///
    private let generator = UINotificationFeedbackGenerator()

    /// Notices Queue.
    ///
    private var notices = [Notice]()

    /// Notice currently onScreen
    ///
    private var noticeOnScreen: Notice?

    /// Dismiss the current onScreen notice
    ///
    private var dismissNoticeOnScreen: (() -> Void)?

    /// UIViewController to be used as Notice(s) Presenter
    ///
    weak var presentingViewController: UIViewController?

    /// Observes keyboard and repositions Notice
    ///
    private var keyboardFrameObserver: KeyboardFrameObserver?

    /// Enqueues the specified Notice for display.
    ///
    func enqueue(notice: Notice) {
        guard
            noticeOnScreen != notice, // Ignore if we are already presenting this notice.
            !notices.contains(notice) // Ignore if this notice is already enqueued and waiting for presentation.
        else {
            return
        }
        notices.append(notice)
        presentNextNoticeIfPossible()
    }

    /// It dismisses the provided `Notice` if it is currenly presented in the foreground, or removes it from the queue
    ///
    func cancel(notice: Notice) {
        notices.removeAll(where: { $0 == notice })
        if notice == noticeOnScreen {
            dismissNoticeOnScreen?()
        }
    }
}


// MARK: - Private Methods
//
private extension DefaultNoticePresenter {

    func presentNextNoticeIfPossible() {
        guard noticeOnScreen == nil, let next = notices.popFirst() else {
            return
        }

        present(next)
        noticeOnScreen = next
    }

    func present(_ notice: Notice) {
        if shouldPresentInForeground(notice) {
            presentNoticeInForeground(notice)
            return
        }

        UNUserNotificationCenter.current().loadAuthorizationStatus { status in
            switch status {
            case .authorized:
                self.presentNoticeInBackground(notice)
            default:
                self.presentNoticeInForeground(notice)
            }
        }
    }

    func shouldPresentInForeground(_ notice: Notice) -> Bool {
        return UIApplication.shared.applicationState != .background || notice.notificationInfo == nil
    }

    func presentNoticeInBackground(_ notice: Notice) {
        guard let notificationInfo = notice.notificationInfo else {
            return
        }

        let content = UNMutableNotificationContent(notice: notice)
        let request = UNNotificationRequest(identifier: notificationInfo.identifier, content: content, trigger: nil)

        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                self.dismiss()
            }
        }
    }

    func presentNoticeInForeground(_ notice: Notice) {
        guard let view = presentingViewController?.view else {
            return
        }

        generator.prepare()

        let noticeView = NoticeView(notice: notice)
        noticeView.translatesAutoresizingMaskIntoConstraints = false

        let noticeContainerView = NoticeContainerView(noticeView: noticeView)

        var onScreenBottomOffsetAdjustedForKeyboard: CGFloat = 0
        keyboardFrameObserver = KeyboardFrameObserver { [weak self] keyboardFrame in
            guard let self = self else { return }

            onScreenBottomOffsetAdjustedForKeyboard = -keyboardFrame.height

            // Subtract the tab bar height from keyboard height, if keyboard is visible
            // to avoid having extra gap between keyboard and notice, when `offscreenBottomOffset` has a positive value
            //
            if keyboardFrame.height > 0 {
                onScreenBottomOffsetAdjustedForKeyboard -= self.offscreenBottomOffset
            }

            // Adjust the bottom constraint ONLY if the noticeContainerView is already presented.
            // If noticeContainerView is not already presented, it will be presented using onScreenBottomOffsetAdjustedForKeyboard.
            //
            if noticeContainerView.superview != nil {
                noticeContainerView.noticeBottomConstraint.constant = onScreenBottomOffsetAdjustedForKeyboard
                self.animatePresentation(toState: {
                    noticeContainerView.layoutIfNeeded()
                })
            }
        }
        keyboardFrameObserver?.startObservingKeyboardFrame(sendInitialEvent: true)

        addNoticeContainerToPresentingViewController(noticeContainerView)

        NSLayoutConstraint.activate([
            noticeContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            noticeContainerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            makeBottomConstraintForNoticeContainer(noticeContainerView)
        ])

        let offScreenState = { [weak noticeView, weak self] in
            guard let noticeView = noticeView, let self = self else {
                return
            }
            noticeView.alpha = UIKitConstants.alphaZero
            noticeContainerView.noticeBottomConstraint.constant = self.offscreenBottomOffset

            noticeContainerView.layoutIfNeeded()
        }

        let onScreenState = {
            noticeView.alpha = UIKitConstants.alphaFull
            noticeContainerView.noticeBottomConstraint.constant = onScreenBottomOffsetAdjustedForKeyboard

            noticeContainerView.layoutIfNeeded()
        }

        let hiddenState = { [weak noticeView] in
            guard let noticeView = noticeView else {
                return
            }
            noticeView.alpha = UIKitConstants.alphaZero
        }

        let dismiss = { [weak noticeContainerView] in
            guard let noticeContainerView = noticeContainerView, noticeContainerView.superview != nil, notice == self.noticeOnScreen else {
                return
            }

            self.animatePresentation(fromState: {}, toState: hiddenState, completion: {
                noticeContainerView.removeFromSuperview()
                self.dismiss()
            })
        }

        dismissNoticeOnScreen = dismiss
        noticeView.dismissHandler = dismiss

        if let feedbackType = notice.feedbackType {
            generator.notificationOccurred(feedbackType)
        }

        animatePresentation(fromState: offScreenState, toState: onScreenState, completion: {
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Animations.dismissDelay) { [weak self] in
                self?.dismissNoticeOnScreen?()
            }
        })
    }

    func dismiss() {
        dismissNoticeOnScreen = nil
        noticeOnScreen = nil
        keyboardFrameObserver = nil
        presentNextNoticeIfPossible()
    }

    func addNoticeContainerToPresentingViewController(_ noticeContainer: UIView) {
        if let tabBarController = presentingViewController as? UITabBarController {
            tabBarController.view.insertSubview(noticeContainer, belowSubview: tabBarController.tabBar)
        } else {
            presentingViewController?.view.addSubview(noticeContainer)
        }
    }

    func makeBottomConstraintForNoticeContainer(_ container: UIView) -> NSLayoutConstraint {
        guard let presentingViewController = presentingViewController else {
            fatalError("NoticePresenter requires a presentingViewController!")
        }

        if let tabBarController = presentingViewController as? UITabBarController {
            return container.bottomAnchor.constraint(equalTo: tabBarController.tabBar.topAnchor)
        }

        return container.bottomAnchor.constraint(equalTo: presentingViewController.view.bottomAnchor)
    }

    var offscreenBottomOffset: CGFloat {
        if let tabBarController = presentingViewController as? UITabBarController {
            return tabBarController.tabBar.bounds.height
        }

        return 0
    }

    func animatePresentation(fromState: (() -> Void)? = nil,
                             toState: @escaping () -> Void,
                             completion: (() -> Void)? = nil) {
        fromState?()

        UIView.animate(withDuration: Animations.appearanceDuration,
                       delay: 0,
                       usingSpringWithDamping: Animations.appearanceSpringDamping,
                       initialSpringVelocity: Animations.appearanceSpringVelocity,
                       options: [],
                       animations: toState,
                       completion: { _ in
                        completion?()
        })
    }

    private enum Animations {
        static let appearanceDuration: TimeInterval = 1.0
        static let appearanceSpringDamping: CGFloat = 0.7
        static let appearanceSpringVelocity: CGFloat = 0.0
        static let dismissDelay: TimeInterval = 5.0
    }
}


// MARK: - NoticeContainerView: Small wrapper view that ensures a notice remains centered and at a maximum width when
//         displayed in a regular size class.
//
private class NoticeContainerView: UIView {

    let containerMargin: CGFloat = 16.0

    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = 0
        return stackView
    }()

    private(set) lazy var noticeBottomConstraint: NSLayoutConstraint = {
        return stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
    }()

    let noticeView: NoticeView


    /// Designated Initializer
    ///
    init(noticeView: NoticeView) {
        self.noticeView = noticeView

        super.init(frame: .zero)

        /// Padding Setup: Padding views on either side, of equal width to ensure centering
        ///
        let leftPaddingView = UIView()
        let rightPaddingView = UIView()
        rightPaddingView.translatesAutoresizingMaskIntoConstraints = false
        leftPaddingView.translatesAutoresizingMaskIntoConstraints = false

        /// StackView Setup
        ///
        stackView.addArrangedSubview(leftPaddingView)
        stackView.addArrangedSubview(noticeView)
        stackView.addArrangedSubview(rightPaddingView)

        contentView.addSubview(stackView)

        /// NoticeContainer Setup
        ///
        translatesAutoresizingMaskIntoConstraints = false
        layoutMargins = UIEdgeInsets(top: containerMargin, left: containerMargin, bottom: containerMargin, right: containerMargin)
        addSubview(contentView)

        /// LayoutContraints: ContentView
        ///
        NSLayoutConstraint.activate([
            contentView.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            contentView.topAnchor.constraint(equalTo: layoutMarginsGuide.topAnchor),
            contentView.bottomAnchor.constraint(equalTo: layoutMarginsGuide.bottomAnchor)
        ])

        /// LayoutContraints: StackView
        ///
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor),
            noticeBottomConstraint
        ])

        /// LayoutContraints: Padding
        ///
        let paddingWidthConstraint = leftPaddingView.widthAnchor.constraint(equalToConstant: 0)
        paddingWidthConstraint.priority = .defaultLow

        NSLayoutConstraint.activate([
            paddingWidthConstraint,
            leftPaddingView.widthAnchor.constraint(equalTo: rightPaddingView.widthAnchor)
        ])
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private lazy var noticeWidthConstraint: NSLayoutConstraint = {
        // At regular width, the notice shouldn't be any wider than 1/2 the app's width
        return noticeView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.5)
    }()

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        let isRegularWidth = traitCollection.containsTraits(in: UITraitCollection(horizontalSizeClass: .regular))
        noticeWidthConstraint.isActive = isRegularWidth

        layoutIfNeeded()
    }
}


// MARK: - UNMutableNotificationContent Notice Methods
//
private extension UNMutableNotificationContent {
    convenience init(notice: Notice) {
        self.init()

        title = notice.notificationInfo?.title ?? notice.title

        if let body = notice.notificationInfo?.body {
            self.body = body
        } else if let message = notice.message {
            subtitle = message
        }

        if let categoryIdentifier = notice.notificationInfo?.categoryIdentifier {
            self.categoryIdentifier = categoryIdentifier
        }

        if let userInfo = notice.notificationInfo?.userInfo {
            self.userInfo = userInfo
        }

        sound = .default
    }
}
