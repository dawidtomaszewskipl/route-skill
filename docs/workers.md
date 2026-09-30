# Workers and CLI mechanics

Everything here was first checked against **Codex CLI 0.153.4** and **Antigravity CLI 1.1.27** on
2026-09-06; the catalogs and the flags route uses were re-checked on **Codex CLI 0.155.1** and
**agy 1.2.8** on 2026-09-22, and the Codex side again on **Codex CLI 0.159.2** on 2026-09-30 (the
agy facts are still those of 1.2.8). Both rosters and both flag sets move; re-check with `codex exec --help`,
`codex exec resume --help`, `agy --help` and `agy models` rather than trusting a table that has aged.

## Family is decided by the model, not by the CLI

The Antigravity catalog is not Gemini-only:

```
$ agy models
gemini-3.8-flash-high     Gemini 3.8 Flash (High)
gemini-3.8-flash-medium   Gemini 3.8 Flash (Medium)
gemini-3.8-flash-low      Gemini 3.8 Flash (Low)
gemini-3.7-flash-high     Gemini 3.7 Flash (High)    ← older Flash generations, also -medium/-low
gemini-3.6-flash-high     Gemini 3.6 Flash (High)
gemini-3.1-pro-high       Gemini 3.1 Pro (High)      ← still listed (and -low), removed from the route roster
claude-sonnet-4-6         Claude Sonnet 4.6 (Thinking)
claude-opus-4-6-thinking  Claude Opus 4.6 (Thinking)
gpt-oss-120b-medium       GPT-OSS 120B (Medium)
```

No Claude model newer than 4.6 is in the agy catalog — Opus 5.5 is reachable only as a Claude Code
subagent. An `agy` call with no `--model` runs the account default. If that is a Claude model, "Google
critiqued the Claude plan" was Claude critiquing Claude, and nothing in the output says so. Codex
behaves the same way, taking its model from `~/.codex/config.toml` when `-m` is absent.

**Availability is detected, not assumed.** Stage 0 checks three different things, all free of model
turns: installation (`command -v codex`, `command -v agy`), sign-in (`codex login status` — prints
`Logged in using ChatGPT` and exits 0; `agy models` succeeding, since it fetches the catalog) and
health (`codex doctor --summary`, exit 0 with `0 fail`, **run where the worker will run** — the same
signed-in install fails doctor inside a sandbox with unreachable endpoints). A health failure makes the
worker unavailable in that environment, not signed out; none of the checks proves entitlement to a
particular model. The cross-family rule then resolves among the families that are actually there; with
Claude alone every external role is a different Claude model than the implementer and the run is marked
degraded. A `--model` naming an unavailable family halts with a question. A policy file
(`docs/policy.md`) can also switch a family off.

**Pass `--model` / `-m` on every external call. Record the requested model; the served model is
unverified unless you confirmed it** (vendor-side substitution at quota limits is a rumour, not a
verified behaviour — omitting `--model` is the real risk).

## OpenAI — `codex exec`

### Models

Catalog of Codex CLI **0.159.2**, read from `~/.codex/models_cache.json` on 2026-09-30 (entries
with `visibility: list`, in catalog priority order):

| Slug | Route slot | Catalog efforts | Default |
| --- | --- | --- | --- |
| `gpt-6.1-sol` | `sol` — "latest workhorse model for coding and everyday work" | `low … ultra` | **`low`** |
| `gpt-6-astra` | `astra` — frontier, "for the most demanding work" | `low … ultra` | `medium` |
| `gpt-6-sol` | — (previous Sol, "previous generation workhorse model") | `low … ultra` | `medium` |
| `gpt-6-luna` | `luna` | `low … max` | `medium` |
| `gpt-5.6-sol` | — (older Sol) | `low … ultra` | `low` |
| `gpt-5.6-terra` | `terra` — legacy, explicit `--model` only | `low … ultra` | `medium` |
| `gpt-5.6-luna` | — (older Luna) | `low … max` | `medium` |
| `gpt-5.5` | — (the catalog says it retires on 2026-10-14) | `low … xhigh` | `medium` |

**GPT-6.1 Sol** (`gpt-6.1-sol`) was released on 2026-09-29 and is the `sol` slot from route 3.3.
OpenAI's announcement ([Introducing GPT-6.1 Sol](https://openai.com/index/introducing-gpt-6-1-sol/))
says it "nearly matches GPT-6 Astra's intelligence on agentic coding, computer use, and professional
work at one-fifth of Astra's standard input and output token prices": on DeepSWE v1.1 it matches
Astra at roughly a fifth of the cost and beats GPT-6 Sol's best score by 6.4 points at a lower
effort; API prices $2 input, $0.10 cached input, $10 output per million tokens. These are the
vendor's figures, not route's: route has measured GPT-6 Sol only as a critic so far, and the rubric
does not move until the ledger shows Sol builds. A "GPT-6.1 Sol Ultrafast" was announced for the
following days; it is not in the 0.159.2 catalog. Its catalog default effort is `low` where GPT-6
Sol's was `medium` — route pins effort on every line, and a line without the pin runs at whatever
the user config says (`xhigh` on the author's machine) or, isolated, at that catalog default.
The read-only probe cost 18 585 input tokens (12 288 cached) and 8 s on 2026-09-30. GPT-6 Luna
keeps its slot; its strengths relative to Astra are not yet measured either. There is no GPT-6
Terra; the `terra` slot stays on 5.6 and leaves the rubric.

**The catalog is a candidate list, not proof.** `$CODEX_HOME/models_cache.json` (default
`~/.codex`) is a snapshot: it carries `fetched_at`, `client_version` and an account `identity`, so a
missing or stale cache says nothing about an upgrade, and a listed model can still be refused for the
account. So the proof is a probe, remembered: `.route/model-probes.json` (kept across runs) holds
each slug's last successful probe with the `codex --version`, the catalog `identity` and the config
mode it ran under. Stage 0 treats a slot as usable when that record is under 7 days old and all three
still match; otherwise
it runs one read-only probe with model and effort pinned, in the run's config mode
(`-c model_reasoning_effort=low`, "Reply with exactly: OK" — about 18.6k input tokens on
2026-09-30; `docs/commands.md`). Only an error saying the client does not know
the model means "upgrade Codex". Version minimums go stale with every model drop (Astra's was 0.153.1).

`ultra` is a Codex catalog setting ("maximum reasoning with automatic task delegation"); the API's
own list stops at `max`. `none` is rejected. Effort goes on the command line as
`-c model_reasoning_effort=<level>` — set it every time, the defaults differ per model.

### Astra and GPT-6.1 Sol specifics

- **Asynchronous clarification questions** exist in interactive Codex, but the 0.153.4 binary
  states `request_user_input is not supported in exec mode`. A worker cannot ask mid-run; it can
  only *end* with a question. The brief's follow-through block ("do not ask; decide and record
  assumptions") is what prevents that.
- **Context notes across windows** (`features.context_management.experimental_mode`, off by
  default; `codex features list` reports it as under development) replace repeated compaction with
  searchable notes. Requires ChatGPT sign-in on Plus/Pro/Pro Lite; API-key sessions are excluded.
  Optional for very long builds; not part of the canonical lines.
- **Safety layer.** Astra is OpenAI's first model at the Critical cyber tier: it refuses
  proof-of-concept exploit work, and production safety checks can pause or stop legitimate work.
  GPT-6.1 Sol is treated the same way — Critical in cybersecurity, the same safeguards stack as
  Astra ([system card addendum](https://deploymentsafety.openai.com/gpt-6-1-sol), 2026-09-29). A
  `misalignment_policy_violation` or explicit safety block is **not retryable** — stop dispatch,
  keep the checkpoint and the `.jsonl`, report. Only an ordinary out-of-scope decline gets one
  rewritten brief.
- **Fast tier.** `service_tier = "priority"` is the Fast tier: 2× speed at 2× usage for Astra;
  for GPT-6.1 Sol the catalog says "2x speed, increased usage" (GPT-6 Sol and Luna: 1.5×).
  Route keeps it unset (standard) — isolated mode cannot inherit it; pinned mode inherits a
  `service_tier` set in `config.toml`, and stage 0 reports it. A `~/.codex/fast.config.toml` profile holds it for interactive
  use: `codex -p fast`. The served tier is not recorded in session files, so it cannot be observed
  after the fact.

### Flags worth knowing (`codex exec`)

| Flag | Why it matters |
| --- | --- |
| `-o, --output-last-message <file>` | The final answer, verbatim, written host-side — works under `-s read-only` (verified). Read this, never the transcript tail. |
| `--json` | JSONL event stream on stdout: `thread.started` (with `thread_id`), `turn.started`, `item.*`, `turn.completed` (with `usage`). The only honest progress signal. Ordinary progress otherwise goes to **stderr** — capture it separately. |
| `--output-schema <file>` | Enforces a JSON Schema on the final answer (types, enums, `required`, `additionalProperties:false`; no nullable fields — see "Schemas"). |
| `-s <policy>` | `read-only`, `workspace-write`, `danger-full-access`. Read-only still runs read-only shell commands and still loads MCP servers — it is not "tool-less". |
| `--ignore-user-config` | Skip `$CODEX_HOME/config.toml`; auth still comes from `CODEX_HOME`. Route's default (isolated mode, "Config modes" below); `exec` and `resume`. `-c` overrides still apply, but one that names an MCP server only the ignored file defined makes the file invalid at startup (`invalid transport in mcp_servers.<name>`, exit 1). |
| `-c mcp_servers.<name>.enabled=false` | Pinned mode only: disable an MCP server for one call. Measured saving here ≈ 1 s per critic start (5.4 s → 4.5 s with cached `npx` servers); it matters when a server cannot start at all (a container-backed one costs its full `startup_timeout_sec`). |
| `--approve-for-me` | Rung 3 as a flag: `approval_policy` `on-request` with automatic review, implies `workspace-write` and cannot be combined with `-s` (0.159.2: "the argument '--sandbox' cannot be used with '--approve-for-me'"). Route uses the equivalent `-c approvals_reviewer="auto_review"`, which also works on `resume`. |
| `--image=<file>[,<file>…]` (`-i`) | Attach images to the prompt, on `exec` and `resume`. The option takes several values, so `-i shot.png "prompt"` swallows the prompt as a second file ("No prompt provided via stdin", exit 1); use `--image=` or put `--image <file>` before the other flags. Verified with one and with two images. |
| `-C, --cd <dir>` / `--add-dir <dir>` | Working root and extra writable roots (`exec` only — not on `resume`, which runs in the shell's cwd). A parallel worker's worktree goes in `-C`. |
| `-p, --profile <name>` | Layers `$CODEX_HOME/<name>.config.toml` on top of the base config. Profiles can add keys, not remove them. |
| `--thread-source <source>` | Classification for the new/forked thread (0.153). |
| `--ephemeral` | No session file — and therefore no resume. |
| `-` as the prompt | Read the whole prompt from stdin (`codex exec - < brief.md`); EOF closes it. Documented; not the canonical transport. |

**Not used, with the reason** (0.159.2):

| Flag | Why route leaves it out |
| --- | --- |
| `--worktree` (exec, resume, review) | Codex-managed worktree under `$CODEX_HOME/worktrees/<id>/<repo>`, detached HEAD. It cannot be combined with `--ignore-user-config` (verified), so it would pull the whole user config into every parallel writer. Route creates the worktree itself and passes it with `-C` (`docs/commands.md`, "Parallel Codex workers"). |
| `codex exec fork <id>` | Copies a thread's context into a new one. Route continues a role by `resume`; forking a critic into a reviewer would carry the critic's conclusions into what must be an independent read. |
| `--strict-config` | Turns an unknown key in `config.toml` into a startup failure. Isolated mode does not read the file; pinned mode should not fail on the user's own keys. |
| `--enable` / `--disable <feature>` | Shorthand for `-c features.<name>=…`. Nothing route needs to toggle: exec sessions carry multi-agent tools but are instructed not to spawn sub-agents unless asked, and route briefs never ask; `ultra`'s automatic delegation stays unused. |
| `--ignore-rules` | Skips the user's and the project's execpolicy `.rules` — a safety net route does not remove. |
| `--dangerously-bypass-hook-trust`, `--dangerously-bypass-approvals-and-sandbox` | Not rungs; they drop protections meant for already-sandboxed hosts. |

The rest of DevDay 2026 is outside `codex exec`, so route has nothing to adopt from it: reusable
**cloud development environments** and **Dots** (always-on agents with their own cloud computer)
run in OpenAI's cloud, not in the checkout the director gates and commits; the **Agents API** is a
runtime for building one's own agent applications, not a CLI a director launches; `/agents`,
better worktree handling and **voice control** are interactive-TUI features. Codex cloud **Code
Review** is covered under "Review" below.

**`codex exec resume` has a different flag set** (0.159.2): `-m`, `-c`, `--json`, `-o`,
`--output-schema`, `--ignore-user-config`, `-i`/`--image`, `--last`, `--all`, `--ephemeral`,
`--enable`/`--disable`, `--strict-config`, `--ignore-rules`, `--skip-git-repo-check`,
`--thread-source`, `--worktree` and the two `--dangerously-…` flags — but **not** `-s`, `--color`,
`-C`, `--add-dir`, `--approve-for-me`. Sandbox goes through `-c 'sandbox_mode="workspace-write"'`;
the working directory is the shell's. The id may be a UUID or a thread name. Two sessions in August each lost two 8–10-minute windows to
`error: unexpected argument '-s' found`.

**`--last` is banned in automation.** It resumes the newest recorded session in the cwd — the
critic, the builder, or an interactive session you opened meanwhile. Always the thread UUID from
`thread.started.thread_id`.

**Review** has its own subcommand with its own built-in contract — it sees the diff but not the plan or the acceptance criteria, so route's cross reviewer is a read-only `codex exec` with a review brief and `review-schema.json` (`docs/commands.md`); `codex exec review` stays a manual extra. Verified: `--json` and `-o` work on it;
its `turn.completed.usage` reports zeros, so ledger token fields for review calls are `null`:

```bash
codex exec review --uncommitted -m gpt-6.1-sol --ignore-user-config -c model_reasoning_effort=high --json \
  -o .route/review.txt < /dev/null > .route/review.jsonl 2> .route/review.stderr.log
codex exec review --base main …          # against a branch
codex exec review --commit <sha> …       # one commit
```

It takes the run's config mode like every other line (`--ignore-user-config` is in its help on
0.159.2; in pinned mode the "Pinned mode" substitution of `docs/commands.md` applies).

Codex's cloud **Code Review** (DevDay 2026) reviews a pushed GitHub PR or GitLab MR the same way —
with its own contract, without the plan — so it is a manual extra too, never the cross reviewer.

**Health**: `codex doctor` (`--summary`, `--json`) reports auth mode, provider reachability,
installed vs. latest version, and whether a background `app-server` is running.

**Skills**: Codex discovers `~/.codex/skills`, `~/.agents/skills`, `~/.codex/skills/.system` and
`{cwd}/.agents/skills`, injects names + descriptions, and instructs the model to read a relevant
`SKILL.md` completely before acting. A Luna probe from a Laravel project listed all 14 project skills
without being asked; Sol sessions read `pest-testing` and `laravel-best-practices` on their own.
Name the binding skills in the brief anyway.

### Config modes

Every `codex exec` reads `$CODEX_HOME/config.toml` unless told not to, and that file reaches further
than it looks: on the author's machine it starts two MCP servers through `npx`, loads a plugin, sets
`personality`, `model_context_window = 1000000` and `model_reasoning_effort = "xhigh"` (an unpinned
worker ran at `xhigh`), and sets `approvals_reviewer = "auto_review"` — which on 0.159.2 alone turns
`approval_policy` from `never` into `on-request` with automatic review: rung 3 in disguise (verified
2026-09-30). Route therefore runs Codex in one of two modes, decided at stage 0 step 3:

- **isolated** (default) — `--ignore-user-config` on every line, exec and resume: none of the file
  reaches the worker; auth still comes from `CODEX_HOME`.
- **pinned** (fallback) — the 3.2 form: `-c approvals_reviewer="user"` on every line and one
  `-c mcp_servers.<name>.enabled=false` per server on the read-only lines. Everything else in the
  file reaches the worker, MCP servers on writers included, and stage 0 reports what changes the
  rung or the cost (`approval_policy`, `sandbox_mode`, permission keys, `service_tier`).

Pinned is chosen when the file sets a key that decides where or how Codex connects or
authenticates, because skipping it would break the worker or silently change the account:
`model_provider`, a `[model_providers.<id>]` table, `openai_base_url`, `chatgpt_base_url`,
`cli_auth_credentials_store`, `forced_login_method`, `forced_chatgpt_workspace_id` — and,
conservatively, any other key whose name contains `base_url`, `provider`, `login`, `auth`,
`credential` or `proxy` (outside the `mcp_servers`, `projects`, `tui` and `plugins` tables).
`model_provider`, `[model_providers]`, `openai_base_url` and `cli_auth_credentials_store` are in the
Codex configuration reference; `chatgpt_base_url`, `forced_login_method` and
`forced_chatgpt_workspace_id` were found in the 0.159.2 binary next to `cli_auth_credentials_store`.
A corporate CA bundle is an environment variable (`CODEX_CA_CERTIFICATE`, `SSL_CERT_FILE`) and
survives isolated mode. The Assign line names the mode and the key that forced it.

What no flag removes: every exec session carries about 18.6k input tokens of injected context —
the skills list from `~/.codex/skills`, `~/.agents/skills` and `.system` (~20 KB here),
`~/.codex/AGENTS.md`, a recommended-plugins list and the multi-agent instructions (measured
identical with and without `--ignore-user-config`).

A **project-level** `.codex/config.toml` can carry a `default_permissions` profile that makes the
workspace read-only regardless of `-s`, or an MCP server that shells into containers and cannot
start in the sandbox (10 s startup penalty per run). Stage 0 reads it and warns in both modes. Whether
isolated mode still loads a trusted project's file is unverified: in a scratch repository trusted
through `-c 'projects."<path>".trust_level="trusted"'`, the project's `model_reasoning_effort` was not
applied with the user config (the user's `xhigh` won) nor without it (2026-09-30).

The **effective** configuration is not a matter of trust: after every launch and resume the director
reads it back from the session's rollout file (`docs/commands.md`, "Effective-config check").

## Google — `agy`

### Flags

| Flag | Why it matters |
| --- | --- |
| `--model <slug>` | Mandatory on every call (family). The slug embeds the effort (`gemini-3.8-flash-high`). |
| `--effort low\|medium\|high` | Session effort. Must agree with the slug — `…-high` with `--effort medium` contradicts itself. |
| `--mode plan` | Read-only planning mode — the critic setting. |
| `--mode accept-edits` | Auto-approves edits, keeps other prompts — the build setting. |
| `--add-dir <repo>` | **Required for project skills and rules.** Print mode does not treat cwd as the workspace: without `--add-dir` the worker sees only the 5 built-in skills. |
| `--print-timeout` | **Always set it.** It defaulted to 5 minutes up to 1.1.x; 1.2.8 defaults to `0`, which waits until the turn completes. Expiry returns `status:"ERROR"`, `error:"timeout waiting for response"`, exit 1 (there is no `TIMEOUT` status). |
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

- A Gemini **critic, gate or reviewer** reads nothing: its brief forbids tools (reaching for an MCP
  server empties the answer — troubleshooting), so the whole brief goes into `-p` with every fact and
  every convention it must judge against quoted inline. Above ~100 KB, split the review or give the
  role to another family.
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
(~128 KB per argument on Linux: `Argument list too long`). Builders and drafters get a pointer
stub — it keeps prompts small and free of shell-quoting accidents. Critics, gates and reviewers get
their whole brief in `-p`, because their brief forbids reading files; above ~100 KB it is split.
`-p` does not read stdin.

### Skills

Discovery: `{workspace}/.agents/skills/<name>/SKILL.md` and `~/.gemini/config/skills/<name>/`.
Names + descriptions are injected; the model is told it MUST read a relevant `SKILL.md` before
proceeding. `agy --add-dir "$REPO" --output-format json -p "/skills"` lists what a worker will see
without spending a model turn. A `/<skill>` prefix in the prompt expands that skill verbatim
(verified: `-p "/xui-development …"` returned the skill's `name` and first heading; cost = the
whole `SKILL.md` in input tokens).

## Claude — subagents

`Agent` with an explicit `model` and the default `subagent_type`. `subagent_type: "fork"` inherits
context but **ignores** `model`. No effort dial on the call — the model choice is the dial. Parallel
write-mode subagents need `isolation: "worktree"`; their briefs give paths relative to the worktree
root, never the checkout's absolute paths; the director integrates each worktree's result into the
checkout itself and keeps the worktrees until the report (SKILL.md, "Roster").

| Slot | Model (2026-09-22) | Notes for the director |
| --- | --- | --- |
| `opus` | Opus 5.5 (`claude-opus-5-5`) | The alias follows the newest Opus. $4 / $20 per MTok (Opus 5: $5 / $25), cache reads $0.20. Anthropic reports gains mostly on multistep work in a real codebase and on code review (more bugs, fewer false alarms), with fewer tokens per finished task, and much more accurate reading of screenshots, charts and diagrams. Thinking is always on; at a given effort it thinks more than Opus 5. Its reports say plainly what it did and what it needs. |
| `fable` | Fable 5.1 | Most capable and most expensive ($10 / $50). Long turns on hard tasks. Users pulled it out of worker roles over token burn; keep it for the hardest correctness and large UI redesigns. |
| `sonnet` | Sonnet 5 | Mechanical, convention-heavy builds. |
| `haiku` | Haiku 4.5 | Bulk edits without judgment; Claude-only cascade drafter. |

Claude Code's per-model effort setting (`modelSettings` in `settings.json`) is keyed by model id: an
entry for `claude-opus-5` says nothing about `claude-opus-5-5`. Whether it reaches subagents at all
is unverified — route treats subagent effort as unknown and does not record it.

## Schemas

`docs/schemas/critique-schema.json`, `gate-schema.json` and `review-schema.json` are the shared dialect that
both `--output-schema` (JSON Schema, strict: every property `required`, `additionalProperties:false`)
and `--json-schema` (OpenAPI-3.0-style, rejects `["integer","null"]`) accept — verified on both CLIs
with the same file (critique and gate; review uses the same constructs). The rule that makes this possible: **no nullable fields**. `line: 0` and
`escalate_reason: ""` mean "none"; optional lists are empty arrays. All three carry an
`assumptions[]` field, which is where the follow-through block sends assumptions on schema calls.

## Briefs

Write the brief to a file under `.route/` and pass `"$(cat file)"` with `< /dev/null`. External
workers start cold. A brief that works carries: absolute paths (a worktree worker: file references
and edit boundaries relative to its worktree root, its artifacts at absolute `$REPO/.route/…`
paths); explicit change boundaries; the
project's convention files; the binding skills by name; what "done" looks like and which command
proves it; the output contract. Block-structured (task / boundaries / verification / output), not
prose. The run's PLAN.md is the build brief's core.
