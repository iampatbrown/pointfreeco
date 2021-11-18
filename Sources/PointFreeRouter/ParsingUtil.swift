import ApplicativeRouter
import Foundation
import Optics
import Parsing
import Prelude
import Tagged
import UrlFormEncoding

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

public struct FormData<Value: Decodable>: Parser {
  public let decoder: UrlFormDecoder

  @inlinable
  public init(
    _ type: Value.Type,
    decoder: UrlFormDecoder = .init()
  ) {
    self.decoder = decoder
  }

  @inlinable
  public func parse(_ input: inout ArraySlice<UInt8>) -> Value? {
    guard
      let output = try? decoder.decode(Value.self, from: Data(input))
    else { return nil }
    input = []
    return output
  }
}

extension FormData: Printer where Value: Encodable {
  @inlinable
  @inline(__always)
  public func print(_ output: Value) -> ArraySlice<UInt8>? {
    return ArraySlice(urlFormEncode(value: output).utf8)
  }
}

public struct Form<FormParser>: Parser
  where
  FormParser: Parser,
  FormParser.Input == [String: String?] // TODO: should this be an array? [(key: String, value: String?)]
{
  public let formParser: FormParser

  @inlinable
  public init(@ParserBuilder _ formParser: () -> FormParser) {
    self.formParser = formParser()
  }

  @inlinable
  public func parse(_ input: inout ArraySlice<UInt8>) -> FormParser.Output? {
    var form = bodyToForm(input)
    guard
      let output = self.formParser.parse(&form),
      form.isEmpty
    else { return nil }
    input = []
    return output
  }

  @usableFromInline
  func bodyToForm(_ input: ArraySlice<UInt8>) -> [String: String?] {
    let formFields = UrlFormEncoding.parse(query: String(decoding: input, as: UTF8.self))
    return .init(uniqueKeysWithValues: formFields)
  }
}

extension Form: Printer where FormParser: Printer {
  @inlinable
  public func print(_ output: FormParser.Output) -> ArraySlice<UInt8>? {
    guard let form = self.formParser.print(output)
    else { return nil }
    return formToBody(form)
  }

  @usableFromInline
  func formToBody(_ form: [String: String?]) -> ArraySlice<UInt8> {
    var urlComponents = URLComponents()
    urlComponents.queryItems = form.map(URLQueryItem.init(name:value:))
    let encodedString = urlComponents.percentEncodedQuery ?? ""
    return ArraySlice(encodedString.utf8)
  }
}

public struct Field<ValueParser>: Parser
  where
  ValueParser: Parser,
  ValueParser.Input == Substring
{
  public let name: String
  public let valueParser: ValueParser

  @inlinable
  public init(
    _ name: String,
    @ParserBuilder _ valueParser: () -> ValueParser
  ) {
    self.name = name
    self.valueParser = valueParser()
  }

  @inlinable
  public func parse(_ input: inout [String: String?]) -> ValueParser.Output? {
    guard
      let wrapped = input[self.name],
      var value = wrapped?[...],
      let output = self.valueParser.parse(&value),
      value.isEmpty
    else { return nil }
    input[self.name] = nil
    return output
  }
}

extension Field: Printer where ValueParser: Printer {
  @inlinable
  public func print(_ output: ValueParser.Output) -> [String: String?]? {
    guard let value = self.valueParser.print(output).map(String.init) else { return nil }
    return [self.name: value]
  }
}

extension Conversion {
  public static func >>> <NewOutput>(
    lhs: Conversion<Input, Output>,
    rhs: Conversion<Output, NewOutput>
  ) -> Conversion<Input, NewOutput> {
    return .init(
      apply: lhs.apply >>> rhs.apply,
      unapply: rhs.unapply >>> lhs.unapply
    )
  }

  public static func <<< <NewOutput>(
    lhs: Conversion<Output, NewOutput>,
    rhs: Conversion<Input, Output>
  ) -> Conversion<Input, NewOutput> {
    return .init(
      apply: rhs.apply >>> lhs.apply,
      unapply: lhs.unapply >>> rhs.unapply
    )
  }
}

extension Conversion {
  public static func >>> <NewOutput>(
    lhs: Conversion<Input, Output>,
    rhs: PartialConversion<Output, NewOutput>
  ) -> PartialConversion<Input, NewOutput> {
    return .init(
      apply: lhs.apply >=> rhs.apply,
      unapply: rhs.unapply >=> lhs.unapply
    )
  }

  public static func <<< <NewOutput>(
    lhs: Conversion<Output, NewOutput>,
    rhs: PartialConversion<Input, Output>
  ) -> PartialConversion<Input, NewOutput> {
    return .init(
      apply: rhs.apply >=> lhs.apply,
      unapply: lhs.unapply >=> rhs.unapply
    )
  }
}

extension _Routing {
  @inlinable
  public init<Value, RouteParser>(
    casePath route: CasePath<Route, Value>,
    @ParserBuilder to parser: () -> RouteParser
  )
    where
    RouteParser: ParserPrinter,
    RouteParser.Input == URLRequestData,
    RouteParser.Output == Value
  {
    self.init(route, to: parser)
  }

  @inlinable
  public init<Value, RouteParser>(
    closure route: @escaping (Value) -> Route,
    @ParserBuilder to parser: () -> RouteParser
  )
    where
    RouteParser: ParserPrinter,
    RouteParser.Input == URLRequestData,
    RouteParser.Output == Value
  {
    let c = CasePath.case(route) as CasePath<Route, Value>
    self.init(c, to: parser)
  }

  @inlinable
  public init<RouteParser>(
    closure route: CasePath<Route, Void>,
    @ParserBuilder to parser: () -> RouteParser
  ) where
    RouteParser: ParserPrinter,
    RouteParser.Input == URLRequestData,
    RouteParser.Output == Void
  {
    self.init(route, to: parser)
  }
}

extension Parser where Self == Parsers.SubstringIntParser<Int> {
  static var int: Self { .init(isSigned: true, radix: 10) }
}
