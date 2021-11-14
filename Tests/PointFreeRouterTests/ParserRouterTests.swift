import PointFreeRouter
import CustomDump
import XCTest

class ParserRouterTests: XCTestCase {
  func testTwitterUrl() {
    XCTAssertEqual(twitterUrl(to: .mbrandonw), "https://www.twitter.com/mbrandonw")
    XCTAssertEqual(twitterUrl(to: .pointfreeco), "https://www.twitter.com/pointfreeco")
    XCTAssertEqual(twitterUrl(to: .stephencelis), "https://www.twitter.com/stephencelis")
  }
}
