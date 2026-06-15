# Unified Target Source

Rally Scoreboard uses one authored Gleam source tree. The source tree compiles directly for JavaScript and Erlang, with target-specific declarations and imports marked where target-specific code starts. Rally should not generate a separate client package from server-shaped source.

```text
src/
  public/
  admin/
  components/
  generated/
```

Run both target builds when checking generated and authored source:

```sh
gleam build --target javascript
gleam build --target erlang
```

## Page Shape

A page module should read like a basic TEA SPA page with server handlers at the bottom.

```gleam
import components/ui
import admin/page_shared_state.{type AdminPageSharedState}
import broadcasts
import generated/proute/admin/page_input
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import rally/runtime/load as runtime_load

@target(erlang)
import generated/sql/admin/pages/games_sql

@target(javascript)
import generated/rally/server

pub type Model {
  Model(games: List(AdminGameSummary), saving: Bool)
}

pub type Message {
  AdjustHome(id: Int, home_score: Int, away_score: Int, delta: Int)
  Loaded(Result(List(AdminGameSummary), runtime_load.LoadError))
  Saved(Result(GameUpdate, SaveError))
}

pub type ServerMsg {
  Load
  UpdateScore(
    game_id: Int,
    home_score: Int,
    away_score: Int,
    period: String,
  )
  MarkFinal(game_id: Int)
}

pub type LoadResult {
  AdminGamesLoadResult(games: List(AdminGameSummary))
}

pub fn view(model: Model) -> Element(Message) {
  todo
}

// INIT

/// generated/proute/admin/pages module calls this to construct an empty page
/// before Rally applies hydrated or freshly loaded data.
pub fn initial_model(
  _page_shared_state: AdminPageSharedState,
  _query_params: page_input.QueryParams,
) -> Model {
  Model(games: [], saving: False)
}

/// generated/proute/admin/pages module calls this when the route first builds
/// the page.
/// Most Rally pages omit this. Use it only for page-specific client startup
/// effects such as browser APIs, local storage, focus, measurement, or one-off
/// DOM effects. Generated Rally glue handles normal page data loading.
pub fn init(
  page_shared_state page_shared_state: AdminPageSharedState,
  query_params query_params: page_input.QueryParams,
) -> #(Model, Effect(Message)) {
  #(initial_model(page_shared_state, query_params), effect.none())
}

// CLIENT

@target(javascript)
pub fn update(
  _page_shared_state: AdminPageSharedState,
  model model: Model,
  msg msg: Message,
) -> #(Model, Effect(Message)) {
  case msg {
    AdjustHome(id, home_score, away_score, delta) -> #(
      Model(..model, saving: True),
      server.save_admin_games(
        message: UpdateScore(
          game_id: id,
          home_score: home_score + delta,
          away_score: away_score,
          period: "Live",
        ),
        on_result: fn(result) { Saved(result) },
      ),
    )
    Loaded(_) | Saved(_) -> todo
  }
}

// SERVER

@target(erlang)
pub fn load(ctx) -> Result(List(AdminGameSummary), runtime_load.LoadError) {
  todo
}

@target(erlang)
pub fn handle_save(ctx, msg: ServerMsg) -> Result(GameUpdate, SaveError) {
  todo
}

@target(erlang)
pub fn after_save(
  ctx,
  game: GameUpdate,
) -> Result(broadcasts.TargetedEvent, Nil) {
  todo
}
```

Shared imports come first, followed by Erlang-targeted imports, then JavaScript-targeted imports. The module body follows the same target grouping when practical: shared declarations first, then init/shared declarations, then server/client sections for target-specific code.

The section comments are for readers. Rally checks the page contract by function names, signatures, target availability, and wire-visible types.

`initial_model` is the normal starting point for a page. `init` is optional. A page should define `init` only when it needs page-local browser startup work that cannot be represented as loaded page data or normal update behavior. Rally-generated browser glue calls `init` when it exists; otherwise it constructs the page with `initial_model` and no effect. Rally-generated SSR glue uses `initial_model` so server rendering never depends on browser-only effects.

Pages that load server data define a page-local `ServerMsg` load variant, a `LoadResult`, and Erlang-only `load`. Pages that save server data define save variants on `ServerMsg`, browser update branches that call a generated page save effect, Erlang-only `handle_save`, and optional Erlang-only `after_save` when a successful save should send a typed broadcast.

`ServerMsg` constructors are page-local Gleam names. Prefer names such as `Load`, `UpdateScore`, and `MarkFinal`; add more context only when there is a real same-module constructor collision. Rally gives generated protocol helpers route-scoped names such as `encode_admin_games_request` and `save_admin_games`.

Pages that receive broadcasts define `broadcast_subscriptions` and `apply_broadcast`. Generated browser glue uses subscriptions to sync websocket topics for the active page, then routes decoded broadcast events back through the page's `apply_broadcast` hook.

## Generated Save Effects

Page code sends page-local `ServerMsg` values through a generated Rally save
effect:

```gleam
server.save_admin_games(
  message: MarkFinal(id),
  on_result: fn(result) { Saved(result) },
)
```

The effect returns Lustre `Effect(Message)`. Rally handles request id generation,
pending callback registration, wire encoding, result decoding, and dispatching
the selected local `Message`.

`on_result` receives a normal `Result(success, error)` and returns a local
browser `Message`. A save with no success payload uses `Result(Nil, SaveError)`.
A create flow can use `Result(Item, SaveError)`.

Page code carries local context in the completion message only when it needs that context:

```gleam
server.save_admin_games(
  message: UpdateScore(game_id:, home_score:, away_score:, period:),
  on_result: fn(result) { ScoreSaved(game_id, result) },
)
```

Server state events should be delivered to other subscribed clients, excluding the connection that made the change. Request results handle the request lifecycle for the page that sent the request. Broadcast events carry server state for subscribed peers.

Generated load/save transport helpers are internal Rally glue. Authored page
code uses generated page-specific save functions such as
`server.save_admin_games(message:, on_result:)` for page-local server commands,
while generated Rally browser glue handles normal page data loading.

## Authoring Style

Use the existing Rally/Gleam house style for module layout. Large modules use section comment headers to separate major regions:

```text
// TYPES
// INIT
// UPDATE
// BROADCAST
// VIEW
// EFFECTS
// HELPERS
```

Small modules do not need headers when headers add noise.

Imports are grouped by target first:

1. unannotated imports that compile on both targets
2. `@target(erlang)` imports
3. `@target(javascript)` imports

Groups are separated by a blank line. Within each target group, imports are sorted alphabetically.

Generated output and rewritten source should keep this order and style where `gleam format` allows it. The formatter controls final import formatting and preserves blank-line groups. Rally should not fight the formatter, write random import order, or change section layout when behavior did not change.

## Page Data

Page data shapes belong to the page that renders and updates them. A list page, detail page, and form page should duplicate similar fields instead of sharing one model just because their current shapes overlap.

Shared types are for app concepts that do not belong to one page, such as identifiers, enums, or value objects. Page payloads, form models, table rows, detail data, and save responses stay page local.

The approved wire namespaces are page-local types and `src/broadcasts.gleam`.
Wire-visible page protocols may reference those types, primitives, and standard
containers. They may not reference helper, service, query, business, formatting,
or display types, even transitively.

Pages may call helpers and services, but types defined by helpers and services cannot become wire shapes.

## Generated Source

Generated source lives under `src/generated`:

```text
src/generated/proute/**/*.gleam
src/generated/rally/**/*.gleam
src/generated/libero/**/*.gleam
src/generated/libero/**/*.erl
src/generated/sql/**/*.gleam
```

Proute handles file routes, page enums, route params, query params, and page
dispatch shape. Rally reads Proute output and generates page protocol code,
browser boot, hydration, SSR, client transport, websocket transport, server
dispatch, theme, and result glue. Libero writes codec, atom, wire, decoder, and
contract files. Marmot writes typed SQL modules for Erlang-only server
paths.

Generated modules use the same target annotation rules as user-authored modules.

Rally-generated code should stay small and mechanical: codecs, route glue, wire
transport, hydration, SSR, browser boot, websocket transport, server dispatch,
theme, and result envelopes. Rally should not generate a full client app.
Client-side app behavior is written in Gleam, with JS or TS limited to tiny FFI
modules for browser APIs.

## Target Boundaries

Target annotations belong where target-specific code begins:

- JavaScript-only imports and declarations for browser APIs, DOM effects, browser storage, and browser transport setup
- Erlang-only imports and declarations for SQL, secrets, filesystem access, server runtime APIs, and server handlers
- unannotated declarations only when they compile and make sense on both targets

Target-specific imports should be annotated too. Inactive-target builds should not keep unused or invalid imports.

Boundary diagnostics should name the broken rule, the page/action/channel, the offending type or import, the path that made it reachable, and the smallest likely fix.

## Routing And Decoding

Proute handles URL routing and page identity. Rally uses Proute's page, action, or channel identity when dispatching incoming wire messages, and decodes page-local payloads only after that destination is known. This keeps page-local type names local: two pages can both define `Item` without needing global type identity hashes.

## SQL And Marmot

Marmot output belongs under root `src/generated/sql`.

Authored SQL files live beside the page or workflow that uses them, in a local `sql/` directory:

```text
src/public/pages/items.gleam
src/public/pages/items/sql/list_items.sql

src/public/pages/items/id_.gleam
src/public/pages/items/id_/sql/get_item.sql
```

Workflow modules follow the same rule: the workflow keeps its SQL locally, and generated SQL still goes to `src/generated/sql`.

Server code imports these modules from Erlang-only declarations. JavaScript builds must not keep code paths that import SQL modules.
