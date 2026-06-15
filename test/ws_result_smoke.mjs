import assert from "node:assert/strict";
import { spawn } from "node:child_process";

import {
  decode_result_envelope,
  encode_public_games_request,
} from "../build/dev/javascript/scoreboard/generated/rally/client_protocol.mjs";
import { Load, GamesLoaded } from "../build/dev/javascript/scoreboard/public/pages/games.mjs";
import { BitArray, Ok } from "../build/dev/javascript/scoreboard/gleam.mjs";

const baseUrl = process.env.SCOREBOARD_BASE_URL ?? "http://localhost:8081";
const requestId = 77;

let server = null;

try {
  await ensureServer();

  const frames = await requestFrames();
  const resultFrame = frames.find(frame => frame.byteAt(0) === 2);
  const responseFrame = frames.find(frame => frame.byteAt(0) === 0);

  assert.ok(resultFrame, "expected a correlated result frame");
  assert.equal(responseFrame, undefined, "load data should not arrive as a separate response frame");

  const decodedResult = decode_result_envelope(resultFrame);
  assert.ok(decodedResult instanceof Ok, "result frame should decode");
  assert.equal(decodedResult[0][0], requestId);
  assert.ok(decodedResult[0][1] instanceof Ok, "load result should be Ok");
  assert.ok(
    decodedResult[0][1][0] instanceof GamesLoaded,
    "load result should carry the page-local loaded data payload",
  );
} finally {
  if (server) {
    await stopServer(server);
  }
}

async function requestFrames() {
  const socket = new WebSocket(wsUrl("/ws"));
  socket.binaryType = "arraybuffer";

  const frames = [];

  await new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      reject(new Error("timed out waiting for websocket response frames"));
    }, 5_000);

    socket.addEventListener("open", () => {
      const frame = encode_public_games_request(requestId, new Load());
      socket.send(frame.rawBuffer);
    });

    socket.addEventListener("message", event => {
      const frame = new BitArray(new Uint8Array(event.data));
      frames.push(frame);

      if (frame.byteAt(0) === 2) {
        setTimeout(() => {
          clearTimeout(timeout);
          socket.close();
          resolve();
        }, 250);
      }
    });

    socket.addEventListener("error", () => {
      clearTimeout(timeout);
      reject(new Error("websocket connection failed"));
    });
  });

  return frames;
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

function url(route) {
  return new URL(route, baseUrl).toString();
}

function wsUrl(route) {
  const target = new URL(route, baseUrl);
  target.protocol = target.protocol === "https:" ? "wss:" : "ws:";
  return target.toString();
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}
