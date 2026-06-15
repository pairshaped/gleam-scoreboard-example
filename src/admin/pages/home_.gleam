//// Admin default route.
////
//// This page exists so `/admin` is a real Proute page while delegating the
//// actual model, update, subscriptions, and view to the admin games page.

import admin/page_shared_state.{type AdminPageSharedState}
import admin/pages/games as games_page
import broadcasts
import generated/proute/admin/page_input
import lustre/effect.{type Effect}
import lustre/element.{type Element}

/// Proute contract: generated Proute code stores this page state inside its
/// route-level page wrapper. This alias deliberately reuses the games page model.
pub type Model =
  games_page.Model

/// Proute contract: generated Proute code wraps these messages so `/admin` can
/// reuse the games page update function without inventing a second message type.
pub type Message =
  games_page.Message

/// Proute contract: generated Proute code calls this to construct `/admin`.
/// This route reuses the games page model so `/admin` and `/admin/games` stay in sync.
pub fn initial_model(
  page_shared_state page_shared_state: AdminPageSharedState,
  query_params query_params: page_input.QueryParams,
) -> Model {
  games_page.initial_model(page_shared_state, query_params)
}

/// Proute contract: generated Proute code calls this when `AdminHomeMsg` is active.
pub fn update(
  page_shared_state page_shared_state: AdminPageSharedState,
  model model: Model,
  msg msg: Message,
) -> #(Model, Effect(Message)) {
  games_page.update(page_shared_state, model, msg)
}

// BROADCAST

/// Rally contract: generated browser code calls this whenever the active page
/// changes so the websocket joins the right broadcast topics.
pub fn broadcast_subscriptions(model: Model) -> List(broadcasts.Topic) {
  games_page.broadcast_subscriptions(model)
}

/// Rally contract: generated browser code calls this after a broadcast frame has
/// been decoded for one of this page's subscribed topics.
pub fn apply_broadcast(
  model model: Model,
  message message: broadcasts.Event,
) -> #(Model, Effect(Message)) {
  games_page.apply_broadcast(model:, message:)
}

/// Proute contract: generated Proute code calls this to render the active page.
pub fn view(model model: Model) -> Element(Message) {
  games_page.view(model:)
}
