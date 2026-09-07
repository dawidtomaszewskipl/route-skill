# route

*English. Polska wersja: [README_pl.md](README_pl.md).*

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
| OpenAI | `codex exec` ([Codex CLI](https://developers.openai.com/codex/cli)) | GPT-6 Astra, GPT-5.6 Sol / Terra / Luna |
| Google | `agy` (Antigravity CLI) | Gemini 3.8 Flash |

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
- **Cheap first, when you ask for it.** `--cascade` lets an inexpensive model
  draft and a mechanical + cross-vendor gate decide whether to accept or
  escalate — the *cascade* pattern from GitHub's Project HydraFusion.
- **Every run is resumable and accounted for.** A checkpoint file survives
  quota walls and crashes; a ledger records what each stage cost.

## Install

```bash
git clone https://github.com/dawidtomaszewskipl/route-skill.git
cd route-skill
./install.sh            # copies SKILL.md and docs/ to ~/.claude/skills/route/
```

Or by hand:

```bash
mkdir -p ~/.claude/skills/route
cp -R SKILL.md docs ~/.claude/skills/route/
```

Per-project instead of global: copy it to `<project>/.claude/skills/route/`.

### Requirements

Claude Code alone is enough — the loop degrades to Claude-only workers, and the
plan critique falls back within the family (weaker, but the loop still runs). For
the full roster:

- **Codex CLI ≥ 0.153.1** (GPT-6 Astra) — `npm i -g @openai/codex`, then `codex login`.
  Verify with `codex doctor`.
- **Antigravity CLI ≥ 1.1.27** (`agy`; reports denied actions) — install from Google
  Antigravity, then `agy models` to confirm sign-in.

## Use

```
/route add a soft-delete flow for invoices
/route --model=sol --review=cross migrate the reporting job to a queue
/route --model=gemini --skip-tests regenerate the API docs
/route --cascade --model=fable add the retry policy to the payment webhook
/route --resume
```

### Flags

| Flag | Effect |
| --- | --- |
| `--model=<worker>` | Pick the implementer: `sonnet`, `opus`, `fable`, `haiku`, `astra`, `sol`, `terra`, `luna`, `gemini`, `self`. Omit it and the director picks, announcing the choice. |
| `--review` / `--review=full` | Director reads the diff **and** a cross-vendor reviewer runs. |
| `--review=self` | Director reads the diff only. |
| `--review=cross` | Cross-vendor reviewer only; director reads its findings and spot-checks. |
| *(no `--review`)* | No review stage. Tests still gate the run. |
| `--skip-tests` | Drops the tests-are-mandatory rule. |
| `--cascade[=luna\|haiku\|gemini]` | A cheap drafter builds first; tests plus a cross-vendor gate accept or escalate to the implementer. See [cascade](docs/cascade.md). |
| `--resume` | Continue the run recorded in `.route/CHECKPOINT.md`. |

Review is opt-in; **plan critique never is**. An unknown flag value halts the
loop with a question rather than falling back to something you did not ask for.

### The loop

0. **Validate** — flags, CLI versions, project skills, sandbox reach, clean
   tree — before any model call.
1. **Interview** — one question at a time, until the spec has no gaps.
2. **Assign** — one line naming implementer, critic, review mode, sandbox
   level and (with `--cascade`) the drafter. You override in a word.
3. **Plan** — `.route/PLAN.md`.
4. **Critique** — the plan goes to another vendor (at most three rounds).
   High stakes gets a third.
5. **Build** — or draft + gate with `--cascade`. One writer at a time.
6. **Review** — per the flag.
7. **Fix** — findings and test failures go back to the builder (at most three
   rounds, then the checkpoint and the decision come back to you).
8. **Approve** — the director runs the tests itself and commits.
9. **Report** — who did what, what it cost, which guarantees ran, which were
   skipped.

## How the director decides

Routing is a **written rubric plus a few hard rules**, applied and announced by the session model —
not a learned router, and not a per-task capability signature. No benchmark is consulted at run
time; which model sits in which slot was the author's call from published results at the time of
writing, and it lives nowhere the director reads — the rubric below is the whole logic.

| Task shape | Slot |
| --- | --- |
| Mechanical build from a settled plan (migration, factory, resource, CRUD) — framework scaffolding included, it is convention-heavy rather than mechanical | `sonnet` |
| Ordinary feature work that still needs thinking while writing | `opus` |
| Hard correctness: concurrency, money, permissions, data integrity | `fable`, or `astra` when the Claude pool is the constraint |
| Large, self-contained chunk | `sol` or `gemini` (the idle pools); `terra` / `luna` when large but not hard |
| Bulk edits with no judgment in them | `haiku` |
| Handoff would cost more than the code | `self` |

**Effort is policy, not inference.** Critique `medium` (Astra on high-stakes work: `high`), build
`medium`, cascade draft `low`. Claude subagents have no dial — the model choice is the dial.

**Hard rules.** The plan critic and any external reviewer come from a different model family than
the implementer whenever one is available (Claude-only runs use a different Claude model and are
marked degraded; `--review=self` is the director's own read); the model is pinned on every external
call; unknown or illegal flags halt with a question; a worker's green run is evidence, not a verdict.

**The director says which row fired.** At the assignment stage the run gets one line —
`implementer=fable (hard correctness: money + concurrency) · critic=sol (cross-family) · …` — and
you override it in a word. Where the choice came from a policy file it says `(policy)`.

**Where adaptation lives.** `--cascade` changes the builder through a draft-and-gate protocol —
on evidence: the director's tests unless `--skip-tests`, plus a schema-validated gate verdict from
another eligible family (a different Claude model in degraded mode), or immediate escalation on
`DRAFT_ABORT` — not on a guess about the task. Outside cascade, an ordinary out-of-scope decline
permits one rewritten brief; the worker is rerouted only if the decline persists. The per-stage ledger (`.route/ledger.jsonl`) is the data a smarter router
would need; if you want to build one, that is the place to start.

**Fewer than three families.** Route requires Claude Code as the director; everything else is
detected, not assumed — stage 0 checks installation (`command -v`), sign-in (`codex login status`,
`agy models`) and health (`codex doctor`) — and every external role is resolved among the families
that are actually there. Claude alone works: critics and reviewers use a different Claude model from
the implementer, the cascade gate a different model from the drafter, and these checks are marked
degraded. When OpenAI implements, the critic is
Claude or an available Gemini worker, per policy and the cross-family rule. Google is a third pool
and a third set of blind spots, not a price argument.

**Standing preferences.** `route.policy.yml` in a repo or `~/.claude/route.policy.yml` for yourself:
deny slots, set defaults, pin efforts, switch a family off — see [policy](docs/policy.md).

## Documentation

- [Workers and CLI mechanics](docs/workers.md) — how each family is invoked,
  model catalogs, effort dials, resuming, structured output, skills visibility.
- [Sandbox and pre-flight](docs/sandbox-and-preflight.md) — what a sandboxed
  worker genuinely cannot reach, how to check it for free, and the escalation
  ladder.
- [Cascade](docs/cascade.md) — the draft → gate → accept/escalate protocol.
- [Checkpoint](docs/checkpoint.md) — the resumable run state and how `--resume`
  uses it.
- [Policy](docs/policy.md) — standing roster preferences per repo or per user.
- [Troubleshooting](docs/troubleshooting.md) — every failure seen in real runs,
  with the fix that worked.
- [Schemas](docs/schemas/) — the critique and gate verdict schemas, in the one
  dialect both CLIs accept.

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

**Evidence over assumptions.** Version 3 was rebuilt from the logs of twenty real
runs and from adversarial critiques of its own plan by GPT-6 Astra and Gemini
3.8 Flash — the same loop it prescribes. The canonical command lines are the
ones that actually ran.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) — from the 2026-08-16 project-local predecessor to the
current release.

## License

MIT — see [LICENSE](LICENSE).
