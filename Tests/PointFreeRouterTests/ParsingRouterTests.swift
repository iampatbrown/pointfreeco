import PointFreeRouter
import Models
import CustomDump
import XCTest

class ParserRouterTests: XCTestCase {
  func testTwitterUrl() {
    XCTAssertEqual(twitterUrl(to: .mbrandonw), "https://www.twitter.com/mbrandonw")
    XCTAssertEqual(twitterUrl(to: .pointfreeco), "https://www.twitter.com/pointfreeco")
    XCTAssertEqual(twitterUrl(to: .stephencelis), "https://www.twitter.com/stephencelis")
  }


  func testApiEpisodes() {
    let request = URLRequest(url: URL(string: "http://localhost:8080/api/episodes")!)
    let route = Route.api(.episodes)

    let router = PointFreeRouter(router: .empty)
    XCTAssertEqual(
      router.match(request: request),
      route
    )

    XCTAssertEqual(
      router.request(for: route),
      request
    )
  }

  func testApiEpisodeId() {
    let request = URLRequest(url: URL(string: "http://localhost:8080/api/episodes/1")!)
    let route = Route.api(.episode(.init(rawValue: 1)))

    let router = PointFreeRouter(router: .empty)
    XCTAssertEqual(
      router.match(request: request),
      route
    )

    XCTAssertEqual(
      router.request(for: route),
      request
    )
  }


  func testUpdateProfile() {
    let profileData = ProfileData(
      email: "blobby@blob.co",
      extraInvoiceInfo: nil,
      emailSettings: [:],
      name: "Blobby McBlob"
    )
    let route = Route.account(.update(profileData))
    let router = PointFreeRouter(router: .empty)
    guard let request = router.request(for: route) else {
        XCTFail("")
        return
    }

    XCTAssertEqual("POST", request.httpMethod)
    XCTAssertEqual("/account", request.url?.path)
    XCTAssertEqual(route, router.match(request: request))
  }
}
