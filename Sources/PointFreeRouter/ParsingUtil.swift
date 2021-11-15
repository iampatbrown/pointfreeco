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

extension Router {
  init<P>(_ parserPrinter: P) where P: ParserPrinter, P.Input == URLRequestData, P.Output == A {
    self = PartialIso(parserPrinter) <¢> .empty
  }
}


public struct UrlForm<Value: Decodable>: Parser {
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

extension UrlForm: Printer where Value: Encodable {
  @inlinable
  @inline(__always)
  public func print(_ output: Value) -> ArraySlice<UInt8>? {
    return ArraySlice(urlFormEncode(value: output).utf8)
  }
}

public struct FormField<ValueParser>: Parser
  where
  ValueParser: Parser,
  ValueParser.Input == Substring
  {
    public let name: String
    public let valueParser: ValueParser

  @inlinable
  public init(
    _ name: String,
    _ value: ValueParser
  ) {
    self.name = name
    self.valueParser = value
  }

    @inlinable
    public init(_ name: String) where ValueParser == Rest<Substring> {
      self.init(name, Rest())
    }

  @inlinable
    public func parse(_ input: inout ArraySlice<UInt8>) -> ValueParser.Output? {
      return nil
  }
}

extension FormField: Printer where ValueParser: Printer {
  @inlinable
  public func print(_ output: Output) -> ArraySlice<UInt8>? {
    guard let value = self.valueParser.print(output) else { return nil }
    return ArraySlice(value.utf8)
  }
}



// TODO: Temp


extension String {
  static var fromBody: PartialConversion<ArraySlice<UInt8>, Self> {
    .init(
      apply: { String(decoding: $0, as: UTF8.self) },
      unapply: { ArraySlice($0.utf8) }
    )
  }
}

extension PartialConversion where Input == String, Output == [(key: String, value: String?)] {
  /// An isomorphism between strings and dictionaries using form encoded format.
  public static var formEncodedFields: PartialConversion {
    return .init(
      apply: formEncodedStringToFields,
      unapply: fieldsToFormEncodedString
    )
  }
}

private func first(key: String) -> PartialConversion<[(key: String, value: String?)], String> {
  return PartialConversion<[(key: String, value: String?)], String>(
    apply: { $0.first(where: { $0.key == key })?.value },
    unapply: { [(key: key, value: $0)] }
  )
}

private func formEncodedStringToFields(_ body: String) -> [(key: String, value: String?)] {
  return parse(query: body)
}

private func fieldsToFormEncodedString(_ data: [(key: String, value: String?)]) -> String {
  var urlComponents = URLComponents()
  urlComponents.queryItems = data.map(URLQueryItem.init(name:value:))
  return urlComponents.percentEncodedQuery ?? ""
}

public func parse(query: String) -> [(String, String?)] {
  return pairs(query)
}

private func pairs(_ query: String, sort: Bool = false) -> [(String, String?)] {
  let pairs = query
    .split(separator: "&")
    .map { (pairString: Substring) -> (name: String, value: String?) in
      let pairArray = pairString.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        .compactMap(
          String.init
            >>> { $0.replacingOccurrences(of: "+", with: " ") }
            >>> ^\.removingPercentEncoding
        )
      return (pairArray[0], pairArray.count == 2 ? pairArray[1] : nil)
    }

  return sort ? pairs.sorted { $0.name < $1.name } : pairs
}
