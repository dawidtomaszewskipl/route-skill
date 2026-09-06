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
task: "soft-delete flow for invoices"
flags: "--model=sol --review=cross --cascade"
branch: feature/invoices-soft-delete
base_sha: 3704e20…
stage: build            # interview | assign | plan | critique | draft | gate | build | review | fix | report
round: 1
roster:
  implementer: {slot: sol, model_requested: gpt-5.6-sol, effort: medium}
  drafter:     {slot: luna, model_requested: gpt-5.6-luna, effort: low}
  critic:      {slot: gemini, model_requested: gemini-3.8-flash-medium, effort: medium}
  reviewer:    {slot: fable, model_requested: fable, effort: ""}
sessions:
  codex: [01a075d7-9c4e-7580-b41d-0ce7c87bf4b9]
  agy:   [b538f8bb-9a0e-4978-bc3d-988ccef298eb]
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

## Treść

- **Zrobione** — ukończone etapy i commity, z hashami.
- **W toku** — który worker, która sesja, kiedy wystartował, ostatnia próbka postępu.
- **Do zrobienia po wznowieniu** — lista w trybie rozkazującym, którą dyrektor wykonuje.
- **Diagnoza** — bieżący czerwony stan, jeśli jest: który test, dlaczego, co próbowano.

## Procedura wznowienia

1. Przeczytaj checkpoint. Jeśli `stage` to `report`, nie ma czego wznawiać.
2. **Sonduj ponownie**: `codex doctor --summary`, `agy --version`, limity — nadpisz `runtime`.
   Nigdy nie wnioskuj z zapamiętanego limitu.
3. `git status` względem `tree_state`. Rozjazd znaczy, że ktoś (worker, użytkownik) dotknął drzewa
   od tamtej pory — najpierw protokół dirty-exit. Stan `stashed:` nakładasz albo kasujesz dopiero po
   potwierdzeniu, że `branch` jest wymeldowany i `git rev-parse HEAD == base_sha`.
4. Kontynuuj od `stage` z `next_action`, wznawiając wątki Codexa po UUID i rozmowy agy po id —
   tylko te, których ostatnia tura była `SUCCESS`; wszystko inne startuje jako nowa sesja z
   osadzonym bieżącym `git diff`.
