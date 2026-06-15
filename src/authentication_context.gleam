//// Shared authentication context for the signed-in browser identity.
////
//// Mounts consume this type. They do not own authentication.
//// Auth policy stays in the server auth modules.

import gleam/option.{type Option, None, Some}
import gleam/string

/// Shared identity value for browser mounts and SSR shell rendering.
/// app_ssr builds this from the authenticated server session, then app_shell and
/// browser mount code consume it without owning authentication policy.
pub type AuthenticationContext {
  AuthenticationContext(
    user_id: Int,
    email: String,
    display_name: Option(String),
  )
}

/// Display label used by app_shell.
/// Shells call this after SSR or browser boot has already provided the shared
/// AuthenticationContext.
pub fn display_label(context: AuthenticationContext) -> String {
  case context.display_name {
    Some(name) -> name
    None -> context.email
  }
}

/// Normalizes email before auth records become AuthenticationContext values.
/// app_auth uses the same rule for server-loaded users and sign-in handling.
pub fn normalize_email(email: String) -> String {
  email
  |> string.trim
  |> string.lowercase
}

/// Normalizes optional display names before they enter AuthenticationContext.
/// app_auth uses this while decoding authenticated users from the database.
pub fn normalize_display_name(name: String) -> Option(String) {
  case string.trim(name) {
    "" -> None
    trimmed -> Some(trimmed)
  }
}
