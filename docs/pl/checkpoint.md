# Checkpoint

*Oryginał: [../checkpoint.md](../checkpoint.md).*

`.route/CHECKPOINT.md` sprawia, że run route da się wznowić po ścianie limitu, błędzie API,
blokadzie bezpieczeństwa albo zamkniętym laptopie. Jest przepisywany w miejscu — nigdy dopisywany
— po każdej zmianie etapu, przy każdym starcie workera (z id sesji; to ten jeden zapis, który
ratuje wznawialność), przy każdym zakończeniu workera, po każdej rundzie bramki lub poprawek i
przy każdym blokerze.

## Front matter

```yaml
run_id: 2026-09-06T10-31-route-a1b2
written_at: 2026-09-06T11:02:14+02:00
task: "CRUD screens for the tags dictionary"
flags: "--model=sol --review=cross --cascade --rounds=2 --tests=covering"
test_scope: covering    # covering | covering,browser | full | full,browser | none
plan_only: false        # true after a --plan-only run; plan_sha256 is then the approved plan's hash
plan_sha256: ""
tasks:                  # tylko po --setup z osobnymi runami
  - {id: 1, text: "CRUD screens for the tags dictionary", flags: "--model=sol --review=cross --cascade --rounds=2 --tests=covering",
     status: in_progress, plan: .route/tasks/1/PLAN.md, plan_sha256: "", critics: []}
  - {id: 2, text: "tag filter in the posts list", flags: "--model=opus --plan-only --tests=browser",
     status: queued, plan: .route/tasks/2/PLAN.md, plan_sha256: "", critics: []}
                        # status: queued | in_progress | planned (a --plan-only run finished) | done
current_task: 1
branch: feature/tags-crud
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
  claude: []             # subagent ids, continued with SendMessage within the session;
                         # a worktree subagent as {id: …, worktree: <path>}
artifacts:
  plan: .route/tasks/1/PLAN.md    # PLAN.md tego runu (.route/PLAN.md bez kolejki)
  briefs: [.route/brief-critique.md, .route/brief-build.md]
  outputs: [.route/critique.json, .route/build.jsonl, .route/build.txt]
tree_state: dirty-worker   # clean | dirty-worker | dirty-draft | stashed:route-draft-<run_id>
tree: {branch: feature/tags-crud, head: 3704e20…, fingerprint: 9f2c41…}
                           # przepisywane przy każdym checkpoincie; fingerprint = sha256 z `git diff HEAD --binary`
                           # i z kolejnych ścieżek nieśledzonych plików z ich sha256, w kolejności posortowanej
tests: {cmd: "vendor/bin/sail artisan test --compact", last_result: "1104/1104", duration_s: 412, T_slow_s: 417}
runtime: {codex_version: 0.153.4, agy_version: 1.1.27, doctor_ok: true, probed_at: 2026-09-06T10:31:00+02:00}
agy_log: {path: ~/.gemini/antigravity-cli/log/cli-20260906_103105.log, baseline_bytes: 4120}
blockers: []               # [{kind: quota|api|safety-pause|question, who, at, detail}]
open_findings: []
next_action: "sample build.jsonl; on turn.completed run tests, then review stage"
ledger: .route/ledger.jsonl
```

## Treść

- **Zrobione** — ukończone etapy i commity, z hashami.
- **W toku** — który worker, która sesja, kiedy wystartował, ostatnia próbka postępu.
- **Do zrobienia po wznowieniu** — lista w trybie rozkazującym, którą dyrektor wykonuje.
- **Diagnoza** — bieżący czerwony stan, jeśli jest: który test, dlaczego, co próbowano.

## Procedura wznowienia

1. Przeczytaj checkpoint. Jeśli `stage` to `report`, a `tasks` ma wpis `queued`, uruchom to zadanie
   jako nowy run z zapisanymi flagami. Jeśli `stage` to `report` w innym przypadku, nie ma czego wznawiać (tam kończy się też run
   z `--plan-only`; budowa według jego planu to nowy run startujący od tego planu).
2. **Sonduj ponownie**: `codex doctor --summary`, `agy --version`, limity — nadpisz `runtime`.
   Nigdy nie wnioskuj z zapamiętanego limitu.
3. Porównaj drzewo z `tree`: gałąź, `git rev-parse HEAD` i fingerprint przeliczony tak samo. Każda
   różnica znaczy, że ktoś (worker, użytkownik) dotknął drzewa od zapisu checkpointu — nawet gdy
   `git status` wygląda tak samo — więc najpierw protokół dirty-exit (SKILL.md, „Time and the
   watchdog"). Stan `stashed:` nakładasz albo kasujesz dopiero po
   potwierdzeniu, że `branch` jest bieżącą gałęzią i `git rev-parse HEAD == base_sha`.
4. Kontynuuj od `stage` z `next_action`, kontynuując każdego workera tak, jak mówi SKILL.md
   „Launching workers": Codex po UUID wątku (także po zatrzymaniu przez API albo limit), agy po id
   tylko po turze `SUCCESS`, subagentów Claude przez `SendMessage` w tej samej sesji albo od nowa po
   restarcie.
5. Checkpoint z `plan_only: true` przy `stage: report` nie jest wznawiany, tylko budowany: SKILL.md,
   „Building a `--plan-only` plan".
