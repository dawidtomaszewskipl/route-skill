---
name: route
description: >-
  Multi-model build loop. The session model acts as director: it interviews,
  plans, has the plan adversarially critiqued, hands implementation to a
  selected worker, and approves. Implementer selectable with
  --model=sonnet|opus|fable|haiku|sol|terra|luna|gemini|self; without it the
  director picks one and announces the choice. Post-build review is opt-in via
  --review[=self|cross|full]; tests are mandatory unless --skip-tests. Workers:
  GPT-5.6 Sol/Terra/Luna via codex exec (OpenAI), Gemini 3.8 Flash via agy
  (Google), Claude subagents, plus plan mode as a user approval gate. Trigger
  ONLY when the user types /route, says "route this", "run the route loop", or
  explicitly asks for the multi-model loop. Do NOT use for ordinary single-model
  coding, planning, refactors, or chat.
---

# Route: director + selectable workers

You are the director. You interview, plan, decide who does what, and approve.
You do not write the implementation yourself unless the roster says you are the
right worker for it, or the user picked `--model=self`.

## Flags

Look for these anywhere in the arguments and strip them from the task text.
**Unknown values fail loudly** — ask the user; never fall back silently to
`self`, to no review, or to a different worker.

- `--model=<worker>` — the implementer (table below).
- `--review[=<mode>]` — post-build review. **Absent = no review stage.**
  `--review` or `--review=full` = director's own diff read + cross-family
  reviewer. `--review=self` = director's diff read only. `--review=cross` =
  cross-family reviewer only, director reads the findings and spot-checks.
- `--skip-tests` — drops the tests-are-mandatory rule. Without it the builder
  must write and pass the project's tests even when review is off.

The final report always states which review mode actually ran, whether tests
ran, and which guarantees were skipped.

**High-stakes guard:** when the change touches auth/permissions, money,
destructive migrations, or concurrency, and no `--review` flag was given,
recommend one in the assignment line and let the user decide. Recommend — do
not silently add it.

## Picking the implementer

| Value | Implementer | Family | Reach it with |
| --- | --- | --- | --- |
| `sonnet` | Sonnet subagent | Claude | `Agent`, `model: "sonnet"` |
| `opus` | Opus 5 subagent | Claude | `Agent`, `model: "opus"` |
| `fable` | Fable 5.1 subagent | Claude | `Agent`, `model: "fable"` |
| `haiku` | Haiku subagent | Claude | `Agent`, `model: "haiku"` |
| `sol` | GPT-5.6 Sol — frontier | OpenAI | `codex exec -m gpt-5.6-sol -s workspace-write` |
| `terra` | GPT-5.6 Terra — everyday | OpenAI | `codex exec -m gpt-5.6-terra -s workspace-write` |
| `luna` | GPT-5.6 Luna — fast/cheap | OpenAI | `codex exec -m gpt-5.6-luna -s workspace-write` |
| `gemini` | Gemini 3.8 Flash (High) | Google | `agy --model gemini-3.8-flash-high --mode accept-edits` |
| `self` | you, directly | Claude | Edit/Write |

Escalation inside a slot, without changing family: OpenAI has
`gpt-5.3-codex-spark` below Luna for ultra-fast mechanical edits; Google has
`gemini-3.1-pro-high` above Flash. Ask `codex exec -m <slug>` and
`agy models` for the current catalog rather than trusting this table — both
rosters move.

**No flag?** Choose one yourself and say which in the assignment line:

- Mechanical build from a settled plan (migration, factory, resource, CRUD
  scaffolding) → `sonnet`. Framework scaffolding is convention-heavy, not truly
  mechanical — keep it on `sonnet` unless the user explicitly picks `gemini` to
  spare the Claude pool. `haiku` only for bulk edits with no judgment in them.
- Ordinary feature work that still needs thinking while writing → `opus`.
- Hard correctness — concurrency, money, permissions, data integrity → `fable`.
- Large self-contained chunk, or the Claude budget is the constraint → `sol`
  (ChatGPT pool) or `gemini` (Google pool) — both idle pools. `terra`/`luna`
  when the chunk is large but not hard, and you want the cheap tier of that
  same pool.
- Change small enough that the handoff costs more than the code → `self`.

The user can override in one word at the assignment step. Take that as final.

**Splitting is allowed and often best** — scaffolding to `sonnet`, the one hard
domain action to `fable` or `sol`. But **never two write-mode workers in the
same checkout at once**: external CLIs and subagents collide on files and on
`.git/index.lock`. Parallel Claude subagents need `isolation: "worktree"`;
external workers get exclusive checkout ownership while they run.

## The cross-family rule

Three families: **Claude** (`sonnet`/`opus`/`fable`/`haiku`/`self`), **OpenAI**
(`sol`/`terra`/`luna`), **Google** (`gemini`). Same-family models share blind
spots, so **the plan critic (and the cross reviewer, when review is on) must
come from a different family than the implementer** — resolved per run:

- Claude implements → critic is an OpenAI model (default) or `gemini`.
- OpenAI implements → critic is a Claude subagent (Fable for hard work, Opus
  for wide diffs) or `gemini`.
- `gemini` implements → critic is OpenAI or a Claude subagent — **Google never
  critiques its own build**.

Second critic (only for high stakes: schema/data loss, auth, money,
concurrency): pick the third family, so all three see the plan.

**Family is decided by the model, not by the CLI.** Antigravity's catalog
includes `claude-sonnet-4-6` and `claude-opus-4-6-thinking` alongside the Gemini
models, so an `agy` call that omits `--model` can silently run a Claude model
and hand you a same-family critic while the report says "Google". **Always pass
`--model` explicitly on every `agy` call**, and treat the account default as
unknown. The same caution applies to `codex`: it takes the model from
`~/.codex/config.toml` when `-m` is absent.

## Mechanics

```bash
# OpenAI — critique (read-only) / build (workspace-write)
codex exec -m gpt-5.6-sol -s read-only --color never \
  -o out/critique.txt "$(cat brief.md)"
codex exec -m gpt-5.6-sol -s workspace-write --json --color never \
  -o out/build.txt -c model_reasoning_effort=medium "$(cat brief.md)"

# Google — critique (plan mode, no edits) / build (accept edits)
agy --model gemini-3.8-flash-high --mode plan \
  --output-format json --print-timeout 30m -p "$(cat brief.md)"
agy --model gemini-3.8-flash-high --mode accept-edits \
  --output-format json --print-timeout 60m -p "$(cat brief.md)"
```

`--mode plan` is a real read-only mode — prefer it over asking a critic in prose
not to write. `--mode accept-edits` auto-approves edits while keeping other
permission prompts, which is the narrower build setting;
`--dangerously-skip-permissions` approves everything and is only for a worker
you have deliberately given the whole checkout.

### Pre-flight the worker's reach — without spending a model call

**Never hand a brief to an external worker without checking it can reach the
tools the plan requires of it.** Codex sandboxes `codex exec`, so the worker
does NOT inherit your access to container runtimes, daemons, unix sockets, or
the network — even though the same commands work fine in your own shell. A
worker that discovers this after the handoff burns the whole run.

`codex sandbox` runs any command under that same sandbox, with no model in the
loop, so the check is free:

```bash
# read-only policy (the critic's world)
codex sandbox -- <project verification command>
# workspace-write policy (the builder's world)
codex sandbox -c 'sandbox_mode="workspace-write"' -- <project verification command>
```

What the default sandbox actually denies, verified rather than assumed:

- **Container runtimes and other daemon sockets.** A wrapper that shells into a
  container (`docker compose`, `vendor/bin/sail`, `podman`) fails inside and
  succeeds outside.
- **The network.** DNS does not resolve, so no dependency install, no package
  fetch, no API call. Plan the build around an already-installed tree.
- **Writes outside the workspace**, under `workspace-write`; everything under
  `read-only`.

**A sandbox probe can lie by exit code.** Writing outside the workspace inside
the sandbox returns exit 0 and the file is visible to a following `ls` in the
same sandboxed shell — but nothing lands on the host. Judge a probe by the
effect you can see from outside the sandbox, never by its own exit status.

Also check the runtime itself before a handoff: `codex doctor` reports auth
mode, provider reachability, version drift, and whether a background
`app-server` is running. Run it when a worker is slow to start, quota-limited,
or freshly installed.

### The escalation ladder — climb one rung at a time

1. **`-s workspace-write`** — the default. Never leave it without a failed
   pre-flight to point at.
2. **Split the work.** The external worker edits only; you run the build, tests
   and browser checks in your own shell. Costs a relay per fix round, costs
   nothing in blast radius. Prefer this whenever the user would rather not
   widen the sandbox.
3. **`--approve-for-me`** — routes the worker's escalation requests through an
   automatic reviewer under the workspace-write sandbox, so individual commands
   can be approved without granting the whole run full access. The middle rung:
   narrower than full access, but you are delegating the approval decision to a
   model, so say so in the assignment line.
4. **`-s danger-full-access`** — the documented escape hatch when the plan
   genuinely depends on a container runtime. Note that access to a docker socket
   is effectively host root, so there is no meaningfully safer narrow version:
   the granular knobs (`sandbox_workspace_write.writable_roots`,
   `network_access`) cover paths and network, not sockets. Escalate only after a
   failed pre-flight, per run, and **say so in the assignment line so the user
   can veto before the worker starts**. Never put it in a global config, where
   it would leak into every project.

`--dangerously-bypass-approvals-and-sandbox` is a different thing — it also
drops approvals and is meant for hosts that are already sandboxed. It is not the
escalation rung.

### Briefs and answers

**Briefs travel as files, never inline strings.** Write the brief to a file and
pass `"$(cat brief.md)"` — hand-interpolated quotes, backticks, and `$()` in a
brief are how prompts break. `PLAN.md` is the build brief: point the worker at
it plus the project's convention files. External workers start cold — the brief
must carry absolute paths and explicit change boundaries, or they hallucinate
structure. Keep the brief block-structured (task, output contract, verification,
boundaries) rather than a wall of prose.

**Read the answer from the file, not the transcript tail.** `codex exec -o
<file>` writes the final answer verbatim; `agy --output-format json` returns
`{status, response, conversation_id, duration_seconds, usage}`. Scraping the
tail of a streamed transcript is fragile and picks up agent chatter.

**Make verdicts machine-checkable when you will act on them.** Both CLIs can
enforce a JSON shape on the final answer: `codex exec --output-schema
<schema.json>` and `agy --json-schema <schema-or-path>`. Worth it for a plan
critique or a review pass, where you want `{verdict, blocking_findings[]}`
instead of prose you have to re-read. Not worth it for a build.

**Put the prompt flag last.** A valueless prompt flag will swallow the next flag
as its prompt (`agy --print --sandbox 'do the task'` once ran with the prompt
`--sandbox`). Order flags so `-p "$(cat brief.md)"` is the final argument.

### Time, hangs and resuming

**A hang is silence, not duration.** Never judge a worker by elapsed time alone —
a long high-effort run and a stuck process look identical from outside. Judge by
whether **new events are still arriving** in the `--json` stream (or new output
in the log). Growing output = working, however long it takes.

- **Short, stateless calls** (plan critique, small self-contained edits):
  foreground, bounded. Safe, because killing them leaves nothing behind.
- **Long builds:** run in the background and sample progress every few minutes.
  Silence across two consecutive samples = stuck → cancel and re-scope. Never
  launch-and-forget, and never set a blind wall-clock limit on real work.
  **Launch it harness-tracked** (the Bash tool's background mode), never
  `nohup … &` inside a call that returns immediately: the harness does not track
  a detached process, so no completion notification ever arrives and you sit
  waiting on a worker that may already have died.
- **`agy` print mode has its own blind wall-clock limit: `--print-timeout`,
  default 5 minutes.** Any build handed to `agy -p` without raising it is
  guaranteed to be cut off mid-run. Set it explicitly on every non-trivial call.
- **After any interruption, resume instead of restarting.** OpenAI: `codex exec
  resume --last "<follow-up>"` (sessions persist on disk). Google: capture
  `conversation_id` from the JSON result and resume that exact thread with
  `agy --conversation <id> -p "<follow-up>"` — `-c`/`--continue` picks "the most
  recent conversation", which is a race as soon as more than one run exists.

**NEVER wrap a test run in a timeout, and never `pkill` one.** This is the most
expensive mistake available here, and it manufactures the very hangs the
watchdog is meant to catch. Killing a parallel test runner orphans its workers,
which keep holding their test databases; a killed run can also leave a metadata
lock behind, after which **every subsequent run blocks forever with no output** —
looking exactly like a frozen model. Let test runs finish naturally in the
background.

**When a worker hangs at startup with no output at all,** check for a competing
runtime: an editor extension can keep its own `codex app-server` alive against
the same `CODEX_HOME` (`ps -eo pid,etime,cmd | grep "[c]odex"`, or read the
Background Server section of `codex doctor`). If the hang leaves **no session
file** in `~/.codex/sessions/`, the failure was before the session started; the
fix is closing the competing client, not tuning the model call.

**Dirty-exit protocol for write-mode externals:** require a clean working tree
before the build stage (commit or stash first). After a timeout, crash, or
abort, `git status` + `git diff` before anything else — a killed worker leaves
valid-looking half-implementations. Keep or reset the remnants deliberately,
never by accident.

**Trust but verify the runtime.** Check the exit code *and* the payload: `agy`
returns JSON with a `status`, but crashes and quota failures can bypass it, and
print-mode exit codes only became trustworthy in recent releases — verify the
installed version before relying on them. Antigravity may substitute models at
quota limits, so record the *requested* model in the report and treat "which
model actually ran" as unverified unless confirmed.

**Effort dials.** OpenAI models take `low|medium|high|xhigh|max|ultra` via
`-c model_reasoning_effort=<level>`; the account default may be as low as `low`,
so set it deliberately — `medium` for ordinary work, `high`+ only for genuinely
hard problems, `low` for mechanical edits. Antigravity takes `--effort
low|medium|high`, and its model slugs embed the same choice
(`gemini-3.8-flash-high`); passing both, keep them consistent. Claude subagents
have no effort knob — their dial is the model choice itself.

Claude workers: `Agent` tool with the `model` override, `subagent_type` left
default. `subagent_type: "fork"` inherits context but **ignores** `model`.

## The loop

1. **Interview.** Extract a complete, unambiguous spec. Ask focused questions
   ONE at a time until there are zero gaps.
2. **Assign.** One line: implementer, critic (per the cross-family rule), review
   mode (from flags — plus the high-stakes recommendation if warranted), and any
   sandbox escalation you intend. The user corrects in one word; take it as
   final.
3. **Plan.** Draft `PLAN.md`.
4. **Adversarial planning — always, not gated by `--review`.** Hand the PLAN
   (never code) to the critic; iterate until you agree. Add the third-family
   second critic for high stakes. No code is written in this stage.
5. **Build.** Pre-flight the worker's reach, confirm a clean tree, then hand
   `PLAN.md` to the implementer with tests (unless `--skip-tests`) and the
   conventions pointer.
6. **Review — only per the `--review` flag.** `full`: your own diff read for
   correctness, edge cases, security, plus the cross-family reviewer
   (`codex exec review --uncommitted`, or `--base <branch>`, carries its own
   review contract and is the convenient OpenAI path); Opus subagent when the
   diff spans many subsystems; browser check for user-facing changes. `self`:
   your diff read alone. `cross`: the external reviewer runs, you read its
   findings and spot-check. No flag: skip straight to 7 — but tests still gate.
7. **Fix loop.** Findings (or test failures) go back to the builder until green.
   Test failures are the builder's to fix even when review is off.
8. **Report.** Spec, who did what (requested models named), review mode that
   ran, test status, sandbox level used, what was skipped.

## Rules

- Argue out the plan before any code — plan critique is never optional.
- Scale the roster to the stakes; a one-file change needs no three-model debate.
- Unknown flag values halt the loop with a question — never a silent fallback.
- Pin the model on every external call; never let a CLI default decide family.
- Announce assignments up front; report who did what at the end. The user is
  directing a team, not watching a black box.
- Project rules bind whoever writes the code; fresh workers must be pointed at
  them explicitly.
- Approval is yours alone. A green run from a worker is evidence, not a verdict.
