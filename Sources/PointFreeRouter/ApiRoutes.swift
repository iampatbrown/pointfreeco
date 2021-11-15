import ApplicativeRouter
import Models
import Parsing
import Prelude
import CasePaths

extension Route {
  public enum Api: Equatable {
    case episodes
    case episode(Episode.Id)
  }
}

 let apiRouter
  = apiRouters.reduce(.empty, <|>)

private let apiRouters: [Router<Route.Api>] = [
  .case(.episodes)
    <¢> "episodes" <% end,

  .case(Route.Api.episode)
    <¢> "episodes" %> pathParam(.tagged(.int)) <% end,
]

let _apiRouter = OneOf {
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



