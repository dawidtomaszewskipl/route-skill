# Workers and CLI mechanics

Everything here was checked against **Codex CLI 0.153.4** and **Antigravity CLI 1.1.27** on
2026-09-06. Both rosters and both flag sets move; re-check with `codex exec --help`,
`codex exec resume --help`, `agy --help` and `agy models` rather than trusting a table that has aged.

## Family is decided by the model, not by the CLI

The Antigravity catalog is not Gemini-only:

```
$ agy models
gemini-3.8-flash-high     Gemini 3.8 Flash (High)
gemini-3.8-flash-medium   Gemini 3.8 Flash (Medium)
gemini-3.8-flash-low      Gemini 3.8 Flash (Low)
gemini-3.1-pro-high       Gemini 3.1 Pro (High)      ← still listed, removed from the route roster
claude-sonnet-4-6         Claude Sonnet 4.6 (Thinking)
claude-opus-4-6-thinking  Claude Opus 4.6 (Thinking)
gpt-oss-120b-medium       GPT-OSS 120B (Medium)
```

An `agy` call with no `--model` runs the account default. If that is a Claude model, "Google
critiqued the Claude plan" was Claude critiquing Claude, and nothing in the output says so. Codex
behaves the same way, taking its model from `~/.codex/config.toml` when `-m` is absent.

**Pass `--model` / `-m` on every external call. Record the requested model; the served model is
unverified unless you confirmed it** (vendor-side substitution at quota limits is a rumour, not a
verified behaviour — omitting `--model` is the real risk).

## OpenAI — `codex exec`

### Models

| Slug | Shape | Catalog efforts | Default |
| --- | --- | --- | --- |
| `gpt-6-astra` | Frontier (SWE, terminal, computer use); needs CLI ≥ 0.153.1 | `low medium high xhigh max ultra` | `medium` |
| `gpt-5.6-sol` | Reliable everyday workhorse | `low … ultra` | `low` |
| `gpt-5.6-terra` | Balanced everyday | `low … ultra` | `medium` |
| `gpt-5.6-luna` | Fast and cheap | `low … max` | `medium` |
| `gpt-5.4-mini` | Small, simple tasks | `low … xhigh` | `medium` |
| `gpt-5.3-codex-spark` | Ultra-fast mechanical edits | `low … xhigh` | `high` |

`ultra` is a Codex catalog setting ("maximum reasoning with automatic task delegation"); the API's
own list stops at `max`. `none` is rejected. Effort goes on the command line as
`-c model_reasoning_effort=<level>` — set it every time, the defaults differ per model.

### Astra specifics

- **Asynchronous clarification questions** exist in interactive Codex, but the 0.153.4 binary
  states `request_user_input is not supported in exec mode`. A worker cannot ask mid-run; it can
  only *end* with a question. The brief's follow-through block ("do not ask; decide and record
  assumptions") is what prevents that.
- **Context notes across windows** (`features.context_management.experimental_mode`, off by
  default; `codex features list` reports it as under development) replace repeated compaction with
  searchable notes. Requires ChatGPT sign-in on Plus/Pro/Pro Lite; API-key sessions are excluded.
  Optional for very long builds; not part of the canonical lines.
- **Safety layer.** Astra is OpenAI's first model at the Critical cyber tier: it refuses
  proof-of-concept exploit work, and production safety checks can pause or stop legitimate work. A
  `misalignment_policy_violation` or explicit safety block is **not retryable** — stop dispatch,
  keep the checkpoint and the `.jsonl`, report. Only an ordinary out-of-scope decline gets one
  rewritten brief.
- **Fast tier.** `service_tier = "priority"` is the Fast tier: 2× speed at 2× usage for Astra.
  Route keeps it unset (standard). A `~/.codex/fast.config.toml` profile holds it for interactive
  use: `codex -p fast`. The served tier is not recorded in session files, so it cannot be observed
  after the fact.

### Flags worth knowing (`codex exec`)

| Flag | Why it matters |
| --- | --- |
| `-o, --output-last-message <file>` | The final answer, verbatim, written host-side — works under `-s read-only` (verified). Read this, never the transcript tail. |
| `--json` | JSONL event stream on stdout: `thread.started` (with `thread_id`), `turn.started`, `item.*`, `turn.completed` (with `usage`). The only honest progress signal. Ordinary progress otherwise goes to **stderr** — capture it separately. |
| `--output-schema <file>` | Enforces a JSON Schema on the final answer (types, enums, `required`, `additionalProperties:false`; no nullable fields — see "Schemas"). |
| `-s <policy>` | `read-only`, `workspace-write`, `danger-full-access`. Read-only still runs read-only shell commands and still loads MCP servers — it is not "tool-less". |
| `-c mcp_servers.<name>.enabled=false` | Disable an MCP server for one call. Measured saving here ≈ 1 s per critic start (5.4 s → 4.5 s with cached `npx` servers); it matters when a server cannot start at all (a container-backed one costs its full `startup_timeout_sec`). |
| `--approve-for-me` | Escalation requests reviewed automatically under workspace-write — the middle rung of the ladder. |
| `-C, --cd <dir>` / `--add-dir <dir>` | Working root and extra writable roots (`exec` only — not on `resume`). |
| `-p, --profile <name>` | Layers `$CODEX_HOME/<name>.config.toml` on top of the base config. Profiles can add keys, not remove them. |
| `--thread-source <source>` | Classification for the new/forked thread (0.153). |
| `--ephemeral` | No session file — and therefore no resume. |
| `-` as the prompt | Read the whole prompt from stdin (`codex exec - < brief.md`); EOF closes it. Documented; not the canonical transport. |

**`codex exec resume` has a different flag set**: `-m`, `-c`, `--json`, `-o`, `--output-schema`,
`--last`, `--all` — but **not** `-s`, `--color`, `-C`, `--add-dir`. Sandbox goes through
`-c 'sandbox_mode="workspace-write"'`. Two sessions in August each lost two 8–10-minute windows to
`error: unexpected argument '-s' found`.

**`--last` is banned in automation.** It resumes the newest recorded session in the cwd — the
critic, the builder, or an interactive session you opened meanwhile. Always the thread UUID from
`thread.started.thread_id`.

**Review** has its own subcommand with its own contract. Verified: `--json` and `-o` work on it;
its `turn.completed.usage` reports zeros, so ledger token fields for review calls are `null`:

```bash
codex exec review --uncommitted -m gpt-5.6-sol -c model_reasoning_effort=high --json \
  -o .route/review.txt < /dev/null > .route/review.jsonl 2> .route/review.stderr.log
codex exec review --base main …          # against a branch
codex exec review --commit <sha> …       # one commit
```

**Health**: `codex doctor` (`--summary`, `--json`) reports auth mode, provider reachability,
installed vs. latest version, and whether a background `app-server` is running.

**Skills**: Codex discovers `~/.codex/skills`, `~/.agents/skills`, `~/.codex/skills/.system` and
`{cwd}/.agents/skills`, injects names + descriptions, and instructs the model to read a relevant
`SKILL.md` completely before acting. A Luna probe from a Laravel project listed all 14 project skills
without being asked; Sol sessions read `pest-testing` and `laravel-best-practices` on their own.
Name the binding skills in the brief anyway.

**Global config traps.** Every `codex exec` starts every MCP server in `~/.codex/config.toml`
(here: perplexity and playwright via `npx`) — disable them on critique lines. A project-level
`.codex/config.toml` can carry a `default_permissions` profile that makes the workspace read-only
regardless of `-s`, or an MCP server that shells into containers and cannot start in the sandbox
(10 s startup penalty per run). Stage 0 reads it and warns.

## Google — `agy`

### Flags

| Flag | Why it matters |
| --- | --- |
| `--model <slug>` | Mandatory on every call (family). The slug embeds the effort (`gemini-3.8-flash-high`). |
| `--effort low\|medium\|high` | Session effort. Must agree with the slug — `…-high` with `--effort medium` contradicts itself. |
| `--mode plan` | Read-only planning mode — the critic setting. |
| `--mode accept-edits` | Auto-approves edits, keeps other prompts — the build setting. |
| `--add-dir <repo>` | **Required for project skills and rules.** Print mode does not treat cwd as the workspace: without `--add-dir` the worker sees only the 5 built-in skills. |
| `--print-timeout` | **Defaults to 5 minutes.** Expiry returns `status:"ERROR"`, `error:"timeout waiting for response"`, exit 1 (there is no `TIMEOUT` status). |
| `--output-format json` | One envelope written whole at exit: `{conversation_id, status, response, duration_seconds, num_turns, usage, denied_actions?, json_schema?}`. |
| `--json-schema <schema-or-path>` | Schema enforced on the `response` string. agy adds `toolAction` and `toolSummary` keys to the object — drop them before validating. |
| `--input-format stream-json` | NDJSON prompts on stdin; **requires `--output-format stream-json`**. Observed on 1.1.27: stdout is `{"event":"init","conversation_id":…,"init":{"model","cwd","tools":[…]}}` followed by `{"event":"result","result":{…the same envelope as `--output-format json`…}}`; input lines must carry an `"event"` field (a `{"type":"user",…}` message is rejected with `stream input message is missing the "event" field`). A different mode with a different parser; not used by route. |
| `--conversation <id>` | Resume by id. `-c`/`--continue` means "most recent conversation" — a race as soon as two runs exist. |
| `--dangerously-skip-permissions` | Approves everything. Was blocked once by Claude Code's own auto-mode classifier; `--mode` settings are what route uses. |
| `--agent <name>` | Run a custom agent; its Markdown frontmatter can preload `skills:` — an option, not used by route. |

### Headless permissions — the one that bites

In print mode any tool action that would need a permission prompt is **auto-denied, and the whole
turn is cancelled**:

```
$ agy --mode plan … -p "…run agy --help to verify…"
jetski: no output produced — a tool required the "command" permission that headless mode cannot
prompt for, so it was auto-denied. Add an allow-rule under permissions.allow in settings.json
(e.g. command(<target>)). Alternatively, re-run with --dangerously-skip-permissions …
{"status":"CANCELED","response":"","denied_actions":[{"action":"command","display_name":"RunCommand"}], …}   exit 0
```

Consequences:

- A Gemini **critic** is a read-only review without shell execution — it reads files and skills, it
  cannot run `git diff` or the tests. The brief carries every fact inline.
- A Gemini **builder** is edits-only. Its brief says so; the director runs tests and builds. One
  attempted command aborts the run with `CANCELED`, exit 0, and an empty response.
- `denied_actions` is **absent** when nothing was denied — treat a missing key as `[]`.
- To let a Gemini worker run specific commands, `permissions.allow` rules (`command(<target>)`) in
  `~/.gemini/antigravity-cli/settings.json` are the documented mechanism — unverified in route, and
  broader than route needs.

### Payload check, every call

`status == "SUCCESS"` · `response != ""` · `(denied_actions ?? []) == []` · for schema calls:
strip Markdown fences, drop `toolAction`/`toolSummary`, `JSON.parse`, validate. Any non-`SUCCESS`
status invalidates the `conversation_id` — the history may hold an orphaned tool call; the
follow-up is a new conversation carrying the current `git diff`.

A successful envelope:

```json
{"conversation_id":"b538f8bb-…","status":"SUCCESS","response":"{…}",
 "duration_seconds":111.3,"num_turns":1,
 "usage":{"input_tokens":52238,"output_tokens":33649,"thinking_tokens":29804,
          "cache_read_tokens":240719,"total_tokens":85887}}
```

### Prompt size

A 34 KB brief through `-p` ran fine on 1.1.27 (16.5 k input tokens). The bound is the OS argv limit
(~128 KB per argument on Linux: `Argument list too long`). Route uses a pointer stub anyway — it
keeps prompts small and free of shell-quoting accidents. `-p` does not read stdin.

### Skills

Discovery: `{workspace}/.agents/skills/<name>/SKILL.md` and `~/.gemini/config/skills/<name>/`.
Names + descriptions are injected; the model is told it MUST read a relevant `SKILL.md` before
proceeding. `agy --add-dir "$REPO" --output-format json -p "/skills"` lists what a worker will see
without spending a model turn. A `/<skill>` prefix in the prompt expands that skill verbatim
(verified: `-p "/xui-development …"` returned the skill's `name` and first heading; cost = the
whole `SKILL.md` in input tokens).

## Claude — subagents

`Agent` with an explicit `model` and the default `subagent_type`. `subagent_type: "fork"` inherits
context but **ignores** `model`. No effort dial — the model choice is the dial. Parallel write-mode
subagents need `isolation: "worktree"`.

## Schemas

`docs/schemas/critique-schema.json` and `docs/schemas/gate-schema.json` are the shared dialect that
both `--output-schema` (JSON Schema, strict: every property `required`, `additionalProperties:false`)
and `--json-schema` (OpenAPI-3.0-style, rejects `["integer","null"]`) accept — verified on both CLIs
with the same file. The rule that makes this possible: **no nullable fields**. `line: 0` and
`escalate_reason: ""` mean "none"; optional lists are empty arrays. Both schemas carry an
`assumptions[]` field, which is where the follow-through block sends assumptions on schema calls.

## Briefs

Write the brief to a file under `.route/` and pass `"$(cat file)"` with `< /dev/null`. External
workers start cold. A brief that works carries: absolute paths; explicit change boundaries; the
project's convention files; the binding skills by name; what "done" looks like and which command
proves it; the output contract. Block-structured (task / boundaries / verification / output), not
prose. `.route/PLAN.md` is the build brief's core.
