# Launch commands

Read this before the first external launch of a run. `SKILL.md` keeps the invariants; this file
keeps the exact lines.

## Launch rules

- Every model call and every test run goes through the Bash tool's background mode
  (`run_in_background: true`), stdout and stderr redirected under `.route/`. **Never detach in the
  shell** — no trailing `&`, `nohup`, `setsid`, `disown`: the tool returns at once, no harness task
  exists, and the completion notification that wakes the director never arrives. A process that must
  outlive the shell is awaited by the same background command
  (`until ! kill -0 "$PID"; do sleep 20; done`).
- Briefs are files; the prompt is `"$(cat file)"`; **stdin is closed with `< /dev/null`** — an open
  stdin (a heredoc in the same command) is the only confirmed cause of a "hung" Codex.
- The lines below are **templates** shown with the stage defaults. On every launch and resume
  substitute the effective model and per-stage effort after policy resolution (Gemini: the slug
  suffix and `--effort` together).

## Codex

```bash
# critique — read-only, context embedded in the brief, MCP servers off
codex exec -m gpt-6-sol -s read-only --color never --json -c model_reasoning_effort=medium \
  -c mcp_servers.perplexity.enabled=false -c mcp_servers.playwright.enabled=false \
  --output-schema .route/critique-schema.json -o .route/critique.json \
  "$(cat .route/brief-critique.md)" < /dev/null > .route/critique.jsonl 2> .route/critique.stderr.log
#   high stakes: -m gpt-6-astra -c model_reasoning_effort=high

# build — workspace-write
codex exec -m gpt-6-sol -s workspace-write --color never --json -c model_reasoning_effort=medium \
  -o .route/build.txt "$(cat .route/brief-build.md)" < /dev/null > .route/build.jsonl 2> .route/build.stderr.log

# resume — NO -s / --color / -C; sandbox via -c; ALWAYS the thread UUID from
# thread.started.thread_id in the run's .jsonl. --last is banned: it picks the newest
# session in the cwd, whatever started it.
codex exec resume <THREAD_UUID> --json -m gpt-6-sol -c 'sandbox_mode="workspace-write"' \
  -c model_reasoning_effort=medium -o .route/fix1.txt \
  "$(cat .route/brief-fix1.md)" < /dev/null > .route/fix1.jsonl 2> .route/fix1.stderr.log

# review — carries its own review contract; effort = the `review` stage (default high)
codex exec review --uncommitted -m gpt-6-sol -c model_reasoning_effort=high --json \
  -o .route/review.txt < /dev/null > .route/review.jsonl 2> .route/review.stderr.log   # alt: --base <branch>

# cascade drafter
codex exec -m gpt-6-luna -s workspace-write --color never --json -c model_reasoning_effort=low \
  -o .route/draft.txt "$(cat .route/brief-draft.md)" < /dev/null > .route/draft.jsonl 2> .route/draft.stderr.log
```

## agy

```bash
# --add-dir "$REPO" on every call or the worker sees no project skills/rules.
# Stubs may start with "/<skill>" to force-load a binding skill.
REPO="$(git rev-parse --show-toplevel)"

# critique — plan mode, read-only, no shell; the brief opens with the "no tools" paragraph
# and carries every fact inline; the verdict is JSON inside payload.response
agy --model gemini-3.8-flash-medium --mode plan --effort medium --add-dir "$REPO" --output-format json \
  --json-schema .route/critique-schema.json --print-timeout 30m \
  -p "$(cat .route/stub-critique.md)" < /dev/null > .route/agy-critique.json 2> .route/agy-critique.stderr.log

# build — accept-edits, EDITS ONLY: one denied command cancels the whole run
agy --model gemini-3.8-flash-medium --mode accept-edits --effort medium --add-dir "$REPO" --output-format json \
  --print-timeout 60m -p "$(cat .route/stub-build.md)" < /dev/null > .route/agy-build.json 2> .route/agy-build.stderr.log

# cascade drafter
agy --model gemini-3.8-flash-low --mode accept-edits --effort low --add-dir "$REPO" --output-format json \
  --print-timeout 30m -p "$(cat .route/stub-draft.md)" < /dev/null > .route/agy-draft.json 2> .route/agy-draft.stderr.log

# resume — by id, never -c/--continue; only after a SUCCESS turn
agy --conversation <CONVERSATION_ID> --model gemini-3.8-flash-medium --mode accept-edits --effort medium \
  --add-dir "$REPO" --output-format json --print-timeout 60m \
  -p "$(cat .route/stub-fix1.md)" < /dev/null > .route/agy-fix1.json 2> .route/agy-fix1.stderr.log
```

**Stubs.** The `-p` prompt is a pointer — *"Read `.route/brief-build.md` in the workspace and
execute it exactly. Your final answer is only what it asks for."* — small and free of shell quoting;
the OS argv limit (~128 KB) is the hard bound. `--input-format stream-json` is a different mode
(events out, no envelope) and is not used here.

## Claude subagents

`Agent` with the `model` override and the default `subagent_type`, the brief's path in the prompt.
`subagent_type: "fork"` inherits context but **ignores** `model`.

## Reading results

Never load a whole `.jsonl` into context — a long build log is tens of thousands of tokens. Take
only what you need:

```bash
grep -m1 '"thread.started"' .route/build.jsonl                  # thread_id for resume
grep '"turn.completed"' .route/build.jsonl | tail -1             # usage
grep -E '"turn.failed"' .route/build.jsonl | tail -3             # failure, if any
```

- **Codex:** the `-o` file is the answer. `thread_id` and `usage` come from the `.jsonl`. A
  `"type":"error"` event about a reconnect or a 503 is Codex retrying its stream, not a failure; a
  failure is `turn.failed`, or an exit without `turn.completed`.
- **agy:** one JSON envelope written whole at exit. Check every call: `status == "SUCCESS"`,
  `response != ""`, `(denied_actions ?? []) == []` (the key is absent when nothing was denied).
  `CANCELED` = a denied tool action; `ERROR` + `"timeout waiting for response"` = `--print-timeout`
  expired. Any non-`SUCCESS` status invalidates the `conversation_id` — follow up in a **new**
  conversation carrying the current `git diff`.
- **Schema calls:** strip Markdown fences, drop agy's injected `toolAction`/`toolSummary`, parse,
  validate against the schema in `.route/`, then act. Never act on a verdict you did not validate.

## Progress sampling

Every 5 minutes, by a `Monitor` loop (`persistent: true`, one line per sample, exits when the PID
dies) or a background `sleep 300` — never by ending the turn. A sample is healthy when the PID is
alive (`kill -0`) and one of these moved:

- new events in the Codex `.jsonl` (count lines, do not read them);
- the agy run's CLI log grew — note the newest `~/.gemini/antigravity-cli/log/cli-*.log` *before*
  launching, poll until a newer one exists, record it and its size as the baseline (never the agy
  `.json`, which is written whole at exit);
- `git status` changed.

Silence is a hang only after `max(15 min, 2 × T_slow)` of it, and never for a test run. Before
killing, read the files: stderr prints `Reading additional input from stdin...` even on healthy
runs; the hang signal is that line **with no `thread.started` event** — relaunch with stdin closed.
No new file under `~/.codex/sessions/` → startup failure (competing `app-server`; `codex doctor`).
Kill by PID (`ps -eo pid,etime,cmd | grep '[c]odex exec'` → `kill <PID>`) or by the harness task.
