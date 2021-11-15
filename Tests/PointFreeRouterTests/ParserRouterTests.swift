import PointFreeRouter
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
}
