# route

A multi-model build loop for [Claude Code](https://claude.com/claude-code), packaged as a skill.

`/route` turns the session model into a **director**. It interviews you until the
spec has no gaps, writes a plan, hands that plan to a model **from a different
vendor** to be torn apart, hands the surviving plan to whichever worker suits the
job, and only then approves the result. You direct a team instead of watching one
model do everything.

The workers live behind three CLIs:

| Family | Reached through | Typical members |
| --- | --- | --- |
| Claude | Claude Code subagents | Fable 5.1, Opus 5, Sonnet, Haiku |
| OpenAI | `codex exec` ([Codex CLI](https://developers.openai.com/codex/cli)) | GPT-5.6 Sol / Terra / Luna |
| Google | `agy` (Antigravity CLI) | Gemini 3.8 Flash, Gemini 3.1 Pro |

## Why bother

Three things fall out of splitting the roles that do not fall out of a single
long chat:

- **Plans get attacked before code exists.** The critic is always from another
  vendor, because models from one family share blind spots. Catching a bad plan
  costs one call; catching it after the build costs the build.
- **Work lands in the right pool.** Subscription budgets are per-vendor. A large,
  well-specified chunk can go to an idle pool while the pool you are burning
  handles the parts that need judgment.
- **The escalation ladder is explicit.** Nothing silently gets full access to
  your machine because it was convenient.

## Install

```bash
git clone https://github.com/dawidtomaszewskipl/route-skill.git
cd route-skill
./install.sh            # copies SKILL.md to ~/.claude/skills/route/
```

Or by hand:

```bash
mkdir -p ~/.claude/skills/route
cp SKILL.md ~/.claude/skills/route/SKILL.md
```

Per-project instead of global: copy it to `<project>/.claude/skills/route/`.

### Requirements

Claude Code alone is enough — the loop degrades to Claude-only workers, and the
plan critique falls back within the family (weaker, but the loop still runs). For
the full roster:

- **Codex CLI** — `npm i -g @openai/codex`, then `codex login`. Verify with
  `codex doctor`.
- **Antigravity CLI** (`agy`) — install from Google Antigravity, then `agy models`
  to confirm sign-in.

## Use

```
/route add a soft-delete flow for invoices
/route --model=sol --review=cross migrate the reporting job to a queue
/route --model=gemini --skip-tests regenerate the API docs
```

### Flags

| Flag | Effect |
| --- | --- |
| `--model=<worker>` | Pick the implementer: `sonnet`, `opus`, `fable`, `haiku`, `sol`, `terra`, `luna`, `gemini`, `self`. Omit it and the director picks, announcing the choice. |
| `--review` / `--review=full` | Director reads the diff **and** a cross-vendor reviewer runs. |
| `--review=self` | Director reads the diff only. |
| `--review=cross` | Cross-vendor reviewer only; director reads its findings and spot-checks. |
| *(no `--review`)* | No review stage. Tests still gate the run. |
| `--skip-tests` | Drops the tests-are-mandatory rule. |

Review is opt-in; **plan critique never is**. An unknown flag value halts the
loop with a question rather than falling back to something you did not ask for.

### The loop

1. **Interview** — one question at a time, until the spec has no gaps.
2. **Assign** — one line naming implementer, critic, review mode and sandbox
   level. You override in a word.
3. **Plan** — `PLAN.md`.
4. **Critique** — the plan goes to another vendor. High stakes gets a third.
5. **Build** — worker reach is pre-flighted, the tree is clean, then the brief
   goes out.
6. **Review** — per the flag.
7. **Fix** — findings and test failures go back to the builder until green.
8. **Report** — who did what, which guarantees ran, which were skipped.

## Documentation

- [Workers and CLI mechanics](docs/workers.md) — how each family is invoked,
  model catalogs, effort dials, resuming, structured output.
- [Sandbox and pre-flight](docs/sandbox-and-preflight.md) — what a sandboxed
  worker genuinely cannot reach, how to check it for free, and the escalation
  ladder.
- [Troubleshooting](docs/troubleshooting.md) — hangs, dirty exits, the
  test-runner trap, cross-family leaks.

## Design notes

**The director does not write the code.** Its job is the spec, the plan, the
assignment and the verdict. That separation is what makes the critique
adversarial rather than self-congratulatory.

**Never two write-mode workers in one checkout.** External CLIs and subagents
collide on files and on `.git/index.lock`. Parallel Claude subagents get their
own worktrees; external workers get exclusive ownership of the checkout while
they run.

**Approval is the director's alone.** A green run from a worker is evidence, not
a verdict.

## License

MIT — see [LICENSE](LICENSE).
