@target(erlang)
import admin/pages/games as admin_games_page
import authentication_context
@target(erlang)
import broadcasts
@target(erlang)
import generated/proute/public/page_input
@target(erlang)
import gleam/erlang/process
@target(erlang)
import gleam/list
import gleam/option.{None, Some}
import gleeunit
import gleeunit/should
@target(erlang)
import public/pages/games/id_ as public_game_detail_page
@target(erlang)
import public/pages/standings as public_standings_page
@target(erlang)
import public/pages/teams/slug_ as public_team_detail_page
@target(erlang)
import rally/runtime/load as runtime_load
@target(erlang)
import rally/runtime/topics
@target(erlang)
import sqlight

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn normalize_email_test() {
  authentication_context.normalize_email(" Admin@Example.COM ")
  |> should.equal("admin@example.com")
}

pub fn normalize_display_name_test() {
  authentication_context.normalize_display_name(" Fan ")
  |> should.equal(Some("Fan"))

  authentication_context.normalize_display_name(" ")
  |> should.equal(None)
}

@target(erlang)
pub fn mark_final_returns_save_ack_payload_and_game_update_test() {
  let db = live_game_db()

  let result = admin_games_page.handle_save(db, admin_games_page.MarkFinal(1))
  let broadcast = broadcasts.game_updated_broadcast(db, 1)

  case result, broadcast {
    Ok(admin_games_page.AdminGamesUpdate(
      status: admin_games_page.AdminGamesFinal,
      ..,
    )),
      Ok(broadcasts.TargetedEvent(
        topics: [
          broadcasts.AllGames,
          broadcasts.AdminGames,
          broadcasts.Game(1),
          broadcasts.Team("toronto-towers"),
          broadcasts.Team("montreal-meteors"),
        ],
        event: broadcasts.BroadcastGameUpdated(updated),
      ))
    -> updated.status == broadcasts.BroadcastFinal
    _, _ -> False
  }
  |> should.equal(True)

  let assert Ok(_) = sqlight.close(db)
}

@target(erlang)
pub fn update_score_returns_save_ack_payload_and_game_update_test() {
  let db = final_game_db()

  let result =
    admin_games_page.handle_save(
      db,
      admin_games_page.UpdateScore(1, 5, 2, "Live"),
    )
  let broadcast = broadcasts.game_updated_broadcast(db, 1)

  case result, broadcast {
    Ok(admin_games_page.AdminGamesUpdate(
      status: admin_games_page.AdminGamesLive("Live"),
      ..,
    )),
      Ok(broadcasts.TargetedEvent(
        topics: [
          broadcasts.AllGames,
          broadcasts.AdminGames,
          broadcasts.Game(1),
          broadcasts.Team("toronto-towers"),
          broadcasts.Team("montreal-meteors"),
        ],
        event: broadcasts.BroadcastGameUpdated(updated),
      ))
    -> updated.status == broadcasts.BroadcastLive("Live")
    _, _ -> False
  }
  |> should.equal(True)

  let assert Ok(_) = sqlight.close(db)
}

@target(erlang)
pub fn rally_topics_exclude_origin_connection_test() {
  process.flush_messages()
  topics.start()
  topics.join("origin-excluded-test")

  let frame = <<"hello">>
  let selector = topics.frame_selector()

  topics.broadcast_except_self("origin-excluded-test", frame)

  process.selector_receive(selector, within: 100)
  |> should.equal(Error(Nil))
}

@target(erlang)
pub fn rally_topics_deliver_to_peer_connection_test() {
  topics.start()
  let topic = "peer-delivery-test"
  let frame = <<"hello peer">>
  let joined_subject = process.new_subject()
  let result_subject = process.new_subject()

  let _pid =
    process.spawn(fn() {
      topics.join(topic)
      process.send(joined_subject, Nil)
      case process.selector_receive(topics.frame_selector(), within: 1000) {
        Ok(received) -> process.send(result_subject, received)
        Error(_) -> process.send(result_subject, <<>>)
      }
    })

  let assert Ok(Nil) = process.receive(joined_subject, 1000)

  topics.join(topic)
  topics.broadcast_except_self(topic, frame)

  process.receive(result_subject, 1000)
  |> should.equal(Ok(frame))
}

@target(erlang)
pub fn page_broadcast_subscriptions_follow_route_params_test() {
  let game_route = page_input.GamesIdRouteParams(id: "1")
  let invalid_game_route = page_input.GamesIdRouteParams(id: "abc")
  let team_route = page_input.TeamsSlugRouteParams(slug: "toronto-towers")

  public_game_detail_page.broadcast_subscriptions(
    game_route,
    public_game_detail_page.Model(game: None),
  )
  |> should.equal([broadcasts.Game(1)])

  public_game_detail_page.broadcast_subscriptions(
    invalid_game_route,
    public_game_detail_page.Model(game: None),
  )
  |> should.equal([])

  public_game_detail_page.broadcast_subscriptions(
    game_route,
    public_game_detail_page.Model(
      game: Some(public_game_detail_page.GameDetail(
        id: 99,
        home: public_game_detail_page.Team(
          code: "TOR",
          name: "Toronto Towers",
          slug: "toronto-towers",
        ),
        away: public_game_detail_page.Team(
          code: "MTL",
          name: "Montreal Meteors",
          slug: "montreal-meteors",
        ),
        home_score: 4,
        away_score: 2,
        status: public_game_detail_page.Live("3rd"),
      )),
    ),
  )
  |> should.equal([broadcasts.Game(1)])

  public_team_detail_page.broadcast_subscriptions(
    team_route,
    public_team_detail_page.Model(team: None),
  )
  |> should.equal([broadcasts.Team("toronto-towers")])

  public_team_detail_page.broadcast_subscriptions(
    team_route,
    public_team_detail_page.Model(
      team: Some(
        public_team_detail_page.TeamDetail(
          code: "TOR",
          name: "Toronto Towers",
          slug: "different-loaded-slug",
          wins: 0,
          losses: 0,
          points_for: 0,
          points_against: 0,
          recent_games: [],
        ),
      ),
    ),
  )
  |> should.equal([broadcasts.Team("toronto-towers")])
}

@target(erlang)
pub fn load_standings_returns_page_owned_game_summaries_test() {
  let db = live_game_db()

  let result = public_standings_page.load(db)

  case result {
    Ok(games) -> list.length(games)
    _ -> 0
  }
  |> should.equal(1)

  result
  |> has_toronto_game_summary(home_score: 4, away_score: 2)
  |> should.equal(True)

  let assert Ok(_) = sqlight.close(db)
}

@target(erlang)
fn has_toronto_game_summary(
  result: Result(
    List(public_standings_page.GameSummary),
    runtime_load.LoadError,
  ),
  home_score home_score: Int,
  away_score away_score: Int,
) -> Bool {
  case result {
    Ok(games) ->
      list.any(games, fn(game) {
        game.home.code == "TOR"
        && game.home_score == home_score
        && game.away_score == away_score
      })
    Error(_) -> False
  }
}

@target(erlang)
fn live_game_db() -> sqlight.Connection {
  test_db_with_game(period: "3rd", final: "0")
}

@target(erlang)
fn final_game_db() -> sqlight.Connection {
  test_db_with_game(period: "Final", final: "1")
}

@target(erlang)
fn test_db_with_game(
  period period: String,
  final final: String,
) -> sqlight.Connection {
  let assert Ok(db) = sqlight.open("file:scoreboard_test?mode=memory")
  let assert Ok(_) = sqlight.exec("
      CREATE TABLE teams (
        code TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        slug TEXT NOT NULL
      );

      CREATE TABLE games (
        id INTEGER PRIMARY KEY,
        home_code TEXT NOT NULL REFERENCES teams (code),
        away_code TEXT NOT NULL REFERENCES teams (code),
        home_score INTEGER NOT NULL DEFAULT 0,
        away_score INTEGER NOT NULL DEFAULT 0,
        period TEXT NOT NULL DEFAULT 'Scheduled',
        final INTEGER NOT NULL DEFAULT 0,
        CHECK (home_code <> away_code),
        CHECK (final IN (0, 1))
      );

      INSERT INTO teams (code, name, slug)
      VALUES
        ('TOR', 'Toronto Towers', 'toronto-towers'),
        ('MTL', 'Montreal Meteors', 'montreal-meteors');

      INSERT INTO games (
        id,
        home_code,
        away_code,
        home_score,
        away_score,
        period,
        final
      )
      VALUES (1, 'TOR', 'MTL', 4, 2, '" <> period <> "', " <> final <> ");
      ", on: db)
  db
}
