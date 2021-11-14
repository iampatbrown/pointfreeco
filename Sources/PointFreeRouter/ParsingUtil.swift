import Foundation
import Optics
import Parsing
import Prelude

extension Printer where Input == URLRequestData {
  public func url(for output: Output, base: URL?) -> URL? {
    self.print(output).flatMap { request(from: $0, base: base) }.flatMap { $0.url }
  }
}

private func request(from data: URLRequestData, base: URL?) -> URLRequest? {
  (
    data.path.isEmpty && data.query.isEmpty
      ? (base ?? URL(string: "/"))
      : urlComponents(from: data).url(relativeTo: base)
  ).map {
    URLRequest(url: $0)
      |> \.httpMethod .~ data.method
      |> \.httpBody .~ data.body.map(Data.init)
      |> \.allHTTPHeaderFields .~ .some(data.headers.mapValues(String.init))
  }
}

private func urlComponents(from data: URLRequestData) -> URLComponents {
  var components = URLComponents()
  components.path = data.path.joined(separator: "/")
  let query = data.query.mapValues { $0.compactMap { $0 }.joined() }.filter { !$0.value.isEmpty }
  if !query.isEmpty {
    components.queryItems = query.map(URLQueryItem.init(name:value:))
  }
  return components
}
