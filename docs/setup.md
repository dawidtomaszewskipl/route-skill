# Setup

`--setup` replaces remembering flags with a short questionnaire. The director reads the prompt,
recommends a configuration from what the task is, and asks. The answer is a flag line the user can
reuse next time.

## Reading the input

- **The task text** after the flags are stripped.
- **A plan, if there is one:** a pasted result of Claude Code's `/plan`, a path to a plan file, or an
  existing `.route/PLAN.md`. A plan changes the recommendations: its steps are the tasks, and a plan
  that is already settled lowers the value of extra critique rounds.
- **Several tasks** ("zrób A, potem B", a numbered list, plan phases) are listed separately, each with:

| Fact | How it is judged | What it drives |
| --- | --- | --- |
| Stakes | auth/permissions, money, destructive migrations, concurrency, data integrity | rubric row 1, Astra as critic, second critic, `--review` |
| User-facing UI | views, components, layout, styles | `opus`, visual check |
| Rubric row | SKILL.md "Roster", evaluated in order — stakes first | implementer |
| Test footprint | which suites cover the touched code; browser tests present? shared code touched? | `--tests` |
| Size | files and subsystems touched | `sol`/`gemini` for large self-contained work, `self` for tiny |
| Plan maturity | settled plan vs. an idea | rounds, `--plan-only` |

## Questions

Ask with `AskUserQuestion`, at most 4 questions per call, in **two steps**, because later options
depend on earlier answers (the implementer decides which critics are cross-family; the mode decides
whether review is legal).

**Policy values are defaults, not answers.** Show them — "opus (policy default)" — and when the
rubric recommends something else for this task, make the rubric's pick the recommended option and
say why. Skip only questions that flags or the user's own words already answered, and questions with
a single eligible option.

**Step 1 — shape of the work**

| Question (header) | Options, recommended first | Recommended when |
| --- | --- | --- |
| Tasks (`Zadania`) — only with several tasks | separate runs in sequence · one run · only the first task now | separate when the tasks share no files; one run when one needs the other |
| Mode (`Tryb`) | full run · `--plan-only` · `--cascade` | plan-only when the prompt asks for a plan or the task is an idea; cascade for large mechanical work |
| Implementer (`Wykonawca`) | rubric pick · policy default (when different) · `astra` · `sol` | the rubric row for the task |

**Step 2 — computed from step 1's answers**

| Question (header) | Options, recommended first | Recommended when |
| --- | --- | --- |
| Critic (`Krytyk`) | cross-family default · `astra` · `gemini` · two critics | only families other than the chosen implementer's (and the drafter's under cascade); `astra` + the third family for high stakes |
| Rounds (`Rundy`) | 2 · 1 · 4 | 1 for a settled plan; 4 for a design-heavy or high-stakes plan |
| Review (`Review`) — not asked under `--plan-only` | none · `cross` · `full` · `self` | `cross` or `full` for high stakes; none for mechanical work |
| Tests (`Testy`) | `covering` · `browser` · `full` · skip | `browser` when the task changes a flow a browser suite covers; `full` when it touches shared code (SKILL.md "Test scope"); skip never recommended, and illegal under cascade |

Each option's description says why, in one line tied to the task: "money + concurrency → hard
correctness", "3 Blade views + a modal → UI, screenshots decide". Use the `preview` field when two
options differ in a way a short flag line shows best.

**Separate runs:** after step 1, step 2 is asked per task only where the recommendations differ —
up to two calls per task; shared answers are asked once. Anything left unanswered takes the
recommended option, and the flag line says so.

## Output

```
Setup: /route --model=opus --critic=astra,gemini --rounds=2 --review=cross --tests=covering <task>
Assign: implementer=opus (user, setup; rubric: UI) · critic=astra (user, setup) · …
```

Every answer maps to a flag, so the line is complete and reusable. Separate runs: one line per task,
in order, stored in the checkpoint as `tasks` with `current_task`; the first run starts, and each
next one starts after the previous one's report — `--resume` at `stage: report` picks up the next
queued task (one writer at a time).
