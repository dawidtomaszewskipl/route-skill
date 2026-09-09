# Changelog

Versions before 2.0 were never published and had no commits or tags: 0.1 was a project-local
skill in one Laravel project, and 1.0–1.4 were successive edits of the author's global Claude Code
skill file. Their numbers and dates are reconstructed after the fact from the sessions in which they
were written, so treat them as a narrative, not as releases. From 2.0 on, every version is a tagged
commit in this repository.

## 3.1.1 — 2026-09-09

Fixes the "Codex finished, nothing happens" stall. An audit of the last two weeks of transcripts
showed 34 of 36 worker launches detached in the shell (`setsid nohup … & disown`) with the Bash
tool's `run_in_background` unset: the tool returned in seconds, no harness task existed, and the
completion notification that wakes the director was never produced — idle gaps of 0.7 to 127
minutes, every one ended by the user asking. Launches that used the tool's background mode were
resumed 6–10 s after the worker exited.

- **Background means the Bash tool's background mode, nothing else**: `&`, `nohup`, `setsid` and
  `disown` are banned in worker commands; a process that must outlive the shell is awaited by the
  same background command (`until ! kill -0 "$PID"; do sleep 20; done`).
- **Never yield with a live worker and no harness task for it**; a worker found without one gets
  a wait loop armed before the director ends its turn.
- The 5-minute progress sample is a `Monitor` loop or a background `sleep 300`, never a turn end.
- New troubleshooting entry (EN + PL) with the evidence; the Codex plugin's `--background` rescue
  is noted as the same detach pattern, polled through `/codex:status`, so not a fix.

## 3.1.0 — 2026-09-07

Prompted by a community comment asking on what basis the director picks a worker and an effort —
"signatures? benchmarks? or just the first LLM guessing?" The routing was already a written rubric;
this release makes it legible, detectable and configurable, and explains it in the README.

- **README "How the director decides"** (EN + PL): the rubric table, effort-as-policy, the hard
  rules, what route is *not* (no learned router; no benchmark consulted at run time), where the only
  run-time adaptation lives (`--cascade`), what happens with fewer than three families, and the new
  policy file.
- **Assignment line with reasons**: every choice names the rubric row or rule that produced it,
  policy-sourced values are marked `(policy)`, degradations are spelled out.
- **Family availability in stage 0**: installation (`command -v`), sign-in (`codex login status`,
  `agy models`) and health (`codex doctor --summary`, run where the worker runs) checked separately;
  roles resolve among eligible families; Claude-only runs use a different Claude model for critic,
  reviewer and gate and are marked degraded; a `--model` naming an unavailable family halts.
- **Roster policy file** — `route.policy.yml` (repo) and `~/.claude/route.policy.yml` (user): `deny`,
  `implementer`, `critic`, `reviewer`, `cascade_drafter`, per-stage `effort`, `families`. Precedence
  flags > repo > user > defaults, resolved per key; validation of the *effective* roster after the
  merge (`docs/policy.md`, `docs/examples/route.policy.yml`).
- Unknown flag *names* now fail loudly, not only unknown values; the Astra version guard applies to
  Astra in any role; canonical Gemini build/resume lines show the `medium` stage default.
- SKILL.md grew to 454 lines (from 401): the availability and policy rules cost more than the plan's
  budget, and honesty won over brevity.

Validated before release by GPT-6 Astra (`gpt-6-astra`, effort high, read-only, critique schema)
in two rounds over the full diff with the community comment as the acceptance question: round one
"revise" (11 blocking, 3 major — among them `codex doctor` mistaken for a sign-in test, Gemini build
lines at `high` against an advertised `medium`, a self-contradictory example policy, precedence
rules that could both accept and halt one assignment); round two "revise" (4 blocking, 0 major — all
consistency fallout of the first fixes: the cascade gate must differ from the *drafter*, the
degraded-mode and `--skip-tests` caveats in the README, the Claude-only drafter default versus an
explicit drafter). All were applied; the 0.153.1 minimum was kept with its source linked rather
than softened.

## 3.0.0 — 2026-09-06

Rebuilt from the logs of twenty real route runs (2026-08-16 → 09-04) and from adversarial critiques
of its own plan by GPT-6 Astra (Codex mechanics) and Gemini 3.8 Flash (agy mechanics).

**Roster and flags**
- `--model=astra` — GPT-6 Astra (`gpt-6-astra`, Codex CLI ≥ 0.153.1) as the OpenAI frontier slot and
  the high-stakes critic; Sol stays the default critic and everyday worker.
- `--cascade[=luna|haiku|gemini]` — a cheap drafter builds, a mechanical gate (boundaries + the
  director's own test run) and a cross-family gate critic accept or escalate; two gate rounds max.
  The *cascade* pattern from GitHub's Project HydraFusion.
- `--resume` — continue from `.route/CHECKPOINT.md`.
- Illegal flag combinations fail loudly (`--cascade` with `--model=luna|haiku`, drafter == implementer).

**Loop**
- Stage 0 "validated routing" before any model call: flags, CLI versions, `codex doctor`, project
  `.codex/config.toml` traps, `.route/` + `.git/info/exclude`, clean tree, sandbox reach probe,
  agy `/skills` probe, `T_slow`.
- Bounded execution: critique ≤ 3 rounds, gate ≤ 2, fix loop ≤ 3 — then checkpoint and hand back.
- Fail-safe application: nothing is committed before the gate and the director's own test run pass.
- Per-stage cost ledger (`.route/ledger.jsonl`) and a cost table in the report; standard service tier
  on every Codex call (`priority` moved to a `fast` profile for interactive use).
- Checkpoint written at every stage transition and worker launch; resume re-probes limits instead of
  remembering them.

**Mechanics, all verified live on Codex 0.153.4 / agy 1.1.27**
- `< /dev/null` on every external call — an open stdin was the only confirmed cause of a "hung"
  Codex (three sessions, 19–75 minutes each).
- `codex exec resume` only by thread UUID; `--last` banned; sandbox through `-c sandbox_mode`
  because `resume` rejects `-s` and `--color`.
- All worker state in `.route/` — never `/tmp`, whose visibility inside the sandbox varies.
- agy: `--add-dir "$REPO"` on every call (without it the worker sees none of the project's
  `.agents/skills`); effort matches the model slug; a headless run is cancelled outright by the first
  denied tool action (`status:"CANCELED"`, exit 0, `denied_actions`) — Gemini builders are
  edits-only, the director runs tests; `--print-timeout` expiry is `status:"ERROR"` with exit 1;
  never resume a non-`SUCCESS` conversation.
- One JSON-schema dialect with no nullable fields, accepted by both `codex exec --output-schema` and
  `agy --json-schema` (`docs/schemas/`); agy's verdict is parsed out of `payload.response` after
  stripping fences and its injected `toolAction`/`toolSummary` keys.
- Watchdog: 600 s foreground cap of the Bash tool, background for every model call and test run,
  silence floor `max(15 min, 2 × T_slow)`, progress read from the Codex `.jsonl` or the agy CLI log
  (never the agy `.json`, written whole at exit), kill by PID, never `pkill -f`.
- Safety stops (Astra's Critical-tier layer) are not retryable — stop, keep diagnostics, report.
- Gemini 3.1 Pro removed from the roster for good; catalog still lists it.

**Docs**
- `workers.md`, `sandbox-and-preflight.md`, `troubleshooting.md` rewritten from evidence; new
  `cascade.md`, `checkpoint.md`, `schemas/`; `install.sh` copies `docs/`.

## 2.0.0 — 2026-09-03

First public release of the skill as a repository (`SKILL.md`, docs, `install.sh`, MIT).

- Roster refreshed: Fable 5.1, Opus 5, GPT-5.6 Sol/Terra/Luna as three OpenAI cost tiers, Gemini
  3.8 Flash High.
- New hard rule: family is decided by the model, not the CLI — `agy` hosts Claude models, so
  `--model` is mandatory on every call.
- Zero-cost pre-flight with `codex sandbox -- <cmd>` instead of a throwaway model run; recorded that
  a sandbox write outside the workspace fakes success (exit 0, visible inside, absent on the host)
  and that the sandbox has no network.
- Escalation ladder extended to four rungs (`workspace-write` → split the work → `--approve-for-me`
  → `danger-full-access`).
- agy: `--print-timeout` (default 5 min) called out; resume by `--conversation <id>` instead of the
  racy `-c`; `--mode plan` / `--mode accept-edits` instead of `--dangerously-skip-permissions`.
- Codex: effort scale `low…ultra`, `--output-schema`, `codex exec review --uncommitted|--base`,
  `codex doctor`.

## Pre-release history (global skill, not yet a repository)

### 1.4 — 2026-08-26
- `gemini-pro` (Gemini 3.1 Pro) removed at the user's request — "3.7 Flash does markedly better";
  the Google slot becomes Flash only.

### 1.3 — 2026-08-20
- "A hang is silence, not duration": judge a worker by whether new events arrive, never by elapsed
  time; long builds in the background with sampled progress; resume instead of restart.
- Read the answer from `-o <file>` (`--output-last-message`), not from the transcript tail.
- Startup-hang forensics: a competing `codex app-server` and, the actual culprit that day, a global
  MCP server shelling into a container runtime that was not running (removed from the global config).

### 1.2 — 2026-08-18
- Third family: Google via Antigravity CLI — `--model=gemini` (Gemini 3.7 Flash) and
  `--model=gemini-pro` (Gemini 3.1 Pro).
- `--review[=self|cross|full]`; no flag means no review stage (Sol had recommended `full` by
  default; the user chose opt-in).
- Cross-family disqualification resolved per run; Google never critiques its own build.
- Hardening agreed by the Sol + Gemini Pro critique of the plan: briefs travel as files, clean tree
  before an external build plus a dirty-exit protocol, the watchdog covers agy, unknown flag values
  fail loudly, the report names the review that actually ran and the *requested* model.
- Flash rejected as the default Laravel scaffolder ("convention-heavy, not mechanical").

### 1.1 — 2026-08-17 (same day as 1.0)
- `--model=<worker>` flag — the user wanted to juggle implementers ("Sol is fine but slow and
  hungry"); natural-language selection rejected because a task mentioning a model name would
  collide with it; "director proposes" kept as the no-flag default.
- Watchdog rule after a Codex run sat silent for an hour: foreground timeout for short critiques,
  background with progress checks for builds.
- Corrections to the first draft: `haiku` added to the frontmatter, the effort dial declared
  inapplicable to Claude subagents, `--model=` parsed anywhere in the arguments.

### 1.0 — 2026-08-17
- First global skill: the session model is the director (because `/model` cannot switch
  mid-session, "use Fable for this stage" always means a subagent with an overridden model);
  roster Fable / Opus / Sol; Sol as implementer *and* adversarial critic; plan mode as the user's
  approval gate, not a worker; pool economics (Claude subagents eat the session's pool, Sol eats an
  idle one); project-local copies deleted so the global version cannot drift.

### 0.1 — 2026-08-16
- Project-local predecessor in letsy_pl: "Route: Fable 5 runs GPT-5.6 Sol" — a fixed two-role loop
  (Fable plans, Sol builds) that the global skill replaced the next day.
