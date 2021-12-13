import UIKit
import Yosemite
import Charts
import XLPagerTabStrip
import WordPressUI
import class AutomatticTracks.CrashLogging


final class TopPerformerDataViewController: UIViewController {

    // MARK: - Properties

    private let timeRange: StatsTimeRangeV4
    private let granularity: StatGranularity
    private let siteID: Int64
    private let siteTimeZone: TimeZone
    private let currentDate: Date

    var hasTopEarnerStatsItems: Bool {
        return (topEarnerStats?.items?.count ?? 0) > 0
    }

    @IBOutlet private weak var tableView: IntrinsicTableView!

    /// A child view controller that is shown when `displayGhostContent()` is called.
    ///
    private lazy var ghostTableViewController = GhostTableViewController()

    /// ResultsController: Loads TopEarnerStats for the current granularity from the Storage Layer
    ///
    private lazy var resultsController: ResultsController<StorageTopEarnerStats> = {
        let storageManager = ServiceLocator.storageManager
        let formattedDateString: String = {
            let date = timeRange.latestDate(currentDate: currentDate, siteTimezone: siteTimeZone)
            return StatsStoreV4.buildDateString(from: date, with: granularity)
        }()
        let predicate = NSPredicate(format: "granularity = %@ AND date = %@ AND siteID = %ld", granularity.rawValue, formattedDateString, siteID)
        let descriptor = NSSortDescriptor(key: "date", ascending: true)

        return ResultsController<StorageTopEarnerStats>(storageManager: storageManager, matching: predicate, sortedBy: [descriptor])
    }()

    private var isInitialLoad: Bool = true  // Used in trackChangedTabIfNeeded()

    private let imageService: ImageService = ServiceLocator.imageService

    // MARK: - Computed Properties

    private var topEarnerStats: TopEarnerStats? {
        return resultsController.fetchedObjects.first
    }

    private var tabDescription: String {
        switch granularity {
        case .day:
            return NSLocalizedString("Today", comment: "Top Performers section title - today")
        case .week:
            return NSLocalizedString("This Week", comment: "Top Performers section title - this week")
        case .month:
            return NSLocalizedString("This Month", comment: "Top Performers section title - this month")
        case .year:
            return NSLocalizedString("This Year", comment: "Top Performers section title - this year")
        }
    }

    // MARK: - Initialization

    /// Designated Initializer
    ///
    init(siteID: Int64, siteTimeZone: TimeZone, currentDate: Date, timeRange: StatsTimeRangeV4) {
        self.siteID = siteID
        self.siteTimeZone = siteTimeZone
        self.currentDate = currentDate
        self.granularity = timeRange.topEarnerStatsGranularity
        self.timeRange = timeRange
        super.init(nibName: type(of: self).nibName, bundle: nil)
    }

    /// NSCoder Conformance
    ///
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    // MARK: - View Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureTableView()
        configureResultsController()
        registerTableViewCells()
        registerTableViewHeaderFooters()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        trackChangedTabIfNeeded()
    }
}


// MARK: - Public Interface
//
extension TopPerformerDataViewController {

    /// Renders Placeholder Content.
    ///
    /// Why is this public? Because the `syncTopPerformers` method is actually called from TopPerformersViewController.
    /// We coordinate multiple placeholder animations from that spot!
    ///
    func displayGhostContent() {
        guard let ghostView = ghostTableViewController.view else {
            return
        }

        ghostView.translatesAutoresizingMaskIntoConstraints = false
        addChild(ghostTableViewController)
        view.addSubview(ghostView)
        view.pinSubviewToAllEdges(ghostView)
        ghostTableViewController.didMove(toParent: self)
    }

    /// Removes the Placeholder Content.
    ///
    /// Why is this public? Because the `syncTopPerformers` method is actually called from TopPerformersViewController.
    /// We coordinate multiple placeholder animations from that spot!
    ///
    func removeGhostContent() {
        guard let ghostView = ghostTableViewController.view else {
            return
        }

        ghostTableViewController.willMove(toParent: nil)
        ghostView.removeFromSuperview()
        ghostTableViewController.removeFromParent()
    }
}


// MARK: - Configuration
//
private extension TopPerformerDataViewController {

    func configureView() {
        view.backgroundColor = .basicBackground
    }

    func configureTableView() {
        tableView.backgroundColor = TableViewStyle.backgroundColor
        tableView.separatorColor = TableViewStyle.separatorColor
        tableView.estimatedRowHeight = Constants.estimatedRowHeight
        tableView.rowHeight = UITableView.automaticDimension
        tableView.applyFooterViewForHidingExtraRowPlaceholders()
    }

    func configureResultsController() {
        resultsController.onDidChangeContent = { [weak self] in
            self?.tableView.reloadData()
        }
        resultsController.onDidResetContent = { [weak self] in
            self?.tableView.reloadData()
        }

        do {
            try resultsController.performFetch()
        } catch {
            ServiceLocator.crashLogging.logError(error)
        }
    }

    func registerTableViewCells() {
        tableView.registerNib(for: ProductTableViewCell.self)
        tableView.registerNib(for: NoPeriodDataTableViewCell.self)
    }

    func registerTableViewHeaderFooters() {
        let headersAndFooters = [TopPerformersHeaderView.self]

        for kind in headersAndFooters {
            tableView.register(kind.loadNib(), forHeaderFooterViewReuseIdentifier: kind.reuseIdentifier)
        }
    }
}


// MARK: - IndicatorInfoProvider Conformance (Tab Bar)
//
extension TopPerformerDataViewController: IndicatorInfoProvider {
    func indicatorInfo(for pagerTabStripController: PagerTabStripViewController) -> IndicatorInfo {
        return IndicatorInfo(title: tabDescription)
    }
}


// MARK: - UITableViewDataSource Conformance
//
extension TopPerformerDataViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return Constants.numberOfSections
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfRows()
    }

    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let cell = tableView.dequeueReusableHeaderFooterView(withIdentifier: TopPerformersHeaderView.reuseIdentifier) as? TopPerformersHeaderView else {
            fatalError()
        }

        cell.configure(descriptionText: Text.sectionDescription,
                       leftText: Text.sectionLeftColumn.uppercased(),
                       rightText: Text.sectionRightColumn.uppercased())
        return cell
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let statsItem = statsItem(at: indexPath) else {
            return tableView.dequeueReusableCell(withIdentifier: NoPeriodDataTableViewCell.reuseIdentifier, for: indexPath)
        }
        let cell = tableView.dequeueReusableCell(ProductTableViewCell.self, for: indexPath)

        cell.configure(statsItem, imageService: imageService)
        cell.hidesBottomBorder = tableView.lastIndexPathOfTheLastSection() == indexPath ? true : false
        return cell
    }
}


// MARK: - UITableViewDelegate Conformance
//
extension TopPerformerDataViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let statsItem = statsItem(at: indexPath) else {
            return
        }
        presentProductDetails(statsItem: statsItem)
    }

    func tableView(_ tableView: UITableView, estimatedHeightForHeaderInSection section: Int) -> CGFloat {
        return Constants.estimatedSectionHeight
    }

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
}

// MARK: Navigation Actions
//

private extension TopPerformerDataViewController {

    /// Presents the product details for a given TopEarnerStatsItem.
    ///
    func presentProductDetails(statsItem: TopEarnerStatsItem) {
        let loaderViewController = ProductLoaderViewController(model: .init(topEarnerStatsItem: statsItem),
                                                               siteID: siteID,
                                                               forceReadOnly: false)
        let navController = WooNavigationController(rootViewController: loaderViewController)
        present(navController, animated: true, completion: nil)
    }
}

// MARK: - Private Helpers
//
private extension TopPerformerDataViewController {

    func trackChangedTabIfNeeded() {
        // This is a little bit of a workaround to prevent the "tab tapped" tracks event from firing when launching the app.
        if granularity == .day && isInitialLoad {
            isInitialLoad = false
            return
        }
        ServiceLocator.analytics.track(.dashboardTopPerformersDate, withProperties: ["range": granularity.rawValue])
        isInitialLoad = false
    }

    func statsItem(at indexPath: IndexPath) -> TopEarnerStatsItem? {
        guard let topEarnerStatsItem = topEarnerStats?.items?.sorted(by: >)[safe: indexPath.row] else {
            return nil
        }

        return topEarnerStatsItem
    }

    func numberOfRows() -> Int {
        guard hasTopEarnerStatsItems, let itemCount = topEarnerStats?.items?.count else {
            return Constants.emptyStateRowCount
        }
        return itemCount
    }
}

// MARK: - Ghost View

private extension TopPerformerDataViewController {
    final class GhostTableViewController: UITableViewController {

        init() {
            super.init(style: .plain)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func viewDidLoad() {
            super.viewDidLoad()

            // Make sure that Ghost will not have any dataSource or delegate to _swap_. This is
            // just to reduce the chance of having ”invalid number of rows” crashes because of
            // delegate swapping.
            tableView.dataSource = nil
            tableView.delegate = nil

            tableView.backgroundColor = TableViewStyle.backgroundColor
            tableView.separatorStyle = .none
            tableView.estimatedRowHeight = Constants.estimatedRowHeight
            tableView.applyFooterViewForHidingExtraRowPlaceholders()
            tableView.registerNib(for: ProductTableViewCell.self)
        }

        /// Activate the ghost if this view is added to the parent.
        ///
        override func viewWillAppear(_ animated: Bool) {
            super.viewWillAppear(animated)

            let options = GhostOptions(displaysSectionHeader: false,
                                       reuseIdentifier: ProductTableViewCell.reuseIdentifier,
                                       rowsPerSection: Constants.placeholderRowsPerSection)
            tableView.displayGhostContent(options: options,
                                          style: .wooDefaultGhostStyle)
        }

        /// Deactivate the ghost if this view is removed from the parent.
        ///
        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            tableView.removeGhostContent()
        }
    }
}

// MARK: - Constants!
//
private extension TopPerformerDataViewController {
    enum Text {
        static let sectionDescription = NSLocalizedString("Gain insights into how products are performing on your store",
                                                          comment: "Description for Top Performers section of My Store tab.")
        static let sectionLeftColumn = NSLocalizedString("Product", comment: "Description for Top Performers left column header")
        static let sectionRightColumn = NSLocalizedString("Total Spend", comment: "Description for Top Performers right column header")
    }

    enum TableViewStyle {
        static let backgroundColor = UIColor.basicBackground
        static let separatorColor = UIColor.systemColor(.separator)
    }

    enum Constants {
        static let estimatedRowHeight           = CGFloat(80)
        static let estimatedSectionHeight       = CGFloat(125)
        static let numberOfSections             = 1
        static let emptyStateRowCount           = 1
        static let placeholderRowsPerSection    = [3]
    }
}
