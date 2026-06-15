import generated/proute/public/page_input
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import public/page_shared_state.{type PublicPageSharedState}

/// Proute contract: generated Proute code stores this page state inside its
/// route-level page wrapper.
pub type Model {
  Model(title: String)
}

/// Proute contract: generated Proute code wraps these messages before calling
/// this page's update function. The not-found page has no client events.
pub type Message {
  NoOp
}

/// Proute contract: generated Proute code calls this to construct the not-found page.
pub fn initial_model(
  _page_shared_state: PublicPageSharedState,
  _query_params: page_input.QueryParams,
) -> Model {
  Model(title: "Not found")
}

/// Proute contract: generated Proute code calls this when `NotFoundMsg` is active.
pub fn update(
  model model: Model,
  msg _msg: Message,
) -> #(Model, Effect(Message)) {
  #(model, effect.none())
}

/// Proute contract: generated Proute code calls this to render the active page.
pub fn view(model model: Model) -> Element(Message) {
  html.main([], [
    html.section([attribute.class("panel")], [
      html.h1([], [html.text(model.title)]),
      html.p([attribute.class("muted")], [
        html.text("Rally Scoreboard route placeholder."),
      ]),
    ]),
  ])
}
