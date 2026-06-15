import generated/proute/public/page_input
import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import public/page_shared_state.{type PublicPageSharedState}

/// Proute contract: generated Proute code stores this page state inside its
/// route-level page wrapper.
pub type Model {
  Model(return_to: String, invalid: Bool, sent: Bool)
}

/// Proute contract: generated Proute code wraps these messages before calling
/// this page's update function. This form page has no client events yet.
pub type Message {
  NoOp
}

/// Proute contract: generated Proute code calls this to construct the sign-in page.
/// It keeps the return target and error flag in the model so SSR and browser
/// hydration render the same form without needing any init effects.
pub fn initial_model(
  _page_shared_state: PublicPageSharedState,
  query_params: page_input.QueryParams,
) -> Model {
  let page_input.QueryParams(values:) = query_params
  Model(
    return_to: find_query(values, "return_to") |> safe_admin_return_to,
    invalid: find_query(values, "error") == Ok("invalid"),
    sent: find_query(values, "sent") == Ok("1"),
  )
}

/// Proute contract: generated Proute code calls this when `SignInMsg` is active.
pub fn update(
  model model: Model,
  msg _msg: Message,
) -> #(Model, Effect(Message)) {
  #(model, effect.none())
}

/// Proute contract: generated Proute code calls this to render the active page.
pub fn view(model model: Model) -> Element(Message) {
  html.section([attribute.class("panel")], [
    html.h1([], [html.text("Sign in")]),
    html.p([attribute.class("muted")], [
      html.text("Use the demo admin code to open the score desk."),
    ]),
    case model.sent {
      True ->
        html.p([attribute.class("muted")], [
          html.text("If that email is known, the sign-in code was sent."),
        ])
      False -> html.text("")
    },
    case model.invalid {
      True ->
        html.p([attribute.class("auth-error")], [
          html.text("Invalid sign-in code."),
        ])
      False -> html.text("")
    },
    html.form(
      [
        attribute.method("post"),
        attribute.action("/sign_in/code"),
        attribute.class("sign-in-form"),
      ],
      [
        html.input([
          attribute.type_("hidden"),
          attribute.name("return_to"),
          attribute.value(model.return_to),
        ]),
        html.label([attribute.for("email")], [html.text("Email")]),
        html.input([
          attribute.id("email"),
          attribute.name("email"),
          attribute.type_("email"),
          attribute.autocomplete("email"),
          attribute.placeholder("admin@example.com"),
          attribute.required(True),
        ]),
        html.button([attribute.type_("submit")], [html.text("Send Code")]),
      ],
    ),
    html.form(
      [
        attribute.method("post"),
        attribute.action("/sign_in"),
        attribute.class("sign-in-form"),
      ],
      [
        html.input([
          attribute.type_("hidden"),
          attribute.name("return_to"),
          attribute.value(model.return_to),
        ]),
        html.label([attribute.for("code")], [html.text("Sign-in code")]),
        html.input([
          attribute.id("code"),
          attribute.name("code"),
          attribute.type_("text"),
          attribute.autocomplete("one-time-code"),
          attribute.placeholder("A1Z9Q"),
          attribute.required(True),
        ]),
        html.button([attribute.type_("submit")], [html.text("Sign In")]),
      ],
    ),
  ])
}

fn find_query(
  values: List(#(String, String)),
  key: String,
) -> Result(String, Nil) {
  list.find_map(values, fn(pair) {
    case pair.0 {
      name if name == key -> Ok(pair.1)
      _ -> Error(Nil)
    }
  })
}

/// Keeps post-sign-in redirects inside the admin route space.
fn safe_admin_return_to(path: Result(String, Nil)) -> String {
  case path {
    Ok("/admin") -> "/admin"
    Ok("/admin/" <> rest) -> "/admin/" <> rest
    _ -> "/admin/games"
  }
}
