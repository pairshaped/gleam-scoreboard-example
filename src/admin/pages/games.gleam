import admin/page_shared_state.{type AdminPageSharedState}
import broadcasts
import generated/proute/admin/page_input
import gleam/int
import gleam/list
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/event
import rally/runtime/load as runtime_load

@target(erlang)
import generated/sql/admin/pages/games_sql
@target(erlang)
import sqlight

@target(javascript)
import generated/rally/server

// TYPES

pub type GameStatus {
  Scheduled
  Live(period: String)
  Final
}

pub type GameSummary {
  GameSummary(
    id: Int,
    home_code: String,
    away_code: String,
    home_score: Int,
    away_score: Int,
    status: GameStatus,
    needs_attention: Bool,
  )
}

/// Rally contract: handle_save returns this as the page's save result.
/// Generated websocket code encodes it for the requester, and broadcast handling
/// can also project BroadcastGameUpdated frames into this page-local shape.
pub type GameUpdate {
  GameUpdate(
    id: Int,
    home_code: String,
    away_code: String,
    home_score: Int,
    away_score: Int,
    status: GameStatus,
  )
}

/// Rally contract: `load` returns plain page data, then generated Rally code
/// wraps that data in `GamesLoaded` so Libero can encode a typed load response.
/// The browser unwraps this before dispatching `Message.Loaded`.
pub type LoadResult {
  GamesLoaded(games: List(GameSummary))
}

/// Rally contract: handle_save returns this when a page save fails.
/// Generated websocket code converts it into the transport save error shape.
pub type SaveError {
  SaveError(message: String)
}

/// Rally contract: generated Rally code uses ServerMsg as the page's server
/// request envelope. Load triggers load; save variants are decoded and passed
/// to handle_save.
pub type ServerMsg {
  Load
  UpdateScore(game_id: Int, home_score: Int, away_score: Int, period: String)
  MarkFinal(game_id: Int)
}

/// Proute contract: generated Proute code stores this page state inside its
/// route-level page wrapper.
pub type Model {
  Model(games: List(GameSummary))
}

/// Proute contract: generated Proute code wraps these messages so the app can
/// route browser events, load results, and save results back to this page's
/// update function.
pub type Message {
  AdjustAway(id: Int, home_score: Int, away_score: Int, delta: Int)
  AdjustHome(id: Int, home_score: Int, away_score: Int, delta: Int)
  Loaded(Result(List(GameSummary), runtime_load.LoadError))
  MarkFinalClicked(id: Int)
  Saved(Result(GameUpdate, SaveError))
}

/// Proute contract: generated Proute code calls this to construct an empty page.
/// Rally later applies hydrated data or the result of `load`.
pub fn initial_model(
  _page_shared_state: AdminPageSharedState,
  _query_params: page_input.QueryParams,
) -> Model {
  Model(games: [])
}

// UPDATE

/// Proute contract: generated Proute code calls this when an `AdminGamesMsg` is
/// active. This is ordinary Lustre update logic, but the function name and signature matter.
pub fn update(
  _page_shared_state: AdminPageSharedState,
  model model: Model,
  msg msg: Message,
) -> #(Model, Effect(Message)) {
  case msg {
    Loaded(Ok(games)) -> #(Model(games:), effect.none())
    Loaded(Error(_)) -> #(model, effect.none())
    Saved(Ok(game)) -> #(
      upsert_game(model, game_update_summary(game)),
      effect.none(),
    )
    Saved(Error(_)) -> #(model, effect.none())
    AdjustAway(..) | AdjustHome(..) | MarkFinalClicked(..) -> #(
      model,
      message_effect(msg),
    )
  }
}

// BROADCAST

/// Rally contract: generated browser code calls this whenever the active page
/// changes so the websocket joins the right broadcast topics.
pub fn broadcast_subscriptions(_model: Model) -> List(broadcasts.Topic) {
  [broadcasts.admin_games_topic()]
}

/// Rally contract: generated browser code calls this after a broadcast frame has
/// been decoded for the admin games topic.
pub fn apply_broadcast(
  model model: Model,
  message message: broadcasts.Event,
) -> #(Model, Effect(Message)) {
  case message {
    broadcasts.BroadcastGameUpdated(game) ->
      game_updated(model, admin_game_update(game))
  }
}

/// Applies one admin game update to the loaded admin games list.
pub fn game_updated(
  model model: Model,
  game game: GameUpdate,
) -> #(Model, Effect(Message)) {
  #(upsert_game(model, game_update_summary(game)), effect.none())
}

// VIEW

/// Proute contract: generated Proute code calls this to render the active page.
pub fn view(model model: Model) -> Element(Message) {
  view_games(
    games: model.games,
    on_adjust_away: fn(id, home_score, away_score, delta) {
      AdjustAway(id:, home_score:, away_score:, delta:)
    },
    on_adjust_home: fn(id, home_score, away_score, delta) {
      AdjustHome(id:, home_score:, away_score:, delta:)
    },
    on_mark_final: fn(id) { MarkFinalClicked(id:) },
  )
}

// HELPERS

fn view_games(
  games games: List(GameSummary),
  on_adjust_away on_adjust_away: fn(Int, Int, Int, Int) -> msg,
  on_adjust_home on_adjust_home: fn(Int, Int, Int, Int) -> msg,
  on_mark_final on_mark_final: fn(Int) -> msg,
) -> Element(msg) {
  case games {
    [] -> html.p([attribute.class("muted")], [html.text("No games yet.")])
    _ ->
      html.div(
        [attribute.class("game-grid")],
        list.map(games, fn(game) {
          view_game_card(game, on_adjust_away, on_adjust_home, on_mark_final)
        }),
      )
  }
}

fn view_game_card(
  game: GameSummary,
  on_adjust_away: fn(Int, Int, Int, Int) -> msg,
  on_adjust_home: fn(Int, Int, Int, Int) -> msg,
  on_mark_final: fn(Int) -> msg,
) -> Element(msg) {
  html.article([attribute.class("game-card")], [
    html.div([attribute.class("admin-score-row")], [
      html.strong([], [html.text(game.away_code)]),
      score_button(
        "-",
        on_adjust_away(game.id, game.home_score, game.away_score, -1),
      ),
      score_button(
        "+",
        on_adjust_away(game.id, game.home_score, game.away_score, 1),
      ),
      html.span([attribute.class("score")], [
        html.text(int.to_string(game.away_score)),
      ]),
    ]),
    html.div([attribute.class("admin-score-row")], [
      html.strong([], [html.text(game.home_code)]),
      score_button(
        "-",
        on_adjust_home(game.id, game.home_score, game.away_score, -1),
      ),
      score_button(
        "+",
        on_adjust_home(game.id, game.home_score, game.away_score, 1),
      ),
      html.span([attribute.class("score")], [
        html.text(int.to_string(game.home_score)),
      ]),
    ]),
    html.div([attribute.class("score-line admin-status-row")], [
      status_badge(game.status),
      final_action(game, on_mark_final),
    ]),
  ])
}

fn score_button(label: String, msg: msg) -> Element(msg) {
  html.button([attribute.class("small score-control"), event.on_click(msg)], [
    html.text(label),
  ])
}

fn final_action(
  game: GameSummary,
  on_mark_final: fn(Int) -> msg,
) -> Element(msg) {
  case game.status {
    Final -> html.span([], [])
    _ ->
      html.button(
        [
          attribute.class("small secondary"),
          event.on_click(on_mark_final(game.id)),
        ],
        [html.text("Finalize")],
      )
  }
}

fn upsert_game(model: Model, game: GameSummary) -> Model {
  let games =
    list.map(model.games, fn(existing) {
      case existing.id == game.id {
        True -> game
        False -> existing
      }
    })

  Model(games:)
}

fn game_update_summary(game: GameUpdate) -> GameSummary {
  GameSummary(
    id: game.id,
    home_code: game.home_code,
    away_code: game.away_code,
    home_score: game.home_score,
    away_score: game.away_score,
    status: game.status,
    needs_attention: False,
  )
}

fn admin_game_update(game: broadcasts.GameSnapshot) -> GameUpdate {
  let broadcasts.BroadcastGameSnapshot(
    id:,
    home: broadcasts.BroadcastTeam(code: home_code, ..),
    away: broadcasts.BroadcastTeam(code: away_code, ..),
    home_score:,
    away_score:,
    status:,
  ) = game

  GameUpdate(
    id:,
    home_code:,
    away_code:,
    home_score:,
    away_score:,
    status: admin_game_status(status),
  )
}

fn admin_game_status(status: broadcasts.GameStatus) -> GameStatus {
  case status {
    broadcasts.BroadcastScheduled -> Scheduled
    broadcasts.BroadcastLive(period) -> Live(period)
    broadcasts.BroadcastFinal -> Final
  }
}

fn status_badge(status: GameStatus) -> Element(msg) {
  case status {
    Scheduled -> html.span([attribute.class("badge")], [html.text("Scheduled")])
    Live(period) ->
      html.span([attribute.class("badge live")], [html.text(period)])
    Final -> html.span([attribute.class("badge final")], [html.text("Final")])
  }
}

@target(javascript)
/// Sends browser score mutations to the generated Rally save effect.
fn message_effect(msg: Message) -> Effect(Message) {
  case msg {
    AdjustAway(id, home_score, away_score, delta) ->
      server.save_admin_games(
        message: UpdateScore(
          game_id: id,
          home_score: home_score,
          away_score: clamp_score(away_score + delta),
          period: "Live",
        ),
        on_result: fn(result) { Saved(map_save_result(result)) },
      )
    AdjustHome(id, home_score, away_score, delta) ->
      server.save_admin_games(
        message: UpdateScore(
          game_id: id,
          home_score: clamp_score(home_score + delta),
          away_score: away_score,
          period: "Live",
        ),
        on_result: fn(result) { Saved(map_save_result(result)) },
      )
    MarkFinalClicked(id) ->
      server.save_admin_games(message: MarkFinal(id), on_result: fn(result) {
        Saved(map_save_result(result))
      })
    Loaded(_) | Saved(_) -> effect.none()
  }
}

@target(erlang)
/// Server-side no-op because admin mutations are handled in `handle_save`.
fn message_effect(_msg: Message) -> Effect(Message) {
  effect.none()
}

// nolint: prefer_guard_clause -- the case reads as a simple clamp.
@target(javascript)
fn clamp_score(score: Int) -> Int {
  case score < 0 {
    True -> 0
    False -> score
  }
}

@target(javascript)
/// Converts transport save failures into the page-local save error.
fn map_save_result(
  result: Result(GameUpdate, List(server.SaveError)),
) -> Result(GameUpdate, SaveError) {
  case result {
    Ok(game) -> Ok(game)
    Error([server.SaveError(message: message, ..), ..]) ->
      Error(SaveError(message:))
    Error([]) -> Error(SaveError(message: "Could not save game."))
  }
}

// SERVER

@target(erlang)
/// Rally contract: generated SSR and websocket code call this on the Erlang
/// target. The returned data is wrapped in `LoadResult` for the wire.
pub fn load(
  db: sqlight.Connection,
) -> Result(List(GameSummary), runtime_load.LoadError) {
  case games_sql.list_admin_games(db:) {
    Ok(rows) -> Ok(list.map(rows, admin_game_summary_from_row))
    Error(sqlight.SqlightError(..)) ->
      Error(runtime_load.LoadError(message: "Could not load games."))
  }
}

@target(erlang)
/// Rally contract: generated websocket code calls this after decoding a ServerMsg
/// save variant and verifying that the connection is authorized.
pub fn handle_save(
  db: sqlight.Connection,
  msg: ServerMsg,
) -> Result(GameUpdate, SaveError) {
  case msg {
    Load -> Error(SaveError(message: "Load is not a save action."))
    UpdateScore(game_id, home_score, away_score, period) ->
      case
        games_sql.update_game_score(
          db:,
          home_score:,
          away_score:,
          period:,
          game_id:,
        )
      {
        Ok([row, ..]) -> Ok(game_update_from_score_row(row))
        Ok([]) -> Error(SaveError(message: "Game not found."))
        Error(sqlight.SqlightError(..)) ->
          Error(SaveError(message: "Could not save game."))
      }

    MarkFinal(game_id) ->
      case games_sql.update_game_final(db:, game_id:) {
        Ok([row, ..]) -> Ok(game_update_from_final_row(row))
        Ok([]) -> Error(SaveError(message: "Game not found."))
        Error(sqlight.SqlightError(..)) ->
          Error(SaveError(message: "Could not save game."))
      }
  }
}

@target(erlang)
/// Rally contract: generated websocket code calls this after a successful
/// handle_save result when a page save should emit a typed broadcast.
pub fn after_save(
  db: sqlight.Connection,
  game: GameUpdate,
) -> Result(broadcasts.TargetedEvent, Nil) {
  broadcasts.game_updated_broadcast(db, game.id)
}

@target(erlang)
fn admin_game_summary_from_row(
  row: games_sql.ListAdminGamesRow,
) -> GameSummary {
  GameSummary(
    id: row.id,
    home_code: row.home_code,
    away_code: row.away_code,
    home_score: row.home_score,
    away_score: row.away_score,
    status: game_status(row.period, row.final),
    needs_attention: False,
  )
}

@target(erlang)
fn game_update_from_score_row(row: games_sql.UpdateGameScoreRow) -> GameUpdate {
  GameUpdate(
    id: row.id,
    home_code: row.home_code,
    away_code: row.away_code,
    home_score: row.home_score,
    away_score: row.away_score,
    status: game_status(row.period, row.final),
  )
}

@target(erlang)
fn game_update_from_final_row(row: games_sql.UpdateGameFinalRow) -> GameUpdate {
  GameUpdate(
    id: row.id,
    home_code: row.home_code,
    away_code: row.away_code,
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
