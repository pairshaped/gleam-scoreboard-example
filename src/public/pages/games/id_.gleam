import broadcasts
import generated/proute/public/page_input
import gleam/int
import gleam/option.{type Option, None, Some}
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import public/page_shared_state.{type PublicPageSharedState}
import rally/runtime/load as runtime_load

@target(erlang)
import generated/sql/public/pages/games/id__sql as games_sql
@target(erlang)
import sqlight

// TYPES

pub type GameStatus {
  Scheduled
  Live(period: String)
  Final
}

pub type Team {
  Team(code: String, name: String, slug: String)
}

pub type GameDetail {
  GameDetail(
    id: Int,
    home: Team,
    away: Team,
    home_score: Int,
    away_score: Int,
    status: GameStatus,
  )
}

/// Server request to load one game by id.
pub type ServerMsg {
  Load(game_id: Int)
}

pub type LoadResult {
  PublicGameDetailLoaded(game: GameDetail)
}

pub type Model {
  Model(game: Option(GameDetail))
}

pub type Message {
  Loaded(Result(GameDetail, runtime_load.LoadError))
  NavigateTeam(slug: String)
}

// INIT

/// generated/proute/public/pages module calls this when the route first builds
/// the page.
/// Most Rally pages omit this and let generated browser/SSR glue layer loaded
/// data onto `initial_model`. Keep `init` only for page-specific client startup
/// work, such as browser APIs, local storage, focus, measurement, or one-off DOM
/// effects. This example shows a browser alert and deliberately does not start a
/// data load; generated Rally load glue owns that.
pub fn init(
  page_shared_state page_shared_state: PublicPageSharedState,
  route_params route_params: page_input.GamesIdRouteParams,
  query_params query_params: page_input.QueryParams,
) -> #(Model, Effect(Message)) {
  #(
    initial_model(page_shared_state, route_params, query_params),
    effect.from(fn(_dispatch) { show_game_detail_alert(route_params.id) }),
  )
}

/// generated/proute/public/pages module calls this to construct an empty page before
/// Rally applies hydrated or freshly loaded data.
pub fn initial_model(
  _page_shared_state: PublicPageSharedState,
  _route_params: page_input.GamesIdRouteParams,
  _query_params: page_input.QueryParams,
) -> Model {
  Model(game: None)
}

@target(javascript)
/// Browser-only demo alert used by this page's optional init hook.
@external(javascript, "./id__ffi.mjs", "show_game_detail_alert")
fn show_game_detail_alert(id: String) -> Nil

@target(erlang)
/// Server-side no-op so SSR can compile the shared init code.
fn show_game_detail_alert(_id: String) -> Nil {
  Nil
}

// UPDATE

/// generated/proute/public/pages module calls this when a GamesIdMsg is active on the
/// current page.
pub fn update(
  model model: Model,
  msg msg: Message,
) -> #(Model, Effect(Message)) {
  case msg {
    Loaded(Ok(game)) -> #(Model(game: Some(game)), effect.none())
    Loaded(Error(_)) -> #(model, effect.none())
    NavigateTeam(_) -> #(model, effect.none())
  }
}

// BROADCAST

/// Required because generated/rally/browser_app module calls this to sync active broadcast topics.
pub fn broadcast_subscriptions(
  route_params: page_input.GamesIdRouteParams,
  _model: Model,
) -> List(broadcasts.Topic) {
  case int.parse(route_params.id) {
    Ok(game_id) -> [broadcasts.game_topic(game_id)]
    Error(Nil) -> []
  }
}

/// Required because generated/rally/browser_app module calls this after a game update frame
/// is decoded for this page's route game topic.
pub fn apply_broadcast(
  model model: Model,
  message message: broadcasts.Event,
) -> #(Model, Effect(Message)) {
  case message {
    broadcasts.BroadcastGameUpdated(game) -> game_updated(model, game)
  }
}

/// Applies a broadcast snapshot when it matches the loaded game detail.
pub fn game_updated(
  model model: Model,
  game game: broadcasts.GameSnapshot,
) -> #(Model, Effect(Message)) {
  let broadcasts.BroadcastGameSnapshot(id:, ..) = game
  case model.game {
    Some(detail) if detail.id == id -> #(
      Model(game: Some(update_detail(detail, game))),
      effect.none(),
    )
    _ -> #(model, effect.none())
  }
}

// VIEW

pub fn view(model model: Model) -> Element(Message) {
  html.main([], [
    html.section([attribute.class("panel")], [
      section_head("Game detail"),
      view_game_detail(model.game, fn(slug) { NavigateTeam(slug:) }),
    ]),
  ])
}

// HELPERS

fn view_game_detail(
  game: Option(GameDetail),
  on_navigate_team: fn(String) -> msg,
) -> Element(msg) {
  case game {
    None -> html.p([attribute.class("muted")], [html.text("Loading game...")])
    Some(game) ->
      html.div([], [
        html.div([attribute.class("game-card")], [
          html.div([attribute.class("team-row")], [
            html.a(
              [
                attribute.href("/teams/" <> game.away.slug),
                event.on_click(on_navigate_team(game.away.slug))
                  |> event.prevent_default,
              ],
              [html.strong([], [html.text(game.away.name)])],
            ),
            html.span([attribute.class("score")], [
              html.text(int.to_string(game.away_score)),
            ]),
          ]),
          html.div([attribute.class("team-row")], [
            html.a(
              [
                attribute.href("/teams/" <> game.home.slug),
                event.on_click(on_navigate_team(game.home.slug))
                  |> event.prevent_default,
              ],
              [html.strong([], [html.text(game.home.name)])],
            ),
            html.span([attribute.class("score")], [
              html.text(int.to_string(game.home_score)),
            ]),
          ]),
          status_badge(game.status),
        ]),
      ])
  }
}

fn update_detail(
  detail: GameDetail,
  game: broadcasts.GameSnapshot,
) -> GameDetail {
  let broadcasts.BroadcastGameSnapshot(home_score:, away_score:, status:, ..) =
    game
  GameDetail(
    ..detail,
    home_score:,
    away_score:,
    status: broadcast_game_status(status),
  )
}

fn broadcast_game_status(status: broadcasts.GameStatus) -> GameStatus {
  case status {
    broadcasts.BroadcastScheduled -> Scheduled
    broadcasts.BroadcastLive(period) -> Live(period)
    broadcasts.BroadcastFinal -> Final
  }
}

fn section_head(title: String) -> Element(msg) {
  html.div([attribute.class("section-head")], [
    html.div([], [html.h1([], [html.text(title)]), html.span([], [])]),
  ])
}

fn status_badge(status: GameStatus) -> Element(msg) {
  case status {
    Scheduled -> html.span([attribute.class("badge")], [html.text("Scheduled")])
    Live(period) ->
      html.span([attribute.class("badge live")], [html.text(period)])
    Final -> html.span([attribute.class("badge final")], [html.text("Final")])
  }
}

// SERVER

@target(erlang)
/// Required because generated/rally/server_ssr and generated/rally/server_ws
/// modules call this, then wrap page data in the Rally/Libero load result shape.
pub fn load(
  db: sqlight.Connection,
  game_id: Int,
) -> Result(GameDetail, runtime_load.LoadError) {
  case games_sql.get_game(db:, game_id:) {
    Ok([row, ..]) -> Ok(game_detail_from_row(row))
    Ok([]) -> Error(runtime_load.LoadError(message: "Game not found."))
    Error(sqlight.SqlightError(..)) ->
      Error(runtime_load.LoadError(message: "Could not load game."))
  }
}

@target(erlang)
fn game_detail_from_row(row: games_sql.GetGameRow) -> GameDetail {
  GameDetail(
    id: row.id,
    home: Team(row.home_code, row.home_name, row.home_slug),
    away: Team(row.away_code, row.away_name, row.away_slug),
    home_score: row.home_score,
    away_score: row.away_score,
    status: game_status(row.period, row.final),
  )
}

@target(erlang)
fn game_status(period: String, final: Int) -> GameStatus {
  case final == 1, period {
    True, _ -> Final
    False, "Scheduled" -> Scheduled
    False, _ -> Live(period)
  }
}
