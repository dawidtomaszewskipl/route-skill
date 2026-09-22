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
| Rubric row | the first matching row in SKILL.md "Roster" | implementer |
| Stakes | auth/permissions, money, destructive migrations, concurrency, data integrity | Astra as critic, second critic, `--review` |
| User-facing UI | views, components, layout, styles | `opus`, visual check |
| Test footprint | which suites cover the touched code; browser tests present? | test scope |
| Size | files and subsystems touched | `sol`/`gemini` for large self-contained work, `self` for tiny |
| Plan maturity | settled plan vs. an idea | rounds, `--plan-only` |

## Questions

Ask only what is still open after flags, plain words and policy. Drop a question whose only eligible
answer is already known. At most 4 questions per `AskUserQuestion` call and 2 calls in total; the
first call carries the questions that change the most.

| # | Question (header) | Options, recommended first | Recommended when |
| --- | --- | --- | --- |
| 0 | Tasks (`Zadania`) | one run · separate runs in sequence · only the first task now | separate runs when the tasks share no files; one run when one needs the other |
| 1 | Implementer (`Wykonawca`) | rubric pick · the policy default · `astra` · `sol` | rubric row for the task; show the policy default when it differs |
| 2 | Plan critic (`Krytyk`) | cross-family default · `astra` · `gemini` · two critics | `astra` + third family for high stakes |
| 3 | Critique rounds (`Rundy`) | 2 · 1 · 4 | 1 for a settled plan; 4 for a design-heavy or high-stakes plan |
| 4 | Review (`Review`) | none · `cross` · `full` · `self` | `cross` or `full` for high stakes; none for mechanical work |
| 5 | Tests (`Testy`) | covering tests, no browser · + browser tests · skip | browser only when the task changes a flow the browser suite covers |
| 6 | Mode (`Tryb`) | full run · `--plan-only` · `--cascade` | plan-only when the prompt asks for a plan or the task is an idea; cascade for large mechanical work |

Each option's description says why, in one line tied to the task: "money + concurrency → hard
correctness", "3 Blade views + a modal → UI, screenshots decide". Use the `preview` field when two
options differ in a way a short flag line shows best.

For separate runs, questions 1–6 are asked per task only where the recommendations differ; shared
answers are asked once.

## Output

```
Setup: /route --model=opus --critic=astra,gemini --rounds=2 --review=cross <task>
Assign: implementer=opus (user, setup; rubric: UI) · critic=astra (user, setup) · …
```

Separate runs: one flag line per task, in order, then the first run starts; the next starts after the
previous one's report (one writer at a time). The flag lines go into the checkpoint's `flags`, so
`--resume` does not ask again.
