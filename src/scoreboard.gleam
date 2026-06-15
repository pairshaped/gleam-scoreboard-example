@target(erlang)
import app_auth
@target(erlang)
import app_auth_http
@target(erlang)
import app_document
@target(erlang)
import app_ws
@target(erlang)
import gleam/http/request.{type Request}
@target(erlang)
import gleam/http/response.{type Response}
@target(erlang)
import gleam/option.{None, Some}
@target(erlang)
import mist.{type Connection, type ResponseData}
@target(erlang)
import rally/runtime/auth_http
@target(erlang)
import rally/runtime/bootstrap

@target(erlang)
/// Server entrypoint.
/// Rally owns standard bootstrap. The app supplies product-specific handlers.
pub fn main() -> Nil {
  case
    bootstrap.start(
      default_port: 8080,
      handlers: bootstrap.Handlers(
        auth: handle_auth_path,
        websocket: handle_websocket_path,
        admin: handle_admin_path,
        public: handle_public_path,
      ),
    )
  {
    Ok(Nil) -> Nil
    Error(error) -> panic as bootstrap.start_error_message(error)
  }
}

@target(erlang)
fn handle_admin_path(
  req req: Request(Connection),
  context context: bootstrap.Context,
) -> Response(ResponseData) {
  auth_http.protect(
    req:,
    auth: app_auth_http.request_auth(db: context.db, session: context.session),
    render: fn(_user) {
      app_document.response(
        req:,
        path: req.path,
        db: context.db,
        session: context.session,
      )
    },
  )
}

@target(erlang)
fn handle_auth_path(
  req req: Request(Connection),
  context context: bootstrap.Context,
) -> Result(Response(ResponseData), Nil) {
  let code_routes =
    auth_http.CodeAuthRoutes(
      session: fn(context: bootstrap.Context) { context.session },
      verify_code: fn(code, context: bootstrap.Context) {
        app_auth.verify_sign_in_code(db: context.db, code:)
      },
      deliver_code: fn(email, context: bootstrap.Context) {
        app_auth.deliver_sign_in_code(db: context.db, email:)
      },
      sign_in_default_return_to: "/admin/games",
      sign_in_return_to: app_auth_http.admin_return_to,
      sign_out_default_return_to: "/games",
      secure: False,
    )

  let google_routes =
    auth_http.GoogleAuthRoutes(
      session: fn(context: bootstrap.Context) { context.session },
      credentials: fn(_context: bootstrap.Context) {
        app_auth_http.google_credentials()
      },
      sign_in: fn(callback, context: bootstrap.Context) {
        app_auth.sign_in_with_google_code(db: context.db, callback:)
      },
      sign_in_default_return_to: "/admin/games",
      sign_in_return_to: app_auth_http.admin_return_to,
      secure: False,
    )

  case auth_http.route_code_auth(req:, context:, routes: code_routes) {
    Ok(resp) -> Ok(resp)
    Error(Nil) ->
      auth_http.route_google_auth(req:, context:, routes: google_routes)
  }
}

@target(erlang)
fn handle_websocket_path(
  req req: Request(Connection),
  context context: bootstrap.Context,
) -> Response(ResponseData) {
  let admin_user = case
    auth_http.authorized_user(
      req:,
      auth: app_auth_http.request_auth(db: context.db, session: context.session),
    )
  {
    Ok(user) -> Some(user)
    Error(Nil) -> None
  }
  mist.websocket(
    req,
    app_ws.handler,
    fn(conn) { app_ws.on_init(conn, context.db, admin_user) },
    app_ws.on_close,
  )
}

@target(erlang)
fn handle_public_path(
  req req: Request(Connection),
  context context: bootstrap.Context,
) -> Response(ResponseData) {
  app_document.response(
    req:,
    path: req.path,
    db: context.db,
    session: context.session,
  )
}

@target(javascript)
/// JavaScript-side compile anchor for the server module.
/// Browser builds can import this module without pulling in Erlang-only code.
pub fn ensure() -> Nil {
  Nil
}
