import ApplicativeRouter
import CasePaths
import Models
import Parsing
import Prelude

extension Route {
  public enum Api: Equatable {
    case episodes
    case episode(Episode.Id)
  }
}

let apiRouter
  = apiRouters.reduce(.empty, <|>)

private let apiRouters: [ApplicativeRouter.Router<Route.Api>] = [
  .case(.episodes)
    <¢> "episodes" <% end,

  .case(Route.Api.episode)
    <¢> "episodes" %> pathParam(.tagged(.int)) <% end,
]

let __apiRouter = OneOf {
  Routing(/Route.Api.episodes) {
    Method.get
    Path(FromUTF8View { "episodes".utf8 })
  }

  Routing(/Route.Api.episode) {
    Method.get
    Path(FromUTF8View { "episodes".utf8 })
    Path(FromUTF8View { Int.parser().map(Episode.Id.fromRawValue) })
  }
}


let ___apiRouter = OneOf {
  Routing(/Route.Api.episodes) {
    Method.get
    Path(StartsWith("episodes"))
  }

  Routing(/Route.Api.episode) {
    Method.get
    Path(StartsWith("episodes"))
    Path(Int.parser().map(Episode.Id.fromRawValue))
  }
}

let _apiRouter = _Router<Route.Api> {
  _Routing(/Route.Api.episodes) {
    Method.get
    Path(StartsWith("episodes"))
  }

  _Routing(/Route.Api.episode) {
    Method.get
    Path(StartsWith("episodes"))
    Path(Int.parser().map(Episode.Id.fromRawValue))
  }
}
