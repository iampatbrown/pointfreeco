import Database
import DatabaseTestSupport
import Dependencies
import Either
import GitHub
import HttpPipeline
import Models
import ModelsTestSupport
import PointFreePrelude
import PointFreeTestSupport
import Prelude
import SnapshotTesting
import Stripe
import StripeTestSupport
import XCTest

@testable import PointFree

#if !os(Linux)
  import WebKit
#endif

@MainActor
final class AccountIntegrationTests: LiveDatabaseTestCase {
  @Dependency(\.database) var database

  func testLeaveTeam() async throws {
    let currentUser = try await self.database.registerUser(
      withGitHubEnvelope: .init(
        accessToken: .init(accessToken: "deadbeef-currentUser"),
        gitHubUser: .init(
          createdAt: .init(timeIntervalSince1970: 1_234_543_210), id: 1, name: "Blob")
      ),
      email: "blob@pointfree.co",
      now: { .mock }
    )

    _ = try await self.database.createEnterpriseEmail("blob@corporate.com", currentUser.id)

    let owner = try await self.database.registerUser(
      withGitHubEnvelope: .init(
        accessToken: .init(accessToken: "deadbeef-owner"),
        gitHubUser: .init(
          createdAt: .init(timeIntervalSince1970: 1_234_543_210), id: 2, name: "Owner")
      ),
      email: "owner@pointfree.co",
      now: { .mock }
    )

    let subscription = try await self.database.createSubscription(
      Stripe.Subscription.mock,
      owner.id,
      false,
      nil
    )

    _ = try await self.database.addUserIdToSubscriptionId(currentUser.id, subscription.id)

    let conn = connection(from: request(to: .team(.leave), session: .loggedIn(as: currentUser)))

    await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

    let subscriptionId = try await self.database.fetchUserById(currentUser.id).subscriptionId
    XCTAssertEqual(subscriptionId, nil)

    let emails = try await self.database.fetchEnterpriseEmails()
    XCTAssertEqual(emails, [])
  }
}

@MainActor
final class AccountTests: TestCase {
  override func setUp() async throws {
    try await super.setUp()
    //SnapshotTesting.isRecording = true
  }

  func testAccount() async throws {
    await withDependencies {
      $0.teamYearly()
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 2800)),
              "mobile": .connWebView(size: .init(width: 400, height: 2400)),
            ]
          )
        }
      #endif
    }
  }

  func testAccount_InvoiceBilling() async throws {
    var customer = Stripe.Customer.mock
    customer.invoiceSettings.defaultPaymentMethod = nil
    var subscription = Stripe.Subscription.teamYearly
    subscription.customer = .right(customer)

    await withDependencies {
      $0.teamYearly()
      $0.stripe.fetchSubscription = { _ in subscription }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 2800)),
              "mobile": .connWebView(size: .init(width: 400, height: 2400)),
            ]
          )
        }
      #endif
    }
  }

  func testTeam_OwnerIsNotSubscriber() async throws {
    var currentUser = User.nonSubscriber
    currentUser.episodeCreditCount = 2
    var subscription = Models.Subscription.mock
    subscription.userId = currentUser.id

    await withDependencies {
      $0.teamYearly()
      $0.database.fetchUserById = { _ in currentUser }
      $0.database.fetchSubscriptionTeammatesByOwnerId = { _ in [] }
      $0.database.fetchSubscriptionById = { _ in subscription }
    } operation: {
      var session = Session.loggedIn
      session.user = .standard(currentUser.id)
      let conn = connection(from: request(to: .account(), session: session))

      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 2000)),
              "mobile": .connWebView(size: .init(width: 400, height: 1800)),
            ]
          )
        }
      #endif
    }
  }

  func testTeam_NoRemainingSeats() async throws {
    let currentUser = User.nonSubscriber
    var subscription = Models.Subscription.mock
    subscription.userId = currentUser.id
    var stripeSubscription = Stripe.Subscription.mock
    stripeSubscription.quantity = 2

    await withDependencies {
      $0.teamYearly()
      $0.database.fetchUserById = { _ in currentUser }
      $0.database.fetchSubscriptionTeammatesByOwnerId = { _ in [.mock, .mock] }
      $0.database.fetchSubscriptionById = { _ in subscription }
      $0.database.fetchTeamInvites = { _ in [] }
      $0.stripe.fetchSubscription = { _ in stripeSubscription }
    } operation: {
      var session = Session.loggedIn
      session.user = .standard(currentUser.id)
      let conn = connection(from: request(to: .account(), session: session))

      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 1800)),
              "mobile": .connWebView(size: .init(width: 400, height: 1600)),
            ]
          )
        }
      #endif
    }
  }

  func testTeam_AsTeammate() async throws {
    await withDependencies {
      $0.teamYearlyTeammate()
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn(as: .teammate)))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 1500)),
              "mobile": .connWebView(size: .init(width: 400, height: 1300)),
            ]
          )
        }
      #endif
    }
  }

  func testTeam_AsTeammate_previousSubscription() async throws {
    await withDependencies {
      $0.teamYearlyTeammate()
      $0.database.fetchSubscriptionByOwnerId = const(
        update(.canceled) { $0.userId = User.teammate.id }
      )
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn(as: .teammate)))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 1500)),
              "mobile": .connWebView(size: .init(width: 400, height: 1300)),
            ]
          )
        }
      #endif
    }
  }

  func testAccount_WithExtraInvoiceInfo() async throws {
    var customer = Stripe.Customer.mock
    customer.metadata = ["extraInvoiceInfo": "VAT: 1234567890"]
    var subscription = Stripe.Subscription.mock
    subscription.customer = .right(customer)

    await withDependencies {
      $0.teamYearly()
      $0.stripe.fetchSubscription = { _ in subscription }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 1000)),
              "mobile": .connWebView(size: .init(width: 400, height: 1000)),
            ]
          )
        }
      #endif
    }
  }

  func testAccountWithFlashNotice() async throws {
    var session = Session.loggedIn
    session.flash = Flash(.notice, "You’ve subscribed!")

    let conn = connection(
      from: request(to: .account(), session: session))

    await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

    #if !os(Linux)
      if self.isScreenshotTestingAvailable {
        await assertSnapshots(
          matching: await siteMiddleware(conn),
          as: [
            "desktop": .connWebView(size: .init(width: 1080, height: 80)),
            "mobile": .connWebView(size: .init(width: 400, height: 80)),
          ]
        )
      }
    #endif
  }

  func testAccountWithFlashWarning() async throws {
    var session = Session.loggedIn
    session.flash = Flash(.warning, "Your subscription is past-due!")

    let conn = connection(from: request(to: .account(), session: session))

    await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

    #if !os(Linux)
      if self.isScreenshotTestingAvailable {
        await assertSnapshots(
          matching: await siteMiddleware(conn),
          as: [
            "desktop": .connWebView(size: .init(width: 1080, height: 80)),
            "mobile": .connWebView(size: .init(width: 400, height: 80)),
          ]
        )
      }
    #endif
  }

  func testAccountWithFlashError() async throws {
    var session = Session.loggedIn
    session.flash = Flash(.error, "An error has occurred!")

    let conn = connection(from: request(to: .account(), session: session))

    await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

    #if !os(Linux)
      if self.isScreenshotTestingAvailable {
        await assertSnapshots(
          matching: await siteMiddleware(conn),
          as: [
            "desktop": .connWebView(size: .init(width: 1080, height: 80)),
            "mobile": .connWebView(size: .init(width: 400, height: 80)),
          ]
        )
      }
    #endif
  }

  func testAccountWithPastDue() async throws {
    var subscription = Models.Subscription.mock
    subscription.stripeSubscriptionStatus = .pastDue

    var stripeSubscription = Stripe.Subscription.mock
    stripeSubscription.cancelAtPeriodEnd = false
    stripeSubscription.status = .pastDue

    await withDependencies {
      $0.database.fetchSubscriptionById = { _ in subscription }
      $0.database.fetchSubscriptionByOwnerId = { _ in subscription }
      $0.stripe.fetchSubscription = { _ in stripeSubscription }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 2000)),
              "mobile": .connWebView(size: .init(width: 400, height: 1800)),
            ]
          )
        }
      #endif
    }
  }

  func testAccountCancelingSubscription() async throws {
    await withDependencies {
      $0.stripe.fetchSubscription = { _ in .canceling }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 2200)),
              "mobile": .connWebView(size: .init(width: 400, height: 2000)),
            ]
          )
        }
      #endif
    }
  }

  func testAccountCanceledSubscription() async throws {
    await withDependencies {
      $0.database.fetchSubscriptionById = { _ in .canceled }
      $0.stripe.fetchSubscription = { _ in .canceled }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 1400)),
              "mobile": .connWebView(size: .init(width: 400, height: 1200)),
            ]
          )
        }
      #endif
    }
  }

  func testEpisodeCredits_1Credit_NoneChosen() async throws {
    var user = User.mock
    user.subscriptionId = nil
    user.episodeCreditCount = 1

    await withDependencies {
      $0.database.fetchUserById = { _ in user }
      $0.database.fetchEpisodeCredits = { _ in [] }
      $0.database.fetchSubscriptionByOwnerId = { _ in throw unit }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 1200)),
              "mobile": .connWebView(size: .init(width: 400, height: 1000)),
            ]
          )
        }
      #endif
    }
  }

  func testEpisodeCredits_1Credit_1Chosen() async throws {
    var user = User.mock
    user.subscriptionId = nil
    user.episodeCreditCount = 1

    await withDependencies {
      $0.database.fetchUserById = { _ in user }
      $0.database.fetchEpisodeCredits = { _ in [.mock] }
      $0.database.fetchSubscriptionByOwnerId = { _ in throw unit }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 1200)),
              "mobile": .connWebView(size: .init(width: 400, height: 1000)),
            ]
          )
        }
      #endif
    }
  }

  func testAccountWithDiscount() async throws {
    var subscription = Stripe.Subscription.mock
    subscription.discount = .mock

    await withDependencies {
      $0.teamYearly()
      $0.stripe.fetchSubscription = { _ in subscription }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 2400)),
              "mobile": .connWebView(size: .init(width: 400, height: 2000)),
            ]
          )
        }
      #endif
    }
  }

  func testAccountWithCredit() async throws {
    var subscription = Stripe.Subscription.mock
    subscription.customer = .right(update(.mock) { $0.balance = -18_00 })

    await withDependencies {
      $0.individualMonthly()
      $0.stripe.fetchSubscription = { _ in subscription }
    } operation: {
      let conn = connection(from: request(to: .account(), session: .loggedIn))
      await assertSnapshot(matching: await siteMiddleware(conn), as: .conn)

      #if !os(Linux)
        if self.isScreenshotTestingAvailable {
          await assertSnapshots(
            matching: await siteMiddleware(conn),
            as: [
              "desktop": .connWebView(size: .init(width: 1080, height: 2800)),
              "mobile": .connWebView(size: .init(width: 400, height: 2400)),
            ]
          )
        }
      #endif
    }
  }
}
