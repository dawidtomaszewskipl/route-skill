# Workerzy i mechanika CLI

*Oryginał: [../workers.md](../workers.md).*

Wszystko poniżej sprawdzono na **Codex CLI 0.153.4** i **Antigravity CLI 1.1.27** w dniu
2026-09-06. Oba rostery i oba zestawy flag się zmieniają; sprawdzaj `codex exec --help`,
`codex exec resume --help`, `agy --help` i `agy models`, zamiast ufać tabeli, która się zestarzała.

## Rodzinę wyznacza model, nie CLI

Katalog Antigravity nie jest wyłącznie geminiowy:

```
$ agy models
gemini-3.8-flash-high     Gemini 3.8 Flash (High)
gemini-3.8-flash-medium   Gemini 3.8 Flash (Medium)
gemini-3.8-flash-low      Gemini 3.8 Flash (Low)
gemini-3.1-pro-high       Gemini 3.1 Pro (High)      ← nadal w katalogu, usunięty z rosteru route
claude-sonnet-4-6         Claude Sonnet 4.6 (Thinking)
claude-opus-4-6-thinking  Claude Opus 4.6 (Thinking)
gpt-oss-120b-medium       GPT-OSS 120B (Medium)
```

Wywołanie `agy` bez `--model` uruchamia domyślny model konta. Jeśli to model Claude'a, „Google
skrytykował plan Claude'a" było krytyką Claude'a przez Claude'a — i nic w outpucie tego nie mówi.
Codex zachowuje się tak samo: bierze model z `~/.codex/config.toml`, gdy brak `-m`.

**Dostępność jest wykrywana, nie zakładana.** Etap 0 sprawdza trzy różne rzeczy, bez żadnej tury
modelu: instalację (`command -v codex`, `command -v agy`), zalogowanie (`codex login status` —
wypisuje `Logged in using ChatGPT` i kończy się kodem 0; udane `agy models`, bo pobiera katalog) i
zdrowie (`codex doctor --summary`, exit 0 z `0 fail`, **uruchomione tam, gdzie będzie działał
worker** — ta sama zalogowana instalacja oblewa doctora wewnątrz sandboxa z nieosiągalnymi
endpointami). Porażka zdrowia czyni workera niedostępnym w tym środowisku, nie wylogowanym; żadne z
tych sprawdzeń nie dowodzi uprawnienia do konkretnego modelu. Reguła krzyżowa rozstrzyga potem w
obrębie rodzin, które naprawdę są; przy samym Claudzie każda rola zewnętrzna to inny model Claude'a
niż implementator, a run jest oznaczony jako zdegradowany. `--model` wskazujące niedostępną rodzinę
zatrzymuje pętlę pytaniem. Plik polityki (`docs/policy.md`) też może wyłączyć rodzinę.

**Podawaj `--model` / `-m` na każdym wywołaniu zewnętrznym. Zapisuj model żądany; model obsłużony
jest niezweryfikowany, dopóki go nie potwierdzisz** (cicha podmiana po stronie dostawcy przy
limitach to pogłoska, nie zweryfikowane zachowanie — realnym ryzykiem jest pominięcie `--model`).

## OpenAI — `codex exec`

### Modele

| Slug | Charakter | Efforty w katalogu | Domyślny |
| --- | --- | --- | --- |
| `gpt-6-astra` | Frontier (SWE, terminal, obsługa komputera); wymaga CLI ≥ 0.153.1 (wersja, której [release notes](https://learn.chatgpt.com/docs/changelog) dodały wpis Astry do katalogu; tu testowano 0.153.4) | `low medium high xhigh max ultra` | `medium` |
| `gpt-5.6-sol` | Niezawodny codzienny workhorse | `low … ultra` | `low` |
| `gpt-5.6-terra` | Zbalansowany codzienny | `low … ultra` | `medium` |
| `gpt-5.6-luna` | Szybki i tani | `low … max` | `medium` |
| `gpt-5.4-mini` | Mały, proste zadania | `low … xhigh` | `medium` |
| `gpt-5.3-codex-spark` | Ultraszybkie mechaniczne edycje | `low … xhigh` | `high` |

`ultra` to ustawienie katalogu Codexa („maksymalne rozumowanie z automatyczną delegacją zadań");
własna lista API kończy się na `max`. `none` jest odrzucane. Effort podaje się w linii poleceń jako
`-c model_reasoning_effort=<poziom>` — zawsze, bo domyślne różnią się między modelami.

### Specyfika Astry

- **Asynchroniczne pytania doprecyzowujące** istnieją w interaktywnym Codexie, ale binarka 0.153.4
  mówi wprost: `request_user_input is not supported in exec mode`. Worker nie zapyta w trakcie;
  może co najwyżej *zakończyć* pytaniem. Blok follow-through w briefie („nie pytaj; decyduj i
  zapisuj założenia") temu zapobiega.
- **Notatki kontekstu między oknami** (`features.context_management.experimental_mode`, domyślnie
  wyłączone; `codex features list` raportuje jako w budowie) zastępują wielokrotne kompaktowanie
  przeszukiwalnymi notatkami. Wymaga logowania ChatGPT na Plus/Pro/Pro Lite; sesje po kluczu API są
  wykluczone. Opcja dla bardzo długich buildów; nie ma jej w liniach kanonicznych.
- **Warstwa bezpieczeństwa.** Astra to pierwszy model OpenAI na progu Critical w cyberbezpieczeństwie:
  odmawia pracy nad exploitami proof-of-concept, a produkcyjne kontrole bezpieczeństwa mogą
  wstrzymać lub zatrzymać legalną pracę. `misalignment_policy_violation` albo jawna blokada
  bezpieczeństwa **nie podlega ponowieniu** — zatrzymaj dispatch, zachowaj checkpoint i `.jsonl`,
  zaraportuj. Tylko zwykła odmowa poza zakresem dostaje jeden przepisany brief.
- **Tier Fast.** `service_tier = "priority"` to tier Fast: 2× prędkość za 2× zużycie u Astry. Route
  zostawia go nieustawionym (standard). Profil `~/.codex/fast.config.toml` trzyma go dla użytku
  interaktywnego: `codex -p fast`. Obsłużony tier nie jest zapisywany w plikach sesji, więc nie da
  się go zaobserwować po fakcie.

### Flagi warte znajomości (`codex exec`)

| Flaga | Dlaczego ma znaczenie |
| --- | --- |
| `-o, --output-last-message <plik>` | Końcowa odpowiedź, dosłownie, zapisywana po stronie hosta — działa pod `-s read-only` (zweryfikowane). Czytaj to, nigdy ogon transkryptu. |
| `--json` | Strumień zdarzeń JSONL na stdout: `thread.started` (z `thread_id`), `turn.started`, `item.*`, `turn.completed` (z `usage`). Jedyny uczciwy sygnał postępu. Zwykły postęp idzie inaczej na **stderr** — przechwytuj go osobno. |
| `--output-schema <plik>` | Wymusza JSON Schema na końcowej odpowiedzi (typy, enumy, `required`, `additionalProperties:false`; bez pól nullable — zob. „Schematy"). |
| `-s <polityka>` | `read-only`, `workspace-write`, `danger-full-access`. Read-only nadal uruchamia komendy tylko do odczytu i nadal ładuje serwery MCP — to nie jest „bez narzędzi". |
| `-c mcp_servers.<nazwa>.enabled=false` | Wyłącza serwer MCP na jedno wywołanie. Zmierzona oszczędność tutaj ≈ 1 s na start krytyka (5,4 s → 4,5 s przy zbuforowanych serwerach `npx`); ma znaczenie, gdy serwer w ogóle nie może wystartować (kontenerowy kosztuje pełny `startup_timeout_sec`). |
| `--approve-for-me` | Prośby o eskalację oceniane automatycznie pod workspace-write — środkowy szczebel drabiny. |
| `-C, --cd <dir>` / `--add-dir <dir>` | Katalog roboczy i dodatkowe zapisywalne korzenie (tylko `exec` — nie na `resume`). |
| `-p, --profile <nazwa>` | Nakłada `$CODEX_HOME/<nazwa>.config.toml` na bazowy config. Profile mogą dodawać klucze, nie usuwać. |
| `--thread-source <źródło>` | Klasyfikacja nowego/rozwidlonego wątku (0.153). |
| `--ephemeral` | Bez pliku sesji — a więc bez wznowienia. |
| `-` jako prompt | Cały prompt ze stdin (`codex exec - < brief.md`); EOF go zamyka. Udokumentowane; nie jest transportem kanonicznym. |

**`codex exec resume` ma inny zestaw flag**: `-m`, `-c`, `--json`, `-o`, `--output-schema`,
`--last`, `--all` — ale **nie** `-s`, `--color`, `-C`, `--add-dir`. Sandbox idzie przez
`-c 'sandbox_mode="workspace-write"'`. Dwie sesje w sierpniu straciły po dwa okna 8–10 minut na
`error: unexpected argument '-s' found`.

**`--last` jest zakazane w automatyzacji.** Wznawia najnowszą zapisaną sesję w cwd — krytyka,
buildera albo sesję interaktywną, którą otworzyłeś w międzyczasie. Zawsze UUID wątku z
`thread.started.thread_id`.

**Review** ma własną podkomendę z własnym kontraktem. Zweryfikowane: `--json` i `-o` na niej
działają; jej `turn.completed.usage` raportuje zera, więc pola tokenów w ledgerze dla wywołań review
to `null`:

```bash
codex exec review --uncommitted -m gpt-5.6-sol -c model_reasoning_effort=high --json \
  -o .route/review.txt < /dev/null > .route/review.jsonl 2> .route/review.stderr.log
codex exec review --base main …          # względem gałęzi
codex exec review --commit <sha> …       # jeden commit
```

**Zdrowie**: `codex doctor` (`--summary`, `--json`) raportuje tryb auth, osiągalność dostawcy,
wersję zainstalowaną vs najnowszą i czy działa `app-server` w tle.

**Skille**: Codex odkrywa `~/.codex/skills`, `~/.agents/skills`, `~/.codex/skills/.system` i
`{cwd}/.agents/skills`, wstrzykuje nazwy + opisy i każe modelowi przeczytać cały `SKILL.md`
odpowiedniego skilla przed działaniem. Sonda Luną z projektu Laravel wymieniła wszystkie 14 skilli
projektu bez proszenia; sesje Sola same czytały `pest-testing` i `laravel-best-practices`. Mimo to
wymieniaj wiążące skille w briefie.

**Pułapki globalnego configu.** Każde `codex exec` startuje każdy serwer MCP z
`~/.codex/config.toml` (tutaj: perplexity i playwright przez `npx`) — wyłączaj je na liniach
krytyki. Projektowy `.codex/config.toml` może nieść profil `default_permissions`, który czyni
workspace tylko do odczytu niezależnie od `-s`, albo serwer MCP wchodzący do kontenerów, który nie
wystartuje w sandboxie (10 s kary przy każdym runie). Etap 0 go czyta i ostrzega.

## Google — `agy`

### Flagi

| Flaga | Dlaczego ma znaczenie |
| --- | --- |
| `--model <slug>` | Obowiązkowa na każdym wywołaniu (rodzina). Slug zawiera effort (`gemini-3.8-flash-high`). |
| `--effort low\|medium\|high` | Effort sesji. Musi zgadzać się ze slugiem — `…-high` z `--effort medium` przeczy samo sobie. |
| `--mode plan` | Tryb planowania tylko do odczytu — ustawienie krytyka. |
| `--mode accept-edits` | Automatycznie zatwierdza edycje, inne pytania zostawia — ustawienie buildu. |
| `--add-dir <repo>` | **Wymagane dla skilli i reguł projektu.** Tryb print nie traktuje cwd jako workspace: bez `--add-dir` worker widzi tylko 5 wbudowanych skilli. |
| `--print-timeout` | **Domyślnie 5 minut.** Wygaśnięcie zwraca `status:"ERROR"`, `error:"timeout waiting for response"`, exit 1 (statusu `TIMEOUT` nie ma). |
| `--output-format json` | Jedna koperta zapisana w całości przy wyjściu: `{conversation_id, status, response, duration_seconds, num_turns, usage, denied_actions?, json_schema?}`. |
| `--json-schema <schemat-lub-ścieżka>` | Schemat wymuszany na stringu `response`. agy dokleja do obiektu klucze `toolAction` i `toolSummary` — usuń je przed walidacją. |
| `--input-format stream-json` | Prompty NDJSON na stdin; **wymaga `--output-format stream-json`**. Zaobserwowane na 1.1.27: stdout to `{"event":"init","conversation_id":…,"init":{"model","cwd","tools":[…]}}`, potem `{"event":"result","result":{…ta sama koperta co przy `--output-format json`…}}`; linie wejściowe muszą mieć pole `"event"` (komunikat `{"type":"user",…}` jest odrzucany z `stream input message is missing the "event" field`). Inny tryb z innym parserem; route go nie używa. |
| `--conversation <id>` | Wznowienie po id. `-c`/`--continue` znaczy „najnowsza rozmowa" — wyścig, gdy tylko istnieją dwa runy. |
| `--dangerously-skip-permissions` | Zatwierdza wszystko. Raz zablokowane przez własny klasyfikator auto-mode Claude Code; route używa ustawień `--mode`. |
| `--agent <nazwa>` | Uruchamia własnego agenta; jego frontmatter Markdown może wstępnie załadować `skills:` — opcja, nieużywana przez route. |

### Uprawnienia headless — to, co gryzie

W trybie print każda akcja narzędzia, która wymagałaby pytania o uprawnienie, jest **automatycznie
odrzucana, a cała tura anulowana**:

```
$ agy --mode plan … -p "…run agy --help to verify…"
jetski: no output produced — a tool required the "command" permission that headless mode cannot
prompt for, so it was auto-denied. Add an allow-rule under permissions.allow in settings.json
(e.g. command(<target>)). Alternatively, re-run with --dangerously-skip-permissions …
{"status":"CANCELED","response":"","denied_actions":[{"action":"command","display_name":"RunCommand"}], …}   exit 0
```

Konsekwencje:

- **Krytyk** Gemini to recenzja tylko do odczytu bez wykonywania poleceń powłoki — czyta pliki i
  skille, nie uruchomi `git diff` ani testów. Brief niesie każdy fakt inline.
- **Builder** Gemini tylko edytuje. Brief mówi to wprost; testy i buildy odpala dyrektor. Jedna
  próba komendy przerywa run z `CANCELED`, exit 0 i pustą odpowiedzią.
- `denied_actions` jest **nieobecne**, gdy nic nie odmówiono — brak klucza traktuj jak `[]`.
- Żeby worker Gemini mógł uruchamiać konkretne komendy, udokumentowanym mechanizmem są reguły
  `permissions.allow` (`command(<cel>)`) w `~/.gemini/antigravity-cli/settings.json` —
  niezweryfikowane w route i szersze, niż route potrzebuje.

### Sprawdzenie payloadu, każde wywołanie

`status == "SUCCESS"` · `response != ""` · `(denied_actions ?? []) == []` · przy wywołaniach ze
schematem: zdejmij znaczniki Markdown, usuń `toolAction`/`toolSummary`, `JSON.parse`, zwaliduj.
Każdy status inny niż `SUCCESS` unieważnia `conversation_id` — historia może trzymać osierocone
wywołanie narzędzia; kontynuacja to nowa rozmowa z bieżącym `git diff`.

Udana koperta:

```json
{"conversation_id":"b538f8bb-…","status":"SUCCESS","response":"{…}",
 "duration_seconds":111.3,"num_turns":1,
 "usage":{"input_tokens":52238,"output_tokens":33649,"thinking_tokens":29804,
          "cache_read_tokens":240719,"total_tokens":85887}}
```

### Rozmiar promptu

Brief 34 KB przez `-p` przeszedł bez problemu na 1.1.27 (16,5 tys. tokenów wejścia). Granicą jest
limit argv systemu (~128 KB na argument w Linuksie: `Argument list too long`). Route i tak używa
stubu-wskaźnika — trzyma prompty małe i wolne od wypadków z cudzysłowami. `-p` nie czyta stdin.

### Skille

Odkrywanie: `{workspace}/.agents/skills/<nazwa>/SKILL.md` i `~/.gemini/config/skills/<nazwa>/`.
Wstrzykiwane są nazwy + opisy; model dostaje polecenie, że MUSI przeczytać odpowiedni `SKILL.md`
przed działaniem. `agy --add-dir "$REPO" --output-format json -p "/skills"` pokazuje, co worker
zobaczy, bez wydawania tury modelu. Prefiks `/<skill>` w promptcie rozwija ten skill dosłownie
(zweryfikowane: `-p "/xui-development …"` zwróciło `name` skilla i pierwszy nagłówek; koszt = cały
`SKILL.md` w tokenach wejścia).

## Claude — subagenci

`Agent` z jawnym `model` i domyślnym `subagent_type`. `subagent_type: "fork"` dziedziczy kontekst,
ale **ignoruje** `model`. Brak pokrętła effortu — pokrętłem jest wybór modelu. Równolegli piszący
subagenci potrzebują `isolation: "worktree"`.

## Schematy

`docs/schemas/critique-schema.json` i `docs/schemas/gate-schema.json` to wspólny dialekt, który
przyjmują zarówno `--output-schema` (JSON Schema, tryb ścisły: każda właściwość w `required`,
`additionalProperties:false`), jak i `--json-schema` (styl OpenAPI 3.0, odrzuca
`["integer","null"]`) — zweryfikowane na obu CLI tym samym plikiem. Reguła, która to umożliwia:
**żadnych pól nullable**. `line: 0` i `escalate_reason: ""` znaczą „brak"; opcjonalne listy to puste
tablice. Oba schematy mają pole `assumptions[]`, do którego blok follow-through kieruje założenia
przy wywołaniach ze schematem.

## Briefy

Zapisz brief do pliku w `.route/` i przekaż `"$(cat plik)"` z `< /dev/null`. Zewnętrzni workerzy
startują na zimno. Działający brief niesie: ścieżki bezwzględne; jawne granice zmian; pliki
konwencji projektu; wiążące skille po nazwie; jak wygląda „gotowe" i która komenda to dowodzi;
kontrakt wyjścia. Blokowa struktura (zadanie / granice / weryfikacja / wyjście), nie proza.
Rdzeniem briefu buildu jest `.route/PLAN.md`.
