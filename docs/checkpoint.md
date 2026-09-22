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
flags: "--model=sol --review=cross --cascade --rounds=2 --tests=covering"
test_scope: covering    # covering | covering,browser | full | full,browser | none
plan_only: false        # true after a --plan-only run; plan_sha256 is then the approved plan's hash
plan_sha256: ""
tasks:                  # only after --setup with separate runs
  - {id: 1, text: "soft-delete flow for invoices", flags: "--model=sol --review=cross --cascade --rounds=2 --tests=covering", status: in_progress}
  - {id: 2, text: "restore action in the invoice list", flags: "--model=opus --tests=browser", status: queued}
current_task: 1
branch: feature/invoices-soft-delete
base_sha: 3704e20…
stage: build            # interview | assign | plan | critique | draft | gate | build | review | fix | report
round: 1
roster:
  implementer: {slot: sol, model_requested: gpt-6-sol, effort: medium}
  drafter:     {slot: luna, model_requested: gpt-6-luna, effort: medium}
  critic:      {slot: gemini, model_requested: gemini-3.8-flash-medium, effort: medium}
  second_critic: {slot: "", model_requested: "", effort: ""}
  reviewer:    {slot: fable, model_requested: fable, effort: ""}
sessions:
  codex: [01a075d7-9c4e-7580-b41d-0ce7c87bf4b9]
  agy:   [b538f8bb-9a0e-4978-bc3d-988ccef298eb]
  claude: []             # subagent ids, continued with SendMessage within the session
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

1. Read the checkpoint. If `stage` is `report` and `tasks` has a `queued` entry, start that task as
   a new run with its recorded flags. If `stage` is `report` otherwise, there is nothing to resume (a `--plan-only` run
   ends there too; building its plan is a new run that starts from `.route/PLAN.md`).
2. **Re-probe**: `codex doctor --summary`, `agy --version`, the limits — overwrite `runtime`. Never
   reason from a remembered limit.
3. `git status` against `tree_state`. A mismatch means someone (a worker, the user) touched the tree
   since — the dirty-exit protocol (SKILL.md, "Time and the watchdog") before anything else. A `stashed:` state is applied or dropped only
   after confirming `branch` is checked out and `git rev-parse HEAD == base_sha`.
4. Continue at `stage` with `next_action`, continuing each worker as SKILL.md "Launching workers"
   says: Codex by thread UUID (also after an API or quota stop), agy by id only after a `SUCCESS`
   turn, Claude subagents with `SendMessage` in the same session or anew after a restart.
5. A checkpoint with `plan_only: true` at `stage: report` is not resumed but built: SKILL.md,
   "Building a `--plan-only` plan".
