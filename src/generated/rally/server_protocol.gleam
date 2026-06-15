@target(javascript)
pub fn ensure() -> Nil {
  Nil
}

@target(erlang)
import admin/pages/games as admin_games_wire
@target(erlang)
import broadcasts as push_payload
@target(erlang)
import generated/libero/etf as libero_etf
@target(erlang)
import generated/rally/result.{type ApiLoadError, type ApiSaveError}
@target(erlang)
import public/pages/games as public_games_wire
@target(erlang)
import public/pages/games/id_ as public_games_id_wire
@target(erlang)
import public/pages/standings as public_standings_wire
@target(erlang)
import public/pages/teams/slug_ as public_teams_slug_wire

@target(erlang)
pub fn ensure() -> Nil {
  libero_etf.ensure()
}

@target(erlang)
pub type AdminGamesClientRequest {
  AdminGamesClientRequest(
    request_id: Int,
    module: String,
    message: admin_games_wire.ServerMsg,
  )
}

@target(erlang)
pub type PublicGamesIdClientRequest {
  PublicGamesIdClientRequest(
    request_id: Int,
    module: String,
    message: public_games_id_wire.ServerMsg,
  )
}

@target(erlang)
pub type PublicGamesClientRequest {
  PublicGamesClientRequest(
    request_id: Int,
    module: String,
    message: public_games_wire.ServerMsg,
  )
}

@target(erlang)
pub type PublicStandingsClientRequest {
  PublicStandingsClientRequest(
    request_id: Int,
    module: String,
    message: public_standings_wire.ServerMsg,
  )
}

@target(erlang)
pub type PublicTeamsSlugClientRequest {
  PublicTeamsSlugClientRequest(
    request_id: Int,
    module: String,
    message: public_teams_slug_wire.ServerMsg,
  )
}

@target(erlang)
pub fn decode_admin_games_request(
  bytes: BitArray,
) -> Result(AdminGamesClientRequest, Nil) {
  case decode_any(bytes) {
    Ok(#(request_id, module, message)) ->
      Ok(AdminGamesClientRequest(request_id:, module:, message:))
    _ -> Error(Nil)
  }
}

@target(erlang)
pub fn decode_public_games_id_request(
  bytes: BitArray,
) -> Result(PublicGamesIdClientRequest, Nil) {
  case decode_any(bytes) {
    Ok(#(request_id, module, message)) ->
      Ok(PublicGamesIdClientRequest(request_id:, module:, message:))
    _ -> Error(Nil)
  }
}

@target(erlang)
pub fn decode_public_games_request(
  bytes: BitArray,
) -> Result(PublicGamesClientRequest, Nil) {
  case decode_any(bytes) {
    Ok(#(request_id, module, message)) ->
      Ok(PublicGamesClientRequest(request_id:, module:, message:))
    _ -> Error(Nil)
  }
}

@target(erlang)
pub fn decode_public_standings_request(
  bytes: BitArray,
) -> Result(PublicStandingsClientRequest, Nil) {
  case decode_any(bytes) {
    Ok(#(request_id, module, message)) ->
      Ok(PublicStandingsClientRequest(request_id:, module:, message:))
    _ -> Error(Nil)
  }
}

@target(erlang)
pub fn decode_public_teams_slug_request(
  bytes: BitArray,
) -> Result(PublicTeamsSlugClientRequest, Nil) {
  case decode_any(bytes) {
    Ok(#(request_id, module, message)) ->
      Ok(PublicTeamsSlugClientRequest(request_id:, module:, message:))
    _ -> Error(Nil)
  }
}

@target(erlang)
pub fn encode_admin_games_load_result(
  request_id request_id: Int,
  result result: Result(admin_games_wire.LoadResult, List(ApiLoadError)),
) -> BitArray {
  encode_result_frame(
    request_id,
    encode_admin_games_load_result_payload(result),
  )
}

@target(erlang)
pub fn encode_public_games_id_load_result(
  request_id request_id: Int,
  result result: Result(public_games_id_wire.LoadResult, List(ApiLoadError)),
) -> BitArray {
  encode_result_frame(
    request_id,
    encode_public_games_id_load_result_payload(result),
  )
}

@target(erlang)
pub fn encode_public_games_load_result(
  request_id request_id: Int,
  result result: Result(public_games_wire.LoadResult, List(ApiLoadError)),
) -> BitArray {
  encode_result_frame(
    request_id,
    encode_public_games_load_result_payload(result),
  )
}

@target(erlang)
pub fn encode_public_standings_load_result(
  request_id request_id: Int,
  result result: Result(public_standings_wire.LoadResult, List(ApiLoadError)),
) -> BitArray {
  encode_result_frame(
    request_id,
    encode_public_standings_load_result_payload(result),
  )
}

@target(erlang)
pub fn encode_public_teams_slug_load_result(
  request_id request_id: Int,
  result result: Result(public_teams_slug_wire.LoadResult, List(ApiLoadError)),
) -> BitArray {
  encode_result_frame(
    request_id,
    encode_public_teams_slug_load_result_payload(result),
  )
}

@target(erlang)
pub fn encode_admin_games_save_result(
  request_id request_id: Int,
  result result: Result(admin_games_wire.GameUpdate, List(ApiSaveError)),
) -> BitArray {
  encode_result_frame(
    request_id,
    encode_admin_games_save_result_payload(result),
  )
}

@target(erlang)
fn encode_admin_games_load_result_payload(
  result: Result(admin_games_wire.LoadResult, List(ApiLoadError)),
) -> Result(a, List(ApiLoadError)) {
  encode_ok_payload(result, encode_admin_games_load_result_value)
}

@target(erlang)
@external(erlang, "generated@libero_wire", "encode_admin_pages_games__load_result")
fn encode_admin_games_load_result_value(
  _value: admin_games_wire.LoadResult,
) -> a {
  panic as "generated/rally/server_protocol.encode_admin_games_load_result_value external missing"
}

@target(erlang)
fn encode_public_games_id_load_result_payload(
  result: Result(public_games_id_wire.LoadResult, List(ApiLoadError)),
) -> Result(a, List(ApiLoadError)) {
  encode_ok_payload(result, encode_public_games_id_load_result_value)
}

@target(erlang)
@external(erlang, "generated@libero_wire", "encode_public_pages_games_id___load_result")
fn encode_public_games_id_load_result_value(
  _value: public_games_id_wire.LoadResult,
) -> a {
  panic as "generated/rally/server_protocol.encode_public_games_id_load_result_value external missing"
}

@target(erlang)
fn encode_public_games_load_result_payload(
  result: Result(public_games_wire.LoadResult, List(ApiLoadError)),
) -> Result(a, List(ApiLoadError)) {
  encode_ok_payload(result, encode_public_games_load_result_value)
}

@target(erlang)
@external(erlang, "generated@libero_wire", "encode_public_pages_games__load_result")
fn encode_public_games_load_result_value(
  _value: public_games_wire.LoadResult,
) -> a {
  panic as "generated/rally/server_protocol.encode_public_games_load_result_value external missing"
}

@target(erlang)
fn encode_public_standings_load_result_payload(
  result: Result(public_standings_wire.LoadResult, List(ApiLoadError)),
) -> Result(a, List(ApiLoadError)) {
  encode_ok_payload(result, encode_public_standings_load_result_value)
}

@target(erlang)
@external(erlang, "generated@libero_wire", "encode_public_pages_standings__load_result")
fn encode_public_standings_load_result_value(
  _value: public_standings_wire.LoadResult,
) -> a {
  panic as "generated/rally/server_protocol.encode_public_standings_load_result_value external missing"
}

@target(erlang)
fn encode_public_teams_slug_load_result_payload(
  result: Result(public_teams_slug_wire.LoadResult, List(ApiLoadError)),
) -> Result(a, List(ApiLoadError)) {
  encode_ok_payload(result, encode_public_teams_slug_load_result_value)
}

@target(erlang)
@external(erlang, "generated@libero_wire", "encode_public_pages_teams_slug___load_result")
fn encode_public_teams_slug_load_result_value(
  _value: public_teams_slug_wire.LoadResult,
) -> a {
  panic as "generated/rally/server_protocol.encode_public_teams_slug_load_result_value external missing"
}

@target(erlang)
fn encode_admin_games_save_result_payload(
  result: Result(admin_games_wire.GameUpdate, List(ApiSaveError)),
) -> Result(a, List(ApiSaveError)) {
  encode_ok_payload(result, encode_admin_games_save_result_value)
}

@target(erlang)
@external(erlang, "generated@libero_wire", "encode_admin_pages_games__game_update")
fn encode_admin_games_save_result_value(
  _value: admin_games_wire.GameUpdate,
) -> a {
  panic as "generated/rally/server_protocol.encode_admin_games_save_result_value external missing"
}

@target(erlang)
@external(erlang, "generated@libero_wire", "encode_broadcasts__event")
fn encode_push_payload(_message: push_payload.Event) -> a {
  panic as "generated/rally/server_protocol.encode_push_payload external missing"
}

@target(erlang)
pub fn encode_push(
  module module: String,
  message message: push_payload.Event,
) -> BitArray {
  let payload = encode_any(#(module, encode_push_payload(message)))
  <<1, payload:bits>>
}

@target(erlang)
fn encode_result_frame(request_id: Int, result: a) -> BitArray {
  let payload = encode_any(#(request_id, result))
  <<2, payload:bits>>
}

@target(erlang)
fn encode_ok_payload(
  result: Result(a, b),
  encode_ok: fn(a) -> c,
) -> Result(c, b) {
  case result {
    Ok(payload) -> Ok(encode_ok(payload))
    Error(error) -> Error(error)
  }
}

@target(erlang)
fn decode_any(bytes: BitArray) -> Result(a, Nil) {
  case libero_etf.decode(bytes) {
    Ok(value) -> Ok(value)
    Error(_) -> Error(Nil)
  }
}

@target(erlang)
fn encode_any(value: a) -> BitArray {
  libero_etf.encode(value)
}
