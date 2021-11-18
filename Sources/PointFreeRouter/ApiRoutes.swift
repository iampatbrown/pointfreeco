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

private let apiRouters: [Router<Route.Api>] = [
  .case(.episodes)
    <¢> "episodes" <% end,

  .case(Route.Api.episode)
    <¢> "episodes" %> pathParam(.tagged(.int)) <% end,
]

let _apiRouter = _Router<Route.Api> {
  _Routing(/Route.Api.episodes) {
    Method.get
    Path(literal: "episodes")
  }

  _Routing(/Route.Api.episode) {
    Method.get
    Path(literal: "episodes")
    Path(Int.parser().map(Episode.Id.fromRawValue))
  }
}
