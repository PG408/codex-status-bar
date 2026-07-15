#!/usr/bin/env node
const assert = require("assert");
const {
  COMMIT_MESSAGE_PROMPT_PREFIX,
  sessionKindForPrompt,
} = require("./lib/session-kind");

assert.equal(
  sessionKindForPrompt(`${COMMIT_MESSAGE_PROMPT_PREFIX}\nCustom commit instructions...\nChanges:\ndiff --git a/a b/a`),
  "commit-message"
);
assert.equal(sessionKindForPrompt(COMMIT_MESSAGE_PROMPT_PREFIX), "commit-message");
assert.equal(
  sessionKindForPrompt("Using the supplied git context below, generate a git commit message."),
  ""
);
assert.equal(
  sessionKindForPrompt(COMMIT_MESSAGE_PROMPT_PREFIX.replace("Make 0 tool calls.", "Make no tool calls.")),
  ""
);
assert.equal(sessionKindForPrompt("Please generate a git commit message for these changes."), "");
assert.equal(sessionKindForPrompt(undefined), "");

console.log("PASS session kind classifier");
