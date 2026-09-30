# Launch commands

Read this before the first external launch of a run. `SKILL.md` keeps the invariants; this file
keeps the exact lines.

## Launch rules

- Every model turn through an external CLI (`codex exec`, an `agy -p` that reaches a model) and
  every test run goes through the Bash tool's background mode (`run_in_background: true`), stdout and
  stderr redirected under `.route/`. Short checks without a model turn (`codex login status`,
  `codex doctor`, `codex sandbox -- …`, `agy models`, `agy --version`, the `/skills` probe) run in
  the foreground, and so does the effective-config check (below). Claude workers go through the `Agent` tool instead (section "Claude subagents"). **Never detach in the
  shell** — no trailing `&`, `nohup`, `setsid`, `disown`: the tool returns at once, no harness task
  exists, and the completion notification that wakes the director never arrives. A process that must
  outlive the shell is awaited by the same background command
  (`until ! kill -0 "$PID"; do sleep 20; done`).
- **Codex config mode.** Every Codex line, exec and resume, carries `--ignore-user-config`
  (**isolated**, the default): `$CODEX_HOME/config.toml` is not read, so its MCP servers, plugins,
  default effort, `personality`, `service_tier` and above all an `approvals_reviewer = "auto_review"`
  never reach a worker; auth still comes from `CODEX_HOME`. Stage 0 switches to **pinned** when that
  file sets a connection or auth key (`docs/workers.md`, "Config modes"): the lines then carry the
  3.2 pins instead (section "Pinned mode"). Never both — an MCP override of a server the ignored file
  defined fails at startup (`docs/troubleshooting.md`).
- **Rung 3** (`docs/sandbox-and-preflight.md`): every line of that worker, resumes included, adds
  `-c approvals_reviewer="auto_review"` — on 0.159.2 this alone turns `approval_policy` from `never`
  into `on-request` with automatic review (verified on exec and resume). `--approve-for-me` is the
  flag form; it implies `workspace-write` and cannot be combined with `-s`.
- Briefs are files; the prompt is `"$(cat file)"`; **stdin is closed with `< /dev/null`** — an open
  stdin (a heredoc in the same command) is the only confirmed cause of a "hung" Codex.
- The lines below are **templates** shown with the stage defaults. On every launch and resume
  substitute the effective model and per-stage effort after policy resolution (Gemini: the slug
  suffix and `--effort` together).

## Codex

```bash
# critique — read-only, context embedded in the brief
codex exec -m gpt-6.1-sol -s read-only --color never --json --ignore-user-config -c model_reasoning_effort=medium \
  --output-schema .route/critique-schema.json -o .route/critique.json \
  "$(cat .route/brief-critique.md)" < /dev/null > .route/critique.jsonl 2> .route/critique.stderr.log
#   high stakes: -m gpt-6-astra -c model_reasoning_effort=high

# build — workspace-write
codex exec -m gpt-6.1-sol -s workspace-write --color never --json --ignore-user-config -c model_reasoning_effort=medium \
  -o .route/build.txt "$(cat .route/brief-build.md)" < /dev/null > .route/build.jsonl 2> .route/build.stderr.log

# builder resume — NO -s / --color / -C; sandbox via -c; ALWAYS the thread UUID from
# thread.started.thread_id in the run's .jsonl. --last is banned: it picks the newest
# session in the cwd, whatever started it. Before it, record the rollout offset (Reading results).
codex exec resume <THREAD_UUID> --ignore-user-config --json -m gpt-6.1-sol -c 'sandbox_mode="workspace-write"' \
  -c model_reasoning_effort=medium -o .route/fix1.txt \
  "$(cat .route/brief-fix1.md)" < /dev/null > .route/fix1.jsonl 2> .route/fix1.stderr.log
# a critic, gate or reviewer keeps its role on resume: read-only and its schema
codex exec resume <THREAD_UUID> --ignore-user-config --json -m gpt-6.1-sol -c 'sandbox_mode="read-only"' \
  -c model_reasoning_effort=medium \
  --output-schema .route/critique-schema.json -o .route/critique-r2.json \
  "$(cat .route/brief-critique-r2.md)" < /dev/null > .route/critique-r2.jsonl 2> .route/critique-r2.stderr.log

# visual fix round for a Codex builder — screenshots as attachments. Use --image=<png>[,<png>…]
# (or --image <png> before the other flags): a bare "-i shot.png" right before the prompt takes
# the prompt as a second file ("No prompt provided via stdin", exit 1).
codex exec resume <THREAD_UUID> --ignore-user-config --json -m gpt-6.1-sol -c 'sandbox_mode="workspace-write"' \
  -c model_reasoning_effort=medium -o .route/fix2.txt \
  --image=.route/evidence/01-desktop-light.png,.route/evidence/03-mobile-light.png \
  "$(cat .route/brief-fix2.md)" < /dev/null > .route/fix2.jsonl 2> .route/fix2.stderr.log

# cross review — read-only, with a contract: the brief carries the spec, PLAN.md, the acceptance
# criteria, the diff (embedded under 40 KB, else the path; untracked files included) and the verdict
# rule "approve iff no blocking or major finding and every plan item is done; minors never change
# the verdict";
# effort = the `review` stage (default high)
codex exec -m gpt-6.1-sol -s read-only --color never --json --ignore-user-config -c model_reasoning_effort=high \
  --output-schema .route/review-schema.json -o .route/review.json \
  "$(cat .route/brief-review.md)" < /dev/null > .route/review.jsonl 2> .route/review.stderr.log
# `codex exec review --uncommitted` has its own built-in contract and sees no plan: a manual extra,
# never the cross reviewer.

# model probe (stage 0 step 5) — one per slug when .route/model-probes.json has no fresh success
codex exec -m gpt-6.1-sol -s read-only --color never --json --ignore-user-config -c model_reasoning_effort=low \
  -o .route/probe-gpt-6.1-sol.txt "Reply with exactly: OK" \
  < /dev/null > .route/probe-gpt-6.1-sol.jsonl 2> .route/probe-gpt-6.1-sol.stderr.log
#   success = exit 0 and the -o file says OK; then record in .route/model-probes.json:
#   {"gpt-6.1-sol": {"ok": true, "probed_at": "<ISO time>", "codex_version": "<codex --version>",
#                    "identity": "<identity from $CODEX_HOME/models_cache.json>", "config_mode": "isolated"}}

# cascade drafter
codex exec -m gpt-6-luna -s workspace-write --color never --json --ignore-user-config -c model_reasoning_effort=medium \
  -o .route/draft.txt "$(cat .route/brief-draft.md)" < /dev/null > .route/draft.jsonl 2> .route/draft.stderr.log
```

### Pinned mode

When stage 0 chose `pinned`, make one substitution on every line above: replace
`--ignore-user-config` with `-c approvals_reviewer="user"`, and on the read-only lines (critique,
gate, review, probe and their resumes) also add `-c mcp_servers.<name>.enabled=false` for each
`[mcp_servers.<name>]` in `$CODEX_HOME/config.toml` (here `perplexity` and `playwright`). Writers
keep the file's MCP servers, and every other key of the file reaches every worker; stage 0 reports
the ones that change the rung or the cost. For example:

```bash
codex exec -m gpt-6.1-sol -s read-only --color never --json -c approvals_reviewer="user" -c model_reasoning_effort=medium \
  -c mcp_servers.perplexity.enabled=false -c mcp_servers.playwright.enabled=false \
  --output-schema .route/critique-schema.json -o .route/critique.json \
  "$(cat .route/brief-critique.md)" < /dev/null > .route/critique.jsonl 2> .route/critique.stderr.log
```

### Parallel Codex workers

Only for a split the plan makes parallel (SKILL.md, "Roster"). The director creates each worktree
before launch, from `HEAD`; the worker runs in it with `-C`. Artifacts use absolute paths, because
the resume below runs from the worktree directory. Codex's own `--worktree` is not used: it cannot
be combined with `--ignore-user-config`.

```bash
REPO="$(git rev-parse --show-toplevel)"
git worktree add --detach "$REPO/.route/worktrees/part-a" HEAD        # one per part; record HEAD as baseline

codex exec -C "$REPO/.route/worktrees/part-a" -m gpt-6.1-sol -s workspace-write --color never --json \
  --ignore-user-config -c model_reasoning_effort=medium -o "$REPO/.route/part-a.txt" \
  "$(cat "$REPO/.route/brief-part-a.md")" < /dev/null > "$REPO/.route/part-a.jsonl" 2> "$REPO/.route/part-a.stderr.log"

# resume: codex exec resume has no -C and runs in the shell's cwd, so start it from the worktree
cd "$REPO/.route/worktrees/part-a" && codex exec resume <THREAD_UUID> --ignore-user-config --json -m gpt-6.1-sol \
  -c 'sandbox_mode="workspace-write"' -c model_reasoning_effort=medium -o "$REPO/.route/part-a-fix1.txt" \
  "$(cat "$REPO/.route/brief-part-a-fix1.md")" < /dev/null > "$REPO/.route/part-a-fix1.jsonl" 2> "$REPO/.route/part-a-fix1.stderr.log"

# at the report, after the last integration
git worktree remove --force "$REPO/.route/worktrees/part-a" && git worktree prune
```

The brief's edit boundaries are relative to the worktree root. Integration, the `route-integrated`
commit whose SHA becomes the session's `baseline`, and the `HEAD == baseline` check before the next
delta are in SKILL.md, "Roster". Verified on 0.159.2 with two concurrent writers: each wrote only
in its own worktree, the checkout stayed clean, a resume started from the checkout ran in the
checkout (so never do that), one started from the worktree ran in the worktree.

## agy

```bash
# --add-dir "$REPO" on every call or the worker sees no project skills/rules.
# Stubs may start with "/<skill>" to force-load a binding skill.
REPO="$(git rev-parse --show-toplevel)"

# critique — plan mode, read-only, no shell. The WHOLE brief goes into -p (no pointer stub: the
# brief forbids reading files), opening with the "no tools" paragraph; the verdict is JSON inside
# payload.response. Same shape for a gate (gate-schema) or a review (review-schema). A brief over
# ~100 KB is split into parts, each a full brief for its slice, one call per part; the parts combine
# as SKILL.md "Briefs" says (all approve, findings are the union; gates and reviews also merge
# plan coverage: done is the union, missing = plan items no part reports done).
agy --model gemini-3.8-flash-medium --mode plan --effort medium --add-dir "$REPO" --output-format json \
  --json-schema .route/critique-schema.json --print-timeout 30m \
  -p "$(cat .route/brief-critique.md)" < /dev/null > .route/agy-critique.json 2> .route/agy-critique.stderr.log

# build — accept-edits, EDITS ONLY: one denied command cancels the whole run
agy --model gemini-3.8-flash-medium --mode accept-edits --effort medium --add-dir "$REPO" --output-format json \
  --print-timeout 60m -p "$(cat .route/stub-build.md)" < /dev/null > .route/agy-build.json 2> .route/agy-build.stderr.log

# cascade drafter
agy --model gemini-3.8-flash-medium --mode accept-edits --effort medium --add-dir "$REPO" --output-format json \
  --print-timeout 30m -p "$(cat .route/stub-draft.md)" < /dev/null > .route/agy-draft.json 2> .route/agy-draft.stderr.log

# builder resume — by id, never -c/--continue; only after a SUCCESS turn
agy --conversation <CONVERSATION_ID> --model gemini-3.8-flash-medium --mode accept-edits --effort medium \
  --add-dir "$REPO" --output-format json --print-timeout 60m \
  -p "$(cat .route/stub-fix1.md)" < /dev/null > .route/agy-fix1.json 2> .route/agy-fix1.stderr.log

# critic, gate or reviewer continuation — keeps plan mode, its schema and the whole brief in -p
agy --conversation <CONVERSATION_ID> --model gemini-3.8-flash-medium --mode plan --effort medium \
  --add-dir "$REPO" --output-format json --json-schema .route/critique-schema.json --print-timeout 30m \
  -p "$(cat .route/brief-critique-r2.md)" < /dev/null > .route/agy-critique-r2.json 2> .route/agy-critique-r2.stderr.log
```

**Stubs — builders and drafters only.** Their `-p` prompt is a pointer — *"Read `.route/brief-build.md` in the workspace and
execute it exactly. Your final answer is only what it asks for."* — small and free of shell quoting;
the OS argv limit (~128 KB) is the hard bound. Critics, gates and reviewers get their whole brief
in `-p`: above ~100 KB, split the review into parts or give the role to another family. `--input-format stream-json` is a different mode
(events out; the envelope arrives inside the final `result` event) and is not used here.

## Claude subagents

`Agent` with the `model` override and the default `subagent_type`, the brief's path in the prompt.
`subagent_type: "fork"` inherits context but **ignores** `model`. A fix round continues the same
subagent with `SendMessage` to its id (recorded in the checkpoint's `sessions.claude`; `SendMessage`
is a deferred tool — load it with `ToolSearch` first); after a
session restart that id is gone, and a new subagent starts from the checkpoint's to-do list and the
current `git diff`.

## Reading results

Never load a whole `.jsonl` into context — a long build log is tens of thousands of tokens. Take
only what you need:

```bash
grep -m1 '"thread.started"' .route/build.jsonl                  # thread_id for resume
grep '"turn.completed"' .route/build.jsonl | tail -1             # usage
grep -E '"turn.failed"' .route/build.jsonl | tail -3             # failure, if any
```

- **Codex:** the `-o` file is the answer. `thread_id` and `usage` come from the `.jsonl`. A
  `"type":"error"` event about a reconnect or a 503 is Codex retrying its stream, not a failure; a
  failure is `turn.failed`, or an exit without `turn.completed`.
- **agy:** one JSON envelope written whole at exit. Check every call: `status == "SUCCESS"`,
  `response != ""`, `(denied_actions ?? []) == []` (the key is absent when nothing was denied).
  `CANCELED` = a denied tool action; `ERROR` + `"timeout waiting for response"` = `--print-timeout`
  expired. Any non-`SUCCESS` status invalidates the `conversation_id` — follow up in a **new**
  conversation carrying the current `git diff`.
- **Schema calls:** strip Markdown fences, drop agy's injected `toolAction`/`toolSummary`, parse,
  validate against the schema in `.route/`, then act. Never act on a verdict you did not validate.

### Effective-config check

After every Codex launch (once `thread.started` is in the `.jsonl`) and every resume, confirm what
the worker actually runs with. Codex writes a rollout file per thread,
`$CODEX_HOME/sessions/YYYY/MM/DD/rollout-<time>-<thread_id>.jsonl`, with one `turn_context` record
per turn: `model`, `effort`, `sandbox_policy`, `approval_policy`, `approvals_reviewer` and a
`permission_profile` that lists network access and every writable root. Before a resume, record the
rollout's line count as the session's `rollout_offset` (`wc -l < "$R"`); the check reads the first
`turn_context` after it, so an earlier turn's record can never pass for the resumed one (a launch
uses 0). Run it in the foreground; it waits at most two minutes:

```bash
# Effective-config check. Set THREAD (thread.started.thread_id), OFFSET (rollout lines before this
# launch or resume; 0 for a launch) and the expected values, then run in the foreground (<= 2 min).
# Prints OK, MISMATCH <fields> or MISSING; anything but OK stops the worker.
TC=""
for i in $(seq 25); do            # 24 waits of 5 s, then one last read (the rollout outlives the process)
  R=$(find "${CODEX_HOME:-$HOME/.codex}/sessions" -name "rollout-*-$THREAD.jsonl")
  if [ "$(printf '%s' "$R" | grep -c .)" = 1 ]; then
    TC=$(tail -n +$((OFFSET + 1)) "$R" | grep -m1 '"type":"turn_context"')
  fi
  [ -n "$TC" ] || [ "$i" = 25 ] && break
  sleep 5
done
[ -z "$TC" ] && echo MISSING || printf '%s\n' "$TC" | jq -r \
  --arg model "$MODEL" --arg effort "$EFFORT" --arg sandbox "$SANDBOX" \
  --arg approval "$APPROVAL" --arg reviewer "$REVIEWER" --arg root "$ROOT" '
  .payload as $p | ($p.permission_profile // {}) as $pp
  | [ (if $p.model != $model then "model=\($p.model)" else empty end),
      (if $p.effort != $effort then "effort=\($p.effort)" else empty end),
      (if $p.sandbox_policy.type != $sandbox then "sandbox=\($p.sandbox_policy.type)" else empty end),
      (if $p.approval_policy != $approval then "approval_policy=\($p.approval_policy)" else empty end),
      (if $p.approvals_reviewer != $reviewer then "approvals_reviewer=\($p.approvals_reviewer)" else empty end),
      (if $sandbox == "danger-full-access" then
         (if $pp.type != "disabled" then "permission_profile=\($pp.type)" else empty end)
       elif $pp.type != "managed" or $pp.file_system.type != "restricted"
            or ($pp.file_system.entries | type) != "array" then
         "permission_profile=\($pp.type)/\($pp.file_system.type // "none")"
       else
         (if $pp.network != "restricted" then "network=\($pp.network)" else empty end),
         (if ($p.sandbox_policy | has("network_access")) then
            (if $p.sandbox_policy.network_access != false then "network_access=\($p.sandbox_policy.network_access)" else empty end)
          elif $sandbox != "read-only" then "network_access=missing" else empty end),
         ([$pp.file_system.entries[] | select(.access == "write")
           | if .path.type == "path" then .path.path else "special:\(.path.value.kind)" end
           | select(. != "special:slash_tmp" and . != "special:tmpdir")] as $w
          | if $sandbox == "read-only" then (if $w != [] then "writable=\($w | join(","))" else empty end)
            elif $w != [$root] then "writable=\($w | join(","))" else empty end)
       end) ]
  | if length == 0 then "OK" else "MISMATCH " + join(" ") end' || echo "MISMATCH malformed"
```

Expected values (`ROOT` = the directory the worker writes in: the checkout, or its worktree for a
parallel worker; empty for read-only):

| Role | `SANDBOX` | `APPROVAL` | `REVIEWER` | Network | Write roots |
| --- | --- | --- | --- | --- | --- |
| critic, gate, reviewer, probe | `read-only` | `never` | `user` | restricted | none |
| builder, drafter, fix — rung 1 | `workspace-write` | `never` | `user` | restricted | `ROOT` only |
| rung 3 | `workspace-write` | `on-request` | `auto_review` | restricted | `ROOT` only |
| rung 4 | `danger-full-access` | `never` | `user` | not checked (`permission_profile.type: disabled`) | not checked |

`/tmp` and `$TMPDIR` are writable specials in every sandboxed profile and are allowed; any other
writable special (such as the file-system root) is a mismatch. Pinned mode produces the same rows —
that is what the pins are for. The ledger row of the call gets the checked fields as
`effective_config`.

Verified on 0.159.2 against real rollouts — read-only, rung 1, rung 3 on exec and resume, a worktree
writer and its resumed fix, rung 4, a resume at effort `medium` after a launch at the catalog default
— and against altered copies: stale offset, wrong effort, `network_access: true`, contradictory
network fields, a missing or unrestricted file-system section, a writable root special, truncated
JSON, no record, two rollouts for one id.

## Progress sampling

Every 5 minutes, by a background `sleep 300` or a `Monitor` whose command prints one line per
sample and exits when the PID dies — never by ending the turn. The `timeout_ms` maximum differs
between Claude Code builds (10 minutes in some, 30 in others): read it from the tool's schema, set
it, and re-arm the monitor on every expiry. A sample is healthy when the PID is
alive (`kill -0`) and one of these moved:

- new events in the Codex `.jsonl` (count lines, do not read them);
- the agy run's CLI log grew — note the newest `~/.gemini/antigravity-cli/log/cli-*.log` *before*
  launching, poll until a newer one exists, record it and its size as the baseline (never the agy
  `.json`, which is written whole at exit);
- `git status` changed.

Silence is a hang only after `max(15 min, 2 × T_slow)` of it, and never for a test run. Before
killing, read the files: stderr prints `Reading additional input from stdin...` even on healthy
runs; the hang signal is that line **with no `thread.started` event** — relaunch with stdin closed.
No new file under `~/.codex/sessions/` → startup failure (competing `app-server`; `codex doctor`).
Kill by PID (`ps -eo pid,etime,cmd | grep '[c]odex exec'` → `kill <PID>`) or by the harness task.
