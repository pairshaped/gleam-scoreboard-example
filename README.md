# Rally Scoreboard

Rally Scoreboard is an example app for [Rally](https://rally.hexdocs.pm/).

The project shows how Rally, Proute, Libero, and Marmot can build a client and server from one source tree.

```sh
gleam build --target javascript
gleam build --target erlang
```

Target-specific code is marked where it starts. Today that means Gleam's `@target(javascript)` and `@target(erlang)` syntax.

Generated code covers route, page, wire, hydration, SSR, browser boot, websocket transport, server dispatch, theme, and Libero codec glue.

## Shape

- `src/public/pages/**` and `src/admin/pages/**` contain authored page modules.
- `src/components/**` contains reusable view code.
- `src/generated/proute/**` is generated route and page glue.
- `src/generated/rally/**` is generated page protocol, SSR, hydration, browser boot, client transport, websocket, server dispatch, theme, and result glue.
- `src/generated/libero/**` is generated Libero codec, decoder, atom, wire, and contract glue.
- `src/generated/sql/**` is generated typed SQL for Erlang-only server paths.

Authored SQL lives beside the page or workflow that uses it, in a local `sql/` directory. Generated SQL stays under `src/generated/sql/**`.

Generated source is checked in so the example can be read, built, and tested without running every generator first.

## Page Shape

Pages define their local `Model`, browser `Message`, pure `initial_model`, shared `view`, and browser `update` functions. Pages that load or save server data also define page-local `ServerMsg` and `LoadResult` types, Erlang-only `load`, and, for pages that can save, Erlang-only `handle_save` and optional `after_save`. Pages that receive broadcasts define `broadcast_subscriptions` and `apply_broadcast`.

`ServerMsg` constructors are local to the page module. Use short names like `Load`, `UpdateScore`, and `MarkFinal` unless they collide with another constructor in the same module. Rally namespaces the generated protocol helpers from the page route, so the public games page still gets generated helpers such as `encode_public_games_request`.

Most pages omit `init`; use it only for page-specific browser startup effects such as browser APIs, local storage, focus, measurement, or one-off DOM effects. Generated Rally glue handles normal page data loading.

Page data shapes belong to the page that renders and updates them. Shared types are for app concepts that do not belong to one page.

Wire-crossing types may reference page-local types, `src/broadcasts.gleam`, primitives, and containers. Pages may call helpers, services, queries, formatters, and display code, but types defined by those modules cannot cross the wire.

Client-side app behavior is written in Gleam. JS or TS is for tiny FFI modules around browser APIs.

## Design Rules

Page data shapes stay local to the page that renders and updates them. A list page, detail page, and admin editing page may duplicate similar fields because they describe different page needs. Extract a shared type only when it is an app concept that does not belong to one page, such as an identifier, enum, topic, or value object.

Authored SQL lives beside the page or workflow that uses it, in a local `sql/` directory. Generated Marmot output stays under `src/generated/sql`.

Page filenames define routes. Authored modules should not import generated route modules, match on generated route constructors, or construct generated page wrappers. Generated Proute and Rally modules handle route parsing, page wrappers, page message wrappers, and route or page dispatch.

## Commands

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
