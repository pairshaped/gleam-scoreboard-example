# Rally Scoreboard

Rally Scoreboard is the definitive [Rally](https://rally.hexdocs.pm/) example app.

The project illustrates how Rally, Proute, Libero, and Marmot can be used to create a client and server from one source tree.

```sh
gleam build --target javascript
gleam build --target erlang
```

Target-specific behavior is marked at the declaration or import boundary. Today that means Gleam's `@target(javascript)` and `@target(erlang)` syntax.

Generated code covers route, page, wire, hydration, SSR, browser boot, websocket transport, server dispatch, theme, and Libero codec glue.

## Shape

- `src/public/pages/**` and `src/admin/pages/**` contain authored page modules.
- `src/components/**` contains reusable view code.
- `src/generated/proute/**` is generated route and page glue.
- `src/generated/rally/**` is generated page protocol, SSR, hydration, browser boot, client transport, websocket, server dispatch, theme, and result glue.
- `src/generated/libero/**` is generated Libero codec, decoder, atom, wire, and contract glue.
- `src/generated/sql/**` is generated typed SQL for Erlang-only server paths.

Authored SQL lives beside the page or workflow that owns it, in a local `sql/` directory. Generated SQL stays under `src/generated/sql/**`.

Generated source is checked in so the example can be read, built, and tested without running every generator first.

## Page Contract

Pages own their local `Model`, browser `Message`, pure `initial_model`, shared `view`, and browser `update` functions. Pages that cross the server boundary also own page-local `ServerMsg` and `LoadResult` types, Erlang-only `load`, and, for save-capable pages, Erlang-only `handle_save` and optional `after_save`. Broadcast-capable pages expose `broadcast_subscriptions` and `apply_broadcast`.

Most pages omit `init`; use it only for page-specific browser startup effects such as browser APIs, local storage, focus, measurement, or one-off DOM effects. Standard page data loading is owned by generated Rally glue.

Page data shapes belong to the page that renders and updates them. Shared types are reserved for stable app concepts independent of a page.

Wire-crossing types may reference page-local types, `src/broadcasts.gleam`, primitives, and containers. Helper, service, query, business, formatting, and display types can be used as behavior, but their owned shapes cannot cross the wire.

Client-side application behavior is authored in Gleam. JS or TS is reserved for tiny FFI modules around browser APIs.

## Design Rules

Page data shapes stay local to the page that renders and updates them. A list page, detail page, and admin editing page may duplicate similar fields because they describe different page needs. Extract a shared type only when it is a stable app concept independent of a page, such as an identifier, enum, topic, or value object.

Authored SQL lives beside the page or workflow that owns the server behavior, in a local `sql/` directory. Generated Marmot output stays under `src/generated/sql`.

Page filenames are the author-facing routing surface. Authored modules should not import generated route modules, match on generated route constructors, or construct generated page wrappers. Generated Proute and Rally modules own route parsing, page wrappers, page message wrappers, and route or page dispatch.

## Current Commands

From the repository root:

```sh
gleam clean
gleam run -m rally reset
gleam run -m rally regen
gleam run -m rally build
mkdir -p tmp
TEMP=$PWD/tmp gleam test
npm run test:browser
```

## Public Routes

- `/`
- `/games`
- `/games?team=TOR`
- `/games/:id`
- `/not_found`
- `/sign_in`
- `/standings`
- `/teams/:slug`

Public routes are generated from `src/public/pages`.

## Admin Routes

- `/admin`
- `/admin/games`
- `/admin/not_found`

Admin routes are generated from `src/admin/pages`.

## Design Notes

The main design note is [docs/unified-target-source.md](docs/unified-target-source.md).
