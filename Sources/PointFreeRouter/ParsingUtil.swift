import ApplicativeRouter
import Foundation
import Optics
import Parsing
import Prelude
import Tagged

extension Printer where Input == URLRequestData {
  public func request(for output: Output, base: URL? = nil) -> URLRequest? {
    self.print(output).flatMap { urlRequest(from: $0, base: base) }
  }

  public func url(for output: Output, base: URL? = nil) -> URL? {
    self.request(for: output, base: base).flatMap(\.url)
  }

  public func absoluteString(for output: Output) -> String? {
    return (self.url(for: output)?.absoluteString)
      .map { $0 == "/" ? "/" : "/" + $0 }
  }
}

extension Parser where Input == URLRequestData {
  public func match(request: URLRequest) -> Output? {
    guard var data = URLRequestData(request: request) else { return nil }
    return self.parse(&data)
  }
}

private func urlRequest(from data: URLRequestData, base: URL?) -> URLRequest? {
  let url = data.path.isEmpty && data.query.isEmpty
    ? (base ?? URL(string: "/"))
    : urlComponents(from: data).url(relativeTo: base)
  return url.map {
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

extension PartialConversion where Output: TaggedType, Input == Output.RawValue {
  public static var tagged: PartialConversion<Output.RawValue, Output> {
    return PartialConversion(
      apply: Output.init(rawValue:),
      unapply: ^\.rawValue
    )
  }
}

extension PartialConversion {
  public static func >>> <NewOutput>(
    lhs: PartialConversion<Input, Output>,
    rhs: PartialConversion<Output, NewOutput>
  ) -> PartialConversion<Input, NewOutput> {
    return .init(
      apply: lhs.apply >=> rhs.apply,
      unapply: rhs.unapply >=> lhs.unapply
    )
  }

  public static func <<< <NewOutput>(
    lhs: PartialConversion<Output, NewOutput>,
    rhs: PartialConversion<Input, Output>
  ) -> PartialConversion<Input, NewOutput> {
    return .init(
      apply: rhs.apply >=> lhs.apply,
      unapply: lhs.unapply >=> rhs.unapply
    )
  }

  static func tagged<T, C>(
    from root: PartialConversion<Input, C>
  ) -> PartialConversion<Input, Output> where Output == Tagged<T, C> {
    return root >>> .tagged
  }
}

extension Tagged {
  static var fromRawValue: PartialConversion<RawValue, Self> {
    return PartialConversion(
      apply: Self.init(rawValue:),
      unapply: ^\.rawValue
    )
  }
}

extension PartialIso {
  init<P>(_ parserPrinter: P) where P: ParserPrinter, P.Input == A, P.Output == B {
    self.init(apply: { parserPrinter.parse($0).output }, unapply: parserPrinter.print)
  }
}

extension Router {
  init<P>(_ parserPrinter: P) where P: ParserPrinter, P.Input == URLRequestData, P.Output == A {
    self = PartialIso(parserPrinter) <¢> .empty
  }
}
