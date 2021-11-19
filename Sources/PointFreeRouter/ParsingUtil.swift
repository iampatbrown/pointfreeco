import Combine
// import ApplicativeRouter
// import Foundation
// import Optics
import Routing
// import Parsing
// import Prelude
// import Tagged
// import UrlFormEncoding

struct Unwrapped<Upstream>: ParserPrinter where Upstream: ParserPrinter {
  public let upstream: Upstream

  public init(@ParserBuilder _ build: () -> Upstream) {
    self.upstream = build()
  }

  @inlinable
  public func parse(_ input: inout Upstream.Input?) -> Upstream.Output? {
    guard var input = input else { return nil }
    return self.upstream.parse(&input)
  }

  @inlinable
  public func print(_ output: Upstream.Output) -> Upstream.Input?? {
    guard let output = self.upstream.print(output) else { return nil }
    return .some(output)
  }
}

struct None<Input, Output>: ParserPrinter {
  init() {}

  @inlinable
  public func parse(_ input: inout Input?) -> Output?? {
    guard input == nil else { return nil }
    return .none
  }

  @inlinable
  public func print(_ output: Output?) -> Input?? {
    guard output == nil else { return nil }
    return .none
  }
}

let urlFormDecoder: URLFormDecoder = {
  let decoder = URLFormDecoder()
  decoder.parsingStrategy = .bracketsWithIndices
  return decoder
}()

// extension Optional: Appendable where Wrapped: Appendable {
//  public init() {
//    self = .some(Wrapped())
//  }
//
//  public mutating func append(contentsOf other: Wrapped?) {
//    if other != nil {
//      self?.append(contentsOf: other!)
//    }
//  }
// }

// extension Printer where Input == URLRequestData {
//  public func request(for output: Output, base: URL? = nil) -> URLRequest? {
//    self.print(output).flatMap { urlRequest(from: $0, base: base) }
//  }
//
//  public func url(for output: Output, base: URL? = nil) -> URL? {
//    self.request(for: output, base: base).flatMap(\.url)
//  }
//
//  public func absoluteString(for output: Output) -> String? {
//    return (self.url(for: output)?.absoluteString)
//      .map { $0 == "/" ? "/" : "/" + $0 }
//  }
// }
//
// extension Parser where Input == URLRequestData {
//  public func match(request: URLRequest) -> Output? {
//    guard var data = URLRequestData(request: request) else { return nil }
//    return self.parse(&data)
//  }
// }
//
// private func urlRequest(from data: URLRequestData, base: URL?) -> URLRequest? {
//  let url: URL? = data.path.isEmpty && data.query.isEmpty
//    ? (base ?? URL(string: "/"))
//    : urlComponents(from: data).url(relativeTo: base)
//  return url.map {
//    URLRequest(url: $0)
//      |> \.httpMethod .~ data.method
//      |> \.httpBody .~ data.body.map(Data.init)
//      |> \.allHTTPHeaderFields .~ .some(data.headers.mapValues(String.init))
//  }
// }
//
// private func urlComponents(from data: URLRequestData) -> URLComponents {
//  var components = URLComponents()
//  components.path = data.path.joined(separator: "/")
//  let query = data.query.mapValues { $0.compactMap { $0 }.joined() }.filter { !$0.value.isEmpty }
//  if !query.isEmpty {
//    components.queryItems = query.map(URLQueryItem.init(name:value:))
//  }
//  return components
// }
//
//
//

// }
//
// extension PartialIso {
//  init<P>(_ parserPrinter: P) where P: ParserPrinter, P.Input == A, P.Output == B {
//    self.init(apply: { parserPrinter.parse($0).output }, unapply: parserPrinter.print)
//  }
// }
//
// public struct FormData<Value: Decodable>: Parser {
//  public let decoder: UrlFormDecoder
//
//  @inlinable
//  public init(
//    _ type: Value.Type,
//    decoder: UrlFormDecoder = .init()
//  ) {
//    self.decoder = decoder
//  }
//
//  @inlinable
//  public func parse(_ input: inout ArraySlice<UInt8>) -> Value? {
//    guard
//      let output = try? decoder.decode(Value.self, from: Data(input))
//    else { return nil }
//    input = []
//    return output
//  }
// }
//
// extension FormData: Printer where Value: Encodable {
//  @inlinable
//  @inline(__always)
//  public func print(_ output: Value) -> ArraySlice<UInt8>? {
//    return ArraySlice(urlFormEncode(value: output).utf8)
//  }
// }
//
// public struct Form<FormParser>: Parser
//  where
//  FormParser: Parser,
//  FormParser.Input == [String: String?] // TODO: should this be an array? [(key: String, value: String?)]
// {
//  public let formParser: FormParser
//
//  @inlinable
//  public init(@ParserBuilder _ formParser: () -> FormParser) {
//    self.formParser = formParser()
//  }
//
//  @inlinable
//  public func parse(_ input: inout ArraySlice<UInt8>) -> FormParser.Output? {
//    var form = bodyToForm(input)
//    guard
//      let output = self.formParser.parse(&form),
//      form.isEmpty
//    else { return nil }
//    input = []
//    return output
//  }
//
//  @usableFromInline
//  func bodyToForm(_ input: ArraySlice<UInt8>) -> [String: String?] {
//    let formFields = UrlFormEncoding.parse(query: String(decoding: input, as: UTF8.self))
//    return .init(uniqueKeysWithValues: formFields)
//  }
// }
//
// extension Form: Printer where FormParser: Printer {
//  @inlinable
//  public func print(_ output: FormParser.Output) -> ArraySlice<UInt8>? {
//    guard let form = self.formParser.print(output)
//    else { return nil }
//    return formToBody(form)
//  }
//
//  @usableFromInline
//  func formToBody(_ form: [String: String?]) -> ArraySlice<UInt8> {
//    var urlComponents = URLComponents()
//    urlComponents.queryItems = form.map(URLQueryItem.init(name:value:))
//    let encodedString = urlComponents.percentEncodedQuery ?? ""
//    return ArraySlice(encodedString.utf8)
//  }
// }
//
// public struct Field<ValueParser>: Parser
//  where
//  ValueParser: Parser,
//  ValueParser.Input == Substring
// {
//  public let name: String
//  public let valueParser: ValueParser
//
//  @inlinable
//  public init(
//    _ name: String,
//    @ParserBuilder _ valueParser: () -> ValueParser
//  ) {
//    self.name = name
//    self.valueParser = valueParser()
//  }
//
//  @inlinable
//  public func parse(_ input: inout [String: String?]) -> ValueParser.Output? {
//    guard
//      let wrapped = input[self.name],
//      var value = wrapped?[...],
//      let output = self.valueParser.parse(&value),
//      value.isEmpty
//    else { return nil }
//    input[self.name] = nil
//    return output
//  }
// }
//
// extension Field: Printer where ValueParser: Printer {
//  @inlinable
//  public func print(_ output: ValueParser.Output) -> [String: String?]? {
//    guard let value = self.valueParser.print(output).map(String.init) else { return nil }
//    return [self.name: value]
//  }
// }
//
