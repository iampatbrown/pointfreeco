import ApplicativeRouter
import Foundation
import Models
import Parsing
import PointFreePrelude
import Prelude
import Stripe

public enum Account: Equatable {
  case confirmEmailChange(payload: Encrypted<String>)
  case index
  case invoices(Invoices)
  case paymentInfo(PaymentInfo)
  case rss(salt: User.RssSalt)
  case rssLegacy(secret1: String, secret2: String)
  case subscription(Subscription)
  case update(ProfileData?)

  public enum Invoices: Equatable {
    case index
    case show(Stripe.Invoice.Id)
  }

  public enum PaymentInfo: Equatable {
    case show
    case update(Stripe.Token.Id?)
  }

  public enum Subscription: Equatable {
    case cancel
    case change(Change)
    case reactivate

    public enum Change: Equatable {
      case show
      case update(Pricing?)
    }
  }
}

let accountRouter
  = accountRouters.reduce(.empty, <|>)

private let accountRouters: [ApplicativeRouter.Router<Account>] = [
  .case(Account.confirmEmailChange)
    <¢> get %> "confirm-email-change"
    %> queryParam("payload", .tagged)
    <% end,

  .case(.index)
    <¢> get <% end,

  .case(.invoices(.index))
    <¢> get %> "invoices" <% end,

  .case { .invoices(.show($0)) }
    <¢> get %> "invoices" %> pathParam(.tagged(.string)) <% end,

  .case(.paymentInfo(.show))
    <¢> get %> "payment-info" <% end,

  .case { .paymentInfo(.update($0)) }
    <¢> post %> "payment-info"
    %> formField("token", Optional.iso.some >>> opt(.tagged(.string)))
    <% end,

  .case(Account.rss)
    <¢> (get <|> head) %> "rss"
    %> pathParam(.tagged)
    <% end,

  .case(Account.rssLegacy)
    <¢> (get <|> head) %> "rss"
    %> pathParam(.id)
    <%> pathParam(.id)
    <% end,

  .case(.subscription(.cancel))
    <¢> post %> "subscription" %> "cancel" <% end,

  .case(.subscription(.change(.show)))
    <¢> get %> "subscription" %> "change" <% end,

  .case { .subscription(.change(.update($0))) }
    <¢> post %> "subscription" %> "change"
    %> formBody(Pricing?.self, decoder: formDecoder)
    <% end,

  .case(.subscription(.reactivate))
    <¢> post %> "subscription" %> "reactivate" <% end,

  .case(Account.update)
    <¢> post %> formBody(ProfileData?.self, decoder: formDecoder) <% end,
]

let __accountRouter = OneOf {
  Routing(/Account.confirmEmailChange) {
    Method.get
    Path(FromUTF8View { "confirm-email-change".utf8 })
    // NB: I'm mainly using PartialConversions to allow printing. Will revisit the ergonomics later.
    Query("payload", FromUTF8View { String.fromSubstringUTF8View.map(Encrypted<String>.fromRawValue) })
  }

  Routing(/Account.index) {
    Method.get
  }

  Routing(/Account.invoices) {
    Path(FromUTF8View { "invoices".utf8 })

    OneOf {
      Routing(/Account.Invoices.index) {
        Method.get
      }

      Routing(/Account.Invoices.show) {
        Method.get
        Path(FromUTF8View { String.fromSubstringUTF8View.map(Stripe.Invoice.Id.fromRawValue) })
      }
    }
  }

  Routing(/Account.paymentInfo) {
    Path(FromUTF8View { "payment-info".utf8 })

    OneOf {
      Routing(/Account.PaymentInfo.show) {
        Method.get
      }

      Routing(/Account.PaymentInfo.update) {
        Method.post
        Body {
          // Maybe just FormField("token", valueParser)
          Form {
            Field("token") {
              Optionally { // TODO: Not sure if this is right
                String.fromSubstring.map(Stripe.Token.Id.fromRawValue)
              }
            }
          }
        }
      }
    }
  }

  Routing(/Account.rss) {
    OneOf {
      Method.get
      Method("HEAD")
    }
    Path(FromUTF8View { "rss".utf8 })
    Path(FromUTF8View { String.fromSubstringUTF8View.map(User.RssSalt.fromRawValue) })
  }

  Routing(/Account.rssLegacy) {
    OneOf {
      Method.get
      Method("HEAD")
    }
    Path(FromUTF8View { "rss".utf8 })
    Path(FromUTF8View { String.fromSubstringUTF8View })
    Path(FromUTF8View { String.fromSubstringUTF8View })
  }

  Routing(/Account.subscription) {
    Path(FromUTF8View { "subscription".utf8 })

    OneOf {
      Routing(/Account.Subscription.cancel) {
        Method.post
        Path(FromUTF8View { "cancel".utf8 })
      }

      Routing(/Account.Subscription.change) {
        OneOf {
          Routing(/Account.Subscription.Change.show) {
            Method.get
            Path(FromUTF8View { "change".utf8 })
          }

          Routing(/Account.Subscription.Change.update) {
            Method.post
            Path(FromUTF8View { "change".utf8 })
            Body { FormData(Pricing?.self, decoder: formDecoder) }
          }
        }
      }

      Routing(/Account.Subscription.reactivate) {
        Method.post
        Path(FromUTF8View { "reactivate".utf8 })
      }
    }
  }

  Routing(/Account.update) {
    Method.post
    Body { FormData(ProfileData?.self, decoder: formDecoder) }
  }
}

let _accountRouter = _Router<Account> {
  _Routing(/Account.confirmEmailChange) {
    Method.get
    Path(StartsWith("confirm-email-change"))
    // NB: I'm mainly using PartialConversions to allow printing. Will revisit the ergonomics later.
    Query("payload", String.fromSubstring.map(Encrypted<String>.fromRawValue))
  }

  _Routing(/Account.index) {
    Method.get
  }

  _Routing(/Account.invoices) {
    Path(StartsWith("invoices"))

    _Router<Account.Invoices> {
      _Routing(/Account.Invoices.index) {
        Method.get
      }

      _Routing(/Account.Invoices.show) {
        Method.get
        Path(String.fromSubstring.map(Stripe.Invoice.Id.fromRawValue))
      }
    }
  }

  _Routing(/Account.paymentInfo) {
    Path(StartsWith("payment-info"))

    _Router<Account.PaymentInfo> {
      _Routing(/Account.PaymentInfo.show) {
        Method.get
      }

      _Routing(/Account.PaymentInfo.update) {
        Method.post
        Body {
          // Maybe just FormField("token", valueParser)
          Form {
            Field("token") {
              Optionally { // TODO: Not sure if this is right
                String.fromSubstring.map(Stripe.Token.Id.fromRawValue)
              }
            }
          }
        }
      }
    }
  }

  _Routing(/Account.rss) {
    OneOf {
      Method.get
      Method("HEAD")
    }
    Path(StartsWith("rss"))
    Path(String.fromSubstring.map(User.RssSalt.fromRawValue))
  }

  _Routing(/Account.rssLegacy) {
    OneOf {
      Method.get
      Method("HEAD")
    }
    Path(StartsWith("rss"))
    Path(String.fromSubstring)
    Path(String.fromSubstring)
  }

  _Routing(/Account.subscription) {
    Path(StartsWith("subscription"))

    _Router<Account.Subscription> {
      _Routing<Account.Subscription>(/Account.Subscription.cancel) {
        Method.post
        Path(StartsWith("cancel"))
      }

      _Routing(/Account.Subscription.change) {
        _Router<Account.Subscription.Change> {
          _Routing(/Account.Subscription.Change.show) {
            Method.get
            Path(StartsWith("change"))
          }

          _Routing(/Account.Subscription.Change.update) {
            Method.post
            Path(StartsWith("change"))
            Body { FormData(Pricing?.self, decoder: formDecoder) }
          }
        }
      }

      _Routing(/Account.Subscription.reactivate) {
        Method.post
        Path(StartsWith("reactivate"))
      }
    }
  }

  _Routing<Account>(/Account.update) {
    Method.post
    Body { FormData(ProfileData?.self, decoder: formDecoder) }
  }
}
