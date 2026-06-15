@target(javascript)
pub fn ensure() -> Nil {
  Nil
}

@target(erlang)
import admin/page_shared_state as admin_page_shared_state
@target(erlang)
import admin/pages/games as admin_games_wire
@target(erlang)
import generated/proute/admin/page_input as admin_page_input
@target(erlang)
import generated/proute/admin/pages as admin_pages
@target(erlang)
import generated/proute/admin/routes as admin_routes
@target(erlang)
import generated/proute/public/page_input as public_page_input
@target(erlang)
import generated/proute/public/pages as public_pages
@target(erlang)
import generated/proute/public/routes as public_routes
@target(erlang)
import generated/rally/result as transport_result
@target(erlang)
import generated/rally/server_protocol
@target(erlang)
import gleam/bit_array
@target(erlang)
import gleam/int
@target(erlang)
import gleam/list
@target(erlang)
import lustre/effect.{type Effect}
@target(erlang)
import lustre/element.{type Element}
@target(erlang)
import public/page_shared_state as public_page_shared_state
@target(erlang)
import public/pages/games as public_games_wire
@target(erlang)
import public/pages/games/id_ as public_games_id_wire
@target(erlang)
import public/pages/standings as public_standings_wire
@target(erlang)
import public/pages/teams/slug_ as public_teams_slug_wire
@target(erlang)
import rally/runtime/load as runtime_load
@target(erlang)
import sqlight as load_context

@target(erlang)
pub type AdminSsrOutput {
  AdminSsrOutput(
    current_path: String,
    content: Element(Nil),
    hydration: List(String),
  )
}

@target(erlang)
pub type PublicSsrOutput {
  PublicSsrOutput(
    current_path: String,
    content: Element(Nil),
    hydration: List(String),
  )
}

@target(erlang)
pub type AdminLoadRoute {
  AdminNoLoad
  AdminGamesLoad(
    to_message: fn(Result(admin_games_wire.LoadResult, List(String))) ->
      admin_pages.Message,
  )
}

@target(erlang)
pub type PublicLoadRoute {
  PublicNoLoad
  PublicGamesIdLoad(
    to_message: fn(Result(public_games_id_wire.LoadResult, List(String))) ->
      public_pages.Message,
  )
  PublicGamesLoad(
    to_message: fn(Result(public_games_wire.LoadResult, List(String))) ->
      public_pages.Message,
  )
  PublicStandingsLoad(
    to_message: fn(Result(public_standings_wire.LoadResult, List(String))) ->
      public_pages.Message,
  )
  PublicTeamsSlugLoad(
    to_message: fn(Result(public_teams_slug_wire.LoadResult, List(String))) ->
      public_pages.Message,
  )
}

@target(erlang)
pub fn admin_load_route(route route: admin_routes.Route) -> AdminLoadRoute {
  case route {
    admin_routes.AdminGames ->
      AdminGamesLoad(to_message: fn(result) {
        case result {
          Ok(admin_games_wire.AdminGamesLoadResult(data)) ->
            admin_pages.AdminGamesMsg(admin_games_wire.Loaded(Ok(data)))
          Error([message, ..]) ->
            admin_pages.AdminGamesMsg(
              admin_games_wire.Loaded(
                Error(runtime_load.LoadError(message: message)),
              ),
            )
          Error([]) ->
            admin_pages.AdminGamesMsg(
              admin_games_wire.Loaded(
                Error(runtime_load.LoadError(message: "Could not load page.")),
              ),
            )
        }
      })
    admin_routes.AdminHome ->
      AdminGamesLoad(to_message: fn(result) {
        case result {
          Ok(admin_games_wire.AdminGamesLoadResult(data)) ->
            admin_pages.AdminHomeMsg(admin_games_wire.Loaded(Ok(data)))
          Error([message, ..]) ->
            admin_pages.AdminHomeMsg(
              admin_games_wire.Loaded(
                Error(runtime_load.LoadError(message: message)),
              ),
            )
          Error([]) ->
            admin_pages.AdminHomeMsg(
              admin_games_wire.Loaded(
                Error(runtime_load.LoadError(message: "Could not load page.")),
              ),
            )
        }
      })
    _ -> AdminNoLoad
  }
}

@target(erlang)
pub fn public_load_route(route route: public_routes.Route) -> PublicLoadRoute {
  case route {
    public_routes.GamesId(id: _) ->
      PublicGamesIdLoad(to_message: fn(result) {
        case result {
          Ok(public_games_id_wire.PublicGameDetailLoaded(data)) ->
            public_pages.GamesIdMsg(public_games_id_wire.Loaded(Ok(data)))
          Error([message, ..]) ->
            public_pages.GamesIdMsg(
              public_games_id_wire.Loaded(
                Error(runtime_load.LoadError(message: message)),
              ),
            )
          Error([]) ->
            public_pages.GamesIdMsg(
              public_games_id_wire.Loaded(
                Error(runtime_load.LoadError(message: "Could not load page.")),
              ),
            )
        }
      })
    public_routes.Games ->
      PublicGamesLoad(to_message: fn(result) {
        case result {
          Ok(public_games_wire.PublicGamesLoaded(data)) ->
            public_pages.GamesMsg(public_games_wire.Loaded(Ok(data)))
          Error([message, ..]) ->
            public_pages.GamesMsg(
              public_games_wire.Loaded(
                Error(runtime_load.LoadError(message: message)),
              ),
            )
          Error([]) ->
            public_pages.GamesMsg(
              public_games_wire.Loaded(
                Error(runtime_load.LoadError(message: "Could not load page.")),
              ),
            )
        }
      })
    public_routes.Home ->
      PublicGamesLoad(to_message: fn(result) {
        case result {
          Ok(public_games_wire.PublicGamesLoaded(data)) ->
            public_pages.HomeMsg(public_games_wire.Loaded(Ok(data)))
          Error([message, ..]) ->
            public_pages.HomeMsg(
              public_games_wire.Loaded(
                Error(runtime_load.LoadError(message: message)),
              ),
            )
          Error([]) ->
            public_pages.HomeMsg(
              public_games_wire.Loaded(
                Error(runtime_load.LoadError(message: "Could not load page.")),
              ),
            )
        }
      })
    public_routes.Standings ->
      PublicStandingsLoad(to_message: fn(result) {
        case result {
          Ok(public_standings_wire.PublicStandingsLoaded(data)) ->
            public_pages.StandingsMsg(public_standings_wire.Loaded(Ok(data)))
          Error([message, ..]) ->
            public_pages.StandingsMsg(
              public_standings_wire.Loaded(
                Error(runtime_load.LoadError(message: message)),
              ),
            )
          Error([]) ->
            public_pages.StandingsMsg(
              public_standings_wire.Loaded(
                Error(runtime_load.LoadError(message: "Could not load page.")),
              ),
            )
        }
      })
    public_routes.TeamsSlug(slug: _) ->
      PublicTeamsSlugLoad(to_message: fn(result) {
        case result {
          Ok(public_teams_slug_wire.PublicTeamDetailLoaded(data)) ->
            public_pages.TeamsSlugMsg(public_teams_slug_wire.Loaded(Ok(data)))
          Error([message, ..]) ->
            public_pages.TeamsSlugMsg(
              public_teams_slug_wire.Loaded(
                Error(runtime_load.LoadError(message: message)),
              ),
            )
          Error([]) ->
            public_pages.TeamsSlugMsg(
              public_teams_slug_wire.Loaded(
                Error(runtime_load.LoadError(message: "Could not load page.")),
              ),
            )
        }
      })
    _ -> PublicNoLoad
  }
}

@target(erlang)
pub fn admin_render_path(
  page_shared_state page_shared_state: admin_page_shared_state.AdminPageSharedState,
  query_params query_params: admin_page_input.QueryParams,
  path path: String,
  load_context load_context: load_context.Connection,
) -> AdminSsrOutput {
  let route = admin_routes.parse_path(path)
  let #(page, hydration) =
    admin_boot_page(
      page_shared_state:,
      query_params:,
      route:,
      load_context:,
      update_page: fn(page, message) {
        admin_pages.update(page_shared_state, page, message)
      },
    )

  AdminSsrOutput(
    current_path: admin_routes.route_to_path(route),
    content: admin_pages.view(page) |> element.map(fn(_) { Nil }),
    hydration:,
  )
}

@target(erlang)
pub fn public_render_path(
  page_shared_state page_shared_state: public_page_shared_state.PublicPageSharedState,
  query_params query_params: public_page_input.QueryParams,
  path path: String,
  load_context load_context: load_context.Connection,
) -> PublicSsrOutput {
  let route = public_routes.parse_path(path)
  let #(page, hydration) =
    public_boot_page(
      page_shared_state:,
      query_params:,
      route:,
      load_context:,
      update_page: fn(page, message) { public_pages.update(page, message) },
    )

  PublicSsrOutput(
    current_path: public_routes.route_to_path(route),
    content: public_pages.view(page) |> element.map(fn(_) { Nil }),
    hydration:,
  )
}

@target(erlang)
pub fn admin_boot_page(
  page_shared_state page_shared_state: admin_page_shared_state.AdminPageSharedState,
  query_params query_params: admin_page_input.QueryParams,
  route route: admin_routes.Route,
  load_context load_context: load_context.Connection,
  update_page update_page: fn(admin_pages.Page, admin_pages.Message) ->
    #(admin_pages.Page, Effect(admin_pages.Message)),
) -> #(admin_pages.Page, List(String)) {
  let page = admin_pages.initial_page(page_shared_state, query_params, route)

  case admin_load_route(route) {
    AdminNoLoad -> #(page, [])
    AdminGamesLoad(to_message:) -> {
      let result = case admin_games_wire.load(load_context) {
        Ok(data) -> Ok(admin_games_wire.AdminGamesLoadResult(data))
        Error(runtime_load.LoadError(message: message)) -> Error([message])
      }
      boot_loaded_page(
        page: page,
        result: result,
        hydration_payload: admin_games_hydration_payload,
        to_message: to_message,
        update_page: update_page,
      )
    }
  }
}

@target(erlang)
pub fn public_boot_page(
  page_shared_state page_shared_state: public_page_shared_state.PublicPageSharedState,
  query_params query_params: public_page_input.QueryParams,
  route route: public_routes.Route,
  load_context load_context: load_context.Connection,
  update_page update_page: fn(public_pages.Page, public_pages.Message) ->
    #(public_pages.Page, Effect(public_pages.Message)),
) -> #(public_pages.Page, List(String)) {
  let page = public_pages.initial_page(page_shared_state, query_params, route)

  case public_load_route(route) {
    PublicNoLoad -> #(page, [])
    PublicGamesIdLoad(to_message:) -> {
      let result = case route {
        public_routes.GamesId(id:) ->
          case int.parse(id) {
            Ok(game_id) ->
              case public_games_id_wire.load(load_context, game_id) {
                Ok(data) ->
                  Ok(public_games_id_wire.PublicGameDetailLoaded(data))
                Error(runtime_load.LoadError(message: message)) ->
                  Error([message])
              }
            Error(Nil) -> Error(["Invalid route parameter."])
          }
        _ -> Error(["Unexpected route."])
      }
      boot_loaded_page(
        page: page,
        result: result,
        hydration_payload: public_games_id_hydration_payload,
        to_message: to_message,
        update_page: update_page,
      )
    }
    PublicGamesLoad(to_message:) -> {
      let result = case public_games_wire.load(load_context) {
        Ok(data) -> Ok(public_games_wire.PublicGamesLoaded(data))
        Error(runtime_load.LoadError(message: message)) -> Error([message])
      }
      boot_loaded_page(
        page: page,
        result: result,
        hydration_payload: public_games_hydration_payload,
        to_message: to_message,
        update_page: update_page,
      )
    }
    PublicStandingsLoad(to_message:) -> {
      let result = case public_standings_wire.load(load_context) {
        Ok(data) -> Ok(public_standings_wire.PublicStandingsLoaded(data))
        Error(runtime_load.LoadError(message: message)) -> Error([message])
      }
      boot_loaded_page(
        page: page,
        result: result,
        hydration_payload: public_standings_hydration_payload,
        to_message: to_message,
        update_page: update_page,
      )
    }
    PublicTeamsSlugLoad(to_message:) -> {
      let result = case route {
        public_routes.TeamsSlug(slug:) ->
          case public_teams_slug_wire.load(load_context, slug) {
            Ok(data) -> Ok(public_teams_slug_wire.PublicTeamDetailLoaded(data))
            Error(runtime_load.LoadError(message: message)) -> Error([message])
          }
        _ -> Error(["Unexpected route."])
      }
      boot_loaded_page(
        page: page,
        result: result,
        hydration_payload: public_teams_slug_hydration_payload,
        to_message: to_message,
        update_page: update_page,
      )
    }
  }
}

@target(erlang)
pub fn admin_games_hydration_payload(
  result result: Result(admin_games_wire.LoadResult, List(String)),
) -> String {
  server_protocol.ensure()
  result
  |> map_load_result
  |> server_protocol.encode_admin_games_load_result(request_id: 0)
  |> bit_array.base64_url_encode(False)
}

@target(erlang)
pub fn public_games_id_hydration_payload(
  result result: Result(public_games_id_wire.LoadResult, List(String)),
) -> String {
  server_protocol.ensure()
  result
  |> map_load_result
  |> server_protocol.encode_public_games_id_load_result(request_id: 0)
  |> bit_array.base64_url_encode(False)
}

@target(erlang)
pub fn public_games_hydration_payload(
  result result: Result(public_games_wire.LoadResult, List(String)),
) -> String {
  server_protocol.ensure()
  result
  |> map_load_result
  |> server_protocol.encode_public_games_load_result(request_id: 0)
  |> bit_array.base64_url_encode(False)
}

@target(erlang)
pub fn public_standings_hydration_payload(
  result result: Result(public_standings_wire.LoadResult, List(String)),
) -> String {
  server_protocol.ensure()
  result
  |> map_load_result
  |> server_protocol.encode_public_standings_load_result(request_id: 0)
  |> bit_array.base64_url_encode(False)
}

@target(erlang)
pub fn public_teams_slug_hydration_payload(
  result result: Result(public_teams_slug_wire.LoadResult, List(String)),
) -> String {
  server_protocol.ensure()
  result
  |> map_load_result
  |> server_protocol.encode_public_teams_slug_load_result(request_id: 0)
  |> bit_array.base64_url_encode(False)
}

@target(erlang)
fn map_load_result(
  result: Result(a, List(String)),
) -> Result(a, List(transport_result.ApiLoadError)) {
  case result {
    Ok(value) -> Ok(value)
    Error(errors) ->
      Error(
        list.map(errors, fn(error) {
          transport_result.ApiLoadError(message: error)
        }),
      )
  }
}

@target(erlang)
fn boot_loaded_page(
  page page: page,
  result result: Result(load_result, List(String)),
  hydration_payload hydration_payload: fn(Result(load_result, List(String))) ->
    String,
  to_message to_message: fn(Result(load_result, List(String))) -> message,
  update_page update_page: fn(page, message) -> #(page, Effect(message)),
) -> #(page, List(String)) {
  let #(page, _) = update_page(page, to_message(result))
  #(page, [hydration_payload(result)])
}
