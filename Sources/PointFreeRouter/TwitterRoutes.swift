import ApplicativeRouter
import Foundation
import Prelude
import Routing

public enum TwitterRoute {
  case mbrandonw
  case pointfreeco
  case stephencelis
}

public let twitterRouter = Routing<TwitterRoute> {
  Routing(/TwitterRoute.mbrandonw) {
    Path("mbrandonw")
  }

  Routing(/TwitterRoute.pointfreeco) {
    Method.get
    Path("pointfreeco")
  }

  Routing(/TwitterRoute.stephencelis) {
    Method.get
    Path("stephencelis")
  }
}

public func twitterUrl(to route: TwitterRoute) -> String {
  return twitterRouter.url(for: route, base: twitterBaseUrl)?.absoluteString ?? ""
}

private let twitterBaseUrl = URL(string: "https://www.twitter.com")!
