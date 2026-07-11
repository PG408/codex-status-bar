#!/usr/bin/env node
const assert = require("assert");

const { resolveSessionSurface, focusTargetForState } = require("./lib/session-surface");

function run(name, fn) {
  try {
    fn();
    console.log(`PASS ${name}`);
  } catch (error) {
    console.error(`FAIL ${name}`);
    console.error(error && error.stack ? error.stack : error);
    process.exitCode = 1;
  }
}

run("payload entrypoint has highest priority", () => {
  const surface = resolveSessionSurface(
    { session_id: "desktop-session", entrypoint: "codex-desktop", term_program: "Apple_Terminal" },
    {},
    { TERM_PROGRAM: "ghostty" },
    { pid: 42, processCommand: "/usr/bin/codex" }
  );
  assert.equal(surface.entrypoint, "codex-desktop");
  assert.equal(surface.entrypointSource, "payload");
  assert.deepEqual(surface.focusTarget, {
    kind: "url",
    url: "codex://threads/desktop-session",
    fallback: { kind: "bundle", bundleId: "com.openai.codex" },
  });
});

run("term program infers cli surface", () => {
  const surface = resolveSessionSurface({}, {}, { TERM_PROGRAM: "ghostty" }, { pid: 42 });
  assert.equal(surface.entrypoint, "cli");
  assert.equal(surface.entrypointSource, "termProgram");
  assert.equal(surface.termProgram, "ghostty");
  assert.deepEqual(surface.focusTarget, { kind: "app", appName: "ghostty" });
});

run("codex desktop process infers desktop surface", () => {
  const surface = resolveSessionSurface(
    { session_id: "process-session" },
    {},
    {},
    {
      pid: 84584,
      processCommand: "/Applications/Codex.app/Contents/Resources/codex app-server --analytics-default-enabled",
    }
  );
  assert.equal(surface.entrypoint, "codex-desktop");
  assert.equal(surface.entrypointSource, "process");
  assert.deepEqual(surface.focusTarget, {
    kind: "url",
    url: "codex://threads/process-session",
    fallback: { kind: "bundle", bundleId: "com.openai.codex" },
  });
});

run("ChatGPT desktop process infers desktop surface", () => {
  const surface = resolveSessionSurface(
    { session_id: "chatgpt-session" },
    {},
    {},
    {
      pid: 10898,
      processCommand: "/Applications/ChatGPT.app/Contents/Resources/codex -c features.code_mode_host=true app-server",
    }
  );
  assert.equal(surface.entrypoint, "codex-desktop");
  assert.equal(surface.entrypointSource, "process");
  assert.equal(surface.focusTarget.url, "codex://threads/chatgpt-session");
});

run("cli surface does not generate desktop thread deeplink", () => {
  const surface = resolveSessionSurface(
    { session_id: "cli-session", entrypoint: "cli", term_program: "Apple_Terminal" },
    {},
    {},
    { pid: 42, processCommand: "/usr/bin/codex" }
  );
  assert.equal(surface.entrypoint, "cli");
  assert.deepEqual(surface.focusTarget, { kind: "app", appName: "Terminal" });
  assert.equal(JSON.stringify(surface.focusTarget).includes("codex://threads/cli-session"), false);
});

run("previous known surface is preserved before unknown fallback", () => {
  const surface = resolveSessionSurface({}, {
    entrypoint: "cli",
    entrypointSource: "termProgram",
    termProgram: "iTerm.app",
    focusTarget: { kind: "app", appName: "iTerm" },
  }, {}, { pid: 42, processCommand: "" });
  assert.equal(surface.entrypoint, "cli");
  assert.equal(surface.entrypointSource, "previous");
  assert.equal(surface.termProgram, "iTerm.app");
  assert.deepEqual(surface.focusTarget, { kind: "app", appName: "iTerm" });
});

run("unknown surface is explicit and has no focus target", () => {
  const surface = resolveSessionSurface({}, {}, {}, { pid: 42, processCommand: "/usr/bin/other" });
  assert.equal(surface.entrypoint, "unknown");
  assert.equal(surface.entrypointSource, "unknown");
  assert.equal(surface.termProgram, "");
  assert.deepEqual(surface.focusTarget, { kind: "none" });
});

run("swift-compatible fallback target is derived from state", () => {
  assert.deepEqual(
    focusTargetForState({ entrypoint: "codex-desktop", sessionId: "fallback-session", termProgram: "" }),
    {
      kind: "url",
      url: "codex://threads/fallback-session",
      fallback: { kind: "bundle", bundleId: "com.openai.codex" },
    }
  );
  assert.deepEqual(
    focusTargetForState({ entrypoint: "cli", termProgram: "Apple_Terminal" }),
    { kind: "app", appName: "Terminal" }
  );
});

if (process.exitCode) process.exit(process.exitCode);
