# Cascade

`--cascade` is route's version of the *cascade* pattern from GitHub's Project HydraFusion: an
efficient model drafts, a quality gate decides whether to accept or escalate to a stronger model,
and extra model calls are spent only when they are likely to improve the result. HydraFusion reports
36–67 % lower cost than a frontier model at roughly equal quality on coding benchmarks; the gate's
internals are undisclosed, so route's gate is its own — mechanical where it can be, cross-family
where it must be.

Opt-in only. Without the flag route behaves as before.

## When it pays

- The plan is settled and mostly mechanical, but not so trivial that `sonnet` would obviously do.
- The pool you would otherwise spend (Claude, or Sol at `medium`) is the constraint.
- A rejected draft costs little: the draft runs at effort `medium` with a 25-minute cap, and the gate's
  mechanical half (tests) is free.

It is refused on high-stakes changes — cascade is for mechanical work, and the rubric routes high
stakes to Fable or Astra — and it is illegal with `--skip-tests`, where the gate would lose its
mechanical half.

## Drafters

| Value | Model | Use when |
| --- | --- | --- |
| `luna` (default) | GPT-6 Luna via Codex, effort `medium` | the ChatGPT pool is open |
| `gemini` | Gemini 3.8 Flash Medium via agy | the ChatGPT pool is walled; edits-only, director runs tests |
| `haiku` | Haiku subagent | both external pools are walled; also the Claude-only default for a bare `--cascade` |

Illegal: `--cascade` with `--model=luna|haiku`, a drafter equal to the implementer, or
`--skip-tests` (Gate A would have no mechanical half).

**Critic family.** Either the implementer or the drafter may end up the builder, and no plan critic
may share the committed builder's family. So every plan critic comes from a family other than both
(Opus implements, Luna drafts → `gemini` critiques the plan; Claude only: a Claude model different
from both). When the eligible families cannot give that (implementer and drafter from two
families and no third one eligible), or the change is high-stakes, `--cascade` halts with a question
at the assignment step: drop the cascade or change the drafter.

## Protocol

1. **Preconditions.** Plan approved by every required critic; clean tree; `base_sha` in the
   checkpoint.
2. **Draft.** Write `.route/brief-draft.md` — `.route/brief-build.md` plus the appendix below — and,
   for a Gemini drafter, `.route/stub-draft.md` pointing at it. The drafter runs at the effective
   draft effort (default `medium` since 3.2: the one recorded `low` draft failed on finish — one-liners, missing tests — not on shape). Background, watchdog as usual, wall cap 25 minutes for the draft only.
3. **Gate A — mechanical, no model.** The change inventory is `git diff --name-only <base_sha>`
   **plus** `git ls-files --others --exclude-standard` (new files are untracked and invisible to the
   diff); all of it must stay inside the plan's boundaries. **First, whatever comes next, write
   `.route/draft.diff` fresh from the current tree** — the tracked diff plus each new file as
   `git diff --no-index /dev/null <file>` — so every later step, escalation included, sees this
   draft and never an earlier run's. A `DRAFT_ABORT` line or a draft stopped at its wall cap then goes
   straight to escalation; otherwise the director runs the tests (never killed) and writes a test
   summary.
4. **Gate B — critic from a different eligible family than the drafter** (Claude only: a different
   Claude model than the drafter, marked degraded), at the critique effort. Self-contained brief with
   the plan, the diff and the test summary; read-only review; `.route/gate-schema.json` enforced. Transport follows the
   brief rules in SKILL.md: Codex and Claude get the diff embedded under 40 KB, otherwise its path;
   a Gemini gate reads nothing, so everything goes into `-p`, split into parts above ~100 KB (every
   part must accept).
5. **Decision, mechanical.** Accept iff `verdict = accept` ∧ Gate A green ∧ no `blocking` or `major`
   finding ∧ `plan_coverage.missing = []`. Revise iff `verdict = revise` ∧ blocking + major ≤ 3 ∧ this
   is round 1. Otherwise escalate. **Two gate rounds maximum.**
6. **Accept.** The tree stays; the director spot-checks; the drafter is the builder for later fix
   rounds; every remaining critic/reviewer assignment is re-checked against the actual builder's
   family (in degraded mode, its model).
7. **Escalate** — also after the second gate round without an accept; that is the planned fallback,
   not a stop. Drafter session finished or killed. Copy `.route/draft.diff` to
   `.route/draft-rejected.diff` (`.route/` is untouched by the stash). A draft that left no changes
   (an early `DRAFT_ABORT`) needs no stash: `tree_state` stays `clean` and the implementer gets the
   empty diff. Otherwise
   `git stash push -u -m route-draft-<run_id>` returns the tree to `base_sha`; the stash name goes into the checkpoint's `tree_state`. The
   implementer receives the original brief plus the gate findings (or "Gate B did not run" after an
   abort or a wall-cap stop) and `draft-rejected.diff`
   labelled "rejected draft: reuse what is right, trust nothing". The stash is dropped at report;
   `--resume` touches it only after confirming the recorded branch and `HEAD == base_sha`.
8. **Report.** `cascade: accepted at round N` or `escalated after N`, with draft + gate cost next to
   the escalation cost from the ledger.

## Drafter appendix (verbatim)

> You are the drafter. If a section of the plan needs judgment you lack, stop and end your answer
> with `DRAFT_ABORT: <reason>`. Provide complete file contents or full functions — never
> placeholders, ellipsis comments (`// ...`) or omitted existing logic. If the context is too large,
> stop with `DRAFT_ABORT: context_limit`. Keep the repository's formatting: one statement per
> line, no packing code into long one-liners. Write every test the plan lists — a missing planned
> test is a gate finding. Do not run tests (the director will). Do not commit.

Gemini drafters additionally get the edits-only sentence from the main brief block: any command
execution aborts the headless run.

## Gate B brief (template)

```
<task>
Review the draft below against the plan. You are the gate: decide accept / revise / escalate.
</task>
<plan>…contents of .route/PLAN.md…</plan>
<boundaries>…files/dirs the plan allows…</boundaries>
<draft_diff>…contents of .route/draft.diff (or: read .route/draft.diff)…</draft_diff>
<tests>…the director's test summary: command, pass/fail counts, failures verbatim…</tests>
<rules>
- accept only if the diff covers every plan item, stays inside the boundaries, and the tests pass
- revise for ≤ 3 concrete, blocking-or-major fixes the same drafter can make
- escalate when the draft misunderstands the plan, needs design judgment, or is incomplete beyond
  three fixes; say why in escalate_reason
- findings cite file and line (line 0 when unknown); no nulls anywhere
</rules>
Answer only with JSON matching the schema.
```

## Verdict shape

```json
{"verdict":"accept|revise|escalate","confidence":0.0,"summary":"",
 "findings":[{"severity":"blocking|major|minor","file":"","line":0,"issue":"","fix":""}],
 "plan_coverage":{"done":[],"missing":[]},"tests_assessment":"adequate|thin|missing",
 "escalate_reason":"","assumptions":[]}
```

The schema file (`docs/schemas/gate-schema.json`) is accepted verbatim by both `codex exec
--output-schema` and `agy --json-schema` because it declares no nullable field.

## What the real runs say about cost

These figures come from GPT-5.6 workers and a draft at effort `low`; GPT-6 Sol and Luna at the 3.2
defaults are not yet measured — the ledger will tell. From the ledger-shaped data in past sessions: a Sol critique costs 4–10 minutes; a Sol build 13–35;
a review fix-loop 40–52. A Luna draft at a low effort plus a mechanical gate and one Flash critique
is well under the cheapest of those. The cascade earns its keep when at least one draft in three is
accepted; the report's cascade line is how you find out whether that holds for your project.
