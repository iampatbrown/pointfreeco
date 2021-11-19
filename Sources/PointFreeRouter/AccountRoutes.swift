import ApplicativeRouter
import Foundation
import Models
import PointFreePrelude
import Prelude
import Routing
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

private let accountRouters: [Router<Account>] = [
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

let _accountRouter = Routing<Account> {
  Routing(/Account.confirmEmailChange) {
    Method.get
    Path("confirm-email-change")
    Query("payload", String.fromSubstring.map(Encrypted<String>.fromRawValue))
  }

  Routing(/Account.index) {
    Method.get
  }

  Routing(/Account.invoices) {
    Path("invoices")

    Routing<Account.Invoices> {
      Routing(/Account.Invoices.index) {
        Method.get
      }

      Routing(/Account.Invoices.show) {
        Method.get
        Path { String.fromSubstring.map(Stripe.Invoice.Id.fromRawValue) }
      }
    }
  }

  Routing(/Account.paymentInfo) {
    Path("payment-info")

    Routing<Account.PaymentInfo> {
      Routing(/Account.PaymentInfo.show) {
        Method.get
      }

      Routing(/Account.PaymentInfo.update) {
        Method.post
        Body {
          FormField("token") {
            OneOf {
              Unwrapped { Optionally { Stripe.Token.Id.fromRawValue } }
              None<String, Stripe.Token.Id>()
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
    Path("rss")
    Path { String.fromSubstring.map(User.RssSalt.fromRawValue) }
  }

  Routing(/Account.rssLegacy) {
    OneOf {
      Method.get
      Method("HEAD")
    }
    Path("rss")
    Path {
      String.fromSubstring
      String.fromSubstring
    }
  }

  Routing(/Account.subscription) {
    Path("subscription")

    Routing<Account.Subscription> {
      Routing<Account.Subscription>(/Account.Subscription.cancel) {
        Method.post
        Path("cancel")
      }

      Routing(/Account.Subscription.change) {
        Routing<Account.Subscription.Change> {
          Routing(/Account.Subscription.Change.show) {
            Method.get
            Path("change")
          }

          Routing(/Account.Subscription.Change.update) {
            Method.post
            Path("change")
            Body { FormEncoded(Pricing?.self, decoder: urlFormDecoder) }
          }
        }
      }

      Routing(/Account.Subscription.reactivate) {
        Method.post
        Path("reactivate")
      }
    }
  }

  Routing<Account>(/Account.update) {
    Method.post
    Body { FormEncoded(ProfileData?.self, decoder: urlFormDecoder) }
  }
}
