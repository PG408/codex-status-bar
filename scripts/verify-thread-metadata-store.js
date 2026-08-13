#!/usr/bin/env node
const cp = require("child_process");
const fs = require("fs");
const os = require("os");
const path = require("path");

const repoRoot = path.resolve(__dirname, "..");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "codex-thread-metadata-"));
const db = path.join(tmp, "state_5.sqlite");
const dbForSwift = JSON.stringify(db);
const verifier = path.join(tmp, "VerifyThreadMetadata.swift");
const binary = path.join(tmp, "verify-thread-metadata");

function run(command, args, options = {}) {
  cp.execFileSync(command, args, { stdio: "inherit", ...options });
}

try {
  run("sqlite3", [db, `
    create table threads (
      id text primary key,
      rollout_path text not null default '',
      archived integer not null default 0,
      archived_at integer
    );
    create table thread_spawn_edges (
      parent_thread_id text not null,
      child_thread_id text not null primary key,
      status text not null
    );
    insert into threads (id, rollout_path, archived, archived_at)
      values ('active-thread', '', 0, null);
    insert into threads (id, rollout_path, archived, archived_at)
      values ('archived-thread', '', 1, 12345);
    insert into threads (id, rollout_path, archived, archived_at)
      values ('child-one', '/tmp/child-one.jsonl', 0, null);
    insert into threads (id, rollout_path, archived, archived_at)
      values ('child-two', '/tmp/child-two.jsonl', 0, null);
    insert into thread_spawn_edges (parent_thread_id, child_thread_id, status)
      values ('parent-one', 'child-one', 'open');
    insert into thread_spawn_edges (parent_thread_id, child_thread_id, status)
      values ('parent-two', 'child-two', 'open');
  `]);

  fs.writeFileSync(verifier, `
import Foundation

func assertBool(_ actual: Bool, _ expected: Bool, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

func assertDouble(_ actual: Double, _ expected: Double, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

func assertString(_ actual: String, _ expected: String, _ label: String) {
    if actual != expected {
        fputs("FAIL \\(label): expected \\(expected), got \\(actual)\\n", stderr)
        exit(1)
    }
}

@main
struct VerifyThreadMetadata {
    static func main() {
        let store = ThreadMetadataStore(sqlitePath: ${dbForSwift})
        let metadata = store.metadata(for: ["active-thread", "archived-thread", "missing-thread"])
        assertBool(metadata["active-thread"]?.archived ?? true, false, "active thread is not archived")
        assertBool(metadata["archived-thread"]?.archived ?? false, true, "archived thread is archived")
        assertDouble(metadata["archived-thread"]?.archivedAt ?? 0, 12345, "archived_at is read")
        assertBool(metadata["missing-thread"] == nil, true, "missing thread has no metadata")

        let children = store.subagentThreads(for: ["parent-one"])
        assertBool(children["parent-one"]?.count == 1, true, "only requested parent children are read")
        assertString(children["parent-one"]?.first?.id ?? "", "child-one", "child id is read")
        assertString(
            children["parent-one"]?.first?.rolloutPath ?? "",
            "/tmp/child-one.jsonl",
            "child rollout path is read"
        )
        assertBool(children["parent-two"] == nil, true, "unrequested parent is excluded")
    }
}
`);

  run("/usr/bin/swiftc", [
    path.join(repoRoot, "Sources", "ThreadMetadataStore.swift"),
    verifier,
    "-o",
    binary,
  ]);
  run(binary, []);
  console.log("PASS thread metadata store");
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}
