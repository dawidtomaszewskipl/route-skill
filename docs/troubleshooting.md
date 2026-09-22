# Troubleshooting

Every entry below happened in a real route run between 2026-08-16 and 2026-09-21.

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

## Codex finished long ago and the director noticed only when asked "how is it going?"

The worker was launched as `setsid nohup run.sh … & disown` inside the Bash command, with the
tool's `run_in_background` left unset. The tool returned after the `sleep 15` that followed, no
harness task was registered, and the completion notification that would have woken the director
never existed. The director ended its turn ("second batch starting") and waited for something that
could not arrive. Across two sessions this was 34 of 36 launches — idle gaps of 0.7 to 127 minutes,
every one ended by the user typing. The same runs launched with `run_in_background: true` were
resumed by the director 6–10 s after the worker exited, with no human in between.

Fix: the Bash tool's background mode is the *only* background mechanism — no `&`, `nohup`,
`setsid`, `disown` in the command. If a process must outlive the shell, the same background
command waits for its PID so the task ends when the worker does. Never end a turn with a live
worker and no task for it. The Codex plugin's `--background` rescue does the same detach
(`spawn(detached) + unref()`) and is polled through `/codex:status`, so it does not fix this.

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

## agy: exit 0, `status:"SUCCESS"`, empty response, `denied_actions:[{"action":"mcp"}]`

A different signature from the `CANCELED` case above, and a nastier one: the status says
**SUCCESS**, so a check that reads only `status` concludes the critique passed and moves on with
nothing. The worker reached for an MCP tool the project configures (Laravel Boost, Perplexity,
Playwright), headless mode auto-denied it because it cannot prompt, and the turn ended with no
answer. stderr names it exactly:

```
jetski: no output produced — a tool required the "mcp" permission that headless mode cannot
prompt for, so it was auto-denied.
```

Usage still shows thousands of output and thinking tokens — the model did the work and then threw
it away reaching for a tool. This is why the envelope check is three conditions, not one:
`status == "SUCCESS"` **and** `response != ""` **and** `denied_actions == []`.

Fix in the brief, not in the user's global config: open a critic brief with an explicit
prohibition — *"This brief is self-contained. Do NOT call any tools: do not read files, do not run
commands, do not call MCP, do not search the repository. Answer from the text below alone."* — and
make sure every fact the critic needs really is inline. `--dangerously-skip-permissions` also
clears it but grants far more than a read-only critic should have, and `agy mcp disable` mutates
the user's setup for every project. Start a new conversation; the one that produced no answer has
nothing to resume.

Measured on agy 1.1.28: same brief, same model, same effort — 37 s and no answer with the
prohibition absent, 202 s and a full verdict with it present.

## agy: exit 1, `status:"ERROR"`, `error:"timeout waiting for response"`

`--print-timeout` expired (5 minutes by default up to agy 1.1.x; 1.2.8 defaults to no limit, so a
missing value hangs instead — route always sets it). There is no `TIMEOUT` status. Start a new
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

## The progress monitor raised an alarm on a healthy Codex run

The Codex `.jsonl` carried `{"type":"error", …}` lines about a stream reconnect (HTTP 503) in the
middle of a build that finished normally. Codex retries its stream by itself; the event is a
notice. The director's own monitor treated every `"type":"error"` as a failure (2026-09-09). A
failure is `turn.failed`, or the process exiting without `turn.completed` — check for those.

## The ledger showed a resumed Codex thread costing twice what it did

`codex exec resume` reports `turn.completed.usage` **cumulatively for the thread**, not for the new
turn. Summing the rows of a thread counted the first call again on every resume (2026-09-20). The
ledger keeps the raw counters in `raw_cumulative` and records `raw[n] − raw[n−1]` as the row's
tokens — computed from the raw counters, not from the previous row's delta (that shortcut breaks on
the second resume: 100, 150, 180 becomes 100, 50, 130). `docs/ledger.md` has the rule.

## Tests failed with missing tables in the middle of a run

Another Claude Code session on the same machine ran its own tests against the shared `testing`
database and dropped tables under the route run — false reds with no relation to the diff
(2026-09-09 in one project, 2026-09-20 in another). Before diagnosing a red that makes no sense,
check for another live test run (`ps -eo pid,etime,cmd | grep '[a]rtisan test'`); wait for it to end
rather than killing it. Never start a second run of the same suite while one is live.

## The cascade draft was right in shape and wrong in finish

A Luna draft at effort `low` (2026-09-17) stayed inside its boundaries but packed code into very
long one-liners, left out two tests the plan listed and wrote one wrong Livewire assertion. The
Gemini gate asked for a revision (confidence 0.95, same diagnosis as the director's own probe); one
fix round was accepted. The drafter appendix now asks for the repository's formatting and for every
planned test; the gate still checks both.

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
