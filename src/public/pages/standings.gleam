import broadcasts
import generated/proute/public/page_input
import gleam/int
import gleam/list
import gleam/order
import gleam/string
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

/// Derived view model for standings rows.
/// view builds these from the loaded GameSummary values so the standings table
/// does not need to store a second copy in Model.
pub type StandingRow {
  StandingRow(
    team_code: String,
    team_name: String,
    slug: String,
    wins: Int,
    losses: Int,
    points_for: Int,
    points_against: Int,
  )
}

/// Rally contract: generated Rally code uses this as the page's server request
/// envelope. `Load` is the request sent when the browser or SSR path needs this
/// page's data.
pub type ServerMsg {
  Load
}

/// Rally contract: `load` returns plain page data, then generated Rally code
/// wraps that data in `StandingsLoaded` so Libero can encode a typed load response.
/// The browser unwraps this before dispatching `Message.Loaded`.
pub type LoadResult {
  StandingsLoaded(games: List(GameSummary))
}

/// Proute contract: generated Proute code stores this page state inside its
/// route-level page wrapper.
pub type Model {
  Model(games: List(GameSummary))
}

/// Proute contract: generated Proute code wraps these messages so the app can
/// route browser events and load results back to this page's update function.
pub type Message {
  Loaded(Result(List(GameSummary), runtime_load.LoadError))
  NavigateTeam(slug: String)
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

/// Proute contract: generated Proute code calls this when a `StandingsMsg` is
/// active. This is ordinary Lustre update logic, but the function name and signature matter.
pub fn update(
  model model: Model,
  msg msg: Message,
) -> #(Model, Effect(Message)) {
  case msg {
    Loaded(Ok(games)) -> #(Model(games:), effect.none())
    Loaded(Error(_)) -> #(model, effect.none())
    NavigateTeam(_) -> #(model, effect.none())
  }
}

// BROADCAST

/// Rally contract: generated browser code calls this whenever the active page
/// changes so the websocket joins the right broadcast topics.
pub fn broadcast_subscriptions(_model: Model) -> List(broadcasts.Topic) {
  [broadcasts.all_games_topic()]
}

/// Rally contract: generated browser code calls this after a broadcast frame has
/// been decoded for the standings topic.
pub fn apply_broadcast(
  model model: Model,
  message message: broadcasts.Event,
) -> #(Model, Effect(Message)) {
  case message {
    broadcasts.BroadcastGameUpdated(game) -> game_updated(model, game)
  }
}

/// Applies one broadcast game snapshot before recomputing standings rows.
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
      section_head("League table"),
      view_standings(from_games(model.games), fn(slug) { NavigateTeam(slug:) }),
    ]),
  ])
}

// HELPERS

/// Recomputes the standings table from the current game summaries.
fn from_games(games: List(GameSummary)) -> List(StandingRow) {
  games
  |> list.fold([], add_game)
  |> list.sort(by: compare_rows)
}

fn view_standings(
  rows: List(StandingRow),
  on_navigate_team: fn(String) -> msg,
) -> Element(msg) {
  case rows {
    [] ->
      html.p([attribute.class("muted")], [html.text("Waiting for standings...")])
    _ ->
      html.table([attribute.class("standings-table")], [
        html.thead([], [
          html.tr([], [
            html.th([], [html.text("Team")]),
            html.th([], [html.text("W")]),
            html.th([], [html.text("L")]),
            html.th([], [html.text("PF")]),
            html.th([], [html.text("PA")]),
          ]),
        ]),
        html.tbody(
          [],
          list.map(rows, fn(row) { view_standing_row(row, on_navigate_team) }),
        ),
      ])
  }
}

fn add_game(rows: List(StandingRow), game: GameSummary) -> List(StandingRow) {
  let #(home_wins, home_losses, home_for, home_against) =
    home_contribution(game)
  let #(away_wins, away_losses, away_for, away_against) =
    away_contribution(game)

  rows
  |> upsert_row(
    team: game.home,
    wins: home_wins,
    losses: home_losses,
    points_for: home_for,
    points_against: home_against,
  )
  |> upsert_row(
    team: game.away,
    wins: away_wins,
    losses: away_losses,
    points_for: away_for,
    points_against: away_against,
  )
}

// nolint: label_possible -- this fold helper is called through a pipe; labelling the accumulator makes the call harder to read.
fn upsert_row(
  current_rows: List(StandingRow),
  team team: Team,
  wins wins: Int,
  losses losses: Int,
  points_for points_for: Int,
  points_against points_against: Int,
) -> List(StandingRow) {
  case list.find(current_rows, fn(row) { row.team_code == team.code }) {
    Ok(_) ->
      list.map(current_rows, fn(row) {
        case row.team_code == team.code {
          True ->
            StandingRow(
              ..row,
              wins: row.wins + wins,
              losses: row.losses + losses,
              points_for: row.points_for + points_for,
              points_against: row.points_against + points_against,
            )
          False -> row
        }
      })
    Error(Nil) ->
      list.append(current_rows, [
        StandingRow(
          team_code: team.code,
          team_name: team.name,
          slug: team.slug,
          wins: wins,
          losses: losses,
          points_for: points_for,
          points_against: points_against,
        ),
      ])
  }
}

fn home_contribution(game: GameSummary) -> #(Int, Int, Int, Int) {
  case game.status {
    Final -> #(
      bool_to_int(game.home_score > game.away_score),
      bool_to_int(game.home_score < game.away_score),
      game.home_score,
      game.away_score,
    )
    _ -> #(0, 0, 0, 0)
  }
}

fn away_contribution(game: GameSummary) -> #(Int, Int, Int, Int) {
  case game.status {
    Final -> #(
      bool_to_int(game.away_score > game.home_score),
      bool_to_int(game.away_score < game.home_score),
      game.away_score,
      game.home_score,
    )
    _ -> #(0, 0, 0, 0)
  }
}

fn compare_rows(a: StandingRow, b: StandingRow) -> order.Order {
  case int.compare(b.wins, a.wins) {
    order.Eq ->
      case int.compare(b.points_for, a.points_for) {
        order.Eq -> string.compare(a.team_code, b.team_code)
        points_order -> points_order
      }
    wins_order -> wins_order
  }
}

// nolint: prefer_guard_clause -- the case expression is clearer for a bool-to-int conversion than a guard with negation.
fn bool_to_int(value: Bool) -> Int {
  case value {
    True -> 1
    False -> 0
  }
}

fn view_standing_row(
  row: StandingRow,
  on_navigate_team: fn(String) -> msg,
) -> Element(msg) {
  html.tr([], [
    html.td([], [
      html.a(
        [
          attribute.href("/teams/" <> row.slug),
          event.on_click(on_navigate_team(row.slug))
            |> event.prevent_default,
        ],
        [
          html.strong([], [html.text(row.team_code)]),
          html.text(" " <> row.team_name),
        ],
      ),
    ]),
    html.td([], [html.text(int.to_string(row.wins))]),
    html.td([], [html.text(int.to_string(row.losses))]),
    html.td([], [html.text(int.to_string(row.points_for))]),
    html.td([], [html.text(int.to_string(row.points_against))]),
  ])
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

fn section_head(title: String) -> Element(msg) {
  html.div([attribute.class("section-head")], [
    html.div([], [html.h1([], [html.text(title)]), html.span([], [])]),
  ])
}

// SERVER

@target(erlang)
/// Rally contract: generated SSR and websocket code call this on the Erlang
/// target. The returned data is wrapped in `LoadResult` for the wire.
/// Focused tests also call it directly.
pub fn load(
  db: sqlight.Connection,
) -> Result(List(GameSummary), runtime_load.LoadError) {
  case games_sql.list_public_games(db:, team_filter: "") {
    Ok(rows) -> Ok(list.map(rows, game_summary_from_row))
    Error(sqlight.SqlightError(..)) ->
      Error(runtime_load.LoadError(message: "Could not load standings."))
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
