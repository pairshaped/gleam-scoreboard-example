import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync, statSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");

function readProjectFile(projectPath) {
  return readFileSync(path.join(root, projectPath), "utf8");
}

function gleamFilesUnder(projectDir) {
  const absoluteDir = path.join(root, projectDir);
  return readdirSync(absoluteDir).flatMap((entry) => {
    const absolutePath = path.join(absoluteDir, entry);
    const projectPath = path.relative(root, absolutePath);

    if (statSync(absolutePath).isDirectory()) {
      return gleamFilesUnder(projectPath);
    }

    return projectPath.endsWith(".gleam") ? [projectPath] : [];
  });
}

function rootGleamFiles() {
  const srcDir = path.join(root, "src");
  return readdirSync(srcDir)
    .map((entry) => path.join("src", entry))
    .filter((projectPath) => {
      const absolutePath = path.join(root, projectPath);
      return statSync(absolutePath).isFile() && projectPath.endsWith(".gleam");
    });
}

function sourceWithoutComments(source) {
  return source.replace(/\/\/.*$/gm, "");
}

function gleamUnionConstructors(projectPath, typeName) {
  const source = readProjectFile(projectPath);
  const union = source.match(
    new RegExp(`pub\\s+type\\s+${typeName}\\s*\\{([\\s\\S]*?)\\n\\}`),
  );

  assert.ok(
    union,
    `Could not find generated Proute ${typeName} union in ${projectPath}`,
  );

  return [...union[1].matchAll(/^\s*([A-Z][A-Za-z0-9_]*)\b/gm)].map(
    (match) => match[1],
  );
}

function regexAlternation(values) {
  return [...new Set(values)]
    .sort((a, b) => b.length - a.length)
    .map((value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"))
    .join("|");
}

function assertNoPatterns(projectPath, patterns) {
  const source = readProjectFile(projectPath);

  for (const { pattern, reason } of patterns) {
    assert.doesNotMatch(
      source,
      pattern,
      `${projectPath} leaks Rally-generated plumbing: ${reason}`,
    );
  }
}

function assertNoCodePatterns(projectPath, patterns) {
  const source = sourceWithoutComments(readProjectFile(projectPath));

  for (const { pattern, reason } of patterns) {
    assert.doesNotMatch(source, pattern, reason(projectPath));
  }
}

const pageModules = [
  ...gleamFilesUnder("src/admin/pages"),
  ...gleamFilesUnder("src/public/pages"),
];

const routeConstructors = regexAlternation([
  ...gleamUnionConstructors("src/generated/proute/admin/routes.gleam", "Route"),
  ...gleamUnionConstructors("src/generated/proute/public/routes.gleam", "Route"),
]);
const pageConstructors = regexAlternation([
  ...gleamUnionConstructors("src/generated/proute/admin/pages.gleam", "Page"),
  ...gleamUnionConstructors("src/generated/proute/public/pages.gleam", "Page"),
]);
const routingDispatchExceptionReasons = new Map();

function assertNoAuthoredRoutingDispatch(projectPath) {
  if (routingDispatchExceptionReasons.has(projectPath)) {
    const exceptionReason = routingDispatchExceptionReasons.get(projectPath);
    assert.notEqual(
      exceptionReason.trim(),
      "",
      `${projectPath} routing guard exception must document the app-policy reason`,
    );
    return;
  }

  const routingRule =
    "README Design Rules say page filenames are the author-facing routing " +
    "surface; generated Proute/Rally glue owns route and page dispatch.";

  assertNoCodePatterns(projectPath, [
    {
      pattern: /import\s+generated\/proute\/(?:admin|public)\/routes\b/,
      reason: (file) =>
        `${file} violates the README routing rule: authored modules must not import generated route modules. ${routingRule}`,
    },
    {
      pattern: new RegExp(
        `\\b(?:admin_routes|public_routes|routes)\\.(?:${routeConstructors})\\b`,
      ),
      reason: (file) =>
        `${file} violates the README routing rule: authored modules must not match generated route constructors. ${routingRule}`,
    },
    {
      pattern: new RegExp(
        `\\b(?:admin_pages|public_pages|pages)\\.(?:${pageConstructors})\\s*\\(`,
      ),
      reason: (file) =>
        `${file} violates the README routing rule: authored modules must not match generated page constructors. ${routingRule}`,
    },
    {
      pattern: new RegExp(`\\b(?:${pageConstructors})\\s*\\(`),
      reason: (file) =>
        `${file} violates the README routing rule: authored modules must not construct generated page wrappers. ${routingRule}`,
    },
  ]);
}

for (const projectPath of [...rootGleamFiles(), ...pageModules]) {
  assertNoAuthoredRoutingDispatch(projectPath);
}

for (const pageModule of pageModules) {
  assertNoPatterns(pageModule, [
    {
      pattern: /generated\/rally\/client_transport/,
      reason: "pages should call the page-facing generated/rally/server API",
    },
    {
      pattern: /generated\/rally\/result/,
      reason: "transport result envelopes are Rally-owned generated plumbing",
    },
    {
      pattern: /generated\/rally\/server_protocol/,
      reason: "wire protocol framing belongs behind generated adapters",
    },
  ]);
}

assertNoPatterns("src/app_ws.gleam", [
  {
    pattern: /generated\/rally\/server_protocol/,
    reason: "websocket request/result protocol calls belong in server_ws",
  },
  {
    pattern: /generated\/rally\/result/,
    reason: "transport result envelopes belong in server_ws",
  },
  {
    pattern: /\bserver_protocol\./,
    reason: "app_ws should consume server_ws, not protocol helpers directly",
  },
  {
    pattern: /\bdecode_[a-z_]+_request\b/,
    reason: "request decoding belongs in server_ws",
  },
  {
    pattern: /\bencode_[a-z_]+_(?:load|save)_result\b/,
    reason: "request result encoding belongs in server_ws",
  },
  {
    pattern: /\bfn load_public_[a-z_]+\b/,
    reason: "public websocket page load adapters belong in generated server_ws",
  },
  {
    pattern: /import\s+(?:admin|public)\/pages\//,
    reason: "app_ws should pass app policy/context to server_ws, not import page modules",
  },
  {
    pattern: /\b(?:admin|public)_[a-z_]+_(?:load|save):\s*\w/,
    reason: "websocket page load/save callbacks belong in generated server_ws",
  },
  {
    pattern: /\bafter_(?:admin|public)_[a-z_]+_save\b/,
    reason: "websocket after-save broadcast plumbing belongs in generated server_ws",
  },
  {
    pattern: /admin_authorized|_authorized:\s*fn\(state\)\s*->\s*Bool/,
    reason: "websocket auth should pass typed request auth context, not collapse auth to a root-owned Bool adapter",
  },
  {
    pattern:
      /\btopics\.(?:start|frame_selector|leave)\b|\bsync_topic_frame\b/,
    reason:
      "websocket topic selector setup, subscription sync, and cleanup belong in server_ws",
  },
  {
    pattern:
      /\bmist\.(?:Binary|Custom|Text|Closed|Shutdown|send_binary_frame|continue|stop)\b/,
    reason: "websocket transport message dispatch belongs in server_ws",
  },
  {
    pattern: /\bhandle_client_frame\b/,
    reason: "websocket client-frame routing belongs in server_ws",
  },
]);

assertNoPatterns("src/app_ssr.gleam", [
  {
    pattern: /generated\/rally\/result/,
    reason: "SSR should consume server_ssr, not transport result envelopes",
  },
  {
    pattern: /generated\/rally\/server_protocol/,
    reason: "SSR wire protocol framing belongs in server_ssr",
  },
  {
    pattern: /\bserver_protocol\./,
    reason: "SSR should consume server_ssr, not protocol helpers directly",
  },
  {
    pattern: /\bbase64_url_encode\b/,
    reason: "hydration payload encoding belongs in server_ssr",
  },
  {
    pattern: /\bencode_[a-z_]+_load_result\b/,
    reason: "load result frame encoding belongs in server_ssr",
  },
  {
    pattern: /fn\s+\w+_hydration_payload\b/,
    reason: "hydration payload helper functions should be generated",
  },
  {
    pattern: /(?:admin|public)_[a-z_]+_load:\s*fn/,
    reason: "SSR page load adapters belong in generated server_ssr",
  },
  {
    pattern: /\b(?:Admin|Public)LoadHandlers\b|\b(?:admin|public)_load_handlers\b/,
    reason:
      "SSR load-context wrapper records belong in generated server_ssr or should disappear",
  },
  {
    pattern: /\bhandlers:\s*server_ssr\./,
    reason: "app_ssr should pass load context directly to generated SSR glue",
  },
]);

assert.ok(
  !existsSync(path.join(root, "src/page_stub.gleam")),
  "src/page_stub.gleam should not return as root-level placeholder page glue",
);

for (const browserApp of ["src/admin_app.gleam", "src/public_app.gleam"]) {
  assertNoPatterns(browserApp, [
    {
      pattern: /\btype\s+(?:Model|Msg)\b|\bfn\s+(?:init|update|navigate)\b/,
      reason: "standard browser Model/Msg/init/update/navigation lifecycle belongs in browser_app",
    },
    {
      pattern: /PageMsg|ServerFrame|ShellNavigate|BrowserPathChanged/,
      reason: "browser lifecycle message variants belong in generated browser_app",
    },
    {
      pattern: /browser\.path|device_dark_mode|initial_page_from_path|load_path|message_path|server_frame_effect|navigation_effects|startup_effects|sync_topics|page_broadcast_subscriptions/,
      reason: "current-path boot, loads, navigation, server frames, and topic sync belong in browser_app",
    },
    {
      pattern: /\blustre\.application\b/,
      reason: "browser app startup belongs in browser_app",
    },
    {
      pattern: /\blustre\.start\b/,
      reason: "browser app mounting belongs in browser_app",
    },
    {
      pattern: /\bbrowser_mount\.startup_effects\b/,
      reason: "startup effect wiring belongs in browser_app",
    },
    {
      pattern: /\bbrowser_mount\.push_path\b/,
      reason: "navigation effect wiring belongs in browser_app",
    },
  ]);
}

for (const staleGeneratedFile of [
  "src/generated/rally/admin_boot.gleam",
  "src/generated/rally/public_boot.gleam",
  "src/generated/rally/to_client_application.gleam",
]) {
  assert.equal(
    existsSync(path.join(root, staleGeneratedFile)),
    false,
    `${staleGeneratedFile} contains app-owned behavior and must not live in generated/rally`,
  );
}

for (const staleFrameworkModule of [
  "src/app_config.gleam",
  "src/app_config_ffi.erl",
  "src/app_session.gleam",
  "src/app_session_crypto_ffi.erl",
  "src/app_topics.gleam",
  "src/app_topics_ffi.erl",
  "src/device_preferences.gleam",
  "src/server_context.gleam",
  "src/to_client_application.gleam",
]) {
  assert.equal(
    existsSync(path.join(root, staleFrameworkModule)),
    false,
    `${staleFrameworkModule} is generic Rally topic plumbing and must not live in app code`,
  );
}

assertNoPatterns("src/app_auth.gleam", [
  {
    pattern: /app_session|session_cookie|find_session|_scoreboard_session/,
    reason: "generic session-cookie lookup and codec details belong in Rally runtime session helpers",
  },
  {
    pattern: /gleam\/crypto|crypto\.hmac|secure_compare|runtime-sign-in-code-hmac-sha256|parse_hash|base64_url_decode/,
    reason: "generic login-code HMAC verification belongs in Rally runtime auth helpers",
  },
]);

assertNoPatterns("src/app_auth_http.gleam", [
  {
    pattern: /gleam\/http\/cookie|session_cookie_attributes|_scoreboard_session/,
    reason: "generic auth session cookie attributes belong in Rally runtime session helpers",
  },
  {
    pattern: /app_session|app_session_crypto_ffi|find_auth_cookie|decode_user_id|get_cookies/,
    reason: "session cookie crypto belongs in Rally runtime session helpers",
  },
  {
    pattern: /mist\.read_body|bit_array\.to_string|uri\.parse_query/,
    reason: "generic sign-in form parsing belongs in Rally runtime auth HTTP helpers",
  },
  {
    pattern: /response\.(?:new|set_header|set_body|set_cookie|expire_cookie)/,
    reason: "standard auth redirect and session-cookie responses belong in Rally runtime auth HTTP helpers",
  },
  {
    pattern: /read_sign_in_form|issue_user_session|invalid_sign_in_redirect/,
    reason: "standard sign-in POST workflow belongs in Rally runtime auth HTTP helpers",
  },
]);

assertNoPatterns("src/scoreboard_unified.gleam", [
  {
    pattern: /import\s+app_config\b|db_path|sqlight\.open|auth_session_from_env|SCOREBOARD_SECRET_KEY_BASE|SECRET_KEY_BASE|DATABASE_PATH|PORT/,
    reason: "server startup config, DB opening, and auth session lookup belong in Rally runtime bootstrap",
  },
  {
    pattern: /import\s+rally\/runtime\/static\b|static\.serve_asset|"\/assets\/"|"priv\/static"|string\.starts_with\(req\.path,\s*"\/assets\/"\)/,
    reason: "standard static asset routing belongs in Rally runtime bootstrap",
  },
  {
    pattern: /new_auth_session|strong_random_bytes|base64_url_decode|SecretKeyError|secret_key_error/,
    reason: "server startup should ask Rally for auth session configuration instead of owning session-key mechanics",
  },
  {
    pattern: /import\s+gleam\/http(?:\s|$)|http\.(?:Get|Post)|"\/sign_in"|"\/sign_out"|sign_in_redirect/,
    reason: "standard auth route dispatch and protected redirects belong in Rally runtime auth HTTP helpers",
  },
  {
    pattern: /StandardAuthRoutes|sign_in_with_code|auth_http\.sign_out/,
    reason: "standard code auth route composition belongs in Rally runtime auth HTTP helpers",
  },
]);

assertNoPatterns("src/browser_mount.gleam", [
  {
    pattern: /device_dark_mode|dark_mode_changed_effects|persist_dark_mode/,
    reason: "dark-mode storage/application mechanics belong in generated Rally browser helpers",
  },
  {
    pattern: /_scoreboard_device|__rally_dark_mode|dark_mode=/,
    reason: "dark-mode cookie details belong in generated Rally helpers",
  },
]);

assertNoPatterns("src/app_document.gleam", [
  {
    pattern: /device_preferences|_scoreboard_device|__rally_dark_mode|dark_mode=/,
    reason: "SSR dark-mode cookie parsing belongs in generated Rally theme helpers",
  },
  {
    pattern: /response\.(?:new|set_header|set_body)|mist\.Bytes|bytes_tree/,
    reason: "standard HTML response construction belongs in Rally runtime document helpers",
  },
  {
    pattern: /request\.get_query/,
    reason: "query-param extraction into page input belongs in Rally runtime document helpers",
  },
  {
    pattern: /data-hydration|html_attr_escape|string\.replace\("&"|&quot;|&lt;|&gt;/,
    reason: "hydration and boot attribute encoding belongs in Rally runtime document helpers",
  },
  {
    pattern: /admin_app\.mjs|public_app\.mjs/,
    reason: "standard browser entrypoint selection belongs in Rally runtime document helpers",
  },
]);

assertNoPatterns("src/generated/rally/browser_mount.gleam", [
  {
    pattern: /authentication_context/,
    reason: "app authentication context parsing belongs in app code",
  },
  {
    pattern: /cookie_name|_scoreboard_device/,
    reason: "generated Rally browser helpers must not require app-supplied dark-mode cookie names",
  },
]);

for (const generatedBrowserFile of [
  "src/generated/rally/browser_ffi.mjs",
  "src/generated/rally/client_transport_ffi.mjs",
]) {
  assertNoPatterns(generatedBrowserFile, [
    {
      pattern: /scoreboard/i,
      reason: "generated Rally browser plumbing must not carry app names",
    },
  ]);
}

console.log("Boundary guard checks passed");
