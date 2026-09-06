# Checkpoint

`.route/CHECKPOINT.md` is what makes a route run resumable after a quota wall, an API failure, a
safety stop or a closed laptop. It is rewritten in place — never appended — after every stage
transition, at every worker launch (with the session id, the one write that saves resumability),
at every worker finish, after each gate or fix round, and on any blocker.

## Front matter

```yaml
run_id: 2026-09-06T10-31-route-a1b2
written_at: 2026-09-06T11:02:14+02:00
task: "soft-delete flow for invoices"
flags: "--model=sol --review=cross --cascade"
branch: feature/invoices-soft-delete
base_sha: 3704e20…
stage: build            # interview | assign | plan | critique | draft | gate | build | review | fix | report
round: 1
roster:
  implementer: {slot: sol, model_requested: gpt-5.6-sol, effort: medium}
  drafter:     {slot: luna, model_requested: gpt-5.6-luna, effort: low}
  critic:      {slot: gemini, model_requested: gemini-3.8-flash-medium, effort: medium}
  reviewer:    {slot: fable, model_requested: fable, effort: ""}
sessions:
  codex: [01a075d7-9c4e-7580-b41d-0ce7c87bf4b9]
  agy:   [b538f8bb-9a0e-4978-bc3d-988ccef298eb]
artifacts:
  plan: .route/PLAN.md
  briefs: [.route/brief-critique.md, .route/brief-build.md]
  outputs: [.route/critique.json, .route/build.jsonl, .route/build.txt]
tree_state: dirty-worker   # clean | dirty-worker | dirty-draft | stashed:route-draft-<run_id>
tests: {cmd: "vendor/bin/sail artisan test --compact", last_result: "1104/1104", duration_s: 412, T_slow_s: 417}
runtime: {codex_version: 0.153.4, agy_version: 1.1.27, doctor_ok: true, probed_at: 2026-09-06T10:31:00+02:00}
agy_log: {path: ~/.gemini/antigravity-cli/log/cli-20260906_103105.log, baseline_bytes: 4120}
blockers: []               # [{kind: quota|api|safety-pause|question, who, at, detail}]
open_findings: []
next_action: "sample build.jsonl; on turn.completed run tests, then review stage"
ledger: .route/ledger.jsonl
```

## Body

- **Done** — stages and commits completed, with hashes.
- **In flight** — which worker, which session, launched when, last progress sample.
- **To do on resume** — the imperative list the director follows.
- **Diagnosis** — the current red state, if any: which test, why, what was tried.

## Resume procedure

1. Read the checkpoint. If `stage` is `report`, there is nothing to resume.
2. **Re-probe**: `codex doctor --summary`, `agy --version`, the limits — overwrite `runtime`. Never
   reason from a remembered limit.
3. `git status` against `tree_state`. A mismatch means someone (a worker, the user) touched the tree
   since — dirty-exit protocol before anything else. A `stashed:` state is applied or dropped only
   after confirming `branch` is checked out and `git rev-parse HEAD == base_sha`.
4. Continue at `stage` with `next_action`, resuming Codex threads by UUID and agy conversations by
   id — only those whose last turn was `SUCCESS`; anything else starts a new session with the
   current `git diff` embedded.
