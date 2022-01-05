import Foundation

/// Protocol for `CouponsRemote` mainly used for mocking.
///
/// The required methods are intentionally incomplete. Feel free to add the other ones.
///
public protocol CouponsRemoteProtocol {
    func loadAllCoupons(for siteID: Int64,
                        pageNumber: Int,
                        pageSize: Int,
                        completion: @escaping (Result<[Coupon], Error>) -> ())

    func deleteCoupon(for siteID: Int64,
                      couponID: Int64,
                      completion: @escaping (Result<Coupon, Error>) -> Void)

    func updateCoupon(_ coupon: Coupon, completion: @escaping (Result<Coupon, Error>) -> Void)

    func createCoupon(_ coupon: Coupon, completion: @escaping (Result<Coupon, Error>) -> Void)
}


/// Coupons: Remote endpoints
///
public final class CouponsRemote: Remote, CouponsRemoteProtocol {
    // MARK: - Get Coupons

    /// Retrieves all of the `Coupon`s from the API.
    ///
    /// - Parameters:
    ///     - siteID: The site for which we'll fetch coupons.
    ///     - pageNumber: The page number of the coupon list to be fetched.
    ///     - pageSize: The maximum number of coupons to be fetched for the current page.
    ///     - completion: Closure to be executed upon completion.
    ///
    public func loadAllCoupons(for siteID: Int64,
                               pageNumber: Int = Default.pageNumber,
                               pageSize: Int = Default.pageSize,
                               completion: @escaping (Result<[Coupon], Error>) -> ()) {
        let parameters = [
            ParameterKey.page: String(pageNumber),
            ParameterKey.perPage: String(pageSize)
        ]

        let request = JetpackRequest(wooApiVersion: .mark3,
                                     method: .get,
                                     siteID: siteID,
                                     path: Path.coupons,
                                     parameters: parameters)

        let mapper = CouponListMapper(siteID: siteID)

        enqueue(request, mapper: mapper, completion: completion)
    }

    // MARK: - Delete Coupon

    /// Delete a `Coupon`.
    ///
    /// - Parameters:
    ///     - siteID: Site for which we'll delete the product attribute.
    ///     - couponID: ID of the Coupon that will be deleted.
    ///     - completion: Closure to be executed upon completion.
    ///
    public func deleteCoupon(for siteID: Int64,
                             couponID: Int64,
                             completion: @escaping (Result<Coupon, Error>) -> Void) {
        let request = JetpackRequest(wooApiVersion: .mark3,
                                     method: .delete,
                                     siteID: siteID,
                                     path: Path.coupons + "/\(couponID)",
                                     parameters: [ParameterKey.force: true])

        let mapper = CouponMapper(siteID: siteID)

        enqueue(request, mapper: mapper, completion: completion)
    }

    // MARK: - Update Coupon

    /// Update a `Coupon`.
    ///
    /// - Parameters:
    ///     - coupon: The coupon to be updated remotely.
    ///     - completion: Closure to be executed upon completion.
    ///
    public func updateCoupon(_ coupon: Coupon, completion: @escaping (Result<Coupon, Error>) -> Void) {
        do {
            let parameters = try coupon.toDictionary()
            let couponID = coupon.couponID
            let siteID = coupon.siteID
            let path = Path.coupons + "/\(couponID)"
            let request = JetpackRequest(wooApiVersion: .mark3, method: .put, siteID: siteID, path: path, parameters: parameters)
            let mapper = CouponMapper(siteID: siteID)

            enqueue(request, mapper: mapper, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }

    // MARK: - Create coupon

    /// Create a `Coupon`.
    ///
    /// - Parameters:
    ///     - coupon: The coupon to be created remotely.
    ///     - completion: Closure to be executed upon completion.
    ///
    public func createCoupon(_ coupon: Coupon, completion: @escaping (Result<Coupon, Error>) -> Void) {
        do {
            let parameters = try coupon.toDictionary()
            let siteID = coupon.siteID
            let path = Path.coupons
            let request = JetpackRequest(wooApiVersion: .mark3, method: .post, siteID: siteID, path: path, parameters: parameters)
            let mapper = CouponMapper(siteID: siteID)

            enqueue(request, mapper: mapper, completion: completion)
        } catch {
            completion(.failure(error))
        }
    }
}

// MARK: - Constants
//
public extension CouponsRemote {
    enum Default {
        public static let pageSize = 25
        public static let pageNumber = 1
    }

    private enum Path {
        static let coupons = "coupons"
    }

    private enum ParameterKey {
        static let page = "page"
        static let perPage = "per_page"
        static let force = "force"
    }
}
