# Komendy uruchamiania

*Oryginał: [../commands.md](../commands.md).*

Przeczytaj to przed pierwszym zewnętrznym uruchomieniem w runie. `SKILL.md` trzyma niezmienniki;
ten plik trzyma dokładne linie.

## Zasady uruchamiania

- Każda tura modelu przez zewnętrzne CLI (`codex exec`, `agy -p`, które dociera do modelu) i każdy
  run testów idzie przez tryb tła narzędzia Bash (`run_in_background: true`), stdout i stderr
  przekierowane pod `.route/`. Krótkie sprawdzenia bez tury modelu (`codex login status`,
  `codex doctor`, `codex sandbox -- …`, `agy models`, `agy --version`, sonda `/skills`) idą na
  pierwszym planie. Workerzy Claude idą zamiast tego przez narzędzie `Agent` (sekcja „Subagenci
  Claude"). **Nigdy nie odłączaj w
  shellu** — bez końcowego `&`, `nohup`, `setsid`, `disown`: narzędzie wraca od razu, nie powstaje
  zadanie harnessu i powiadomienie o zakończeniu, które budzi dyrektora, nigdy nie przychodzi. Na
  proces, który musi przeżyć shell, czeka ta sama komenda w tle
  (`until ! kill -0 "$PID"; do sleep 20; done`).
- Briefy są plikami; prompt to `"$(cat file)"`; **stdin zamknięty przez `< /dev/null`** — otwarty
  stdin (heredoc w tej samej komendzie) to jedyna potwierdzona przyczyna „zawieszonego" Codeksa.
- Linie poniżej to **szablony** z domyślnymi wartościami etapów. Przy każdym uruchomieniu i
  wznowieniu podstaw efektywny model i effort etapu po rozstrzygnięciu polityki (Gemini: sufiks
  sluga i `--effort` razem).

## Codex

```bash
# krytyka — read-only, kontekst osadzony w briefie, serwery MCP wyłączone
codex exec -m gpt-6-sol -s read-only --color never --json -c model_reasoning_effort=medium \
  -c mcp_servers.perplexity.enabled=false -c mcp_servers.playwright.enabled=false \
  --output-schema .route/critique-schema.json -o .route/critique.json \
  "$(cat .route/brief-critique.md)" < /dev/null > .route/critique.jsonl 2> .route/critique.stderr.log
#   wysoka stawka: -m gpt-6-astra -c model_reasoning_effort=high

# build — workspace-write
codex exec -m gpt-6-sol -s workspace-write --color never --json -c model_reasoning_effort=medium \
  -o .route/build.txt "$(cat .route/brief-build.md)" < /dev/null > .route/build.jsonl 2> .route/build.stderr.log

# wznowienie buildera — BEZ -s / --color / -C; sandbox przez -c; ZAWSZE UUID wątku z
# thread.started.thread_id w .jsonl runu. --last jest zakazane: bierze najnowszą
# sesję w cwd, niezależnie od tego, kto ją zaczął.
codex exec resume <THREAD_UUID> --json -m gpt-6-sol -c 'sandbox_mode="workspace-write"' \
  -c model_reasoning_effort=medium -o .route/fix1.txt \
  "$(cat .route/brief-fix1.md)" < /dev/null > .route/fix1.jsonl 2> .route/fix1.stderr.log
# krytyk, bramka albo recenzent zachowuje swoją rolę przy wznowieniu: read-only i swój schemat
codex exec resume <THREAD_UUID> --json -m gpt-6-sol -c 'sandbox_mode="read-only"' \
  -c model_reasoning_effort=medium -c mcp_servers.perplexity.enabled=false -c mcp_servers.playwright.enabled=false \
  --output-schema .route/critique-schema.json -o .route/critique-r2.json \
  "$(cat .route/brief-critique-r2.md)" < /dev/null > .route/critique-r2.jsonl 2> .route/critique-r2.stderr.log

# recenzja krzyżowa — read-only, z kontraktem: brief niesie specyfikację, PLAN.md, kryteria
# akceptacji i diff (w treści poniżej 40 KB, inaczej ścieżka; z nieśledzonymi plikami);
# effort = etap `review` (domyślnie high)
codex exec -m gpt-6-sol -s read-only --color never --json -c model_reasoning_effort=high \
  -c mcp_servers.perplexity.enabled=false -c mcp_servers.playwright.enabled=false \
  --output-schema .route/review-schema.json -o .route/review.json \
  "$(cat .route/brief-review.md)" < /dev/null > .route/review.jsonl 2> .route/review.stderr.log
# `codex exec review --uncommitted` ma własny wbudowany kontrakt i nie widzi planu: ręczny dodatek,
# nigdy recenzent krzyżowy.

# wywołanie próbne modelu (etap 0, krok 5) — jedno na slug, gdy .route/model-probes.json nie ma
# świeżego sukcesu
codex exec -m gpt-6-sol -s read-only --color never --json -c model_reasoning_effort=low \
  -c mcp_servers.perplexity.enabled=false -c mcp_servers.playwright.enabled=false \
  -o .route/probe-gpt-6-sol.txt "Reply with exactly: OK" \
  < /dev/null > .route/probe-gpt-6-sol.jsonl 2> .route/probe-gpt-6-sol.stderr.log
#   sukces = exit 0 i plik -o mówi OK; wtedy zapis w .route/model-probes.json:
#   {"gpt-6-sol": {"ok": true, "probed_at": "<czas ISO>", "codex_version": "<codex --version>",
#                  "identity": "<identity z $CODEX_HOME/models_cache.json>"}}

# drafter kaskady
codex exec -m gpt-6-luna -s workspace-write --color never --json -c model_reasoning_effort=medium \
  -o .route/draft.txt "$(cat .route/brief-draft.md)" < /dev/null > .route/draft.jsonl 2> .route/draft.stderr.log
```

## agy

```bash
# --add-dir "$REPO" przy każdym wywołaniu, inaczej worker nie widzi skilli ani reguł projektu.
# Stuby mogą zaczynać się od "/<skill>", żeby wymusić wczytanie wiążącego skilla.
REPO="$(git rev-parse --show-toplevel)"

# krytyka — tryb plan, read-only, bez shella. CAŁY brief idzie w -p (bez stuba-wskaźnika: brief
# zakazuje czytania plików), zaczyna się akapitem „bez narzędzi"; werdykt to JSON wewnątrz
# payload.response. Ten sam kształt dla bramki (gate-schema) i recenzji (review-schema). Brief ponad
# ~100 KB dzieli się na części, każda to pełny brief dla swojego wycinka, jedno wywołanie na część;
# łączny werdykt akceptuje tylko wtedy, gdy akceptuje każda część, a znaleziska są sumą.
agy --model gemini-3.8-flash-medium --mode plan --effort medium --add-dir "$REPO" --output-format json \
  --json-schema .route/critique-schema.json --print-timeout 30m \
  -p "$(cat .route/brief-critique.md)" < /dev/null > .route/agy-critique.json 2> .route/agy-critique.stderr.log

# build — accept-edits, TYLKO EDYCJE: jedna odrzucona komenda anuluje cały run
agy --model gemini-3.8-flash-medium --mode accept-edits --effort medium --add-dir "$REPO" --output-format json \
  --print-timeout 60m -p "$(cat .route/stub-build.md)" < /dev/null > .route/agy-build.json 2> .route/agy-build.stderr.log

# drafter kaskady
agy --model gemini-3.8-flash-medium --mode accept-edits --effort medium --add-dir "$REPO" --output-format json \
  --print-timeout 30m -p "$(cat .route/stub-draft.md)" < /dev/null > .route/agy-draft.json 2> .route/agy-draft.stderr.log

# wznowienie buildera — po id, nigdy -c/--continue; tylko po turze SUCCESS
agy --conversation <CONVERSATION_ID> --model gemini-3.8-flash-medium --mode accept-edits --effort medium \
  --add-dir "$REPO" --output-format json --print-timeout 60m \
  -p "$(cat .route/stub-fix1.md)" < /dev/null > .route/agy-fix1.json 2> .route/agy-fix1.stderr.log

# kontynuacja krytyka, bramki albo recenzenta — zachowuje tryb plan, swój schemat i cały brief w -p
agy --conversation <CONVERSATION_ID> --model gemini-3.8-flash-medium --mode plan --effort medium \
  --add-dir "$REPO" --output-format json --json-schema .route/critique-schema.json --print-timeout 30m \
  -p "$(cat .route/brief-critique-r2.md)" < /dev/null > .route/agy-critique-r2.json 2> .route/agy-critique-r2.stderr.log
```

**Stuby — tylko builderzy i drafterzy.** Ich prompt `-p` to wskaźnik — *„Read `.route/brief-build.md` in the workspace and execute it
exactly. Your final answer is only what it asks for."* — mały i wolny od kłopotów z cytowaniem w
shellu; twardą granicą jest limit argv systemu (~128 KB). Krytycy, bramki i recenzenci dostają cały brief
w `-p`: powyżej ~100 KB podziel recenzję na części albo oddaj rolę innej rodzinie. `--input-format stream-json` to inny tryb
(zdarzenia na wyjściu; koperta przychodzi wewnątrz końcowego zdarzenia `result`) i nie jest tu
używany.

## Subagenci Claude

`Agent` z nadpisanym `model` i domyślnym `subagent_type`, ścieżka briefu w prompcie.
`subagent_type: "fork"` dziedziczy kontekst, ale **ignoruje** `model`. Runda poprawek kontynuuje tego
samego subagenta przez `SendMessage` na jego id (zapisane w `sessions.claude` checkpointu;
`SendMessage` to narzędzie ładowane z opóźnieniem — najpierw pobierz je przez `ToolSearch`); po
restarcie sesji tego id już nie ma i nowy subagent startuje z listy „do zrobienia" checkpointu i
aktualnego `git diff`.

## Odczyt wyników

Nigdy nie wczytuj całego `.jsonl` do kontekstu — log długiego buildu to dziesiątki tysięcy tokenów.
Bierz tylko to, czego potrzebujesz:

```bash
grep -m1 '"thread.started"' .route/build.jsonl                  # thread_id do wznowienia
grep '"turn.completed"' .route/build.jsonl | tail -1             # usage
grep -E '"turn.failed"' .route/build.jsonl | tail -3             # awaria, jeśli była
```

- **Codex:** odpowiedzią jest plik `-o`. `thread_id` i `usage` pochodzą z `.jsonl`. Zdarzenie
  `"type":"error"` o ponownym połączeniu albo 503 to Codex ponawiający strumień, nie awaria; awarią
  jest `turn.failed` albo zakończenie bez `turn.completed`.
- **agy:** jedna koperta JSON zapisywana w całości przy wyjściu. Sprawdzaj każde wywołanie:
  `status == "SUCCESS"`, `response != ""`, `(denied_actions ?? []) == []` (klucza nie ma, gdy nic
  nie odrzucono). `CANCELED` = odrzucona akcja narzędzia; `ERROR` + `"timeout waiting for
  response"` = wygasł `--print-timeout`. Każdy status inny niż `SUCCESS` unieważnia
  `conversation_id` — kontynuacja w **nowej** rozmowie z aktualnym `git diff`.
- **Wywołania ze schematem:** zdejmij płotki Markdown, usuń wstrzyknięte przez agy
  `toolAction`/`toolSummary`, sparsuj, zwaliduj względem schematu w `.route/`, dopiero potem działaj.
  Nigdy nie działaj na niezwalidowanym werdykcie.

## Próbkowanie postępu

Co 5 minut, przez `sleep 300` w tle albo `Monitor`, którego komenda wypisuje jedną linię na próbkę i
kończy się, gdy PID umrze — nigdy przez zakończenie tury. Maksymalny `timeout_ms` różni się między
wersjami Claude Code (w jednych 10 minut, w innych 30): odczytaj go ze schematu narzędzia, ustaw i
uzbrajaj monitor ponownie po każdym wygaśnięciu. Próbka jest zdrowa, gdy PID żyje (`kill -0`)
i ruszyło się jedno z poniższych:

- nowe zdarzenia w `.jsonl` Codeksa (licz linie, nie czytaj ich);
- urósł log CLI runu agy — zanotuj najnowszy `~/.gemini/antigravity-cli/log/cli-*.log` *przed*
  uruchomieniem, odpytuj, aż pojawi się nowszy, zapisz go i jego rozmiar jako punkt odniesienia
  (nigdy `.json` agy, zapisywany w całości przy wyjściu);
- zmienił się `git status`.

Cisza jest zwisem dopiero po `max(15 min, 2 × T_slow)` i nigdy dla runu testów. Przed zabiciem
przeczytaj pliki: stderr wypisuje `Reading additional input from stdin...` także przy zdrowych
runach; sygnałem zwisu jest ta linia **bez zdarzenia `thread.started`** — uruchom ponownie z
zamkniętym stdin. Brak nowego pliku w `~/.codex/sessions/` → awaria przy starcie (konkurencyjny
`app-server`; `codex doctor`). Zabijaj po PID (`ps -eo pid,etime,cmd | grep '[c]odex exec'` →
`kill <PID>`) albo przez zadanie harnessu.
