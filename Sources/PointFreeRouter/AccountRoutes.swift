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

let _accountRouter = _Router<Account> {
  _Routing(/Account.confirmEmailChange) {
    Method.get
    Path(literal: "confirm-email-change")
    // NB: I'm mainly using PartialConversions to allow printing. Will revisit the ergonomics later.
    Query("payload", String.fromSubstring >>> Encrypted<String>.fromRawValue)
  }

  _Routing(/Account.index) {
    Method.get
  }

  _Routing(/Account.invoices) {
    Path(literal: "invoices")

    _Router<Account.Invoices> {
      _Routing(/Account.Invoices.index) {
        Method.get
      }

      _Routing(/Account.Invoices.show) {
        Method.get
        Path(String.fromSubstring >>> Stripe.Invoice.Id.fromRawValue)
      }
    }
  }

  _Routing(/Account.paymentInfo) {
    Path(literal: "payment-info")

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
                String.fromSubstring >>> Stripe.Token.Id.fromRawValue
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
    Path(literal: "rss")
    Path(String.fromSubstring >>> User.RssSalt.fromRawValue)
  }

  _Routing(/Account.rssLegacy) {
    OneOf {
      Method.get
      Method("HEAD")
    }
    Path(literal: "rss")
    Path(String.fromSubstring)
    Path(String.fromSubstring)
  }

  _Routing(/Account.subscription) {
    Path(literal: "subscription")

    _Router<Account.Subscription> {
      _Routing<Account.Subscription>(/Account.Subscription.cancel) {
        Method.post
        Path(literal: "cancel")
      }

      _Routing(/Account.Subscription.change) {
        _Router<Account.Subscription.Change> {
          _Routing(/Account.Subscription.Change.show) {
            Method.get
            Path(literal: "change")
          }

          _Routing(/Account.Subscription.Change.update) {
            Method.post
            Path(literal: "change")
            Body { FormData(Pricing?.self, decoder: formDecoder) }
          }
        }
      }

      _Routing(/Account.Subscription.reactivate) {
        Method.post
        Path(literal: "reactivate")
      }
    }
  }

  _Routing<Account>(/Account.update) {
    Method.post
    Body { FormData(ProfileData?.self, decoder: formDecoder) }
  }
}


let __accountRouter = __Routing<Account> {
  __Routing(/Account.confirmEmailChange) {
    Method.get
    Path(literal: "confirm-email-change")
    // NB: I'm mainly using PartialConversions to allow printing. Will revisit the ergonomics later.
    Query("payload", String.fromSubstring >>> Encrypted<String>.fromRawValue)
  }

  __Routing(/Account.index) {
    Method.get
  }

  __Routing(/Account.invoices) {
    Path(literal: "invoices")

    __Routing<Account.Invoices> {
      __Routing(/Account.Invoices.index) {
        Method.get
      }

      __Routing(/Account.Invoices.show) {
        Method.get
        Path(String.fromSubstring >>> Stripe.Invoice.Id.fromRawValue)
      }
    }
  }

  __Routing(/Account.paymentInfo) {
    Path(literal: "payment-info")

    __Routing<Account.PaymentInfo> {
      __Routing(/Account.PaymentInfo.show) {
        Method.get
      }

      __Routing(/Account.PaymentInfo.update) {
        Method.post
        Body {
          // Maybe just FormField("token", valueParser)
          Form {
            Field("token") {
              Optionally { // TODO: Not sure if this is right
                String.fromSubstring >>> Stripe.Token.Id.fromRawValue
              }
            }
          }
        }
      }
    }
  }

  __Routing(/Account.rss) {
    OneOf {
      Method.get
      Method("HEAD")
    }
    Path(literal: "rss")
    Path(String.fromSubstring >>> User.RssSalt.fromRawValue)
  }

  __Routing(/Account.rssLegacy) {
    OneOf {
      Method.get
      Method("HEAD")
    }
    Path(literal: "rss")
    Path(String.fromSubstring)
    Path(String.fromSubstring)
  }

  __Routing(/Account.subscription) {
    Path(literal: "subscription")

    __Routing<Account.Subscription> {
      __Routing<Account.Subscription>(/Account.Subscription.cancel) {
        Method.post
        Path(literal: "cancel")
      }

      __Routing(/Account.Subscription.change) {
        __Routing<Account.Subscription.Change> {
          __Routing(/Account.Subscription.Change.show) {
            Method.get
            Path(literal: "change")
          }

          __Routing(/Account.Subscription.Change.update) {
            Method.post
            Path(literal: "change")
            Body { FormData(Pricing?.self, decoder: formDecoder) }
          }
        }
      }

      __Routing(/Account.Subscription.reactivate) {
        Method.post
        Path(literal: "reactivate")
      }
    }
  }

  __Routing<Account>(/Account.update) {
    Method.post
    Body { FormData(ProfileData?.self, decoder: formDecoder) }
  }
}

let accountConfirmEmailChangePath = /Account.confirmEmailChange
let r0 = __Routing(accountConfirmEmailChangePath) {
  Method.get
  Path(literal: "confirm-email-change")
  // NB: I'm mainly using PartialConversions to allow printing. Will revisit the ergonomics later.
  Query("payload", String.fromSubstring >>> Encrypted<String>.fromRawValue)
}

let accountIndexPath = /Account.index
let r1 = __Routing(accountIndexPath) {
  Method.get
}

let r1Literal = __Routing(/Account.index) {
  Method.get
}

let accountInvoicesPath = /Account.invoices // <1ms to type-check
let accountInvoicesIndexPath = /Account.Invoices.index // <1ms to type-check
let accountsInvoicesShowPath = /Account.Invoices.show // <1ms to type-check
let r2 = __Routing(accountInvoicesPath) { // ~3ms to type-check
  Path(literal: "invoices")
  __Routing<Account.Invoices> {
    __Routing(accountInvoicesIndexPath) { Method.get }
    __Routing(accountsInvoicesShowPath) {
      Method.get
      Path(String.fromSubstring >>> Stripe.Invoice.Id.fromRawValue)
    }
  }
}

let r2literal = __Routing(/Account.invoices) { // ~17ms to type-check
  Path(literal: "invoices")
  __Routing<Account.Invoices> {
    __Routing(/Account.Invoices.index) { Method.get }
    __Routing(/Account.Invoices.show) {
      Method.get
      Path(String.fromSubstring >>> Stripe.Invoice.Id.fromRawValue)
    }
  }
}

let r2literal2 = __Routing(/Account.invoices) {
  Path(literal: "invoices")

  __Routing<Account.Invoices> {
    __Routing((/Account.Invoices.index)) {
      Method.get
    }

    __Routing((/Account.Invoices.show)) {
      Method.get
      Path(String.fromSubstring >>> Stripe.Invoice.Id.fromRawValue)
    }
  }
}

let r3literal = __Routing(/Account.invoices) {
  Path(literal: "invoices")

  __Routing<Account.Invoices> {
    __Routing(/Account.Invoices.index) {
      Method.get
    }

    __Routing(/Account.Invoices.show) {
      Method.get
      Path(String.fromSubstring >>> Stripe.Invoice.Id.fromRawValue)
    }
  }
}

let paymentInfoPath = /Account.paymentInfo
let paymentInfoShowPath = /Account.PaymentInfo.show
let paymentInfoUpdatePath = /Account.PaymentInfo.update
let r3 = __Routing(paymentInfoPath) {
  Path(literal: "payment-info")

  __Routing<Account.PaymentInfo> {
    __Routing(paymentInfoShowPath) {
      Method.get
    }

    __Routing(paymentInfoUpdatePath) {
      Method.post
      Body {
        // Maybe just FormField("token", valueParser)
        Form {
          Field("token") {
            Optionally { // TODO: Not sure if this is right
              String.fromSubstring >>> Stripe.Token.Id.fromRawValue
            }
          }
        }
      }
    }
  }
}

let rssPath = /Account.rss
let r4 = __Routing(rssPath) {
  OneOf {
    Method.get
    Method("HEAD")
  }
  Path(literal: "rss")
  Path(String.fromSubstring >>> User.RssSalt.fromRawValue)
}

let rssLegacyPath = /Account.rssLegacy

// let r5Path = __Routing(rssLegacyPath) {
//  OneOf {
//    Method.get
//    Method("HEAD")
//  }
//  Path(literal: "rss")
//  Path(String.fromSubstring)
//  Path(String.fromSubstring)
// }

let rssLegacyPathCast = /Account.rssLegacy as CasePath<Account, (String, String)>
let r5 = __Routing(rssLegacyPathCast) {
  OneOf {
    Method.get
    Method("HEAD")
  }
  Path(literal: "rss")
  Path(String.fromSubstring)
  Path(String.fromSubstring)
}

let r5Literal = __Routing(/Account.rssLegacy) {
  OneOf {
    Method.get
    Method("HEAD")
  }
  Path(literal: "rss")
  Path(String.fromSubstring)
  Path(String.fromSubstring)
}

let subscriptionPath = /Account.subscription
let subscriptionCancelPath = /Account.Subscription.cancel
let subscriptionChangePath = /Account.Subscription.change
let subscriptionChangeShowPath = /Account.Subscription.Change.show
let subscriptionChangeUpdatePath = /Account.Subscription.Change.update
let subscriptionReactivatePath = /Account.Subscription.reactivate
let r6 = __Routing(subscriptionPath) {
  Path(literal: "subscription")

  __Routing<Account.Subscription> {
    __Routing<Account.Subscription>(subscriptionCancelPath) {
      Method.post
      Path(literal: "cancel")
    }

    __Routing(subscriptionChangePath) {
      __Routing<Account.Subscription.Change> {
        __Routing(subscriptionChangeShowPath) {
          Method.get
          Path(literal: "change")
        }

        __Routing(subscriptionChangeUpdatePath) {
          Method.post
          Path(literal: "change")
          Body { FormData(Pricing?.self, decoder: formDecoder) }
        }
      }
    }

    __Routing(subscriptionReactivatePath) {
      Method.post
      Path(literal: "reactivate")
    }
  }
}

let accountUpdatePath = /Account.update
let r7 = __Routing<Account>(accountUpdatePath) {
  Method.post
  Body { FormData(ProfileData?.self, decoder: formDecoder) }
}
