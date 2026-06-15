@target(erlang)
pub fn ensure() -> Nil {
  Nil
}

@target(javascript)
import broadcasts as push_payload
@target(javascript)
import generated/libero/etf as libero_etf
@target(javascript)
import generated/rally/result.{type ApiLoadError, type ApiSaveError}

@target(javascript)
pub type ServerFrame {
  Push(module: String, message: push_payload.Event)
}

@target(javascript)
pub fn encode_admin_games_request(
  request_id request_id: Int,
  message message: a,
) -> BitArray {
  encode_any(#(request_id, "admin/pages/games", message))
}

@target(javascript)
pub fn encode_public_games_id_request(
  request_id request_id: Int,
  message message: a,
) -> BitArray {
  encode_any(#(request_id, "public/pages/games/id_", message))
}

@target(javascript)
pub fn encode_public_games_request(
  request_id request_id: Int,
  message message: a,
) -> BitArray {
  encode_any(#(request_id, "public/pages/games", message))
}

@target(javascript)
pub fn encode_public_standings_request(
  request_id request_id: Int,
  message message: a,
) -> BitArray {
  encode_any(#(request_id, "public/pages/standings", message))
}

@target(javascript)
pub fn encode_public_teams_slug_request(
  request_id request_id: Int,
  message message: a,
) -> BitArray {
  encode_any(#(request_id, "public/pages/teams/slug_", message))
}

@target(javascript)
pub fn decode_server_frame(bytes: BitArray) -> Result(ServerFrame, Nil) {
  case bytes {
    <<1, payload:bits>> -> {
      case decode_any(payload) {
        Ok(#(module, message)) -> Ok(Push(module:, message:))
        Error(Nil) -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

@target(javascript)
pub fn decode_admin_games_load_result(
  bytes: BitArray,
) -> Result(#(Int, Result(load_result, List(ApiLoadError))), Nil) {
  decode_result_envelope(bytes)
}

@target(javascript)
pub fn decode_public_games_id_load_result(
  bytes: BitArray,
) -> Result(#(Int, Result(load_result, List(ApiLoadError))), Nil) {
  decode_result_envelope(bytes)
}

@target(javascript)
pub fn decode_public_games_load_result(
  bytes: BitArray,
) -> Result(#(Int, Result(load_result, List(ApiLoadError))), Nil) {
  decode_result_envelope(bytes)
}

@target(javascript)
pub fn decode_public_standings_load_result(
  bytes: BitArray,
) -> Result(#(Int, Result(load_result, List(ApiLoadError))), Nil) {
  decode_result_envelope(bytes)
}

@target(javascript)
pub fn decode_public_teams_slug_load_result(
  bytes: BitArray,
) -> Result(#(Int, Result(load_result, List(ApiLoadError))), Nil) {
  decode_result_envelope(bytes)
}

@target(javascript)
pub fn decode_admin_games_save_result(
  bytes: BitArray,
) -> Result(#(Int, Result(save_result, List(ApiSaveError))), Nil) {
  decode_result_envelope(bytes)
}

@target(javascript)
pub fn decode_result_envelope(bytes: BitArray) -> Result(#(Int, a), Nil) {
  case bytes {
    <<2, payload:bits>> -> decode_any(payload)
    _ -> Error(Nil)
  }
}

@target(javascript)
fn encode_any(value: a) -> BitArray {
  libero_etf.encode(value)
}

@target(javascript)
fn decode_any(bytes: BitArray) -> Result(a, Nil) {
  case libero_etf.decode(bytes) {
    Ok(value) -> Ok(value)
    Error(_) -> Error(Nil)
  }
}
