# Changelog

Versions before 2.0 were never published and had no commits or tags: 0.1 was a project-local
skill in one Laravel project, and 1.0–1.4 were successive edits of the author's global Claude Code
skill file. Their numbers and dates are reconstructed after the fact from the sessions in which they
were written, so treat them as a narrative, not as releases. From 2.0 on, every version is a tagged
commit in this repository.

## 3.2.0 — 2026-09-22

Prompted by the release of Claude Opus 5.5 and of GPT-6 Sol and Luna, built from the transcripts of
the route runs since 3.1.1 (2026-09-09 → 09-21) plus the requests users kept making in plain words
because no flag covered them, and slimmed down after a review of the skill by Fable 5.1 at effort
`xhigh`.

**GPT-6 Sol and Luna**
- `sol` is `gpt-6-sol` and `luna` is `gpt-6-luna` (both in the Codex CLI 0.155.1 catalog, both
  default effort `medium`; verified by a read-only probe — no official model page existed that day).
  The canonical lines, the cascade drafter and the examples use them.
- `terra` stays on GPT-5.6 Terra (there is no GPT-6 Terra) as a legacy slot for an explicit
  `--model`, and leaves the rubric; "large but not hard" is `luna` alone.
- The Astra-only `codex ≥ 0.153.1` guard is replaced by a catalog check for every OpenAI slot the run
  needs: the slug must be in `~/.codex/models_cache.json`. Version minimums go stale with every model
  drop.
- Rubric: `sol` is the pool-relief builder for ordinary feature work when the Claude pool is the
  constraint.

**Leaner SKILL.md (543 → 329 lines after the slimming; 497 after the review rounds below)**
- The frontmatter description is five lines: it sits in every session's skill index, whether route
  runs or not. Flags and roster live in the body.
- New `docs/commands.md` (EN + PL) holds the canonical launch lines, result reading and progress
  sampling; the director reads it before its first external launch. SKILL.md keeps five launch
  invariants.
- New `docs/ledger.md` (EN + PL) holds the ledger fields, token sources and report table.
- The cascade section is a pointer to `docs/cascade.md` plus the three rules the director needs
  without opening it; stage 0's policy step points at `docs/policy.md`; incident statistics moved
  out of the rules (they stay in troubleshooting and here).
- Never load a whole `.jsonl` into context — `docs/commands.md` has the three greps that replace it.

**`--setup`** — with this many switches, a questionnaire instead of remembering them. The director
reads the prompt (and a plan it carries or points at — a pasted `/plan` result, a plan file,
`.route/PLAN.md`), splits it into tasks, probes which families are eligible, then asks through
`AskUserQuestion` (at most two calls of four questions): one run or separate runs, implementer,
critic, rounds, review, test scope, mode — each with a recommended option tied to a task fact. The
answer is echoed as a reusable flag line (`docs/setup.md`, EN + PL).

**Defaults changed on Fable's advice**
- Plan critique defaults to **2 rounds** (was 3): in the recorded runs the third round mostly
  produced fallout of the second round's fixes. `--rounds` and `critique_rounds` still raise it.
- **The director's pre-commit test run is scoped**: what the builder ran plus the tests covering the
  change; the full suite only for migrations, shared base classes, config or service providers, or
  when asked. It still catches a worker's green run that disagrees with the director's.
- **Small findings are the director's to fix** — a few lines with no design change are patched
  directly instead of resuming the worker for 10–50 minutes; the report says who fixed what.
- **Cascade draft effort defaults to `medium`** (was `low`): the one recorded `low` draft failed on
  finish (one-liners, missing planned tests), not on shape.
- Not adopted: batching interview questions — the user prefers a thorough one-question-at-a-time
  interview.

**Review by GPT-6 Astra and GPT-6 Sol** — two read-only `codex exec` reviews (effort `high`) of the
changes above found six real bugs and a set of gaps; all were fixed, the minor ones included.
- *Per-family effort.* A stage's effort may be a per-family pair (`openai:` / `google:`); a single
  value above a family's range is clamped (Gemini: `high`) and marked `(clamped)`. Before, a policy
  with `high_stakes_critique: xhigh` would have halted every high-stakes run with Gemini as the
  second critic.
- *Ledger deltas.* `raw_cumulative` keeps Codex's cumulative counters; the token fields hold
  `raw[n] − raw[n−1]`. The first version subtracted the previous row's delta and turned
  100/150/180 into a total of 280.
- *Cascade and the family rule.* With `--cascade` the plan critic differs from both the implementer's
  and the drafter's family, so an accepted OpenAI draft is never judged only by an OpenAI critic
  (tightened in the second round: when that cannot be met, the cascade is refused).
- *Gate A sees new files.* The inventory adds `git ls-files --others --exclude-standard`, and
  `draft.diff` carries new files' contents.
- *Gemini reads nothing, so it gets everything.* Critics, gates and reviewers on agy receive their
  whole brief in `-p` (no pointer stub); above ~100 KB the review is split or given to another family.
- *Stakes first.* The rubric is evaluated in order starting with hard correctness, so a payment
  feature no longer matches the ordinary-feature row first.
- *Approval, not silence.* The plan is built only when every required critic returns `approve` with
  no blocking or major findings on the current revision; at the cap without it, the run stops.
- *`--tests`* (syntax settled in the second round); `--skip-tests` with `--cascade` is illegal.
- *`--setup` in two steps* (shape of the work, then options computed from it); policy values are
  shown as defaults instead of silently answering; a task queue (`tasks`, `current_task`) in the
  checkpoint, picked up by `--resume` at `stage: report`.
- *Flag matrix.* Illegal: `--reviewer` with `--review=self`, `--resume` with any other flag,
  `--setup` with `--resume` (through the previous rule). A second named critic always runs; a named
  critic or reviewer on a denied slot wins with a warning; `--reviewer=gemini` runs on agy.
- *Model availability.* `$CODEX_HOME/models_cache.json` is a candidate list, not proof; a pinned
  read-only probe is (reworked in the second round into remembered probes); "upgrade Codex" only when
  the error says the client does not know the model.
- *A thicker default gate.* The director always reads the diff before committing; the full suite
  also runs for middleware, routes, events, jobs, traits, dependency changes and uncertain reach;
  exact test commands go into the plan; a director's own fix is re-tested, UI evidence refreshed and
  the patched part re-read, and anything in permissions, money or data goes back to the builder.
- *Cross review with a contract.* The reviewer is a read-only `codex exec` with the spec, plan,
  acceptance criteria and diff, validated against the new `docs/schemas/review-schema.json`;
  `codex exec review --uncommitted` stays a manual extra.
- Minor: an orphaned table header in `docs/workers.md`; GPT-6 Sol and Luna labelled provisional and
  the cascade cost figures labelled as GPT-5.6 data; README's "High stakes gets a third" now says a
  second critic from the third vendor; SKILL.md again states that every test run goes to the
  background and that `fork` ignores `model`, rules a Claude-only run needs too.

**Second review round (Astra and GPT-6 Sol on the fixes above)** — 14 of 23 first-round findings
resolved, 9 partly; the rest, and what the fixes themselves broke:
- *Cascade family rule without an escape hatch.* The plan critic must come from a family other than
  both possible builders; with two families only, or on a high-stakes change, `--cascade` halts with
  a question instead of reporting a same-family critique afterwards.
- *`--skip-tests` means none.* Every test obligation is conditional on it; `--tests` with
  `--skip-tests`, or with two scopes, is illegal. `--tests=<scope>[,browser]` with scope
  `covering|full` expresses "full suite and browser tests".
- *Gemini transport everywhere.* Gate B and the prompt-size notes follow the rule: Gemini gets the
  whole brief in `-p`, split above ~100 KB, and a split verdict approves only when every part does.
- *Bash for CLIs and tests, `Agent` for Claude.* The first fix said "every model call through Bash",
  which contradicted the Agent rule one line below.
- *Stage 0 order.* The workspace (`.route/`, exclusion, clean tree) comes before anything that can
  call a model.
- *Remembered probes.* `.route/model-probes.json` keeps each slug's last successful probe with the
  `codex --version` and catalog `identity` it ran under; a match under 7 days old is enough,
  anything else is probed again — the account identity is now part of the check.
- *Review acceptance.* The cross review passes only with `approve`, no blocking or major finding and
  no missing plan item; review and screenshots certify the final diff, so any later edit — builder's
  or director's — goes back through them.
- *Setup order.* Grouping first, then mode and implementer as one choice of valid pairs, then the
  rest; at most three calls per run.
- *Named and defined.* The dirty-exit protocol is defined in SKILL.md; the escalation writes the
  `draft-rejected.diff` it hands over; README lists the review schema.
- *Trimmed.* The final "Rules" list, which repeated the sections and contradicted their exceptions,
  is gone; the setup mechanics live only in `docs/setup.md`; watchdog details point at
  `docs/commands.md`; the full-suite trigger is a criterion with examples; the assignment line has
  one short example.

**Third review round (Astra, GPT-6 Sol, Fable 5.1 at `xhigh`, Gemini 3.8 Flash)** — all four found
something; one Gemini finding was a false positive (a "Schemas" reference that exists in the same
file). Fixed:
- *Continuing a worker, per CLI.* Codex resumes by thread UUID after a completed turn or an API or
  quota stop (the thread holds the context) and starts a new thread only after a safety stop; agy
  continues only after a `SUCCESS` turn; a Claude subagent continues with `SendMessage` in the same
  session, anew after a restart (`sessions.claude` in the checkpoint). The old "never resume a
  non-SUCCESS thread" contradicted "transient API failure → resume by id".
- *Gate B counts major findings.* Accept needs no blocking **or major** finding; revise needs
  blocking + major ≤ 3 — matching the gate brief.
- *`DRAFT_ABORT` gets a fresh diff.* Gate A writes `.route/draft.diff` from the current tree before
  anything else, so an abort or a wall-cap stop never escalates with a missing or stale diff; the
  implementer is told when Gate B did not run.
- *Setup before probes.* Setup runs after stage 0 steps 1–4 and offers unprobed OpenAI slots marked
  as such; step 5 probes what the answers chose. Questions keep to `AskUserQuestion`'s 2–4 options
  (the tests question had five); the rest goes to "Other".
- *Default cross reviewer.* The policy `reviewer`, else the plan critic's slot, else the default
  critic — the first that is cross-family to the committed builder.
- *Two named critics on high stakes* must come from two different families.
- *`--plan-only` has a follow-up.* A later `/route` finding a `plan_only: true` checkpoint offers to
  build it: reuses `PLAN.md` and the recorded flags, interviews only the open decisions, re-critiques
  only a changed plan (`plan_sha256`).
- *Swaps re-critique when needed.* A plan critic that shares the new builder's family is replaced by
  one cross-family critique round before the new builder's first turn.
- *Foreground checks named.* Model turns and test runs go to the background; `codex doctor`,
  `agy models`, the `/skills` probe and similar checks without a model turn stay in the foreground.
- *Evidence refresh with review off* is your own read; *`test_scope`* records `covering,browser` and
  `full,browser`; *schemas* are copied from the skill's own directory, not the project's.
- *Monitor has no `persistent` option* (and expires after at most 30 minutes); *agy 1.2.8* defaults
  `--print-timeout` to no limit (route always sets it, the `/skills` probe included) and has a
  `--sandbox` flag route does not use.
- README: the cascade example no longer uses a payment change (cascade refuses high stakes); the
  rubric cell for `opus` as Fable's step-down is complete; the schemas list names all three.

**Fourth review round (same four reviewers)** — findings down to 3 (Astra), 2 (Sol), 7 minor
(Fable) and 5 (Gemini, two of them false positives: it believed `SendMessage` and `AskUserQuestion`
do not exist in Claude Code; both are in the tool list, `SendMessage` as a deferred tool). Fixed:
- *Building a `--plan-only` plan re-applies the family rule.* The approval stands only while the plan
  is unchanged and no approving critic shares a possible builder's family; an added `--cascade` or a
  changed `--model` can require one critique round by the critics the build roster needs.
- *A resumed critic stays read-only.* A Codex critic, gate or reviewer resumed after a stop keeps
  `sandbox_mode="read-only"` and its `--output-schema` (the only resume template had
  `workspace-write`).
- *The checkpoint fingerprints the tree* (`tree`: branch, HEAD, a hash of tracked changes and
  untracked files), so a user's edit to an already-dirty file after a quota stop is noticed on
  resume.
- *The resume-or-discard question also fires* at `stage: report` with queued tasks or an unbuilt
  plan-only plan, so a new task never silently overwrites them.
- *The reach probe* runs only when a Codex worker will write, with a check that ends in seconds —
  never the suite, which the foreground cap would cut and orphan.
- *Cascade details.* The drafter brief (`brief-draft.md`, `stub-draft.md` for Gemini) is written
  explicitly; Gate B runs at the critique effort; the halt condition says "implementer and drafter
  from two families and no third", not "two families only".
- *Facts.* The `Monitor` timeout maximum differs between Claude Code builds (read it from the tool
  schema); the agy `stream-json` mode does carry the envelope, inside its `result` event;
  `SendMessage` is a deferred tool.
- README: `--model=self` and the rubric's `self` row are exceptions to "the director does not write
  the implementation", alongside the bounded fix.

**Fifth review round** — Gemini: no findings; Sol: 1 minor; Astra: 2 major, 1 minor; Fable: 7 minor.
Fixed:
- *Queued plan-only tasks keep their plans.* With a `--setup` queue each run plans in
  `.route/tasks/<id>/PLAN.md`, and the queue entry records the plan, its hash, the approving critics
  and a `planned` status, so starting the next task no longer overwrites an unbuilt plan.
- *A resumed Gemini critic stays a critic* — a separate continuation template keeps `--mode plan`,
  the schema and the whole brief; the builder template is labelled as such. The Codex critic resume
  also disables the MCP servers like every other critique line.
- *Gate cap in a cascade escalates* (the planned fallback) instead of stopping; an early
  `DRAFT_ABORT` with no changes skips the stash and escalates with an empty diff.
- *High stakes defined once* (auth or permissions, money, concurrency, data integrity, a migration
  that changes or drops existing data); the guard, rubric row 1, the second-critic rule, setup and
  README point at it.
- *Builders get the test-running rules* in their brief (no `timeout`, never kill, background for
  long runs), because a Claude builder has the same 600 s foreground cap.
- *Denied models in Claude-only mode* are skipped for the next eligible Claude model, or the run
  halts with a question.
- The assignment example reports `sandbox=n/a` for a Claude builder; the checkpoint example no
  longer pairs `--cascade` with a high-stakes invoice change; README's "Three things" became
  "Several things"; the Polish checkpoint says "bieżącą gałęzią" instead of the misleading
  "wymeldowany".

**Sixth review round** — Gemini: no findings (the first attempt reached for a shell command, was
denied and returned an empty `SUCCESS`; the retry with a rewritten brief answered — the skill's own
rule, applied to its own review); Astra: 1 minor; Sol: 1 major, 1 minor; Fable: 3 minor. Fixed:
- *PLAN.md means the run's plan* — `.route/PLAN.md`, or `.route/tasks/<id>/PLAN.md` in a queue — in
  the Gate B template and the checkpoint example too.
- *`.route/` is excluded through `git rev-parse --git-path info/exclude`*, which also works in a
  linked worktree, where `.git` is a file.
- *A failed model probe halts with a question* wherever the slot came from; policy.md's
  "drop and pick an alternative" applies only to slots ruled out before any probe.
- *Split Gemini reviews can pass:* each part names the plan items its slice covers; combined
  `missing` holds only items no part reports done.
- *Parallel worktree subagents* are integrated into the checkout by the director, one at a time,
  before the diff read, tests and review.
- *A high-stakes cascade* halts with one remedy — drop the cascade — instead of also offering a
  drafter change that cannot help.

**Seventh review round** — Astra: no findings (first time); Gemini: no findings (third round running);
Sol: 1 major, 1 minor; Fable: 4 minor. Fixed:
- *Building a plan-only plan drops `--plan-only`* from the recorded flags before adding build flags.
- *Split critiques combine by verdict only* — the critique schema has no coverage fields; gates and
  reviews also merge `done`/`missing`.
- *The review verdict rule is in the review brief* ("minor findings never change the verdict"), and a
  `revise` carrying only minors counts as a pass.
- *Worktree builders do not run tests* (shared `testing` database; a fresh worktree has no `.env`,
  `vendor/`, `node_modules/`); the director tests the integrated result.
- *A swapped-in OpenAI worker gets its model probe and reach probe* before its first turn.
- *The director takes the visual-check screenshots* after the build and sends the relevant ones into
  a fix round; the builder's brief still forbids writing to `.route/`.

**Eighth review round** — Astra, Sol and Gemini: no findings; Fable: 2 minor. Fixed:
- *Worktree briefs use paths relative to the worktree root* — the checkout's absolute paths would
  send a worktree subagent's edits into the checkout; the checkpoint records each worktree path.
- README no longer says the cascade gate runs "unless `--skip-tests`" (the combination is illegal).

**Ninth review round** — Sol, Fable and Gemini: no findings; Astra: 1 minor. Fixed:
- *Worktrees live until the report:* a fix round for a worktree builder continues it in its worktree
  and the director integrates only what changed since the last integration; the worktrees are
  removed at the report, not after the first integration.
- `docs/workers.md` states the CLI versions its facts were re-checked on (Codex 0.155.1, agy 1.2.8).

**Tenth review round** — Astra and Gemini: no findings; Sol: 2 major, 1 minor; Fable: 1 major. Fixed:
- *A global `approvals_reviewer = "auto_review"` no longer climbs a rung in silence.* It was set in
  this machine's `~/.codex/config.toml`, making every write-mode Codex worker rung 3 while reports
  said rung 1. Every canonical Codex line now pins `-c approvals_reviewer="user"` (accepted values on
  0.155.1, verified: `user`, `auto_review`, `guardian_subagent`), and stage 0 reads the global config
  as well as the project's.
- *The stage-0 roster is provisional;* the assignment step re-resolves it after the interview, when
  the stakes are known, and probes any newly chosen OpenAI slot.
- *Worktree integration uses `git diff HEAD`,* so staged changes are not lost.
- *`--resume` at `stage: report` handles `planned` tasks* — offered for building, like a plan-only
  checkpoint.

**Eleventh review round** — Astra and Gemini: no findings (Gemini after one retry: its first answer
was again an empty `SUCCESS` after a denied `RunCommand`, and the rewritten brief says it cannot run
anything); Sol: 1 major, 1 minor; Fable: 1 minor. Fixed:
- *Worktree integration has a baseline:* the director stages everything in the worktree, applies
  `git diff --cached HEAD --binary` in the checkout, and commits the integrated state inside the
  worktree (a throwaway branch, never merged), so a fix round's integration takes only the new
  changes.
- *A Gemini builder writes tests but cannot run them;* the director runs them.
- *Rung 3 and the pin:* a worker deliberately at rung 3 carries `-c approvals_reviewer="auto_review"`
  on every line, resumes included (resume has no `--approve-for-me`), and reports say so.

**Fixes**
- The early end of plan critique now keys on the critique schema's real fields: a round with empty
  `blocking_findings` and `major_findings` (the first draft of this release said "all `minor`", a
  severity the critique schema does not have).
- `--plan-only` is also illegal with `--reviewer` (which implies `--review`).
- Review effort is a stage like the others (`effort.review`, default `high`) instead of a value
  hardcoded in one command line.
- An extra Opus read of a wide diff is an addition to the cross reviewer and never reviews an Opus
  build.

**Opus 5.5**
- The `opus` slot is Opus 5.5 — cheaper than Opus 5 ($4 / $20 against $5 / $25 per MTok) and, by
  Anthropic's account, stronger on multistep coding in a real codebase, on code review and on
  reading screenshots. It becomes the default Claude builder for ordinary feature work, the slot for
  user-facing UI work, the step-down from Fable when Fable's cost is the problem, and the default
  Claude critic of an OpenAI build (Fable stays for the hardest correctness).
- Briefs for Opus 5.5 and Fable 5.1 state goal, boundaries and proof of done instead of
  step-by-step instructions; frontend briefs name concrete patterns to avoid.
- `docs/workers.md`: a Claude slot table, the per-model-id effort setting caveat, the agy catalog
  re-read on 1.2.7 (still no Claude model newer than 4.6 there).

**Flags users asked for in words**
- `--critic=<slot>[,<slot>]` and `--reviewer=<slot>` — the roles users kept naming ("krytykuj
  astrą", "review gemini"); still bound by the cross-family rule.
- `--rounds=<n>` and the policy key `critique_rounds` — the three-round cap was lifted by hand in
  two runs (one went six Astra rounds) and lowered in another.
- `--plan-only` — interview, plan, critique, stop with the open decisions; users had been asking
  for it as "zbuduj tylko plan".
- Plain-language roster requests are mapped to these flags and echoed in the assignment line.

**Loop**
- Test scope is settled in the interview, and since the review below it is a flag (`--tests`);
  default: the tests covering the change, no new browser tests unless asked (runs had been stopped
  over 40-minute suites and browser tests nobody wanted).
- Visual check for user-facing layout changes, independent of `--review`: desktop and ~390 px, both
  themes, screenshots under `.route/evidence/` (an Opus build had passed 126 tests with broken modal
  layouts).
- Worker swaps mid-run (limits, a crashed host) follow a written procedure; a skill updated mid-run
  is re-read together with its `docs/`.
- Gemini critic and gate briefs open with the "no tools" paragraph (moved from troubleshooting into
  the brief rules after the empty-`SUCCESS` case recurred on 09-21).

**Troubleshooting (EN + PL)** — agy `SUCCESS` + empty response + `denied_actions:[mcp]` (written
on 09-09, released now); Codex reconnect `"type":"error"` events are not failures; `codex exec
resume` usage is cumulative per thread (the ledger records deltas); a parallel session's tests
dropping tables in the shared `testing` database; the Luna draft's one-liners and missing planned
tests (the drafter appendix now asks for repository formatting and every planned test).

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
