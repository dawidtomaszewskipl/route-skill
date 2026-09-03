# Troubleshooting

## A worker looks stuck

**A hang is silence, not duration.** A long high-effort run and a dead process
look identical from the outside, and elapsed time distinguishes them not at all.
The signal is whether **new events are still arriving**: the `--json` event
stream for Codex, the log for Antigravity. Output still growing means the worker
is working, however long it has been.

So: launch long builds in the background, sample every few minutes, and treat
**silence across two consecutive samples** as stuck — cancel and re-scope. Never
launch-and-forget, and never impose a blind wall-clock limit on real work.

Launch background work through your harness's tracked background mode, not
`nohup … &` inside a call that returns immediately. A detached process is not
tracked, so no completion notification ever arrives and you end up waiting on a
worker that may already have died.

## `agy` cuts off after five minutes

`--print-timeout` defaults to `5m0s`. Print mode has exactly the blind wall-clock
limit you are otherwise told to avoid, and it will guillotine any real build.
Set it explicitly on every non-trivial call:

```bash
agy --model gemini-3.8-flash-high --mode accept-edits \
  --output-format json --print-timeout 60m -p "$(cat brief.md)"
```

## A worker hangs at startup with no output at all

Different failure, different fix. Check for a competing runtime first: an editor
extension can keep its own `codex app-server` alive against the same
`CODEX_HOME`.

```bash
ps -eo pid,etime,cmd | grep "[c]odex"
codex doctor          # see the Background Server section
```

If the hang left **no session file** in `~/.codex/sessions/`, the failure was
before the session started. The fix is closing the competing client, not tuning
the model call.

## Never kill a test run

This is the most expensive mistake available in this loop, and it manufactures
the very hangs the watchdog exists to catch.

Do not wrap a test run in a timeout. Do not `pkill` one. Killing a parallel test
runner orphans its workers, which keep holding their test databases; the killed
run can also leave a metadata lock behind, after which **every subsequent run
blocks forever with no output** — which looks exactly like a frozen model, and
sends you debugging the wrong thing entirely.

Let test runs finish naturally in the background, however long they take.

## A worker died mid-build

Dirty-exit protocol:

1. `git status` and `git diff` **before anything else**. A killed worker leaves
   half-implementations that look finished.
2. Decide deliberately whether to keep or reset the remnants. Never inherit them
   by accident.
3. Resume rather than restart, so you do not pay for the same reasoning twice:
   - `codex exec resume --last "<follow-up>"`
   - `agy --conversation <id> -p "<follow-up>"` — using the `conversation_id`
     from the earlier JSON result, not `-c`, which means "most recent" and races
     as soon as two runs exist.

This is also why the build stage requires a clean tree: without a baseline you
cannot separate the worker's remnants from your own uncommitted work.

## The cross-family guarantee leaked

Symptom: the report says a different vendor critiqued the plan, but the critique
reads suspiciously agreeable.

Cause: an external call without an explicit model. The Antigravity catalog
includes `claude-sonnet-4-6` and `claude-opus-4-6-thinking`; Codex falls back to
`~/.codex/config.toml`. Either way the CLI's name told you nothing about which
family actually answered.

Fix: pass `--model` / `-m` on **every** external call, and record the requested
model in the report. Note that vendors may substitute models at quota limits, so
"which model actually ran" stays unverified unless you confirmed it.

## The run succeeded but the answer is empty

Check the exit code **and** the payload. `agy --output-format json` carries a
`status` field, but crashes and quota failures can bypass the JSON entirely.
Print-mode exit codes were themselves unreliable in older Antigravity builds —
`-p` could exit 0 with an empty response, and benign tool errors were reported as
fatal run failures. Both were fixed across 1.1.18–1.1.20, so check `agy --version`
before trusting an exit code alone.

## Two workers fought over the checkout

Never run two write-mode workers in the same checkout. External CLIs and
subagents collide on files and on `.git/index.lock`, and the resulting damage
looks like a model behaving erratically.

Parallel Claude subagents need their own worktrees (`isolation: "worktree"`).
External workers get exclusive ownership of the checkout for the duration of
their run.

## The worker could not run the tests

You skipped the pre-flight. See [sandbox and pre-flight](sandbox-and-preflight.md):
`codex sandbox -- <verification command>` answers this before the brief is
written, at no cost. The usual culprits are a container runtime and the sandbox's
blocked network.
