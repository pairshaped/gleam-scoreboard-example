import assert from "node:assert/strict";
import { realpathSync } from "node:fs";
import { createRequire } from "node:module";
import { execFileSync, spawn } from "node:child_process";
import path from "node:path";

import { GameUpdate } from "../build/dev/javascript/scoreboard/admin/pages/games.mjs";
import { decode_result_envelope } from "../build/dev/javascript/scoreboard/generated/rally/client_protocol.mjs";
import { BitArray, Ok } from "../build/dev/javascript/scoreboard/gleam.mjs";

const baseUrl = process.env.SCOREBOARD_BASE_URL ?? "http://localhost:8081";

const { chromium } = loadPlaywright();

let server = null;
let browser = null;

try {
  await step("start server", ensureServer);
  await step("assert /games SSR document", () => assertSsrDocument("/games", [
    "/assets/app.css",
    "data-hydration=",
    "Toronto Towers",
    "Montreal Meteors",
  ]));
  await step("assert app stylesheet asset", assertAppStylesheet);

  browser = await step("launch browser", () => chromium.launch());
  const context = await browser.newContext({ colorScheme: "light" });
  const page = await context.newPage();
  page.setDefaultTimeout(8_000);
  page.setDefaultNavigationTimeout(12_000);
  const sentFrames = [];
  const receivedFrames = [];

  page.on("websocket", socket => {
    socket.on("framesent", frame => {
      sentFrames.push(frame.payload);
    });
    socket.on("framereceived", frame => {
      receivedFrames.push(frame.payload);
    });
  });

  await step("load hydrated /games", () =>
    page.goto(url("/games"), { waitUntil: "domcontentloaded" }),
  );
  await step("see public SSR game data", async () => {
    await page.getByText("Toronto Towers").first().waitFor();
    await page.getByText("Montreal Meteors").first().waitFor();
  });
  await page.waitForTimeout(500);

  assert.equal(
    await page.locator("#app").getAttribute("data-hydration"),
    null,
    "hydration data should be consumed after browser boot",
  );
  assert.equal(
    binaryFrames(sentFrames).length,
    0,
    "hydrated direct /games load should not send an initial websocket load request",
  );
  assert.ok(
    topicFrames(sentFrames).includes("sub:games"),
    "hydrated direct /games should sync the games topic",
  );

  await step("dark mode toggle persists through reload", async () => {
    assert.equal(
      await page.locator("html").getAttribute("data-theme"),
      "light",
      "fresh context should start from the light fallback",
    );

    await page.getByRole("switch").click();
    await page.waitForFunction(() =>
      document.documentElement.dataset.theme === "dark"
    );

    const cookies = await context.cookies(url("/games"));
    assert.equal(
      cookies.find(cookie => cookie.name === "dark")?.value,
      "1",
      "dark-mode toggle should persist through the Rally cookie",
    );

    await page.reload({ waitUntil: "domcontentloaded" });
    await page.waitForFunction(() =>
      document.documentElement.dataset.theme === "dark"
    );
    await page.getByText("Toronto Towers").first().waitFor();

    sentFrames.length = 0;
    receivedFrames.length = 0;
  });

  await step("load hydrated /standings", async () => {
    sentFrames.length = 0;
    receivedFrames.length = 0;

    await page.goto(url("/standings"), { waitUntil: "domcontentloaded" });
    await page.getByRole("heading", { name: "League table" }).waitFor();
    await page.getByText("Toronto Towers").first().waitFor();
    await page.waitForTimeout(500);

    assert.equal(
      await page.locator("#app").getAttribute("data-hydration"),
      null,
      "standings hydration data should be consumed after browser boot",
    );
    assert.equal(
      binaryFrames(sentFrames).length,
      0,
      "hydrated direct /standings load should not send an initial websocket load request",
    );
    assert.ok(
      topicFrames(sentFrames).includes("sub:games"),
      "hydrated direct /standings should sync the games topic",
    );
  });

  await step("navigate from standings to games with load result", async () => {
    sentFrames.length = 0;
    receivedFrames.length = 0;

    await page.getByRole("link", { name: "Games" }).click();
    await page.waitForURL("**/games");
    await page.getByRole("heading", { name: "Today" }).waitFor();
    await page.getByText("Toronto Towers").first().waitFor();
    await page.waitForTimeout(500);

    assert.equal(
      binaryFrames(sentFrames).length,
      1,
      "SPA games navigation should send one websocket load request",
    );
    assert.equal(
      receivedFrames.length,
      1,
      "SPA games navigation should receive one load result: "
        + receivedFrames.map(frameSummary).join(", "),
    );
    assert.equal(
      frameKind(receivedFrames[0]),
      "result",
      "SPA games navigation should receive loaded data in the result frame",
    );
  });

  await step("navigate from games to standings with load result", async () => {
    sentFrames.length = 0;
    receivedFrames.length = 0;

    await page.getByRole("link", { name: "Standings" }).click();
    await page.waitForURL("**/standings");
    await page.getByRole("heading", { name: "League table" }).waitFor();
    await page.getByText("Toronto Towers").first().waitFor();
    await page.waitForTimeout(500);

    assert.equal(
      binaryFrames(sentFrames).length,
      1,
      "SPA standings navigation should send one websocket load request",
    );
    assert.equal(
      receivedFrames.length,
      1,
      "SPA standings navigation should receive one load result: "
        + receivedFrames.map(frameSummary).join(", "),
    );
    assert.equal(
      frameKind(receivedFrames[0]),
      "result",
      "SPA standings navigation should receive loaded data in the result frame",
    );
  });

  await step("load hydrated /games/1", async () => {
    sentFrames.length = 0;
    receivedFrames.length = 0;

    await page.goto(url("/games/1"), { waitUntil: "domcontentloaded" });
    await page.getByRole("heading", { name: "Game detail" }).waitFor();
    await page.getByText("Toronto Towers").first().waitFor();
    await page.waitForTimeout(500);

    assert.equal(
      await page.locator("#app").getAttribute("data-hydration"),
      null,
      "game detail hydration data should be consumed after browser boot",
    );
    assert.equal(
      binaryFrames(sentFrames).length,
      0,
      "hydrated direct /games/1 load should not send an initial websocket load request",
    );
    assert.ok(
      topicFrames(sentFrames).includes("sub:game:1"),
      "hydrated direct /games/1 should sync the game detail topic",
    );
  });

  await step("navigate to game detail", async () => {
    await page.getByRole("link", { name: "Games" }).click();
    await page.waitForURL("**/games");
    await page.getByRole("heading", { name: "Today" }).waitFor();
    await page.getByText("Toronto Towers").first().waitFor();
    await page.waitForTimeout(250);
    sentFrames.length = 0;
    receivedFrames.length = 0;

    await page.getByRole("link", { name: "Details" }).first().click();
    await page.waitForURL("**/games/1");
    await page.getByRole("heading", { name: "Game detail" }).waitFor();
    await page.getByText("Toronto Towers").first().waitFor();
    await page.waitForTimeout(500);
  });
  assert.equal(
    binaryFrames(sentFrames).length,
    1,
    "SPA detail navigation should send one websocket load request",
  );
  assert.deepEqual(
    topicFrames(sentFrames),
    ["sub:game:1"],
    "SPA detail navigation should subscribe from route params without a temporary unsub",
  );

  await step("browser back returns to games", async () => {
    await page.goBack();
    await page.waitForURL("**/games");
    await page.getByRole("heading", { name: "Today" }).waitFor();
    await page.getByText("Toronto Towers").first().waitFor();
    await page.waitForTimeout(500);
  });

  await step("load hydrated /teams/toronto-towers", async () => {
    sentFrames.length = 0;
    receivedFrames.length = 0;

    await page.goto(url("/teams/toronto-towers"), {
      waitUntil: "domcontentloaded",
    });
    await page.getByRole("heading", { name: "Toronto Towers" }).waitFor();
    await page.getByText("Recent games").waitFor();
    await page.waitForTimeout(500);

    assert.equal(
      await page.locator("#app").getAttribute("data-hydration"),
      null,
      "team detail hydration data should be consumed after browser boot",
    );
    assert.equal(
      binaryFrames(sentFrames).length,
      0,
      "hydrated direct /teams/toronto-towers load should not send an initial websocket load request",
    );
    assert.ok(
      topicFrames(sentFrames).includes("sub:team:toronto-towers"),
      "hydrated direct team detail should sync the team topic",
    );
  });

  await step("sign in to admin", async () => {
    await page.goto(url("/sign_in?return_to=/admin/games"), {
      waitUntil: "domcontentloaded",
    });
    await page.getByLabel("Sign-in code").fill("A1Z9Q");
    await page.getByRole("button", { name: "Sign In" }).click();
    await page.waitForURL("**/admin/games");
    await page.getByText("Admin score desk").waitFor();
    await page.getByText("Finalize").first().waitFor();
  });

  await step("admin score save acks origin and broadcasts to peer", async () => {
    sentFrames.length = 0;
    receivedFrames.length = 0;

    const peerPage = await context.newPage();
    const peerReceivedFrames = [];
    peerPage.on("websocket", socket => {
      socket.on("framereceived", frame => {
        peerReceivedFrames.push(frame.payload);
      });
    });
    await peerPage.goto(url("/admin/games"), { waitUntil: "domcontentloaded" });
    await peerPage.getByText("Admin score desk").waitFor();
    await peerPage.getByText("Finalize").first().waitFor();
    peerReceivedFrames.length = 0;

    const firstCard = page.locator(".game-card").first();
    const awayScore = firstCard.locator(".score").first();
    const peerAwayScore = peerPage
      .locator(".game-card")
      .first()
      .locator(".score")
      .first();
    const before = Number(await awayScore.textContent());

    await firstCard.locator(".score-control").nth(1).click();
    await expectText(awayScore, String(before + 1));
    await expectText(peerAwayScore, String(before + 1));
    await page.waitForTimeout(500);

    assert.equal(
      binaryFrames(sentFrames).length,
      1,
      "admin score click should send one websocket save request",
    );
    assert.ok(
      topicFrames(sentFrames).length <= 1,
      "admin score click should not duplicate unchanged topic sync frames: "
        + topicFrames(sentFrames).join(", "),
    );
    const resultFrames = receivedFrames.filter(frame =>
      frameKind(frame) === "result"
    );
    assert.equal(
      resultFrames.length,
      1,
      "admin score click should receive a correlated save result: "
        + receivedFrames.map(frameSummary).join(", "),
    );
    assertSaveResultCarriesGameUpdated(resultFrames[0]);
    assert.equal(
      receivedFrames.some(frame => frameKind(frame) === "push"),
      false,
      "admin score click should not receive its own GameUpdated broadcast: "
        + receivedFrames.map(frameSummary).join(", "),
    );
    assert.ok(
      peerReceivedFrames.some(frame => frameKind(frame) === "push"),
      "peer admin page should receive GameUpdated broadcast: "
        + peerReceivedFrames.map(frameSummary).join(", "),
    );
    await peerPage.close();
  });

} finally {
  if (browser) {
    await browser.close();
  }
  if (server) {
    await stopServer(server);
  }
}

function loadPlaywright() {
  const localRequire = createRequire(import.meta.url);

  try {
    return localRequire("playwright");
  } catch (_) {
    let cliPath;
    try {
      cliPath = execFileSync(
        "sh",
        ["-lc", "command -v playwright || command -v playwright-cli"],
        { encoding: "utf8" },
      ).trim();
    } catch {
      throw new Error(
        "Playwright is not installed. Install `playwright` or `playwright-cli`.",
      );
    }

    const cliRequire = createRequire(realpathSync(cliPath));
    try {
      return cliRequire("playwright");
    } catch (_) {
      return cliRequire("playwright-core");
    }
  }
}

async function ensureServer() {
  if (await isServing()) return;

  server = spawn("gleam", ["run"], {
    cwd: process.cwd(),
    env: { ...process.env, PORT: new URL(baseUrl).port || "8081" },
    detached: true,
    stdio: ["ignore", "pipe", "pipe"],
  });

  let output = "";
  server.stdout.on("data", chunk => {
    output += chunk.toString();
  });
  server.stderr.on("data", chunk => {
    output += chunk.toString();
  });

  const deadline = Date.now() + 20_000;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) {
      throw new Error("Server exited before becoming ready:\n" + output);
    }
    if (await isServing()) return;
    await sleep(250);
  }

  throw new Error("Timed out waiting for server:\n" + output);
}

async function stopServer(server) {
  if (server.exitCode !== null) return;

  try {
    process.kill(-server.pid, "SIGTERM");
  } catch (_) {
    server.kill("SIGTERM");
  }

  const deadline = Date.now() + 2_000;
  while (Date.now() < deadline) {
    if (server.exitCode !== null) return;
    await sleep(100);
  }

  try {
    process.kill(-server.pid, "SIGKILL");
  } catch (_) {
    server.kill("SIGKILL");
  }
}

async function isServing() {
  try {
    const response = await fetch(url("/games"));
    return response.ok;
  } catch {
    return false;
  }
}

async function assertSsrDocument(route, expected) {
  const response = await fetch(url(route));
  assert.equal(response.status, 200);
  const html = await response.text();

  assert.notEqual(
    html,
    '<div id="app"></div>',
    "SSR document should not be an empty app root",
  );

  for (const text of expected) {
    assert.ok(
      html.includes(text),
      `SSR document for ${route} should contain ${JSON.stringify(text)}`,
    );
  }
}

async function assertAppStylesheet() {
  const response = await fetch(url("/assets/app.css"));
  assert.equal(response.status, 200);
  assert.match(
    response.headers.get("content-type") ?? "",
    /^text\/css\b/,
    "app stylesheet should be served as CSS",
  );

  const css = await response.text();
  assert.ok(
    css.includes("--score-ink") && css.includes(".scoreboard-app"),
    "app stylesheet should contain the Scoreboard CSS",
  );
}

function url(route) {
  return new URL(route, baseUrl).toString();
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

function frameSummary(payload) {
  const bytes = frameBytes(payload);
  return `${frameKind(payload)}:${bytes.length}`;
}

function binaryFrames(frames) {
  return frames.filter(frame => typeof frame !== "string");
}

function topicFrames(frames) {
  return frames.filter(frame =>
    typeof frame === "string" && (frame === "unsub" || frame.startsWith("sub:"))
  );
}

function frameKind(payload) {
  const bytes = frameBytes(payload);
  return bytes[0] === 0
    ? "response"
    : bytes[0] === 1
    ? "push"
    : bytes[0] === 2
    ? "result"
    : "raw";
}

function frameBytes(payload) {
  const bytes = payload instanceof Buffer
    ? payload
    : payload instanceof Uint8Array
    ? Buffer.from(payload)
    : Buffer.from(String(payload));
  return bytes;
}

function assertSaveResultCarriesGameUpdated(payload) {
  const frame = new BitArray(new Uint8Array(frameBytes(payload)));
  const decoded = decode_result_envelope(frame);
  assert.ok(decoded instanceof Ok, "save result frame should decode");
  const [, result] = decoded[0];
  assert.ok(result instanceof Ok, "save result should be Ok");
  assert.ok(
    result[0] instanceof GameUpdate,
    "save result should carry the admin page's saved game update",
  );
}

async function expectText(locator, text) {
  const deadline = Date.now() + 5_000;
  while (Date.now() < deadline) {
    if (await locator.textContent() === text) return;
    await sleep(100);
  }

  assert.equal(await locator.textContent(), text);
}

async function step(name, work) {
  process.stdout.write(`browser smoke: ${name}\n`);
  return await work();
}
