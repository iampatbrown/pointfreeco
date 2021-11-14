import ApplicativeRouter
import Foundation
import Parsing
import Prelude

public enum TwitterRoute {
  case mbrandonw
  case pointfreeco
  case stephencelis
}

public let twitterRouter = OneOf {
  Routing(/TwitterRoute.mbrandonw) {
    Method.get
    Path(FromUTF8View { "mbrandonw".utf8 })
  }

  Routing(/TwitterRoute.pointfreeco) {
    Method.get
    Path(FromUTF8View { "pointfreeco".utf8 })
  }

  Routing(/TwitterRoute.stephencelis) {
    Method.get
    Path(FromUTF8View { "stephencelis".utf8 })
  }
}

public func twitterUrl(to route: TwitterRoute) -> String {
  return twitterRouter.url(for: route, base: twitterBaseUrl)?.absoluteString ?? ""
}

private let twitterBaseUrl = URL(string: "https://www.twitter.com")!
