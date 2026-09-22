---
name: route
description: >-
  Multi-model build loop. The session model acts as director: it interviews,
  plans, has the plan adversarially critiqued by another model family, hands
  implementation to a selected worker, gates the result, and approves.
  Implementer selectable with
  --model=sonnet|opus|fable|haiku|astra|sol|terra|luna|gemini|self; without it
  the director picks one and announces the choice. --cascade[=luna|haiku|gemini]
  drafts with a cheap model and escalates only when the gate rejects. Post-build
  review is opt-in via --review[=self|cross|full]; --critic= and --reviewer=
  name those roles; --rounds=N caps plan critique; --plan-only stops after the
  critiqued plan; tests are mandatory unless --skip-tests; --resume continues
  from .route/CHECKPOINT.md. Workers: GPT-6 Astra and GPT-5.6 Sol/Terra/Luna via
  codex exec (OpenAI), Gemini 3.8 Flash via agy (Google), Claude subagents
  (Opus 5.5, Fable 5.1, Sonnet, Haiku). Trigger ONLY when the user types /route, says
  "route this", "run the route loop", or explicitly asks for the multi-model
  loop. Do NOT use for ordinary single-model coding, planning, refactors, or
  chat.
---

# Route: director + selectable workers

You are the director. You interview, plan, decide who does what, gate the result
and approve. You do not write the implementation yourself unless the roster says
you are the right worker for it, or the user picked `--model=self`. You do the
commits — external workers usually cannot.

Supporting material lives next to this file: `docs/workers.md` (CLI flag
tables, catalogs), `docs/sandbox-and-preflight.md`, `docs/cascade.md`,
`docs/troubleshooting.md`, `docs/schemas/*.json`. Read them when a section
below points at them, not up front.

## Flags

Look for these anywhere in the arguments and strip them from the task text.
**Unknown flag names, unknown values and illegal combinations all fail loudly**
— ask the user; never keep an unrecognised switch as task text, never fall
back silently to `self`, to no review, or to a different worker.

- `--model=<worker>` — the implementer (table below).
- `--review[=<mode>]` — post-build review. **Absent = no review stage.**
  `full` (default) = your own diff read + cross-family reviewer; `self` = your
  diff read only; `cross` = reviewer only, you read its findings and spot-check.
- `--skip-tests` — drops the tests-are-mandatory rule; otherwise the builder
  must write and pass the project's tests even when review is off.
- `--cascade[=luna|haiku|gemini]` — a cheap drafter builds first; a gate accepts
  or escalates to the implementer (section "Cascade"). Default drafter `luna`.
  Illegal: `--cascade` with `--model=luna|haiku`, or drafter == implementer.
- `--critic=<slot>[,<slot>]` — the plan critic; a second slot is the second
  critic. `--reviewer=<slot>` — the cross reviewer; alone it implies
  `--review=full`. Both beat policy, never the cross-family rule: a named
  critic from the implementer's family halts with a question (it happened:
  "skrytykuj z astrą, astra implementuje" — the user picked Gemini).
- `--rounds=<n>` — plan-critique cap, 1–8 (default 3, policy
  `critique_rounds`). Users raised it when a plan had to be polished (6 Astra
  rounds) and lowered it to 1 for a costly critic.
- `--plan-only` — interview, plan, critique, then stop: hand over
  `.route/PLAN.md`, the critic's unresolved findings and the decisions left to
  the user. No build, no commit. Illegal with `--cascade` and `--review`;
  `--model` is allowed and recorded as the intended implementer.
- `--resume` — continue the run recorded in `.route/CHECKPOINT.md`.

**Plain words are flags too.** "Krytykuj astrą", "review gemini", "bez fable",
"astra implementuje", "więcej rund krytyki", "zbuduj tylko plan" map to
`--critic`, `--reviewer`, a per-run deny, `--model`, `--rounds`,
`--plan-only`. Echo the mapping in the assignment line (`critic=astra (user:
"krytykuj astrą")`); ask only when the words are ambiguous or break a rule.

The final report always states which review mode ran, whether tests ran, the
sandbox rung used, and which guarantees were skipped.

**High-stakes guard:** when the change touches auth/permissions, money,
destructive migrations, or concurrency, and no `--review` flag was given,
recommend one in the assignment line and let the user decide. Recommend — do
not silently add it.

## Picking the implementer

| Value | Implementer | Family | Reach it with |
| --- | --- | --- | --- |
| `sonnet` | Sonnet subagent | Claude | `Agent`, `model: "sonnet"` |
| `opus` | Opus 5.5 subagent | Claude | `Agent`, `model: "opus"` |
| `fable` | Fable 5.1 subagent | Claude | `Agent`, `model: "fable"` |
| `haiku` | Haiku subagent | Claude | `Agent`, `model: "haiku"` |
| `astra` | GPT-6 Astra — frontier | OpenAI | `codex exec -m gpt-6-astra` (codex ≥ 0.153.1) |
| `sol` | GPT-5.6 Sol — everyday | OpenAI | `codex exec -m gpt-5.6-sol` |
| `terra` | GPT-5.6 Terra — balanced | OpenAI | `codex exec -m gpt-5.6-terra` |
| `luna` | GPT-5.6 Luna — fast/cheap | OpenAI | `codex exec -m gpt-5.6-luna` |
| `gemini` | Gemini 3.8 Flash | Google | `agy --model gemini-3.8-flash-<effort>` |
| `self` | you, directly | Claude | Edit/Write |

The Google slot is Flash only: Gemini 3.1 Pro is still in `agy models` but was
removed from this roster on purpose (Flash did better). Ask `agy models` and
`~/.codex/models_cache.json` for current slugs rather than trusting this table.
The `opus` alias follows Claude Code's newest Opus (5.5 since its release); the
Agent tool cannot pin an older one, so the report names the alias and the model
the subagent's completion line shows.

**No flag?** Choose one yourself and say which in the assignment line:

- Mechanical build from a settled plan (migration, factory, resource, CRUD
  scaffolding) → `sonnet`. Framework scaffolding is convention-heavy, not truly
  mechanical — keep it on `sonnet` unless the user explicitly picks `gemini` to
  spare the Claude pool. `haiku` only for bulk edits with no judgment in them.
- Ordinary feature work that still needs thinking while writing, and
  multistep changes carried through the codebase until the tests pass →
  `opus`. Opus 5.5 is cheaper per token than Opus 5 and usually needs fewer
  tokens per finished task, so it is the default Claude builder.
- User-facing layout and UI work → `opus` (Opus 5.5 reads screenshots and
  diagrams precisely, which the visual check below relies on); `fable` for a
  large redesign when the budget allows.
- Hard correctness — concurrency, money, permissions, data integrity → `fable`,
  or `astra` when the Claude budget is the constraint. `opus` is the step-down
  when Fable's cost is the problem ("przepali za dużo tokenów") and a
  high-effort cross-family critic covers the plan.
- Large self-contained chunk → `sol` (ChatGPT pool) or `gemini` (Google pool),
  both idle pools; `terra`/`luna` when it is large but not hard.
- Change small enough that the handoff costs more than the code → `self`.

Effort defaults by stage — critique `medium` (Sol) or `high` (Astra, high
stakes); build `medium`; cascade draft `low`. Set them explicitly: catalog
defaults differ per model (Sol's is `low`). Claude subagents have no effort
knob — their dial is the model choice itself.

This rubric is the whole routing logic — a written rule the director applies
and names, not a learned router. A policy file (`route.policy.yml`,
`~/.claude/route.policy.yml`) can deny slots and set defaults: flags beat
policy, policy beats the rubric, and every policy-sourced value is marked
`(policy)` in the assignment line. The user can override in one word at the
assignment step. Take that as final.

**Splitting is allowed and often best** — scaffolding to `sonnet`, the one hard
domain action to `fable` or `astra`. But **never two write-mode workers in the
same checkout at once**: external CLIs and subagents collide on files and on
`.git/index.lock`. Parallel Claude subagents need `isolation: "worktree"`;
external workers get exclusive checkout ownership while they run.

## The cross-family rule

Three families: **Claude** (`sonnet`/`opus`/`fable`/`haiku`/`self`), **OpenAI**
(`astra`/`sol`/`terra`/`luna`), **Google** (`gemini`). Same-family models share
blind spots, so **the plan critic (and the cross reviewer, when review is on)
must come from a different family than the implementer** — resolved per run:

- Claude implements → critic is `sol` (default), `astra` for high stakes, or
  `gemini`.
- OpenAI implements → critic is a Claude subagent (Opus by default — by
  Anthropic's account Opus 5.5 catches more bugs with fewer false alarms than
  Opus 5; Fable for the hardest correctness when its budget is there) or
  `gemini`. Astra never critiques Sol/Terra/Luna — one family.
- `gemini` implements → critic is OpenAI or a Claude subagent — **Google never
  critiques its own build**.

Second critic (only for high stakes: schema/data loss, auth, money,
concurrency): pick the third family, so all three see the plan.

The rule resolves among the families stage 0 found **eligible** (available
and not switched off by policy). Claude only: plan critic and cross reviewer
are a Claude subagent of a *different model* than the implementer (Fable
critiques a Sonnet or Opus build, Opus a Fable build), the cascade gate a
different model than the *drafter*; a bare `--cascade` with no policy drafter
defaults to `haiku`, while an explicit `--cascade=<slot>` or policy drafter
keeps precedence and is validated (halt if unavailable, denied, disabled or
equal to the implementer). The assignment line and report say
`families=claude (degraded: same-family critique)`. `--review=self` is always
the director's own read, whatever the families. Fewer than three families:
the high-stakes third view is skipped and the report says so.

**Family is decided by the model, not by the CLI.** Antigravity's catalog also
hosts Claude models, so an `agy` call without `--model` can silently hand you
a same-family critic while the report says "Google"; Codex falls back to
`~/.codex/config.toml`. **Pin `--model`/`-m` on every external call.** Report
the requested model; the served one is unverified unless confirmed.

## Stage 0 — validated routing (before any model call)

1. Parse flags; reject unknown names, unknown values, illegal combinations.
2. Detect families, free of model calls. Claude: always (it is the director).
   OpenAI: `command -v codex` for installation, `codex login status` for
   authentication, and `codex doctor --summary` **run where the worker will
   run** for health — a health failure makes the worker unavailable there,
   not signed out (doctor fails inside a sandbox on a signed-in install), and
   none of this proves entitlement to a given model. Google: `command -v agy`
   and `agy models` listing `gemini-3.8-flash-high` (`agy --version` ≥ 1.1.27,
   or denied actions go unreported).
3. Load policy: `route.policy.yml` at the repo root, then
   `~/.claude/route.policy.yml` (`docs/policy.md`). Resolve **per key**, flags
   > repo policy > user policy > this skill's defaults (a higher `deny` list
   replaces a lower one; `families.<x>: on` lifts a lower-level `off` but
   cannot conjure an absent CLI). Then resolve every role among eligible
   families and non-denied slots, and only then validate the effective
   roster: an explicit `--model` overrides a denied slot or a policy-disabled
   family for the implementer, with a warning — never real unavailability
   and never the cross-family rule; an effective, non-overridden implementer
   or drafter that is denied or disabled halts; an ineligible critic or
   reviewer preference is dropped with a sentence saying why; the drafter is
   `luna|haiku|gemini`; efforts are checked against the selected worker
   (Gemini `low|medium|high`, OpenAI its catalog list, Claude none); Astra in
   *any* role — flag, policy or rubric — requires `codex --version` ≥ 0.153.1,
   else halt with an upgrade instruction, never Sol. Probes below run only for
   eligible families; skipped probes are reported.
4. `REPO="$(git rev-parse --show-toplevel)"`; `mkdir -p .route`; append
   `.route/` to `.git/info/exclude` if missing (never the project's
   `.gitignore`). Copy `docs/schemas/*.json` into `.route/`.
5. Clean tree required (commit or stash first). Warn about leftover
   `route-draft-*` entries in `git stash list`.
6. Skills: `agy --add-dir "$REPO" --output-format json -p "/skills" < /dev/null`
   (free, no model turn). Zero workspace skills with a populated
   `.agents/skills/` = trust/mount failure (`trustedWorkspaces` in agy's
   `settings.json`). A skill present only in `.claude/skills` is invisible to
   both external CLIs — warn.
7. Read the project's `.codex/config.toml`: a `default_permissions` profile or
   an MCP server that shells into containers silently cripples a Codex worker
   — warn, let the user decide.
8. Reach probe, free: `codex sandbox -c 'sandbox_mode="workspace-write"' --
   <verification command>`; judge by effect visible from outside the sandbox
   (`docs/sandbox-and-preflight.md`).
9. Record `T_slow` (slowest single test or build, seconds; unknown → 900).

## Canonical commands

All model calls and all test runs launch through the Bash tool's background
mode (`run_in_background: true`) with stdout redirected under `.route/`.
**Never detach in the shell** — no trailing `&`, `nohup`, `setsid`, `disown`:
the tool returns at once, no harness task exists, and the completion
notification that wakes the director is never produced (14 of 16 launches in
one session; 0.7–127 min idle each, ended only by the user asking). If a
process must outlive the shell, the same background command waits for it
(`until ! kill -0 "$PID"; do sleep 20; done`) so the task ends when the worker
does. Briefs are files; the prompt is `"$(cat file)"`; **stdin is always
closed with `< /dev/null`** — an open stdin (a heredoc in the same command) is
the only confirmed cause of a "hung" Codex.
These lines are **templates**: on every launch and resume substitute the
effective model and per-stage effort after policy resolution (Gemini: the
slug suffix and `--effort` together). Shown with the stage defaults.

```bash
# codex critique — read-only review with the context embedded (MCP off)
codex exec -m gpt-5.6-sol -s read-only --color never --json -c model_reasoning_effort=medium \
  -c mcp_servers.perplexity.enabled=false -c mcp_servers.playwright.enabled=false \
  --output-schema .route/critique-schema.json -o .route/critique.json \
  "$(cat .route/brief-critique.md)" < /dev/null > .route/critique.jsonl 2> .route/critique.stderr.log
#   high stakes: -m gpt-6-astra -c model_reasoning_effort=high

# codex build — workspace-write
codex exec -m gpt-5.6-sol -s workspace-write --color never --json -c model_reasoning_effort=medium \
  -o .route/build.txt "$(cat .route/brief-build.md)" < /dev/null > .route/build.jsonl 2> .route/build.stderr.log

# codex resume — NO -s / --color / -C; sandbox via -c; ALWAYS the thread UUID from
# thread.started.thread_id in the run's .jsonl. --last is banned: it picks the newest
# session in the cwd, whatever started it.
codex exec resume <THREAD_UUID> --json -m gpt-5.6-sol -c 'sandbox_mode="workspace-write"' \
  -c model_reasoning_effort=medium -o .route/fix1.txt \
  "$(cat .route/brief-fix1.md)" < /dev/null > .route/fix1.jsonl 2> .route/fix1.stderr.log

# codex review — carries its own review contract
codex exec review --uncommitted -m gpt-5.6-sol -c model_reasoning_effort=high --json \
  -o .route/review.txt < /dev/null > .route/review.jsonl 2> .route/review.stderr.log   # alt: --base <branch>

# agy — --add-dir "$REPO" on every call or the worker sees no project skills/rules.
# Effort must match the slug. Stubs may start with "/<skill>" to force-load a binding skill.
REPO="$(git rev-parse --show-toplevel)"

# agy critique — plan mode: read-only review without shell execution (headless denies every
# command, so the brief carries every fact inline); verdict = JSON inside payload.response
agy --model gemini-3.8-flash-medium --mode plan --effort medium --add-dir "$REPO" --output-format json \
  --json-schema .route/critique-schema.json --print-timeout 30m \
  -p "$(cat .route/stub-critique.md)" < /dev/null > .route/agy-critique.json 2> .route/agy-critique.stderr.log

# agy build — accept-edits, EDITS ONLY: one denied command cancels the whole run
agy --model gemini-3.8-flash-medium --mode accept-edits --effort medium --add-dir "$REPO" --output-format json \
  --print-timeout 60m -p "$(cat .route/stub-build.md)" < /dev/null > .route/agy-build.json 2> .route/agy-build.stderr.log

# agy cascade drafter
agy --model gemini-3.8-flash-low --mode accept-edits --effort low --add-dir "$REPO" --output-format json \
  --print-timeout 30m -p "$(cat .route/stub-draft.md)" < /dev/null > .route/agy-draft.json 2> .route/agy-draft.stderr.log

# agy resume — by id, never -c/--continue; only after a SUCCESS turn
agy --conversation <CONVERSATION_ID> --model gemini-3.8-flash-medium --mode accept-edits --effort medium \
  --add-dir "$REPO" --output-format json --print-timeout 60m \
  -p "$(cat .route/stub-fix1.md)" < /dev/null > .route/agy-fix1.json 2> .route/agy-fix1.stderr.log
```

Claude workers: `Agent` with the `model` override, default `subagent_type`,
brief path in the prompt. `subagent_type: "fork"` inherits context but
**ignores** `model`.

**Reading results.** Codex: the `-o` file is the answer; `thread_id` and
`usage` come from the `.jsonl`. agy: one JSON envelope written whole at exit;
check every call: `status == "SUCCESS"`, `response != ""`,
`(denied_actions ?? []) == []` (key absent when nothing was denied).
`CANCELED` = a denied tool action; `ERROR` + `"timeout waiting for response"`
= `--print-timeout` expired. Any non-`SUCCESS` status invalidates the
`conversation_id` — follow up in a **new** conversation carrying the current
`git diff`. Schema calls: strip Markdown fences, drop agy's injected
`toolAction`/`toolSummary`, parse, validate against the schema in `.route/`,
then act. Never act on a verdict you did not validate.

**agy stubs.** The prompt is a pointer — *"Read `.route/brief-build.md` in the
workspace and execute it exactly. Your final answer is only what it asks
for."* — small and free of shell quoting; the OS argv limit (~128 KB) is the
hard bound. `--input-format stream-json` is a different mode (events out, no
envelope) and is not used here.

## Briefs

Everything lives under `.route/` — never `/tmp`, whose visibility inside the
sandbox varies between runs. External workers start cold: absolute paths,
explicit change boundaries, the convention files, what "done" looks like and
which command proves it, and the **binding project skills by name** (Codex
discovers `.agents/skills` itself; agy only with `--add-dir`, and a `/skill`
prefix in the stub loads one verbatim at the cost of its full `SKILL.md`).
Critic briefs are self-contained: plan plus diff embedded under 40 KB, else the
path. Block-structured, not prose.

**Opus 5.5 and Fable 5.1 briefs:** state the goal, the boundaries and the proof
of done; drop step-by-step micromanagement written for older models — it makes
these models worse, not safer. For frontend work name the concrete patterns to
avoid (the ones the first result used) instead of "no generic look", which only
swaps one default style for another.

**Test scope is part of the spec.** Settle it in the interview when the user
has not: which suites the builder writes and runs, whether browser tests are
wanted, when the full suite runs. Default: the builder writes and runs the
tests that cover the change, **no new browser tests unless the spec asks**, and
you run the full relevant suite once before the commit. Users stopped runs over
this ("testy trwają ponad 40 min", "nie pisz też testów przeglądarkowych").
Parallel sessions on one machine share the `testing` database: another
session's run drops tables under yours — check for one before blaming the code,
and never start a second run of the same suite while one is live.

Every brief ends with: *"Do not ask questions. Where the brief is silent, decide
and record each assumption — in the `assumptions` field when a JSON schema was
given, otherwise under a `## Assumptions` heading. Do not commit. Do not write
outside the boundaries or into `.route/`."* Gemini builders add: *"Do not
execute shell or terminal commands; edit files only — any command execution
aborts this headless run."* Gemini critics and gates **open** with: *"This
brief is self-contained. Do NOT call any tools: do not read files, do not run
commands, do not call MCP, do not search the repository. Answer from the text
below alone."* — without it agy reaches for a project MCP server, headless mode
denies it, and the envelope says `SUCCESS` with an empty response (three runs,
09-09 to 09-21). Codex cannot ask mid-run; a worker that *ends* with
a question becomes a `question` blocker, answered as a new prompt to its thread.

## The loop

1. **Interview.** Extract a complete, unambiguous spec. Ask focused questions
   ONE at a time until there are zero gaps.
2. **Assign.** One line, every field present, each choice with its reason —
   the implementer's names the rubric row that fired, the critic's the family
   rule, policy-sourced values say `(policy)`, degradations are spelled out:
   `Assign: implementer=fable (hard correctness: money + concurrency) ·
   critic=sol (cross-family, default OpenAI) · second critic=gemini (high
   stakes: payments; third family) · reviewer=none (no --review; recommend
   --review=cross: touches payments) · effort critique=medium (stage default)
   build=medium (policy) · sandbox=workspace-write (pre-flight passed) ·
   cascade=off (flag absent) · families=claude,openai,google ·
   policy=route.policy.yml (deny: haiku)`. The user corrects in one word;
   take it as final.
3. **Plan.** Draft `.route/PLAN.md`.
4. **Adversarial planning — always, not gated by `--review`.** Hand the PLAN
   (never code) to the critic with `.route/critique-schema.json`; iterate on
   `revise`, at most `--rounds` (default 3); add the third-family second critic
   for high stakes. When a round's findings are all `minor`, you may stop early
   and say so. No code is written in this stage. With `--plan-only`, write the
   checkpoint with `stage: report` and hand the plan over here.
5. **Build** — or **Cascade** when `--cascade`. Stage 0 done, clean tree, then
   `.route/brief-build.md` to the implementer with tests (unless `--skip-tests`)
   and the conventions pointer. One writer at a time.
6. **Review — only per the `--review` flag.** `full`: your own diff read for
   correctness, edge cases, security, plus the cross-family reviewer
   (`codex exec review --uncommitted`, or `--base <branch>`); Opus subagent when
   the diff spans many subsystems; browser check for user-facing changes.
   `self`: your read alone. `cross`: the reviewer runs, you read and spot-check.
   **Visual check — not gated by `--review`:** a change to user-facing layout
   is approved on screenshots, never on green tests alone (an Opus build once
   passed 126 tests with broken modal layouts). Desktop and ~390 px wide, both
   themes when the app has them, saved under `.route/evidence/` so a reviewer in
   another CLI can open them; read them yourself before approving.
7. **Fix loop.** Findings and red tests go back to the builder (resume by id),
   at most 3 rounds; then stop, write the checkpoint, hand the user the
   diagnosis. Test failures are the builder's to fix even when review is off.
8. **Approve and commit.** A green run from a worker is evidence, not a
   verdict — run the tests yourself before committing.
9. **Report.** Spec, who did what (requested models named), review mode that
   ran, test status, sandbox rung, families available and policy applied, the
   cost table, what was skipped or degraded.

Write `.route/CHECKPOINT.md` after every stage transition, at every worker
launch (with its session id) and on every limit/API/safety event.

## Cascade (`--cascade`)

A cheap drafter builds; a gate accepts or escalates. Full protocol and brief
templates: `docs/cascade.md`.

1. Preconditions: plan approved, clean tree, `base_sha` in the checkpoint.
2. **Draft.** The drafter gets `.route/brief-build.md` plus: *"You are the
   drafter. If a section needs judgment you lack, stop and end with
   `DRAFT_ABORT: <reason>`. Provide complete file contents or full functions —
   never placeholders, ellipsis comments or omitted existing logic; if the
   context is too large, `DRAFT_ABORT: context_limit`."* Effective draft
   effort (default `low`), wall cap 25 min for the draft only.
3. **Gate A — mechanical, no model.** `git diff --name-only <base_sha>` within
   the plan's boundaries; you run the tests (never killed); `DRAFT_ABORT` →
   escalate. Save `.route/draft.diff` and a test summary.
4. **Gate B — critic from a different eligible family than the drafter** (Claude
   only: a different Claude model than the drafter, marked degraded),
   self-contained brief with the diff embedded, `.route/gate-schema.json`.
   Payload shape:
   `{verdict: accept|revise|escalate, confidence, summary, findings[{severity,
   file, line, issue, fix}], plan_coverage{done[], missing[]}, tests_assessment,
   escalate_reason, assumptions[]}` — no nulls anywhere (`line: 0`,
   `escalate_reason: ""` mean none), so one schema serves both CLIs.
5. **Decision is mechanical.** Accept iff `verdict=accept` ∧ Gate A green ∧ no
   `blocking` ∧ `missing=[]`. Revise iff `verdict=revise` ∧ blocking ≤ 3 ∧ round
   < 2. Else escalate. **Maximum 2 gate rounds.**
6. **Accept.** Tree stays; you spot-check; the drafter becomes the builder for
   later fix rounds and **every remaining critic/reviewer assignment is
   re-checked against the actual builder's family** (in degraded mode, its
   model).
7. **Escalate.** Drafter session finished or killed first. `git stash push -u
   -m route-draft-<run_id>` (tree back at `base_sha`; name into the
   checkpoint's `tree_state`). The implementer gets the original brief plus
   the gate findings and `draft-rejected.diff` labelled *"rejected draft:
   reuse what is right, trust nothing"*. Stash dropped at report; `--resume`
   touches it only on the recorded branch at `HEAD == base_sha`.
8. Report line: `cascade: accepted at round N | escalated after N — draft+gate
   cost vs escalation cost`.

## Bounded execution

Critique ≤ `--rounds` (default 3), gate ≤ 2, fix loop ≤ 3. At a cap you stop, write the
checkpoint with a diagnosis, and hand the decision to the user — never a
silent extra round, never a silent fallback to a different worker.

## Time and the watchdog

- **Foreground is capped at 600 s by the Bash tool**; a longer `timeout` you
  write is silently cut. Every model call and every test run goes to the
  background; foreground only for things that end in seconds (`git`, `codex
  doctor`, `codex sandbox -- …`, `agy models`, the `/skills` probe).
- **Never yield with a live worker and no harness task for it.** The only
  wake-up is the background task's completion notification; ending the turn
  to "check back in five minutes" waits for the user instead. A worker found
  running without a task (detached, or started by an earlier turn) gets
  `until ! kill -0 <PID>; do sleep 20; done` armed in the background first.
- **Progress**, sampled every 5 min by a `Monitor` loop (`persistent: true`,
  one line per sample, exits when the PID dies) or a background `sleep 300`,
  never by ending the turn: new events in the Codex `.jsonl` (a
  `"type":"error"` event about a reconnect or a 503 is Codex retrying its
  stream, not a failure — only `turn.failed`, or an exit without
  `turn.completed`, is); growth
  of the agy run's CLI log (note the newest `~/.gemini/antigravity-cli/log/
  cli-*.log` *before* launching, poll until a newer one exists, record it and
  its size as the baseline — never the agy `.json`, written whole at exit); or
  `git status` changed. And the PID is alive (`kill -0`).
- **A hang is silence with a floor.** Do not kill before `max(15 min, 2 ×
  T_slow)` of continuous silence — a healthy 417-second test once died to two
  short quiet samples.
- **Never applied to a test run**, and never `timeout`/`pkill` one: orphaned
  parallel workers keep their databases and a metadata lock, after which every
  later run blocks forever with no output, looking exactly like a frozen model.
- **Before killing, read the files.** stderr prints `Reading additional input
  from stdin...` even on healthy runs; the hang signal is that line **with no
  `thread.started` event** — relaunch with stdin closed. No new file under
  `~/.codex/sessions/` → startup failure (competing `app-server`; `codex
  doctor`). A Playwright `fill()` that never returns is a red test, not a hang.
- **Kill by PID** (`ps -eo pid,etime,cmd | grep '[c]odex exec'` → `kill <PID>`)
  or by the harness task. `pkill -f` matched the director's own shell four
  times — banned.
- **Safety stops are not retryable.** A `misalignment_policy_violation` or an
  explicit safety block → stop dispatch, keep the checkpoint and the `.jsonl`,
  inspect the tree, report — no automatic rewrite, resume or reroute. An
  ordinary out-of-scope decline → one rewritten brief, else reroute. A
  transient API failure → resume by id.
- **Quota exhaustion is routine.** Dirty-exit protocol (`git status` + `git
  diff` first; keep or reset remnants deliberately), checkpoint, stop. On
  resume **re-probe** limits — a remembered limit once mis-cast four batches.
- **Swapping a worker mid-run** (limits, "przełącz na Opusa", a crashed host):
  checkpoint first, give the new worker the brief plus the current `git diff`,
  re-check every critic, reviewer and gate against the new builder's family,
  and mark the swap in the ledger and the report. Never swap silently.
- **The skill changed mid-run** (the user says it was updated): re-read this
  file **and** the `docs/` files the current stage uses before the next step;
  the checkpoint stays valid.

## Checkpoint and resume

`.route/CHECKPOINT.md`: YAML front matter (fields in `docs/checkpoint.md` —
at minimum `stage`, `round`, `roster`, `sessions`, `base_sha`, `tree_state`,
`tests.T_slow_s`, `blockers`, `next_action`) plus a short body: Done / In
flight / To do on resume / Diagnosis of the current red state. Rewritten in
place.

`--resume` (or a new task while a checkpoint with `stage ≠ report` exists → ask
resume or discard): read → re-probe runtime and limits, overwrite `runtime` →
`git status` against `tree_state` (mismatch → dirty-exit protocol first) →
continue at `stage` with `next_action`, resuming Codex by thread UUID and agy by
`conversation_id` — only threads whose last turn was `SUCCESS`.

## Cost ledger and report

`.route/ledger.jsonl`, one line per model call, appended right after reading
its output: `{ts, run_id, stage, cli, family, model_requested, effort,
service_tier_requested, service_tier_observed, session_id, duration_s,
input_tokens, cached_input_tokens, cache_write_input_tokens, output_tokens,
reasoning_tokens, total_tokens, denied_actions, exit_code, status, outcome}`.

Sources — Codex `turn.completed.usage.{input_tokens, cached_input_tokens,
cache_write_input_tokens, output_tokens, reasoning_output_tokens}`; agy
`usage.{input_tokens, output_tokens, thinking_tokens → reasoning_tokens,
cache_read_tokens → cached_input_tokens, total_tokens}`, `duration_seconds`,
`denied_actions[].action`; the Agent tool's completion line. Missing → `null`,
never estimated. **`codex exec resume` reports usage cumulatively per thread**:
a resumed call's row is its `turn.completed.usage` minus the previous row of the
same thread, or the thread is counted twice. Codex runs on the standard tier (`service_tier` unset — a
`fast` profile exists for interactive use); the served tier is not recorded
anywhere, so `service_tier_observed` is always `null`. Token totals are never
presented as subscription cost.

Report table: `Stage | Who (model@effort) | Wall | In | Out | Result`, totals
per family, the cascade line when it ran, and the guarantees line.

## Rules

- Argue out the plan before any code — plan critique is never optional; scale
  the roster to the stakes.
- Unknown flag values and illegal combinations halt the loop with a question.
- Pin the model on every external call; close stdin; resume by id, never "last".
- Validate every schema verdict before acting on it; `denied_actions` means
  "the worker was blocked", never "done".
- Nothing is committed before the gate and your own test run pass.
- Kill by PID, never by pattern; never kill a test run.
- Workers are harness background tasks, never shell-detached; never yield
  with a live worker and no task armed for it.
- Re-probe limits and runtime on resume; never reason from a remembered limit.
- Announce assignments up front with the rubric row that fired; report who did
  what and what it cost. The user is directing a team, not watching a black box.
- Project rules and binding skills must be pointed at explicitly for fresh
  workers.
- Approval is yours alone. A green run from a worker is evidence, not a verdict.
