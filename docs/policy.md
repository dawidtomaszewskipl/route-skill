# Roster policy

Route's routing is a written rubric (see "Picking the implementer" in `SKILL.md` and "How the
director decides" in the README). A policy file lets you bend that rubric once instead of correcting
the director every run — "never pick Fable here", "critic is always Gemini", "this repo builds with
Sol by default".

## Where

| File | Scope | Typical use |
| --- | --- | --- |
| `route.policy.yml` at the repository root | the project, committed | team conventions: default implementer, banned slots, a family the team does not license |
| `~/.claude/route.policy.yml` | you, every project | your own budget: "I never spend Fable on builds" |

Precedence, highest first: **command-line flags → repo policy → user policy → skill defaults**,
resolved **per key**: a scalar, each `effort.*` entry and each `families.*` entry is taken from the
highest level that sets it. A higher-level `deny` list *replaces* a lower one (an empty list clears
it). `families.<x>: on` lifts a lower-level `off`, but cannot make an absent or signed-out CLI
available.

## Keys

All optional. Slot names are the `--model` values; effort values are the CLI vocabulary.

| Key | Meaning |
| --- | --- |
| `deny: [slot, …]` | The director never picks these on its own. An explicit `--model=<denied>` still wins — with a warning in the assignment line, because you asked. |
| `implementer: slot` | Default implementer when `--model` is absent. Without it, the rubric decides. |
| `critic: slot` | Preferred plan critic, used whenever the cross-family rule allows it. |
| `reviewer: slot` | Preferred cross-family reviewer for `--review=full` and `--review=cross`. |
| `cascade_drafter: slot` | Default drafter for `--cascade` (default `luna`). |
| `effort: {critique, high_stakes_critique, build, draft}` | Per-stage effort for OpenAI and Google workers. Claude subagents have no dial. |
| `families: {openai\|google: on\|off}` | Switch a family off even if its CLI is installed and signed in, or `on` to lift a lower-level `off`. Claude cannot be switched off — it is the director. |

The example with comments: [`examples/route.policy.yml`](examples/route.policy.yml).

## How it is applied

Stage 0 reads both files (if present), reports which were found and the effective values, and then
the picker runs with them. Every value that came from a policy is marked `(policy)` in the
assignment line, so a run always shows where a choice came from:

```
Assign: implementer=sol (policy: repo default) · critic=fable (cross-family; policy critic gemini
unavailable: families.google off) · …
```

The cross-family rule is not a policy key and cannot be switched off. If a policy makes it
unsatisfiable (for example `critic: sol` with `implementer: sol`), the director ignores the critic
preference, says so, and applies the rule.

Precedence is resolved **before** anything is validated. An explicit `--model` overrides a denied
slot or a policy-disabled family *for the implementer*, with a warning in the assignment line — it
never overrides real unavailability (the CLI is missing or signed out) and never the cross-family
rule. An ineligible `critic` or `reviewer` preference is dropped with a sentence saying why, and an
eligible alternative is chosen.

## What halts

Like an illegal flag, an illegal policy stops the loop with a question instead of guessing:

- a slot name that is not in the roster (`gemini-pro`, `gpt-5`);
- a `cascade_drafter` other than `luna`, `haiku` or `gemini`;
- an effort the selected worker does not accept — Gemini takes `low|medium|high`, an OpenAI model
  its own catalog list (Sol/Terra: up to `ultra`, Luna: up to `max`), Claude slots take none;
- an effective, non-overridden `implementer` or `cascade_drafter` that is denied or belongs to a
  family switched off;
- an unavailable family that a flag requires.

## Format

Plain YAML, two-space indents, no anchors, no flow style. The director reads it as text — there is
no parser to satisfy, only a human to keep it legible. Keep it to the keys above; unknown keys are
reported and ignored.
