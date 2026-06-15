import broadcasts
import components/ui
import generated/proute/public/page_input
import gleam/int
import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import public/page_shared_state.{type PublicPageSharedState}
import rally/runtime/load as runtime_load

@target(erlang)
import generated/sql/public/pages/games_sql
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

pub type GameSummary {
  GameSummary(
    id: Int,
    home: Team,
    away: Team,
    home_score: Int,
    away_score: Int,
    status: GameStatus,
  )
}

/// Rally contract: generated Rally code uses this as the page's server request
/// envelope. `Load` is the request sent when the browser or SSR path needs this
/// page's data.
pub type ServerMsg {
  Load
}

/// Rally contract: `load` returns plain page data, then generated Rally code
/// wraps that data in `GamesLoaded` so Libero can encode a typed load response.
/// The browser unwraps this before dispatching `Message.Loaded`.
pub type LoadResult {
  GamesLoaded(games: List(GameSummary))
}

/// Proute contract: generated Proute code stores this page state inside its
/// route-level page wrapper.
pub type Model {
  Model(games: List(GameSummary))
}

/// Proute contract: generated Proute code wraps these messages so the app can
/// route browser events and load results back to this page's update function.
pub type Message {
  NavigateTeam(slug: String)
  NavigateGame(id: Int)
  Loaded(Result(List(GameSummary), runtime_load.LoadError))
}

/// Proute contract: generated Proute code calls this to construct an empty page.
/// Rally later applies hydrated data or the result of `load`.
pub fn initial_model(
  _page_shared_state: PublicPageSharedState,
  _query_params: page_input.QueryParams,
) -> Model {
  Model(games: [])
}

// UPDATE

/// Proute contract: generated Proute code calls this when a `GamesMsg` is active.
/// This is ordinary Lustre update logic, but the function name and signature matter.
pub fn update(
  model model: Model,
  msg msg: Message,
) -> #(Model, Effect(Message)) {
  case msg {
    Loaded(Ok(games)) -> #(Model(games:), effect.none())
    Loaded(Error(_)) -> #(model, effect.none())
    NavigateTeam(_) | NavigateGame(_) -> #(model, effect.none())
  }
}

// BROADCAST

/// Rally contract: generated browser code calls this whenever the active page
/// changes so the websocket joins the right broadcast topics.
pub fn broadcast_subscriptions(_model: Model) -> List(broadcasts.Topic) {
  [broadcasts.all_games_topic()]
}

/// Rally contract: generated browser code calls this after a broadcast frame has
/// been decoded for one of this page's subscribed topics.
pub fn apply_broadcast(
  model model: Model,
  message message: broadcasts.Event,
) -> #(Model, Effect(Message)) {
  case message {
    broadcasts.BroadcastGameUpdated(game) -> game_updated(model, game)
  }
}

/// Applies one broadcast game snapshot to the loaded games list.
pub fn game_updated(
  model model: Model,
  game game: broadcasts.GameSnapshot,
) -> #(Model, Effect(Message)) {
  let broadcasts.BroadcastGameSnapshot(id:, ..) = game
  let games =
    list.map(model.games, fn(summary) {
      case summary.id == id {
        True -> update_summary(summary, game)
        False -> summary
      }
    })

  #(Model(games:), effect.none())
}

// VIEW

/// Proute contract: generated Proute code calls this to render the active page.
pub fn view(model model: Model) -> Element(Message) {
  html.main([], [
    html.section([attribute.class("panel")], [
      ui.section_head("Today", ""),
      view_game_grid(model.games, fn(slug) { NavigateTeam(slug:) }, fn(id) {
        NavigateGame(id:)
      }),
    ]),
  ])
}

// HELPERS

fn view_game_grid(
  games: List(GameSummary),
  on_navigate_team: fn(String) -> msg,
  on_navigate_game: fn(Int) -> msg,
) -> Element(msg) {
  case games {
    [] ->
      html.p([attribute.class("muted")], [html.text("Waiting for scores...")])
    _ ->
      html.div(
        [attribute.class("game-grid")],
        list.map(games, fn(game) {
          view_game_card(game, on_navigate_team, on_navigate_game)
        }),
      )
  }
}

fn view_game_card(
  game: GameSummary,
  on_navigate_team: fn(String) -> msg,
  on_navigate_game: fn(Int) -> msg,
) -> Element(msg) {
  html.article([attribute.class("game-card")], [
    html.div([attribute.class("team-row")], [
      team_link(game.away, on_navigate_team),
      html.span([attribute.class("score")], [
        html.text(int.to_string(game.away_score)),
      ]),
    ]),
    html.div([attribute.class("team-row")], [
      team_link(game.home, on_navigate_team),
      html.span([attribute.class("score")], [
        html.text(int.to_string(game.home_score)),
      ]),
    ]),
    html.div([attribute.class("score-line")], [
      status_badge(game.status),
      html.a(
        [
          attribute.href("/games/" <> int.to_string(game.id)),
          event.on_click(on_navigate_game(game.id))
            |> event.prevent_default,
        ],
        [html.text("Details")],
      ),
    ]),
  ])
}

fn team_link(team: Team, on_navigate_team: fn(String) -> msg) -> Element(msg) {
  html.a(
    [
      attribute.href("/teams/" <> team.slug),
      event.on_click(on_navigate_team(team.slug))
        |> event.prevent_default,
    ],
    [html.strong([], [html.text(team.name)])],
  )
}

fn status_badge(status: GameStatus) -> Element(msg) {
  case status {
    Scheduled -> html.span([attribute.class("badge")], [html.text("Scheduled")])
    Live(period) ->
      html.span([attribute.class("badge live")], [html.text(period)])
    Final -> html.span([attribute.class("badge final")], [html.text("Final")])
  }
}

fn update_summary(
  summary: GameSummary,
  game: broadcasts.GameSnapshot,
) -> GameSummary {
  let broadcasts.BroadcastGameSnapshot(home_score:, away_score:, status:, ..) =
    game
  GameSummary(
    ..summary,
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

// SERVER

@target(erlang)
/// Rally contract: generated SSR and websocket code call this on the Erlang
/// target. The returned data is wrapped in `LoadResult` for the wire.
pub fn load(
  db: sqlight.Connection,
) -> Result(List(GameSummary), runtime_load.LoadError) {
  case games_sql.list_public_games(db:, team_filter: "") {
    Ok(rows) -> Ok(list.map(rows, game_summary_from_row))
    Error(sqlight.SqlightError(..)) ->
      Error(runtime_load.LoadError(message: "Could not load games."))
  }
}

@target(erlang)
fn game_summary_from_row(row: games_sql.ListPublicGamesRow) -> GameSummary {
  GameSummary(
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
