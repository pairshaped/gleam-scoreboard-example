@target(javascript)
import generated/rally/client_protocol
@target(javascript)
import generated/rally/result.{type ApiLoadError, type ApiSaveError}
@target(javascript)
import lustre/effect.{type Effect}

@target(erlang)
pub fn ensure() -> Nil {
  Nil
}

@target(javascript)
pub fn ensure() -> Nil {
  Nil
}

@target(javascript)
pub fn connect(
  url url: String,
  on_frame on_frame: fn(BitArray) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    connect_socket(url, fn(frame) { dispatch(on_frame(frame)) })
  })
}

@target(javascript)
pub fn send_admin_games_load(
  message message: a,
  on_result on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let request_id = next_request_id()
    let frame = client_protocol.encode_admin_games_request(request_id, message)
    send_admin_games_load_frame(request_id, frame, on_result, dispatch)
  })
}

@target(javascript)
pub fn send_public_games_id_load(
  message message: a,
  on_result on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let request_id = next_request_id()
    let frame =
      client_protocol.encode_public_games_id_request(request_id, message)
    send_public_games_id_load_frame(request_id, frame, on_result, dispatch)
  })
}

@target(javascript)
pub fn send_public_games_load(
  message message: a,
  on_result on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let request_id = next_request_id()
    let frame = client_protocol.encode_public_games_request(request_id, message)
    send_public_games_load_frame(request_id, frame, on_result, dispatch)
  })
}

@target(javascript)
pub fn send_public_standings_load(
  message message: a,
  on_result on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let request_id = next_request_id()
    let frame =
      client_protocol.encode_public_standings_request(request_id, message)
    send_public_standings_load_frame(request_id, frame, on_result, dispatch)
  })
}

@target(javascript)
pub fn send_public_teams_slug_load(
  message message: a,
  on_result on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let request_id = next_request_id()
    let frame =
      client_protocol.encode_public_teams_slug_request(request_id, message)
    send_public_teams_slug_load_frame(request_id, frame, on_result, dispatch)
  })
}

@target(javascript)
pub fn send_admin_games_save(
  message message: a,
  on_result on_result: fn(Result(save_result, List(ApiSaveError))) -> msg,
) -> Effect(msg) {
  effect.from(fn(dispatch) {
    let request_id = next_request_id()
    let frame = client_protocol.encode_admin_games_request(request_id, message)
    send_admin_games_save_frame(request_id, frame, on_result, dispatch)
  })
}

@target(javascript)
pub fn sync_topics(topics topics: List(String)) -> Effect(msg) {
  effect.from(fn(_dispatch) { send_topic_frame(topics) })
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "connect")
fn connect_socket(_url: String, _on_frame: fn(BitArray) -> Nil) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "send_load_frame")
fn send_admin_games_load_frame(
  _request_id: Int,
  _frame: BitArray,
  _on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
  _dispatch: fn(msg) -> Nil,
) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "send_load_frame")
fn send_public_games_id_load_frame(
  _request_id: Int,
  _frame: BitArray,
  _on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
  _dispatch: fn(msg) -> Nil,
) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "send_load_frame")
fn send_public_games_load_frame(
  _request_id: Int,
  _frame: BitArray,
  _on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
  _dispatch: fn(msg) -> Nil,
) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "send_load_frame")
fn send_public_standings_load_frame(
  _request_id: Int,
  _frame: BitArray,
  _on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
  _dispatch: fn(msg) -> Nil,
) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "send_load_frame")
fn send_public_teams_slug_load_frame(
  _request_id: Int,
  _frame: BitArray,
  _on_result: fn(Result(load_result, List(ApiLoadError))) -> msg,
  _dispatch: fn(msg) -> Nil,
) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "send_save_frame")
fn send_admin_games_save_frame(
  _request_id: Int,
  _frame: BitArray,
  _on_result: fn(Result(save_result, List(ApiSaveError))) -> msg,
  _dispatch: fn(msg) -> Nil,
) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "send_topic_frame")
fn send_topic_frame(_topics: List(String)) -> Nil {
  Nil
}

@target(javascript)
@external(javascript, "./client_transport_ffi.mjs", "next_request_id")
fn next_request_id() -> Int {
  0
}
