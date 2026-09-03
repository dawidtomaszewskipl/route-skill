# Workers and CLI mechanics

Everything here was checked against **Codex CLI 0.147.0** and **Antigravity CLI
1.1.22**. Both rosters and both flag sets move; re-check with `codex exec --help`,
`agy --help` and `agy models` rather than trusting a table that has aged.

## Family is decided by the model, not by the CLI

This is the one mistake that quietly voids the whole design. The Antigravity
catalog is not Gemini-only:

```
$ agy models
gemini-3.8-flash-high     Gemini 3.8 Flash (High)
gemini-3.8-flash-medium   Gemini 3.8 Flash (Medium)
gemini-3.8-flash-low      Gemini 3.8 Flash (Low)
gemini-3.1-pro-high       Gemini 3.1 Pro (High)
claude-sonnet-4-6         Claude Sonnet 4.6 (Thinking)
claude-opus-4-6-thinking  Claude Opus 4.6 (Thinking)
gpt-oss-120b-medium       GPT-OSS 120B (Medium)
```

An `agy` call with no `--model` runs whatever the account default is. If that
default is a Claude model, a run that reports "Google critiqued the Claude plan"
actually had Claude critique Claude — the cross-family guarantee is gone and
nothing in the output says so. Codex behaves the same way, taking its model from
`~/.codex/config.toml` when `-m` is absent.

**Pass `--model` / `-m` on every external call. Record the requested model in the
report, and treat "which model actually ran" as unverified unless you confirmed
it** — vendors substitute models at quota limits.

## OpenAI — `codex exec`

```bash
# read-only critique
codex exec -m gpt-5.6-sol -s read-only --color never \
  -o out/critique.txt "$(cat brief.md)"

# build
codex exec -m gpt-5.6-sol -s workspace-write --json --color never \
  -o out/build.txt -c model_reasoning_effort=medium "$(cat brief.md)"
```

Flags worth knowing:

| Flag | Why it matters |
| --- | --- |
| `-o, --output-last-message <file>` | The final answer, verbatim. Read this, never the transcript tail. |
| `--json` | JSONL event stream — the only honest progress signal on a long run. |
| `--output-schema <file>` | Enforces a JSON Schema on the final answer. Turns a critique into `{verdict, blocking_findings[]}` you can branch on. |
| `-s <policy>` | `read-only`, `workspace-write`, `danger-full-access`. |
| `--approve-for-me` | Escalation requests get auto-reviewed under workspace-write — a genuine middle rung. |
| `-C, --cd <dir>` / `--add-dir <dir>` | Working root, and extra writable roots. |
| `--profile <name>` | Layers `$CODEX_HOME/<name>.config.toml` over the base config — a clean way to keep a route-specific profile out of your global one. |
| `--ephemeral` | Do not persist the session. Note this also removes your ability to resume it. |
| `--skip-git-repo-check` | Needed outside a git repo. |

**Models** (`gpt-5.6-sol` is the frontier tier at time of writing):

| Slug | Shape |
| --- | --- |
| `gpt-5.6-sol` | Frontier agentic coding |
| `gpt-5.6-terra` | Balanced everyday |
| `gpt-5.6-luna` | Fast and cheap |
| `gpt-5.4-mini` | Small, simple tasks |
| `gpt-5.3-codex-spark` | Ultra-fast mechanical edits |

**Effort** is `-c model_reasoning_effort=<level>`, accepting
`low | medium | high | xhigh | max | ultra`. The account default can be as low as
`low`, so set it deliberately: `medium` for ordinary work, `high` and above only
for genuinely hard problems, `low` for mechanical edits.

**Review** has its own subcommand, which carries a review contract you do not
have to write:

```bash
codex exec review --uncommitted            # staged, unstaged, untracked
codex exec review --base main              # against a branch
codex exec review --commit <sha>           # one commit
```

**Resuming** after an interruption: `codex exec resume --last "<follow-up>"`.
Sessions live in `~/.codex/sessions/`; `codex fork` branches one, `codex apply`
applies the last produced diff to your tree.

**Health**: `codex doctor` (add `--json`) reports auth mode, provider
reachability, version drift and whether a background `app-server` is running.
Run it when a worker will not start.

## Google — `agy`

```bash
# read-only critique
agy --model gemini-3.8-flash-high --mode plan \
  --output-format json --print-timeout 30m -p "$(cat brief.md)"

# build
agy --model gemini-3.8-flash-high --mode accept-edits \
  --output-format json --print-timeout 60m -p "$(cat brief.md)"
```

| Flag | Why it matters |
| --- | --- |
| `--mode plan` | A real read-only planning mode. Use it for critics instead of asking in prose not to write. |
| `--mode accept-edits` | Auto-approves edits, keeps other prompts. The narrow build setting. |
| `--dangerously-skip-permissions` | Approves everything. Only for a worker you have deliberately handed the checkout. |
| `--print-timeout` | **Defaults to 5 minutes.** Any real build via `-p` is cut off unless you raise it. |
| `--output-format json` | `{conversation_id, status, response, duration_seconds, usage}`. |
| `--json-schema` | Schema (inline or path) enforced on the final result. |
| `--effort low\|medium\|high` | Session effort. The model slugs embed the same choice; keep them consistent. |
| `--add-dir` | Extra workspace directories. |
| `--agent` | Run a named custom agent. |
| `--sandbox` | Terminal restrictions on. |

A successful JSON result looks like:

```json
{"conversation_id":"e320b239-…","status":"SUCCESS","response":"OK\n",
 "duration_seconds":2.07,"num_turns":1,
 "usage":{"input_tokens":14704,"output_tokens":1,"total_tokens":14705}}
```

**Resume by ID, not by recency.** Keep `conversation_id` and resume that exact
thread with `agy --conversation <id> -p "<follow-up>"`. `-c` / `--continue` means
"the most recent conversation", which becomes a race the moment more than one run
exists.

**Put the prompt flag last.** A valueless prompt flag has historically swallowed
the following flag as its prompt — `agy --print --sandbox 'do the task'` ran with
the prompt `--sandbox` and the sandbox off. Order arguments so
`-p "$(cat brief.md)"` is final.

**Version floor.** Print-mode exit codes were unreliable in older builds: `-p`
could exit 0 with an empty response, and benign tool errors were reported as
fatal. Both were fixed in the 1.1.18–1.1.20 range. Check `agy --version` before
you rely on an exit code, and check the payload's `status` as well as the code.

## Claude — subagents

Use the `Agent` tool with an explicit `model` override and the default
`subagent_type`. Two things to remember:

- `subagent_type: "fork"` inherits your context but **ignores** `model`. If you
  need a specific model, do not fork.
- Claude subagents have no effort dial. The model choice *is* the dial: Fable for
  hard correctness, Opus for wide diffs and ordinary feature work, Sonnet for
  mechanical builds from a settled plan, Haiku only for bulk edits with no
  judgment in them.
- Parallel write-mode subagents need `isolation: "worktree"`. Two writers in one
  checkout collide on files and on `.git/index.lock`.

## Briefs

Write the brief to a file and pass `"$(cat brief.md)"`. Hand-interpolated quotes,
backticks and `$()` inside a prompt string are the most common way a handoff
breaks before the model ever sees it.

External workers start cold. A brief that works carries:

- absolute paths, not "the usual place";
- explicit change boundaries — what it may touch and what it must not;
- a pointer to the project's convention files;
- what "done" looks like, including which command proves it;
- the output contract, if you intend to parse the answer.

Keep it block-structured rather than prose. Both vendors respond better to a
short tagged contract (task / boundaries / verification / output) than to a long
paragraph.
