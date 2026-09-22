# Cost ledger

`.route/ledger.jsonl`, one line per model call, appended right after reading its output:

```
{ts, run_id, stage, cli, family, model_requested, effort, service_tier_requested,
 service_tier_observed, session_id, duration_s, input_tokens, cached_input_tokens,
 cache_write_input_tokens, output_tokens, reasoning_tokens, total_tokens, raw_cumulative,
 denied_actions, exit_code, status, outcome}
```

## Sources

| CLI | Where the numbers are |
| --- | --- |
| Codex | the last `turn.completed.usage` in the `.jsonl`: `input_tokens`, `cached_input_tokens`, `cache_write_input_tokens`, `output_tokens`, `reasoning_output_tokens` → `reasoning_tokens` |
| agy | the envelope's `usage`: `input_tokens`, `output_tokens`, `thinking_tokens` → `reasoning_tokens`, `cache_read_tokens` → `cached_input_tokens`, `total_tokens`; plus `duration_seconds`, `denied_actions[].action` |
| Claude subagent | the Agent tool's completion line |

Missing → `null`, never estimated. `codex exec review` (a manual extra, not the cross reviewer)
reports zero usage, so its token fields are `null`.

**`codex exec resume` reports usage cumulatively per thread.** Keep the thread's raw counters as
reported in `raw_cumulative` (`null` for a non-Codex call), and put the delta into the token
fields: `delta[n] = raw[n] − raw[n−1]`, both taken from `raw_cumulative`, never from the previous
row's token fields. The token fields then sum to the thread total. Example — raw input 100, 150,
180 → token fields 100, 50, 30 → sum 180. Subtracting the previous row's *delta* instead gives
100, 50, 130 → 280, the error this rule exists to prevent.

Codex runs on the standard tier (`service_tier` unset — a `fast` profile exists for interactive
use); the served tier is not recorded anywhere, so `service_tier_observed` is always `null`. Token
totals are never presented as subscription cost.

A worker swap mid-run gets its own row with `outcome: "swapped: <reason>"` on the abandoned call.

## Report table

`Stage | Who (model@effort) | Wall | In | Out | Result`, totals per family, the cascade line when it
ran (`cascade: accepted at round N | escalated after N — draft+gate cost vs escalation cost`), and
the guarantees line (review mode, tests, sandbox rung, what was skipped or degraded).
