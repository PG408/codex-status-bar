const COMMIT_MESSAGE_PROMPT_PREFIX = [
  "Using the supplied git context below, generate a git commit message.",
  "Write the result into the structured response field message.",
  "message must contain plain commit-message text only, not JSON, field labels, or code fences.",
  "Custom commit instructions for message content and formatting override the fallback rules below.",
  "Make 0 tool calls.",
  "Bounds:",
  "- Keep the complete message under 4000 characters.",
  "- Keep the subject under 72 characters.",
  "Fallback rules:",
  "- Generate a concise single-line subject.",
  "- Use an imperative verb first.",
  "- Do not add a scope prefix unless the context already clearly uses one.",
  "- Do not include markdown, quotes, or trailing punctuation.",
  "",
  "Diff context:",
].join("\n");

function sessionKindForPrompt(prompt) {
  if (typeof prompt !== "string") return "";
  return prompt.startsWith(COMMIT_MESSAGE_PROMPT_PREFIX) ? "commit-message" : "";
}

module.exports = {
  COMMIT_MESSAGE_PROMPT_PREFIX,
  sessionKindForPrompt,
};
