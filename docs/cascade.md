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
- A rejected draft costs little: the draft runs at effort `low` with a 25-minute cap, and the gate's
  mechanical half (tests) is free.

It does not pay for high-stakes changes (the critique already routes those to Fable or Astra), nor
with `--skip-tests`, where the gate loses its mechanical half — route warns.

## Drafters

| Value | Model | Use when |
| --- | --- | --- |
| `luna` (default) | GPT-5.6 Luna via Codex, effort `low` | the ChatGPT pool is open |
| `gemini` | Gemini 3.8 Flash Low via agy | the ChatGPT pool is walled; edits-only, director runs tests |
| `haiku` | Haiku subagent | both external pools are walled |

Illegal: `--cascade` with `--model=luna|haiku`, or a drafter equal to the implementer.

## Protocol

1. **Preconditions.** Plan approved by the critic; clean tree; `base_sha` in the checkpoint.
2. **Draft.** The drafter receives `.route/brief-build.md` plus the appendix below. Background,
   watchdog as usual, wall cap 25 minutes for the draft only.
3. **Gate A — mechanical, no model.** `git diff --name-only <base_sha>` must stay inside the plan's
   boundaries; the director runs the project's tests (never killed); a `DRAFT_ABORT` line in the
   answer goes straight to escalation. Save `.route/draft.diff` and a test summary.
4. **Gate B — critic from a different family than the drafter.** Self-contained brief with the plan,
   the diff (embedded under 40 KB, otherwise the path) and the test summary; read-only review;
   `.route/gate-schema.json` enforced.
5. **Decision, mechanical.** Accept iff `verdict = accept` ∧ Gate A green ∧ no `blocking` finding ∧
   `plan_coverage.missing = []`. Revise iff `verdict = revise` ∧ blocking ≤ 3 ∧ this is round 1.
   Otherwise escalate. **Two gate rounds maximum.**
6. **Accept.** The tree stays; the director spot-checks; the drafter is the builder for later fix
   rounds; every remaining critic/reviewer assignment is re-checked against the drafter's family.
7. **Escalate.** Drafter session finished or killed. `git stash push -u -m route-draft-<run_id>`
   returns the tree to `base_sha`; the stash name goes into the checkpoint's `tree_state`. The
   implementer receives the original brief plus the gate findings and `draft-rejected.diff`
   labelled "rejected draft: reuse what is right, trust nothing". The stash is dropped at report;
   `--resume` touches it only after confirming the recorded branch and `HEAD == base_sha`.
8. **Report.** `cascade: accepted at round N` or `escalated after N`, with draft + gate cost next to
   the escalation cost from the ledger.

## Drafter appendix (verbatim)

> You are the drafter. If a section of the plan needs judgment you lack, stop and end your answer
> with `DRAFT_ABORT: <reason>`. Provide complete file contents or full functions — never
> placeholders, ellipsis comments (`// ...`) or omitted existing logic. If the context is too large,
> stop with `DRAFT_ABORT: context_limit`. Do not run tests (the director will). Do not commit.

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

From the ledger-shaped data in past sessions: a Sol critique costs 4–10 minutes; a Sol build 13–35;
a review fix-loop 40–52. A Luna draft at effort `low` plus a mechanical gate and one Flash critique
is well under the cheapest of those. The cascade earns its keep when at least one draft in three is
accepted; the report's cascade line is how you find out whether that holds for your project.
