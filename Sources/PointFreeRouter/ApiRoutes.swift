import ApplicativeRouter
import CasePaths
import Models
import Parsing
import Prelude
import Routing
import Tagged

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

let _apiRouter = Routing<Route.Api> {
  Routing(/Route.Api.episodes) {
    Method.get
    Path("episodes")
  }

  Routing(/Route.Api.episode) {
    Method.get
    Path("episodes")
    Path { Int.parser().map(Episode.Id.fromRawValue) }
  }
}
