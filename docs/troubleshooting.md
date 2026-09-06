# Troubleshooting

Every entry below happened in a real route run between 2026-08-16 and 2026-09-06.

## Codex sits at `Reading additional input from stdin...` for an hour

Every confirmed Codex "hang" in twenty runs was this — three separate sessions, three separate
diagnoses, 19 to 75 minutes lost each. The `codex exec` call was inside a shell command that also
contained a heredoc, stdin stayed open, and Codex waited for it (its help says so: piped stdin is
appended to the prompt). Nothing was written to disk, so the restart is clean.

The line is printed on healthy runs too. The hang signal is that line **with no `thread.started`
event in the `.jsonl`**. Fix: `< /dev/null` on the command line — it is on every canonical line.

## `codex exec resume` rejects `-s` / `--color`

`error: unexpected argument '-s' found`. The resume subcommand has a smaller flag set: `-m`, `-c`,
`--json`, `-o`, `--output-schema`, `--last`, `--all`. Sandbox goes through
`-c 'sandbox_mode="workspace-write"'`. Two 8–10-minute sampling windows were wasted per session on
this before the working form was found.

## The director's own `timeout 900` was cut at 10 minutes

The Bash tool caps foreground commands at 600 s and sends SIGTERM; the longer value you wrote is
silently ignored. Anything that can take more than a few minutes — every model call, every test run
— goes to the background.

## A healthy 417-second test was killed as a hang

The test emitted nothing for its entire run; two silent samples of 20–25 s "proved" it stuck. The
silence rule now has a floor — `max(15 min, 2 × T_slow)` of *continuous* silence, with `T_slow`
recorded at stage 0 — and is never applied to test runs at all.

## Every test run blocks forever with no output

A killed parallel test runner (`timeout`, `pkill`) orphans its workers, which keep their test
databases and a metadata lock (`Waiting for table metadata lock`). Every subsequent run then waits
on that lock and looks exactly like a frozen model. Recovery that worked: find the blocking
connection id in the database, kill *that* connection by id, leave the others alone. Prevention:
never wrap tests in `timeout`, never `pkill` them, never run two of the same suite at once.

## `pkill -f` returned 144 and killed the wrong thing

`pkill -f "codex exec"` and `pkill -f 'artisan test'` matched the director's own shell — four
sessions, always exit 144. Kill by PID (`ps -eo pid,etime,cmd | grep '[c]odex exec'`, then
`kill <PID>`) or by the harness task id.

## agy: exit 0, `status:"CANCELED"`, empty response

The worker tried a tool action that headless mode cannot prompt for (usually `RunCommand`) and the
turn was cancelled: `denied_actions:[{"action":"command","display_name":"RunCommand"}]`. Fix the
brief (edits-only for builders; every fact inline for critics) or add `permissions.allow` rules —
never retry identically, and never resume that conversation.

## agy: exit 1, `status:"ERROR"`, `error:"timeout waiting for response"`

`--print-timeout` expired (default 5 minutes). There is no `TIMEOUT` status. Start a new
conversation with a larger timeout and the current `git diff` embedded; do not `--conversation`
into the expired one.

## agy: `flag needs an argument: -p` / `Argument list too long`

`-p` does not read stdin, and the OS caps a single argument at ~128 KB. The pointer stub
(`Read .route/brief-build.md … execute it exactly`) sidesteps both. The old "prompts over 4 KB
return `status:"ERROR"`" belief did not reproduce on 1.1.27 — a 34 KB prompt ran normally.

## Gemini "did the work" but ran no tests and saw no skills

Two different causes. Headless `agy` cannot run commands (see `CANCELED` above) — the director runs
the tests. And print mode does not treat cwd as the workspace: without `--add-dir "$REPO"` the
worker sees only the built-in skills and none of the project's `.agents/skills`. Stage 0's
`agy --add-dir "$REPO" -p "/skills"` probe shows exactly what the worker will see.

## The schema verdict will not parse

Three layers: agy's envelope wraps the verdict in the `response` *string*; the model may wrap the
JSON in Markdown fences; agy adds `toolAction`/`toolSummary` keys the schema does not declare. Strip
fences, drop those two keys, parse, validate — then act. Codex's `-o` file is the bare verdict.

## A worker hangs at startup with no output at all

No new session file under `~/.codex/sessions/` means the failure was before the session started.
`codex doctor --summary` shows the background `app-server`; an editor extension keeps its own
against the same `CODEX_HOME`. Once, the real cause was a global MCP server that shelled into a
container runtime that was not running — a 35-minute "hang" fixed by removing it from the global
config.

## A worker died mid-build (quota, API error, cancel)

Six quota events in three weeks; the protocol worked every time it was followed:

1. `git status` and `git diff` **before anything else** — remnants look finished.
2. Keep or reset them deliberately; write the checkpoint with `tree_state` and the blocker.
3. Resume rather than restart: Codex by thread UUID, agy by `conversation_id` (only after a
   `SUCCESS` turn), Claude subagents with the checkpoint's "to do on resume" section.
4. **Re-probe the limit before re-casting the roster.** The one time the director reasoned from a
   remembered limit ("resets 4:10am", at 8:48) it moved four batches off the right worker.

## The worker's green run disagrees with yours

770/770 reported, 769/770 measured. Sandbox differences, stale caches, a test the worker never ran.
A worker's green run is evidence, not a verdict — the commit waits for your own run.

## Playwright `fill()` never returns

A selector moved onto a custom element and `fill()` waited for it indefinitely instead of failing.
That is a red test that looks like a hang. Fix the selector; do not treat it as a watchdog case.

## Two projects served each other's assets

One project's Vite died; the other project's dev server took port 5173; the first silently loaded
the wrong CSS/JS for an hour and a half. Stale `public/hot` was the tell. Not route's fault — but
it is the kind of thing a browser check surfaces and a test suite does not.

## Leftover processes from an interrupted run

`until [ -s file ]` loops and dev servers from a run the director itself had interrupted survived
for hours. The checkpoint's `sessions` and the harness task ids are the inventory to clean up after
any interruption; `git stash list` shows leftover `route-draft-*` stashes from escalated cascades.
