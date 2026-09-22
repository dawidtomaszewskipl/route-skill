---
name: route
description: >-
  Multi-model build loop: the session model directs — interviews, plans, has the
  plan critiqued by another model family, hands the build to a chosen worker
  (Claude subagents, OpenAI via codex exec, Gemini via agy), gates, tests,
  commits and reports. Trigger ONLY when the user types /route, says "route
  this", "run the route loop", or explicitly asks for the multi-model loop. Do
  NOT use for ordinary single-model coding, planning, refactors, or chat.
---

# Route: director + selectable workers

You are the director. You interview, plan, decide who does what, gate the result
and approve. You do not write the implementation yourself unless the roster says
you are the right worker for it, the user picked `--model=self`, or it is a
bounded fix in the fix loop. You do the commits — external workers usually
cannot.

Read `docs/` files when a section points at them, not up front:
`docs/commands.md` (exact launch lines, reading results, progress sampling —
**read it before the first external launch of a run**), `docs/workers.md`
(catalogs, CLI flags), `docs/policy.md`, `docs/cascade.md`, `docs/setup.md`,
`docs/sandbox-and-preflight.md`, `docs/checkpoint.md`, `docs/ledger.md`,
`docs/troubleshooting.md` (every incident behind the rules below),
`docs/schemas/*.json`.

## Flags

Look for these anywhere in the arguments and strip them from the task text.
**Unknown flag names, unknown values and illegal combinations all fail loudly**
— ask the user; never keep an unrecognised switch as task text, never fall
back silently to `self`, to no review, or to a different worker.

- `--model=<slot>` — the implementer (roster below).
- `--review[=full|self|cross]` — post-build review. **Absent = no review
  stage.** `full` (default) = your diff read + cross-family reviewer; `self` =
  your read only; `cross` = reviewer only, you read its findings and spot-check.
- `--critic=<slot>[,<slot>]` — the plan critic; a second named slot is a second
  critic that runs whatever the stakes. `--reviewer=<slot>` — the cross
  reviewer; alone it implies `--review=full`. Both beat policy (a denied slot
  runs with a warning), never the cross-family rule: a named critic or reviewer
  from the implementer's family halts with a question.
- `--rounds=<n>` — plan-critique cap, 1–8 (default 2; policy `critique_rounds`).
- `--tests=covering|browser|full` — test scope (default `covering`): the tests
  covering the change; `browser` adds browser tests; `full` runs the full suite
  before the commit. `--skip-tests` runs none.
- `--setup` — configure the run by questions before anything else (section
  "Setup"); given flags count as answered.
- `--plan-only` — interview, plan, critique, then stop: hand over
  `.route/PLAN.md`, the unresolved findings and the decisions left to the user.
  No build, no commit. `--model` and `--tests` are recorded for the later build.
- `--cascade[=luna|haiku|gemini]` — a cheap drafter builds first, a gate
  accepts or escalates (`docs/cascade.md`). Default drafter `luna`.
- `--resume` — continue the run recorded in `.route/CHECKPOINT.md`, with the
  configuration recorded there.

**Illegal combinations:** `--plan-only` with `--cascade`, `--review` or
`--reviewer`; `--reviewer` with `--review=self`; `--cascade` with
`--model=luna|haiku`, with drafter == implementer, or with `--skip-tests` (the
gate has no mechanical half); `--resume` with any other flag — to change the
configuration, discard the checkpoint and start again.

**Plain words are flags too.** "Krytykuj astrą", "review gemini", "bez fable",
"astra implementuje", "więcej rund krytyki", "bez testów przeglądarkowych",
"zbuduj tylko plan", "zapytaj o konfigurację" map to `--critic`, `--reviewer`,
a per-run deny, `--model`, `--rounds`, `--tests`, `--plan-only`, `--setup`.
Echo the mapping in the assignment line (`critic=astra (user: "krytykuj
astrą")`); ask only when the words are ambiguous or break a rule.

**High-stakes guard:** when the change touches auth/permissions, money,
destructive migrations or concurrency and no `--review` was given, recommend
one in the assignment line. Recommend — do not add it silently.

## Setup (`--setup`)

Configuration by questions instead of flags. Question catalog and
recommendation rules: `docs/setup.md`.

1. **Read the input.** The task text, plus any plan it carries or points at (a
   pasted `/plan` result, a plan file path, an existing `.route/PLAN.md`).
   Split it into tasks; for each note stakes, whether it is user-facing UI,
   its test footprint, its size and the rubric row that fits.
2. **Probe first** — stage 0 steps 1–3 (flags, families, policy), so every
   option offered is eligible.
3. **Ask in two steps** with the `AskUserQuestion` tool, recommended option
   first and labelled "(Recommended)", each description naming the task fact
   behind it. Step 1: tasks (one run or separate runs in sequence), mode,
   implementer. Step 2, with options computed from step 1: critic, rounds,
   review, tests. Policy values are shown as defaults, not skipped — when the
   rubric disagrees for this task, recommend the rubric and say why. Skip only
   what flags or the user's words settled.
4. **Echo the result** as a reusable flag line per task — `/route --model=opus
   --critic=astra,gemini --rounds=2 --review=cross --tests=covering <task>` —
   then the assignment line, and continue with the interview. Setup settles the
   roster; the interview still settles the spec. Separate runs go into the
   checkpoint's task queue.

## Roster

| Slot | Worker | Family | Reach it with |
| --- | --- | --- | --- |
| `sonnet` | Sonnet subagent | Claude | `Agent`, `model: "sonnet"` |
| `opus` | Opus 5.5 subagent | Claude | `Agent`, `model: "opus"` |
| `fable` | Fable 5.1 subagent | Claude | `Agent`, `model: "fable"` |
| `haiku` | Haiku subagent | Claude | `Agent`, `model: "haiku"` |
| `astra` | GPT-6 Astra — frontier | OpenAI | `codex exec -m gpt-6-astra` |
| `sol` | GPT-6 Sol — workhorse (provisional, not yet measured) | OpenAI | `codex exec -m gpt-6-sol` |
| `luna` | GPT-6 Luna — fast, cheap (provisional, not yet measured) | OpenAI | `codex exec -m gpt-6-luna` |
| `terra` | GPT-5.6 Terra — legacy, explicit only | OpenAI | `codex exec -m gpt-5.6-terra` |
| `gemini` | Gemini 3.8 Flash | Google | `agy --model gemini-3.8-flash-<effort>` |
| `self` | you, directly | Claude | Edit/Write |

The Google slot is Flash only (Gemini 3.1 Pro is still in `agy models`; Flash
did better). The `opus` alias follows Claude Code's newest Opus; report the
alias and the model the subagent's completion line shows.

**No flag?** Evaluate in this order and name the row that fired — stakes first,
so a payment feature never lands in the ordinary-feature row:

1. Hard correctness — concurrency, money, permissions, data integrity,
   destructive migrations → `fable`, or `astra` when the Claude budget is the
   constraint; `opus` when Fable's cost is the problem and a high-effort
   cross-family critic covers the plan.
2. User-facing layout and UI → `opus` (it reads screenshots precisely, which the
   visual check relies on); `fable` for a large redesign when the budget allows.
3. Ordinary feature work that needs thinking while writing, multistep changes
   carried through the codebase until the tests pass → `opus`; `sol` when the
   Claude pool is the constraint.
4. Mechanical build from a settled plan (migration, factory, resource, CRUD
   scaffolding — convention-heavy, not truly mechanical) → `sonnet`; `gemini`
   only when the user picks it to spare the Claude pool. `haiku` for bulk edits
   with no judgment in them.
5. Large self-contained chunk → `sol` or `gemini` (the idle pools); `luna` when
   it is large but not hard.
6. Change smaller than the handoff → `self`.

Effort by stage for OpenAI and Google workers (policy key `effort.<stage>`):
critique `medium`, high-stakes critique `high`, build `medium`, review `high`,
cascade draft `medium`. A value may be per family (`{openai: xhigh, google:
high}`); a single value above a family's range is clamped to its maximum
(Gemini: `high`) and marked `(clamped)`. Always pass effort explicitly —
catalog defaults differ per model. Claude subagents take no effort on the call;
the model is the dial.

This rubric is the whole routing logic — a written rule you apply and name, not
a learned router. `route.policy.yml` (repo) and `~/.claude/route.policy.yml`
(user) can deny slots and set defaults: flags > repo policy > user policy >
rubric, per key, and every policy-sourced value is marked `(policy)`
(`docs/policy.md`). The user can override any assignment in one word; take it
as final.

**Splitting is allowed and often best** — scaffolding to `sonnet`, the one hard
action to `fable` or `astra`. **Never two write-mode workers in one checkout at
once**: they collide on files and `.git/index.lock`. Parallel Claude subagents
need `isolation: "worktree"`; an external worker owns the checkout while it
runs.

## The cross-family rule

Three families: **Claude** (`sonnet`/`opus`/`fable`/`haiku`/`self`), **OpenAI**
(`astra`/`sol`/`luna`/`terra`), **Google** (`gemini`). Same-family models share
blind spots, so **the plan critic and the cross reviewer come from a different
family than the builder**:

- Claude implements → critic `sol` (default), `astra` for high stakes, or
  `gemini`.
- OpenAI implements → critic a Claude subagent (`opus` by default, `fable` for
  the hardest correctness when its budget is there) or `gemini`. Astra never
  critiques Sol/Luna/Terra.
- `gemini` implements → critic OpenAI or a Claude subagent; Google never
  critiques its own build.
- High stakes (schema/data loss, auth, money, concurrency) → a second critic
  from the third family.
- **With `--cascade`, the plan critic differs from both the implementer's and
  the drafter's family** when an eligible one exists (Opus implements, Luna
  drafts → critic `gemini`). When none exists and the draft is accepted, the
  report says `plan critic same family as accepted builder`.

Roles resolve among the families stage 0 found **eligible** (available, not
switched off by policy). With fewer than three, the high-stakes third view is
skipped and the report says so. Claude only (`families=claude (degraded:
same-family critique)`):

- critic and reviewer are a Claude subagent of a different model than the
  implementer (Fable for a Sonnet or Opus build, Opus for a Fable build);
- the cascade gate is a different model than the drafter;
- a bare `--cascade` defaults to the `haiku` drafter; an explicit or policy
  drafter keeps precedence and is validated like any other slot.

`--review=self` is always your own read. **Family is decided by the model, not
by the CLI** — agy's catalog also hosts Claude models and Codex falls back to
`$CODEX_HOME/config.toml` — so **pin `--model`/`-m` on every external call**
and report the requested model.

## Stage 0 — validated routing (before any model call)

1. Parse flags; reject unknown names, unknown values, illegal combinations.
2. Detect families. Claude: always. OpenAI: `command -v codex`, `codex login
   status`, and `codex doctor --summary` **run where the worker will run** (a
   doctor failure there means unavailable there, not signed out). Google:
   `command -v agy`, `agy models` listing `gemini-3.8-flash-high`,
   `agy --version` ≥ 1.1.27.
3. Load and merge policy (`docs/policy.md`), resolve every role among eligible
   families, then validate the effective roster as policy.md describes.
   **Each OpenAI slot the roster uses:** `$CODEX_HOME/models_cache.json`
   (default `~/.codex`) is a candidate list. Slug listed, cache fresh
   (`fetched_at` under 7 days, `client_version` = `codex --version`) →
   `listed`. Missing slug or stale cache → one pinned read-only probe call
   (effort `low`, "Reply with exactly: OK") → `probed` or unavailable. Halt
   with an upgrade instruction only when the error says the client does not
   know the model; never substitute another model. Probes below run only for
   eligible families; report skipped ones.
4. `REPO="$(git rev-parse --show-toplevel)"`; `mkdir -p .route`; add `.route/`
   to `.git/info/exclude` (never `.gitignore`); copy `docs/schemas/*.json` into
   `.route/`.
5. Clean tree required. Warn about leftover `route-draft-*` stashes.
6. Skills: `agy --add-dir "$REPO" --output-format json -p "/skills" < /dev/null`
   (no model turn). Zero workspace skills with a populated `.agents/skills/` =
   trust/mount failure. A skill only in `.claude/skills` is invisible to both
   external CLIs — warn.
7. Read the project's `.codex/config.toml`: a `default_permissions` profile or a
   container-backed MCP server silently cripples a Codex worker — warn.
8. Reach probe: `codex sandbox -c 'sandbox_mode="workspace-write"' --
   <verification command>`, judged by effect outside the sandbox
   (`docs/sandbox-and-preflight.md`).
9. Record `T_slow` (slowest single test or build, seconds; unknown → 900).

## Launching workers

`docs/commands.md` has the exact lines. The invariants, for every run —
Claude-only runs included:

- Every model call **and every test run** goes through the Bash tool's
  `run_in_background: true`, output under `.route/`. Never `&`, `nohup`,
  `setsid`, `disown` — the completion notification that wakes you exists only
  for harness tasks.
- Claude workers: `Agent` with an explicit `model` and the default
  `subagent_type`; `subagent_type: "fork"` **ignores** `model`.
- Briefs are files; stdin closed with `< /dev/null`; model and effort pinned.
- Resume Codex by thread UUID and agy by `conversation_id` — never `--last` or
  `--continue`, and never a thread whose last turn was not `SUCCESS`.
- Read answers from the `-o` file or the agy envelope; grep the `.jsonl`,
  never load it whole.
- Validate every agy envelope (`SUCCESS`, non-empty `response`, no
  `denied_actions`) and every schema verdict before acting on it.

## Briefs

Everything lives under `.route/`, never `/tmp`. External workers start cold:
absolute paths, explicit change boundaries, the convention files, what "done"
looks like and which command proves it, and the **binding project skills by
name** (Codex discovers `.agents/skills`; agy only with `--add-dir`).
Block-structured, not prose. For Opus 5.5 and Fable 5.1 workers state goal,
boundaries and proof of done — not step-by-step instructions; for frontend
work name the concrete patterns to avoid rather than "no generic look".

**Critic, gate and reviewer briefs are self-contained.** Codex and Claude: plan
plus diff embedded under 40 KB, else the path. **Gemini reads nothing**: its
whole brief goes into `-p` (no pointer stub), with the conventions it must
judge against quoted inline; above ~100 KB (argv limit ~128 KB) split the
review into parts or give the role to another family.

**Test scope** (`--tests`, settled in the interview when not given): the builder
writes and runs the tests covering the change, and browser tests only with
`browser`. Record the exact test commands in `PLAN.md`. Before the commit you
re-run what the builder ran plus the covering tests, and the **full suite**
when `--tests=full`, or when the change touches migrations, shared base classes
or traits, config, service providers, middleware, routes, events and listeners,
jobs and queues, dependencies (a lockfile), a widely used service — or when you
are unsure of its reach. Parallel sessions share the `testing` database: before
blaming the code for a senseless red, check for another live run.

Every brief ends with: *"Do not ask questions. Where the brief is silent, decide
and record each assumption — in the `assumptions` field when a JSON schema was
given, otherwise under a `## Assumptions` heading. Do not commit. Do not write
outside the boundaries or into `.route/`."* Gemini builders add: *"Do not
execute shell or terminal commands; edit files only — any command execution
aborts this headless run."* Gemini critics, gates and reviewers **open** with:
*"This brief is self-contained. Do NOT call any tools: do not read files, do
not run commands, do not call MCP, do not search the repository. Answer from
the text below alone."* A worker that *ends* with a question becomes a
`question` blocker, answered as a new prompt to its thread.

## The loop

1. **Interview.** Extract a complete, unambiguous spec, including test scope.
   Ask focused questions one at a time until there are zero gaps.
2. **Assign.** One line, every field present, each choice with its reason — the
   rubric row that fired, the family rule, `(policy)`, `(user: "…")`,
   `(clamped)`, degradations spelled out:
   `Assign: implementer=fable (hard correctness: money + concurrency) ·
   critic=sol (cross-family, default OpenAI) · second critic=gemini (high
   stakes; third family) · reviewer=none (no --review; recommend --review=cross:
   touches payments) · effort critique=medium build=medium (policy) · rounds=2
   · tests=covering · sandbox=workspace-write (pre-flight passed) · cascade=off
   · families=claude,openai,google · policy=route.policy.yml (deny: haiku)`.
3. **Plan.** Draft `.route/PLAN.md`.
4. **Critique — always, not gated by `--review`.** The PLAN (never code) goes to
   every required critic with `.route/critique-schema.json`. Revise and resend
   up to `--rounds`. **The plan is approved only when every required critic
   returns `approve` with empty `blocking_findings` and `major_findings` for the
   current revision** — that can happen before the cap. At the cap without it:
   stop, no build, hand the disagreement to the user. `--plan-only` ends here:
   checkpoint `stage: report`, hand the plan over.
5. **Build** — or cascade (`docs/cascade.md`: plan approved, clean tree,
   `base_sha` recorded, gate ≤ 2 rounds; after an accept, re-check every
   remaining critic and reviewer against the drafter's family). One writer at a
   time.
6. **Your diff read — always,** even with review off: boundaries respected,
   nothing unplanned, no obvious bug. Then **review per `--review`**: `full` =
   your read for correctness, edge cases and security plus the cross-family
   reviewer with a contract (`.route/review-schema.json`: spec, plan,
   acceptance criteria, diff — `docs/commands.md`); `self` = your read; `cross`
   = reviewer, then your spot-check. For a wide diff you may add an Opus
   subagent read — in addition to the cross reviewer, and only when Opus did
   not build it.
   **Visual check — not gated by `--review`:** user-facing layout changes are
   approved on screenshots, never on green tests alone. Desktop and ~390 px,
   both themes when the app has them, saved under `.route/evidence/`; read
   them yourself before approving.
7. **Fix loop.** Findings and red tests go back to the builder (resume by id),
   at most 3 rounds, then checkpoint and hand the diagnosis to the user. Test
   failures are the builder's to fix even when review is off. **Bounded fixes
   are yours:** a few lines, no design change, nothing in permissions, money or
   data integrity (those go back to the builder). After your fix, re-run the
   affected tests, refresh screenshots when UI changed, and when review ran,
   have the reviewer (or your own read under `--review=self`) look at the
   patched part again. The report says who fixed what.
8. **Approve and commit.** A worker's green run is evidence, not a verdict —
   run the tests yourself first (scope: "Test scope" above).
9. **Report.** Spec, who did what (requested models named), review mode, test
   scope and status, sandbox rung, families and policy, the cost table
   (`docs/ledger.md`), what was skipped or degraded. A task queue from
   `--setup` continues with the next task.

Caps: critique ≤ `--rounds`, gate ≤ 2, fix loop ≤ 3. At a cap: stop, checkpoint
with a diagnosis, hand the decision over — never a silent extra round, never a
silent fallback to another worker.

## Time and the watchdog

- The Bash tool caps foreground at 600 s and silently cuts a longer `timeout`.
  Foreground only for what ends in seconds (`git`, `codex doctor`, `codex
  sandbox -- …`, `agy models`, the `/skills` probe).
- **Never yield with a live worker and no harness task for it.** A worker found
  without one gets `until ! kill -0 <PID>; do sleep 20; done` armed in the
  background first.
- Sample progress every 5 min with `Monitor` or a background `sleep 300`, never
  by ending the turn (`docs/commands.md` says what counts as progress). Codex
  reconnect `"type":"error"` events are not failures.
- A hang is silence for `max(15 min, 2 × T_slow)`. **Never applied to a test
  run**; never `timeout` or `pkill` tests — orphaned parallel workers hold a
  metadata lock that freezes every later run.
- Read the files before killing; kill by PID or harness task, never `pkill -f`.
- **Safety stops are not retryable** (`misalignment_policy_violation`, explicit
  safety block): stop dispatch, keep checkpoint and `.jsonl`, inspect the tree,
  report. An ordinary out-of-scope decline gets one rewritten brief, then a
  reroute. A transient API failure → resume by id.
- **Quota exhaustion is routine:** `git status` + `git diff` first, keep or reset
  remnants deliberately, checkpoint, stop. On resume re-probe limits — never
  reason from a remembered one.
- **Swapping a worker mid-run** (limits, the user's call, a crashed host):
  checkpoint, give the new worker the brief plus the current `git diff`,
  re-check critics, reviewer and gate against the new builder's family, mark
  the swap in the ledger and the report.
- **The skill changed mid-run:** re-read this file and the `docs/` the current
  stage uses before the next step; the checkpoint stays valid.

## Checkpoint and resume

Write `.route/CHECKPOINT.md` (`docs/checkpoint.md`) after every stage
transition, at every worker launch (with its session id), and on every limit,
API or safety event. Rewritten in place. It holds the resolved configuration
(flags, roster, efforts, `test_scope`) and, after `--setup` with separate runs,
the task queue (`tasks`, `current_task`).

`--resume` (or a new task while a checkpoint with `stage ≠ report` exists → ask
resume or discard): read → re-probe runtime and limits → `git status` against
`tree_state` (mismatch → dirty-exit first) → continue at `stage` with
`next_action`, resuming only threads whose last turn was `SUCCESS`. At
`stage: report` with queued tasks left, `--resume` starts the next one.

## Ledger

One line per model call in `.route/ledger.jsonl`, appended right after reading
its output (fields and sources: `docs/ledger.md`). Missing numbers are `null`,
never estimated. `codex exec resume` usage is cumulative per thread: keep the
raw counters in `raw_cumulative` and record the delta against the previous raw
counters of that thread. Token totals are never presented as subscription
cost.

## Rules

- Argue out the plan before any code; nothing is built without every required
  critic's approval.
- Unknown flags and illegal combinations halt with a question.
- Pin the model on every external call; close stdin; resume by id.
- Validate every verdict before acting; `denied_actions` means "blocked",
  never "done".
- Nothing is committed before your diff read, the gate and your own test run.
- Workers and test runs are harness background tasks; never yield with one
  untracked.
- Announce assignments with the rule that fired; report who did what and what
  it cost. The user is directing a team, not watching a black box.
- Approval is yours alone.
