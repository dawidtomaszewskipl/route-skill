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
and approve — approval is yours alone. You do not write the implementation
unless the roster says you are the right worker, the user picked
`--model=self`, or it is a bounded fix in the fix loop. You do the commits.
Announce every assignment with the rule that produced it and report who did
what and what it cost: the user is directing a team, not watching a black box.

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
  stage.** `full` (default) = your read + cross-family reviewer; `self` = your
  read only; `cross` = reviewer, then your spot-check.
- `--critic=<slot>[,<slot>]` — the plan critic; a second named slot is a second
  critic that runs whatever the stakes. `--reviewer=<slot>` — the cross
  reviewer; alone it implies `--review=full`. Both beat policy (a denied slot
  runs with a warning), never the cross-family rule: a named critic or reviewer
  from the builder's family halts with a question, and so do two named critics
  from one family on a high-stakes change.
- `--rounds=<n>` — plan-critique cap, 1–8 (default 2; policy `critique_rounds`).
- `--tests=<scope>[,browser]` — `covering` (default: the tests covering the
  change) or `full` (the full suite before the commit), optionally with
  `browser` (browser tests too); `--tests=browser` means `covering,browser`.
- `--skip-tests` — no test runs at all (section "Test scope").
- `--setup` — configure the run by questions first (section "Setup").
- `--plan-only` — interview, plan, critique, then stop: hand over
  `.route/PLAN.md`, the unresolved findings and the decisions left to the user.
  No build, no commit. `--model` and `--tests` are recorded for the later build
  (section "Checkpoint and resume").
- `--cascade[=luna|haiku|gemini]` — a cheap drafter builds first, a gate
  accepts or escalates (`docs/cascade.md`). Default drafter `luna`.
- `--resume` — continue the run recorded in `.route/CHECKPOINT.md`, with the
  configuration recorded there.

**Illegal combinations:** `--plan-only` with `--cascade`, `--review` or
`--reviewer`; `--reviewer` with `--review=self`; `--tests` with two scopes or
with `--skip-tests`; `--cascade` with `--model=luna|haiku`, with drafter ==
implementer, or with `--skip-tests`; `--resume` with any other flag — to change
the configuration, discard the checkpoint and start again.

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

Configuration by questions instead of flags. **Read `docs/setup.md` before
asking** — it has the reading of the input, the question order and the
recommendation rules. The contract:

- Runs after stage 0 steps 1–4 (families and policy, no model calls) and before
  the interview; setup settles the roster, the interview still settles the spec.
  Step 5 then probes the OpenAI slots the answers chose; a failed probe asks
  that role again.
- Flags and the user's own words are answers and are not asked again; policy
  values are shown as defaults, not treated as answers.
- Ends with one reusable flag line per run —
  `/route --model=opus --critic=astra,gemini --rounds=2 --review=cross
  --tests=covering <task>` — then the assignment line. Separate runs go into
  the checkpoint's task queue.

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
cascade draft `medium`; the cascade's Gate B runs at the critique effort. A
value may be per family (`openai:` / `google:`); a
single value above a family's range is clamped to its maximum (Gemini: `high`)
and marked `(clamped)`. Always pass effort explicitly — catalog defaults differ
per model. Claude subagents take no effort on the call; the model is the dial.

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
blind spots, so **no plan critic and no cross reviewer shares the family of the
builder whose code is committed**:

- Claude implements → critic `sol` (default), `astra` for high stakes, or
  `gemini`.
- OpenAI implements → critic a Claude subagent (`opus` by default, `fable` for
  the hardest correctness when its budget is there) or `gemini`. Astra never
  critiques Sol/Luna/Terra.
- `gemini` implements → critic OpenAI (`sol` by default) or a Claude
  subagent; Google never critiques its own build.
- **Cross reviewer** (`--review=full|cross`): the policy `reviewer`, else the
  plan critic's slot, else the default critic above — whichever is first
  cross-family to the builder whose code is committed.
- High stakes (schema/data loss, auth, money, concurrency) → a second critic
  from the third family.
- **With `--cascade` either the implementer or the drafter may end up the
  builder,** so every plan critic comes from a family other than both (Opus
  implements, Luna drafts → `gemini`). When the eligible families cannot give
  that (implementer and drafter from two families and no third one eligible),
  or the change is high-stakes (cascade is for mechanical work; the rubric
  sends high stakes elsewhere), `--cascade` halts with a question: drop the
  cascade or change the drafter.

Roles resolve among the families stage 0 found **eligible** (available, not
switched off by policy). With fewer than three, the high-stakes second critic
is skipped and the report says so. Claude only (`families=claude (degraded:
same-family critique)`): critic and reviewer are a Claude model different from
the implementer and, under cascade, from the drafter (Fable for a Sonnet or
Opus build, Opus for a Fable build); the cascade gate is a different model
than the drafter; a bare `--cascade` defaults to the `haiku` drafter.

`--review=self` is always your own read. **Family is decided by the model, not
by the CLI** — agy's catalog also hosts Claude models and Codex falls back to
`$CODEX_HOME/config.toml` — so **pin `--model`/`-m` on every external call**
and report the requested model.

## Stage 0 — validated routing

1. Parse flags; reject unknown names, unknown values, illegal combinations.
2. Workspace: `REPO="$(git rev-parse --show-toplevel)"`; `mkdir -p .route`; add
   `.route/` to `.git/info/exclude` (never `.gitignore`); copy this skill's own
   `docs/schemas/*.json` (next to this SKILL.md, not the project's) into
   `.route/`. Clean tree required; warn about leftover `route-draft-*` stashes.
3. Detect families without model calls. Claude: always. OpenAI: `command -v
   codex`, `codex login status`, and `codex doctor --summary` **run where the
   worker will run** (a doctor failure there means unavailable there, not
   signed out). Google: `command -v agy`, `agy models` listing
   `gemini-3.8-flash-high`, `agy --version` ≥ 1.1.27.
4. Load and merge policy (`docs/policy.md`), resolve every role among eligible
   families, validate the effective roster as policy.md describes, and apply
   the cascade family rule.
5. **OpenAI models the roster uses** (under `--setup`, after its answers). A
   slot is usable when
   `.route/model-probes.json` (kept across runs) holds a successful probe of
   its slug younger than 7 days, made under the same `codex --version` and the
   same catalog `identity` as `$CODEX_HOME/models_cache.json` now shows
   (default `~/.codex`). Otherwise run one pinned read-only probe
   (`docs/commands.md`; a background task, a ledger row) and record it.
   Failure → unavailable; halt with an upgrade instruction only when the error
   says the client does not know the model. Never substitute another model.
6. Skills: `agy --add-dir "$REPO" --output-format json --print-timeout 2m -p
   "/skills" < /dev/null` (no model turn; agy ≥ 1.2 waits forever without a
   timeout). Zero workspace skills with a populated `.agents/skills/` =
   trust/mount failure. A skill only in `.claude/skills` is invisible to both
   external CLIs — warn.
7. Read the project's `.codex/config.toml`: a `default_permissions` profile or a
   container-backed MCP server silently cripples a Codex worker — warn.
8. Reach probe — only when a Codex slot will write (build, fix, draft):
   `codex sandbox -c 'sandbox_mode="workspace-write"' -- <cheap check>`, where
   the check needs the same resources as the tests but ends in seconds
   (`vendor/bin/sail ps`, a database ping, one small test file) — never the
   suite. Judge it by effect outside the sandbox
   (`docs/sandbox-and-preflight.md`).
9. Record `T_slow` (slowest single test or build, seconds; unknown → 900).

Steps 5–8 run only for the eligible families they concern; report skipped ones.

## Launching workers

`docs/commands.md` has the exact lines. The invariants, for every run —
Claude-only runs included:

- **Every model turn through an external CLI (`codex exec`, an `agy -p` that
  reaches a model) and every test run** go through the Bash tool's
  `run_in_background: true`, output under `.route/`. Never `&`, `nohup`,
  `setsid`, `disown` — the completion notification that wakes you exists only
  for harness tasks. Short checks without a model turn (`codex login status`,
  `codex doctor`, `codex sandbox -- …`, `agy models`, `agy --version`, the
  `/skills` probe) run in the foreground.
- **Claude workers** go through the `Agent` tool with an explicit `model` and
  the default `subagent_type`; `subagent_type: "fork"` **ignores** `model`.
- Briefs are files; stdin closed with `< /dev/null`; model and effort pinned.
- **Continuing a worker** (fix rounds, after a stop): Codex — `codex exec
  resume <thread UUID>` after a completed turn or a transient API or quota
  stop, since the thread holds the context; a new thread only after a safety
  stop or when the `.jsonl` has no `thread.started`. A resumed critic, gate or
  reviewer keeps `sandbox_mode="read-only"` and its `--output-schema`
  (`docs/commands.md`). agy — `--conversation <id>` only after a `SUCCESS`
  turn; any other status starts a new conversation carrying the current
  `git diff`. Claude — `SendMessage` (a deferred tool: load it with
  `ToolSearch` first) to the subagent's id within the session; after a session
  restart, a new subagent from the checkpoint's to-do list. Never `--last` or
  `--continue`.
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
judge against quoted inline. Above ~100 KB (argv limit ~128 KB) split it into
parts, each a full brief for its slice; the combined verdict approves only when
every part approves, and the findings are the union — or give the role to
another family.

**Test scope.** Settle it in the interview when `--tests` is not given, and
record the exact test commands in `PLAN.md`. The builder writes and runs the
tests covering the change, browser tests only with `browser`. Before the commit
you re-run what the builder ran plus the covering tests, and the **full suite**
with `--tests=full` or when the change has shared reach — code many features
depend on (migrations, base classes and traits, middleware, routes, events,
jobs, config, providers, dependencies) — or when you cannot bound its reach.
**`--skip-tests` removes every test obligation in this skill**: the builder
writes and runs none, you run none, and the report says `tests: skipped
(flag)`. Parallel sessions share the `testing` database: before blaming the
code for a senseless red, check for another live run.

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
2. **Assign.** One line naming implementer, critic(s), reviewer, drafter, the
   efforts in use, rounds, tests, sandbox rung, families and policy — each
   with its reason (rubric row, family rule, `(policy)`, `(user: "…")`,
   `(clamped)`, a degradation). Example:
   `Assign: implementer=opus (UI) · critic=sol (cross-family default) ·
   reviewer=none (no --review) · effort critique=high (policy) · rounds=2 ·
   tests=covering,browser (user) · sandbox=workspace-write · cascade=off ·
   families=claude,openai,google · policy=route.policy.yml`.
3. **Plan.** Draft `.route/PLAN.md`, test commands included.
4. **Critique — always, not gated by `--review`.** The PLAN (never code) goes to
   every required critic with `.route/critique-schema.json`. Revise and resend
   up to `--rounds`. **The plan is approved only when every required critic
   returns `approve` with empty `blocking_findings` and `major_findings` for the
   current revision** — that can happen before the cap. At the cap without it:
   stop, no build, hand the disagreement to the user. `--plan-only` ends here:
   checkpoint `stage: report` with `plan_only: true` and the approved plan's
   `plan_sha256`, hand the plan over.
5. **Build** — or cascade (`docs/cascade.md`). One writer at a time.
6. **Your diff read — always,** even with review off: boundaries respected
   (untracked files included), nothing unplanned, no obvious bug. Then
   **review per `--review`**: `full` = your read for correctness, edge cases and
   security plus the cross-family reviewer with a contract (spec, plan,
   acceptance criteria, diff; `.route/review-schema.json`); `self` = your read;
   `cross` = reviewer, then your spot-check. **The cross review passes only with
   `verdict: approve`, no blocking or major finding and
   `plan_coverage.missing` empty**; anything else goes to the fix loop. Minor
   findings: fix them or list them in the report — say which. An extra Opus
   read of a wide diff may be added, never in place of the cross reviewer and
   never of an Opus build.
   **Visual check — not gated by `--review`:** user-facing layout changes are
   approved on screenshots, never on green tests alone. Desktop and ~390 px,
   both themes when the app has them, saved under `.route/evidence/`; read
   them yourself.
7. **Fix loop.** Findings and red tests go back to the builder (continued as in
   "Launching workers"), at most 3 rounds, then checkpoint and hand the diagnosis to the user.
   **Bounded fixes are yours:** a few lines, no design change, nothing in
   permissions, money or data integrity (those go back to the builder).
   **Review and screenshots certify the final diff:** after any edit that
   follows them — a builder's round or yours — the changed part goes back to
   the reviewer (your own read under `--review=self` or with review off), the
   tests covering it run
   again, and the screenshots it touches are retaken. The report says who
   fixed what.
8. **Approve and commit** after your diff read, the passed gates and — unless
   `--skip-tests` — your own test run. A worker's green run is evidence, not a
   verdict.
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
  background first. Sample progress every 5 min with `Monitor` or a background
  `sleep 300`, never by ending the turn (`docs/commands.md`).
- A hang is silence for `max(15 min, 2 × T_slow)`, and **never applies to a test
  run**: never `timeout` or `pkill` tests — orphaned parallel workers hold a
  metadata lock that freezes every later run. Before killing a worker read its
  files (`docs/commands.md`); kill by PID or harness task, never `pkill -f`.
- **Safety stops are not retryable** (`misalignment_policy_violation`, explicit
  safety block): stop dispatch, keep checkpoint and `.jsonl`, inspect the tree,
  report. An ordinary out-of-scope decline gets one rewritten brief, then a
  reroute. A transient API failure → continue the worker as in "Launching
  workers".
- **Dirty-exit protocol** — whenever a worker stops without a clean finish
  (quota, crash, kill) or the tree does not match the checkpoint: `git status`,
  `git diff` and the untracked files first; keep or reset each change
  deliberately, never wholesale by reflex; record the decision and
  `tree_state` in the checkpoint. **Quota exhaustion is routine:** dirty-exit,
  checkpoint, stop; on resume re-probe limits — never reason from a remembered
  one.
- **Swapping a worker mid-run** (limits, the user's call, a crashed host):
  checkpoint, give the new worker the brief plus the current `git diff`,
  re-check critics, reviewer and gate against the new builder's family, mark
  the swap in the ledger and the report. A plan critic that now shares the
  builder's family is replaced: one critique round of the current plan by an
  eligible cross-family critic before the new builder's first turn; with none
  eligible, halt with a question.
- **The skill changed mid-run:** re-read this file and the `docs/` the current
  stage uses before the next step; the checkpoint stays valid.

## Checkpoint and resume

Write `.route/CHECKPOINT.md` (`docs/checkpoint.md`) after every stage
transition, at every worker launch (with its session id), and on every limit,
API or safety event. Rewritten in place. It holds the resolved configuration
(flags, roster, efforts, `test_scope`) and, after `--setup` with separate runs,
the task queue (`tasks`, `current_task`).

`--resume` (or a new task while a checkpoint exists with `stage ≠ report`, or
with `stage: report` and queued tasks or `plan_only: true` → ask which to do;
never overwrite it silently): read → re-probe runtime and limits → compare the
tree with the checkpoint's `tree` record — branch, HEAD, the fingerprint of
tracked changes and untracked files (`docs/checkpoint.md`); any difference →
dirty-exit protocol first → continue at `stage` with
`next_action`, continuing workers as in "Launching workers". At
`stage: report` with queued tasks left, `--resume` starts the next one.

**Building a `--plan-only` plan.** A new `/route` that finds a checkpoint with
`plan_only: true` at `stage: report` asks whether to build that plan. Building
reuses `.route/PLAN.md` and the recorded flags (build flags such as `--review`,
`--reviewer`, `--cascade` may be added now), interviews only the open
decisions the plan-only report listed, and re-applies the cross-family rule to
the build roster. The approval stands only while both hold: `PLAN.md` is
unchanged (`plan_sha256` in the checkpoint) and no approving critic shares the
family of a possible builder — a changed `--model` or an added `--cascade` can
break the second. Otherwise one critique round of the current plan by the
critics the build roster requires; with none eligible, halt with a question.
Stage 0 never overwrites an approved `PLAN.md`.

## Ledger

One line per model call in `.route/ledger.jsonl`, appended right after reading
its output (fields and sources: `docs/ledger.md`). Missing numbers are `null`,
never estimated. `codex exec resume` usage is cumulative per thread: keep the
raw counters in `raw_cumulative` and record the delta against the previous raw
counters of that thread. Token totals are never presented as subscription
cost.
