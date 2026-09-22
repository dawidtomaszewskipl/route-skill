# Kaskada

*Oryginał: [../cascade.md](../cascade.md).*

`--cascade` to routowa wersja wzorca *cascade* z Project HydraFusion GitHuba: wydajny model robi
draft, bramka jakości decyduje, czy go przyjąć, czy eskalować do mocniejszego modelu, a dodatkowe
wywołania modeli wydaje się tylko wtedy, gdy mają szansę poprawić wynik. HydraFusion raportuje
36–67 % niższy koszt niż model frontier przy z grubsza tej samej jakości na benchmarkach
programistycznych; wnętrze ich bramki nie jest ujawnione, więc bramka route jest własna —
mechaniczna tam, gdzie może, krzyżowa tam, gdzie musi.

Tylko opt-in. Bez flagi route zachowuje się jak dotychczas.

## Kiedy się opłaca

- Plan jest ustalony i w większości mechaniczny, ale nie tak trywialny, żeby `sonnet` był
  oczywisty.
- Pula, którą byś inaczej zużył (Claude albo Sol na `medium`), jest wąskim gardłem.
- Odrzucony draft kosztuje mało: draft leci na efforcie `medium` z limitem 25 minut, a mechaniczna
  połowa bramki (testy) jest darmowa.

Nie opłaca się przy zmianach wysokiej stawki (krytyka i tak kieruje je do Fable albo Astry) ani z
`--skip-tests`, gdzie bramka traci połowę mechaniczną — route ostrzega.

## Drafterzy

| Wartość | Model | Kiedy |
| --- | --- | --- |
| `luna` (domyślnie) | GPT-6 Luna przez Codex, effort `medium` | pula ChatGPT jest otwarta |
| `gemini` | Gemini 3.8 Flash Medium przez agy | pula ChatGPT jest zamurowana; tylko edycje, testy odpala dyrektor |
| `haiku` | subagent Haiku | obie zewnętrzne pule są zamurowane; także domyślny drafter przy samym Claudzie dla gołego `--cascade` |

Niedozwolone: `--cascade` z `--model=luna|haiku`, drafter równy implementatorowi albo
`--skip-tests` (bramka A straciłaby mechaniczną połowę).

**Rodzina krytyka.** Krytyka planu wybiera się z rodziny innej niż rodzina implementatora **i**
draftera, jeśli taka jest dopuszczona (Opus implementuje, Luna szkicuje → plan krytykuje `gemini`).
Jeśli takiej nie ma, a draft zostanie przyjęty, raport zapisuje `plan critic same family as accepted
builder`; bramka B nadal jest z innej rodziny niż drafter.

## Protokół

1. **Warunki wstępne.** Plan zatwierdzony przez krytyka; czyste drzewo; `base_sha` w checkpoincie.
2. **Draft.** Drafter dostaje `.route/brief-build.md` plus dopisek poniżej, na efektywnym efforcie
   draftu (domyślnie `medium` od 3.2: jedyny zapisany draft na `low` zawiódł na wykończeniu — jednolinijkowce, brakujące testy — a nie na kształcie). W tle, watchdog jak zwykle, limit 25 minut tylko na draft.
3. **Bramka A — mechaniczna, bez modelu.** Inwentarz zmian to `git diff --name-only <base_sha>`
   **plus** `git ls-files --others --exclude-standard` (nowe pliki są nieśledzone i diff ich nie
   widzi); całość musi mieścić się w granicach planu. Dyrektor odpala testy (nigdy ich nie ubija);
   linia `DRAFT_ABORT` idzie prosto do eskalacji. Zapis `.route/draft.diff` — śledzony diff plus
   każdy nowy plik jako `git diff --no-index /dev/null <plik>` — i podsumowania testów.
4. **Bramka B — krytyk z innej dopuszczonej rodziny niż drafter** (przy samym Claudzie: inny model
   Claude'a niż drafter, oznaczony jako zdegradowany). Samowystarczalny brief z planem, diffem
   (osadzony poniżej 40 KB, inaczej ścieżka) i podsumowaniem testów; recenzja tylko do odczytu;
   wymuszony `.route/gate-schema.json`.
5. **Decyzja, mechaniczna.** Akceptacja wtedy i tylko wtedy, gdy `verdict = accept` ∧ bramka A
   zielona ∧ brak znaleziska `blocking` ∧ `plan_coverage.missing = []`. Poprawka, gdy `verdict =
   revise` ∧ blocking ≤ 3 ∧ to runda 1. W przeciwnym razie eskalacja. **Maksymalnie dwie rundy
   bramki.**
6. **Akceptacja.** Drzewo zostaje; dyrektor sprawdza wyrywkowo; drafter jest builderem w dalszych
   rundach poprawek; każdy pozostały przydział krytyka/recenzenta jest sprawdzany ponownie
   względem rodziny faktycznego buildera (w trybie zdegradowanym — jego modelu).
7. **Eskalacja.** Sesja draftera zakończona albo ubita. `git stash push -u -m
   route-draft-<run_id>` cofa drzewo do `base_sha`; nazwa stasha trafia do `tree_state` w
   checkpoincie. Implementator dostaje oryginalny brief plus znaleziska bramki i
   `draft-rejected.diff` z etykietą „odrzucony draft: wykorzystaj, co słuszne, nie ufaj niczemu".
   Stash jest kasowany przy raporcie; `--resume` dotyka go dopiero po potwierdzeniu zapisanej
   gałęzi i `HEAD == base_sha`.
8. **Raport.** `cascade: accepted at round N` albo `escalated after N`, z kosztem draftu + bramki
   obok kosztu eskalacji z ledgera.

## Dopisek do briefu draftera (dosłownie)

> You are the drafter. If a section of the plan needs judgment you lack, stop and end your answer
> with `DRAFT_ABORT: <reason>`. Provide complete file contents or full functions — never
> placeholders, ellipsis comments (`// ...`) or omitted existing logic. If the context is too large,
> stop with `DRAFT_ABORT: context_limit`. Keep the repository's formatting: one statement per
> line, no packing code into long one-liners. Write every test the plan lists — a missing planned
> test is a gate finding. Do not run tests (the director will). Do not commit.

Drafterzy Gemini dostają dodatkowo zdanie „tylko edycje" z głównego bloku briefu: każde wykonanie
komendy przerywa headlessowy run.

## Brief bramki B (szablon)

```
<task>
Review the draft below against the plan. You are the gate: decide accept / revise / escalate.
</task>
<plan>…zawartość .route/PLAN.md…</plan>
<boundaries>…pliki/katalogi dozwolone przez plan…</boundaries>
<draft_diff>…zawartość .route/draft.diff (albo: read .route/draft.diff)…</draft_diff>
<tests>…podsumowanie testów dyrektora: komenda, liczby pass/fail, błędy dosłownie…</tests>
<rules>
- accept only if the diff covers every plan item, stays inside the boundaries, and the tests pass
- revise for ≤ 3 concrete, blocking-or-major fixes the same drafter can make
- escalate when the draft misunderstands the plan, needs design judgment, or is incomplete beyond
  three fixes; say why in escalate_reason
- findings cite file and line (line 0 when unknown); no nulls anywhere
</rules>
Answer only with JSON matching the schema.
```

## Kształt werdyktu

```json
{"verdict":"accept|revise|escalate","confidence":0.0,"summary":"",
 "findings":[{"severity":"blocking|major|minor","file":"","line":0,"issue":"","fix":""}],
 "plan_coverage":{"done":[],"missing":[]},"tests_assessment":"adequate|thin|missing",
 "escalate_reason":"","assumptions":[]}
```

Plik schematu (`docs/schemas/gate-schema.json`) jest przyjmowany dosłownie przez `codex exec
--output-schema` i `agy --json-schema`, bo nie deklaruje żadnego pola nullable.

## Co o koszcie mówią realne runy

Te liczby pochodzą z workerów GPT-5.6 i draftu na effortcie `low`; GPT-6 Sol i Luna na domyślnych
ustawieniach 3.2 nie są jeszcze zmierzone — pokaże to ledger. Z danych o kształcie ledgera z
poprzednich sesji: krytyka Sola to 4–10 minut, build Sola 13–35,
pętla poprawek po review 40–52. Draft Luny na niskim efforcie plus mechaniczna bramka i jedna
krytyka Flasha to znacznie mniej niż najtańsza z tych pozycji. Kaskada zarabia na siebie, gdy
przyjęty zostaje przynajmniej jeden draft na trzy; linia kaskady w raporcie pokazuje, czy to się
sprawdza w Twoim projekcie.
