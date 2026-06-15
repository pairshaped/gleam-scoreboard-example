@target(erlang)
import app_ssr
@target(erlang)
import authentication_context.{type AuthenticationContext}
@target(erlang)
import generated/proute/admin/page_input as admin_page_input
@target(erlang)
import generated/proute/public/page_input as public_page_input
@target(erlang)
import generated/rally/theme
@target(erlang)
import gleam/http/request.{type Request}
@target(erlang)
import gleam/http/response.{type Response}
@target(erlang)
import gleam/option.{type Option, None, Some}
@target(erlang)
import mist.{type Connection, type ResponseData}
@target(erlang)
import rally/runtime/document
@target(erlang)
import rally/runtime/session
@target(erlang)
import sqlight

@target(javascript)
/// JavaScript-side compile anchor for the document module.
/// Browser builds can import this module without pulling in Erlang-only code.
pub fn ensure() -> Nil {
  Nil
}

@target(erlang)
/// HTTP document response for public and admin app routes.
/// The app calls this after routing/auth, and this module chooses the
/// matching SSR mount and browser entrypoint.
pub fn response(
  req req: Request(Connection),
  path path: String,
  db db: sqlight.Connection,
  session session: session.AuthSession,
) -> Response(ResponseData) {
  html(req:, path:, db:, session:)
  |> document.html_response
}

@target(erlang)
fn html(
  req req: Request(Connection),
  path path: String,
  db db: sqlight.Connection,
  session session: session.AuthSession,
) -> String {
  let mount = document.standard_mount(path:, admin_prefix: "/admin")
  let entrypoint = document.standard_entrypoint(mount)
  let dark_mode = theme.request_dark_mode(req)
  let ssr_app = case mount {
    document.Admin ->
      app_ssr.admin(
        req:,
        path:,
        db:,
        query_params: admin_query_params(req),
        dark_mode:,
        session:,
      )
    document.Public ->
      app_ssr.public(
        req:,
        path:,
        db:,
        query_params: public_query_params(req),
        dark_mode:,
        session:,
      )
  }
  let app_attrs =
    app_boot_attrs(
      authentication_context: ssr_app.authentication_context,
      can_access_admin: ssr_app.can_access_admin,
    )
    <> document.hydration_attr(ssr_app.hydration)

  "<!doctype html>
<html " <> theme.document_attribute(req) <> ">
<head>
  <meta charset=\"utf-8\">
  <meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
  <title>Scoreboard</title>
  <link rel=\"stylesheet\" href=\"https://unpkg.com/@knadh/oat/oat.min.css\">
  <link rel=\"stylesheet\" href=\"/assets/app.css\">
</head>
<body>
  <div id=\"app\"" <> app_attrs <> ">" <> ssr_app.html <> "</div>
  <script type=\"module\">
    import { main } from '/_build/scoreboard/" <> entrypoint <> "';
    main();
  </script>
</body>
</html>"
}

@target(erlang)
fn public_query_params(
  req: Request(Connection),
) -> public_page_input.QueryParams {
  document.query_params(
    req:,
    from_values: fn(values) { public_page_input.QueryParams(values:) },
    empty: public_page_input.empty_query_params,
  )
}

@target(erlang)
fn admin_query_params(
  req: Request(Connection),
) -> admin_page_input.QueryParams {
  document.query_params(
    req:,
    from_values: fn(values) { admin_page_input.QueryParams(values:) },
    empty: admin_page_input.empty_query_params,
  )
}

@target(erlang)
fn app_boot_attrs(
  authentication_context authentication_context: Option(AuthenticationContext),
  can_access_admin can_access_admin: Bool,
) -> String {
  case authentication_context {
    Some(context) -> {
      let display_name = case context.display_name {
        Some(value) -> value
        None -> ""
      }
      document.boot_attrs([
        document.IntAttribute("auth-user-id", context.user_id),
        document.StringAttribute("auth-email", context.email),
        document.StringAttribute("auth-display-name", display_name),
        document.BoolAttribute("can-access-admin", can_access_admin),
      ])
    }
    None ->
      document.boot_attrs([
        document.BoolAttribute("can-access-admin", can_access_admin),
      ])
  }
}
