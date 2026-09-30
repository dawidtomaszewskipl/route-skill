# Workerzy i mechanika CLI

*Oryginał: [../workers.md](../workers.md).*

Wszystko poniżej sprawdzono najpierw na **Codex CLI 0.153.4** i **Antigravity CLI 1.1.27** w dniu
2026-09-06; katalogi i flagi używane przez route sprawdzono ponownie na **Codex CLI 0.155.1** i
**agy 1.2.8** 2026-09-22, a stronę Codeksa jeszcze raz na **Codex CLI 0.159.2** 2026-09-30 (fakty o
agy nadal pochodzą z 1.2.8). Oba rostery i oba zestawy flag się zmieniają; sprawdzaj `codex exec --help`,
`codex exec resume --help`, `agy --help` i `agy models`, zamiast ufać tabeli, która się zestarzała.

## Rodzinę wyznacza model, nie CLI

Katalog Antigravity nie jest wyłącznie geminiowy:

```
$ agy models
gemini-3.8-flash-high     Gemini 3.8 Flash (High)
gemini-3.8-flash-medium   Gemini 3.8 Flash (Medium)
gemini-3.8-flash-low      Gemini 3.8 Flash (Low)
gemini-3.7-flash-high     Gemini 3.7 Flash (High)    ← starsze generacje Flash, także -medium/-low
gemini-3.6-flash-high     Gemini 3.6 Flash (High)
gemini-3.1-pro-high       Gemini 3.1 Pro (High)      ← nadal w katalogu (i -low), usunięty z rosteru route
claude-sonnet-4-6         Claude Sonnet 4.6 (Thinking)
claude-opus-4-6-thinking  Claude Opus 4.6 (Thinking)
gpt-oss-120b-medium       GPT-OSS 120B (Medium)
```

W katalogu agy nie ma modelu Claude'a nowszego niż 4.6 — Opus 5.5 jest dostępny wyłącznie jako
subagent Claude Code. Wywołanie `agy` bez `--model` uruchamia domyślny model konta. Jeśli to model Claude'a, „Google
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

Katalog Codex CLI **0.159.2**, odczytany z `~/.codex/models_cache.json` 2026-09-30 (wpisy
z `visibility: list`, w kolejności priorytetu katalogu):

| Slug | Slot route | Efforty w katalogu | Domyślny |
| --- | --- | --- | --- |
| `gpt-6.1-sol` | `sol` — „najnowszy workhorse do kodowania i codziennej pracy" | `low … ultra` | **`low`** |
| `gpt-6-astra` | `astra` — frontier, „do najbardziej wymagającej pracy" | `low … ultra` | `medium` |
| `gpt-6-sol` | — (poprzedni Sol, „workhorse poprzedniej generacji") | `low … ultra` | `medium` |
| `gpt-6-luna` | `luna` | `low … max` | `medium` |
| `gpt-5.6-sol` | — (starszy Sol) | `low … ultra` | `low` |
| `gpt-5.6-terra` | `terra` — przestarzały, tylko jawne `--model` | `low … ultra` | `medium` |
| `gpt-5.6-luna` | — (starsza Luna) | `low … max` | `medium` |
| `gpt-5.5` | — (katalog mówi, że znika 2026-10-14) | `low … xhigh` | `medium` |

**GPT-6.1 Sol** (`gpt-6.1-sol`) został wydany 2026-09-29 i od route 3.3 jest slotem `sol`.
Ogłoszenie OpenAI ([Introducing GPT-6.1 Sol](https://openai.com/index/introducing-gpt-6-1-sol/))
mówi, że „nearly matches GPT-6 Astra's intelligence on agentic coding, computer use, and professional
work at one-fifth of Astra's standard input and output token prices": na DeepSWE v1.1 dorównuje
Astrze przy około jednej piątej kosztu i bije najlepszy wynik GPT-6 Sola o 6,4 punktu przy niższym
effortcie; ceny API to 2 USD za wejście, 0,10 USD za wejście z cache i 10 USD za wyjście za milion
tokenów. To liczby dostawcy, nie route: route mierzył dotąd GPT-6 Sola tylko jako krytyka, a rubryka
nie ruszy, dopóki ledger nie pokaże buildów Sola. „GPT-6.1 Sol Ultrafast" zapowiedziano na
najbliższe dni; nie ma go w katalogu 0.159.2. Jego domyślny effort w katalogu to `low`, gdzie u
GPT-6 Sola było `medium` — route przypina effort na każdej linii, a linia bez przypięcia działa na
tym, co mówi config użytkownika (`xhigh` na maszynie autora) albo, w trybie isolated, na tym domyślnym
efforcie katalogu. Próbne wywołanie read-only kosztowało 18 585 tokenów wejścia (12 288 z cache) i 8 s
2026-09-30. GPT-6 Luna zachowuje swój slot; jej mocne strony względem Astry też nie są jeszcze
zmierzone. GPT-6 Terra nie istnieje; slot `terra` zostaje na 5.6 i wypada z rubryki.

**Katalog to lista kandydatów, nie dowód.** `$CODEX_HOME/models_cache.json` (domyślnie `~/.codex`)
to migawka: ma `fetched_at`, `client_version` i `identity` konta, więc brakujący albo stary cache nie
mówi nic o potrzebie aktualizacji, a model z listy konto nadal może dostać odmowę. Dowodem jest więc
zapamiętane wywołanie próbne: `.route/model-probes.json` (zachowywany między runami) trzyma ostatnie
udane wywołanie próbne każdego sluga razem z `codex --version`, `identity` katalogu i trybem
konfiguracji, przy których się odbyło. Etap 0 uznaje slot za użyteczny, gdy ten wpis ma mniej niż
7 dni i wszystkie trzy nadal się zgadzają; w przeciwnym razie robi jedno wywołanie próbne
read-only z przypiętym modelem i effortem, w trybie konfiguracji runu
(`-c model_reasoning_effort=low`, „Reply with exactly: OK" — około 18,6 tys. tokenów wejścia
2026-09-30; `docs/commands.md`). Tylko błąd mówiący, że klient nie zna modelu, znaczy „zaktualizuj
Codex". Minimalne wersje dezaktualizują się przy każdym nowym modelu (dla Astry było to 0.153.1).

`ultra` to ustawienie katalogu Codexa („maksymalne rozumowanie z automatyczną delegacją zadań");
własna lista API kończy się na `max`. `none` jest odrzucane. Effort podaje się w linii poleceń jako
`-c model_reasoning_effort=<poziom>` — zawsze, bo domyślne różnią się między modelami.

### Specyfika Astry i GPT-6.1 Sol

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
  wstrzymać lub zatrzymać legalną pracę. GPT-6.1 Sol traktuje się tak samo — Critical w
  cyberbezpieczeństwie, ten sam stos zabezpieczeń co Astra ([system card addendum](https://deploymentsafety.openai.com/gpt-6-1-sol),
  2026-09-29). `misalignment_policy_violation` albo jawna blokada
  bezpieczeństwa **nie podlega ponowieniu** — zatrzymaj dispatch, zachowaj checkpoint i `.jsonl`,
  zaraportuj. Tylko zwykła odmowa poza zakresem dostaje jeden przepisany brief.
- **Tier Fast.** `service_tier = "priority"` to tier Fast: 2× prędkość za 2× zużycie u Astry;
  dla GPT-6.1 Sol katalog mówi „2x speed, increased usage" (GPT-6 Sol i Luna: 1,5×). Route zostawia
  go nieustawionym (standard) — tryb isolated go nie odziedziczy; tryb pinned dziedziczy
  `service_tier` ustawiony w `config.toml`, a etap 0 to raportuje. Profil `~/.codex/fast.config.toml`
  trzyma go dla użytku interaktywnego: `codex -p fast`. Obsłużony tier nie jest zapisywany w plikach sesji, więc nie da
  się go zaobserwować po fakcie.

### Flagi warte znajomości (`codex exec`)

| Flaga | Dlaczego ma znaczenie |
| --- | --- |
| `-o, --output-last-message <plik>` | Końcowa odpowiedź, dosłownie, zapisywana po stronie hosta — działa pod `-s read-only` (zweryfikowane). Czytaj to, nigdy ogon transkryptu. |
| `--json` | Strumień zdarzeń JSONL na stdout: `thread.started` (z `thread_id`), `turn.started`, `item.*`, `turn.completed` (z `usage`). Jedyny uczciwy sygnał postępu. Zwykły postęp idzie inaczej na **stderr** — przechwytuj go osobno. |
| `--output-schema <plik>` | Wymusza JSON Schema na końcowej odpowiedzi (typy, enumy, `required`, `additionalProperties:false`; bez pól nullable — zob. „Schematy"). |
| `-s <polityka>` | `read-only`, `workspace-write`, `danger-full-access`. Read-only nadal uruchamia komendy tylko do odczytu i nadal ładuje serwery MCP — to nie jest „bez narzędzi". |
| `--ignore-user-config` | Pomija `$CODEX_HOME/config.toml`; uwierzytelnianie nadal pochodzi z `CODEX_HOME`. Domyślna flaga route (tryb isolated, „Tryby konfiguracji" niżej); `exec` i `resume`. Nadpisania `-c` nadal działają, ale to, które wskazuje serwer MCP zdefiniowany tylko w ignorowanym pliku, czyni plik nieważnym przy starcie (`invalid transport in mcp_servers.<name>`, exit 1). |
| `-c mcp_servers.<nazwa>.enabled=false` | Tylko tryb pinned: wyłącza serwer MCP na jedno wywołanie. Zmierzona oszczędność tutaj ≈ 1 s na start krytyka (5,4 s → 4,5 s przy zbuforowanych serwerach `npx`); ma znaczenie, gdy serwer w ogóle nie może wystartować (kontenerowy kosztuje pełny `startup_timeout_sec`). |
| `--approve-for-me` | Szczebel 3 jako flaga: `approval_policy` `on-request` z automatyczną recenzją, implikuje `workspace-write` i nie łączy się z `-s` (0.159.2: „the argument '--sandbox' cannot be used with '--approve-for-me'"). Route używa równoważnego `-c approvals_reviewer="auto_review"`, które działa też na `resume`. |
| `--image=<plik>[,<plik>…]` (`-i`) | Dołącza obrazy do promptu, na `exec` i `resume`. Opcja przyjmuje kilka wartości, więc `-i shot.png "prompt"` połyka prompt jako drugi plik („No prompt provided via stdin", exit 1); użyj `--image=` albo wstaw `--image <plik>` przed pozostałe flagi. Zweryfikowane z jednym i z dwoma obrazami. |
| `-C, --cd <dir>` / `--add-dir <dir>` | Katalog roboczy i dodatkowe zapisywalne korzenie (tylko `exec` — nie na `resume`, który działa w cwd shella). Worktree workera równoległego idzie w `-C`. |
| `-p, --profile <nazwa>` | Nakłada `$CODEX_HOME/<nazwa>.config.toml` na bazowy config. Profile mogą dodawać klucze, nie usuwać. |
| `--thread-source <źródło>` | Klasyfikacja nowego/rozwidlonego wątku (0.153). |
| `--ephemeral` | Bez pliku sesji — a więc bez wznowienia. |
| `-` jako prompt | Cały prompt ze stdin (`codex exec - < brief.md`); EOF go zamyka. Udokumentowane; nie jest transportem kanonicznym. |

**Nieużywane, z powodem** (0.159.2):

| Flaga | Dlaczego route ją pomija |
| --- | --- |
| `--worktree` (exec, resume, review) | Worktree zarządzane przez Codex pod `$CODEX_HOME/worktrees/<id>/<repo>`, odłączony HEAD. Nie da się go połączyć z `--ignore-user-config` (zweryfikowane), więc wciągnęłoby cały config użytkownika do każdego równoległego writera. Route sam tworzy worktree i przekazuje je przez `-C` (`docs/commands.md`, „Równoległe workery Codeksa"). |
| `codex exec fork <id>` | Kopiuje kontekst wątku do nowego. Route kontynuuje rolę przez `resume`; rozwidlenie krytyka w recenzenta przeniosłoby wnioski krytyka do czegoś, co ma być niezależną lekturą. |
| `--strict-config` | Zamienia nieznany klucz w `config.toml` w awarię startu. Tryb isolated nie czyta pliku; tryb pinned nie powinien padać na własnych kluczach użytkownika. |
| `--enable` / `--disable <feature>` | Skrót dla `-c features.<name>=…`. Nic, co route musiałby przełączać: sesje exec niosą narzędzia multi-agent, ale mają instrukcję, by nie uruchamiać subagentów bez prośby, a briefy route nigdy o to nie proszą; automatyczna delegacja `ultra` pozostaje nieużywana. |
| `--ignore-rules` | Pomija `.rules` execpolicy użytkownika i projektu — siatka bezpieczeństwa, której route nie zdejmuje. |
| `--dangerously-bypass-hook-trust`, `--dangerously-bypass-approvals-and-sandbox` | To nie szczeble; zdejmują zabezpieczenia przeznaczone dla hostów już sandboxowanych. |

Reszta DevDay 2026 leży poza `codex exec`, więc route nie ma z niej czego przyjąć: współdzielone
**chmurowe środowiska deweloperskie** i **Dots** (stale działający agenci z własnym komputerem w
chmurze) działają w chmurze OpenAI, a nie w checkoucie, który dyrektor bramkuje i commituje;
**Agents API** to runtime do budowy własnych aplikacji agentowych, nie CLI uruchamiane przez
dyrektora; `/agents`, lepsza obsługa worktree i **sterowanie głosem** to funkcje interaktywnego
TUI. Chmurowe **Code Review** Codeksa opisuje „Review" niżej.

**`codex exec resume` ma inny zestaw flag** (0.159.2): `-m`, `-c`, `--json`, `-o`,
`--output-schema`, `--ignore-user-config`, `-i`/`--image`, `--last`, `--all`, `--ephemeral`,
`--enable`/`--disable`, `--strict-config`, `--ignore-rules`, `--skip-git-repo-check`,
`--thread-source`, `--worktree` i dwie flagi `--dangerously-…` — ale **nie** `-s`, `--color`,
`-C`, `--add-dir`, `--approve-for-me`. Sandbox idzie przez `-c 'sandbox_mode="workspace-write"'`;
katalogiem roboczym jest cwd shella. Id może być UUID-em albo nazwą wątku. Dwie sesje w sierpniu
straciły po dwa okna 8–10 minut na `error: unexpected argument '-s' found`.

**`--last` jest zakazane w automatyzacji.** Wznawia najnowszą zapisaną sesję w cwd — krytyka,
buildera albo sesję interaktywną, którą otworzyłeś w międzyczasie. Zawsze UUID wątku z
`thread.started.thread_id`.

**Review** ma własną podkomendę z własnym wbudowanym kontraktem — widzi diff, ale nie plan ani
kryteria akceptacji, więc recenzentem krzyżowym route jest `codex exec` read-only z briefem recenzji i
`review-schema.json` (`docs/commands.md`); `codex exec review` zostaje ręcznym dodatkiem. Zweryfikowane: `--json` i `-o` na niej
działają; jej `turn.completed.usage` raportuje zera, więc pola tokenów w ledgerze dla wywołań review
to `null`:

```bash
codex exec review --uncommitted -m gpt-6.1-sol --ignore-user-config -c model_reasoning_effort=high --json \
  -o .route/review.txt < /dev/null > .route/review.jsonl 2> .route/review.stderr.log
codex exec review --base main …          # względem gałęzi
codex exec review --commit <sha> …       # jeden commit
```

Przyjmuje tryb konfiguracji runu jak każda inna linia (`--ignore-user-config` jest w jego pomocy na
0.159.2; w trybie pinned obowiązuje podmiana z „Tryb pinned" w `docs/commands.md`).

Chmurowe **Code Review** Codeksa (DevDay 2026) recenzuje wypchnięty PR z GitHuba albo MR z GitLaba
tak samo — z własnym kontraktem, bez planu — więc to też ręczny dodatek, nigdy recenzent krzyżowy.

**Zdrowie**: `codex doctor` (`--summary`, `--json`) raportuje tryb auth, osiągalność dostawcy,
wersję zainstalowaną vs najnowszą i czy działa `app-server` w tle.

**Skille**: Codex odkrywa `~/.codex/skills`, `~/.agents/skills`, `~/.codex/skills/.system` i
`{cwd}/.agents/skills`, wstrzykuje nazwy + opisy i każe modelowi przeczytać cały `SKILL.md`
odpowiedniego skilla przed działaniem. Sonda Luną z projektu Laravel wymieniła wszystkie 14 skilli
projektu bez proszenia; sesje Sola same czytały `pest-testing` i `laravel-best-practices`. Mimo to
wymieniaj wiążące skille w briefie.

### Tryby konfiguracji

Każde `codex exec` czyta `$CODEX_HOME/config.toml`, o ile mu się tego nie zabroni, a ten plik sięga
dalej, niż się wydaje: na maszynie autora startuje dwa serwery MCP przez `npx`, ładuje plugin,
ustawia `personality`, `model_context_window = 1000000` i `model_reasoning_effort = "xhigh"`
(nieprzypięty worker działał na `xhigh`) oraz ustawia `approvals_reviewer = "auto_review"` — co na
0.159.2 samo zmienia `approval_policy` z `never` na `on-request` z automatyczną recenzją: szczebel 3
w przebraniu (zweryfikowane 2026-09-30). Route uruchamia więc Codeksa w jednym z dwóch trybów,
ustalanym w etapie 0, krok 3:

- **isolated** (domyślnie) — `--ignore-user-config` na każdej linii, exec i resume: nic z pliku nie
  dociera do workera; uwierzytelnianie nadal pochodzi z `CODEX_HOME`.
- **pinned** (awaryjnie) — forma z 3.2: `-c approvals_reviewer="user"` na każdej linii i jedno
  `-c mcp_servers.<name>.enabled=false` na serwer na liniach read-only. Wszystko inne w pliku
  dociera do workera, także serwery MCP u writerów, a etap 0 raportuje, co zmienia szczebel albo
  koszt (`approval_policy`, `sandbox_mode`, klucze uprawnień, `service_tier`).

Pinned wybiera się, gdy plik ustawia klucz decydujący, gdzie albo jak Codex się łączy lub
uwierzytelnia, bo jego pominięcie zepsułoby workera albo po cichu zmieniło konto:
`model_provider`, tabela `[model_providers.<id>]`, `openai_base_url`, `chatgpt_base_url`,
`cli_auth_credentials_store`, `forced_login_method`, `forced_chatgpt_workspace_id` — i, zachowawczo,
każdy inny klucz, którego nazwa zawiera `base_url`, `provider`, `login`, `auth`, `credential` albo
`proxy` (poza tabelami `mcp_servers`, `projects`, `tui` i `plugins`). `model_provider`,
`[model_providers]`, `openai_base_url` i `cli_auth_credentials_store` są w referencji konfiguracji
Codeksa; `chatgpt_base_url`, `forced_login_method` i `forced_chatgpt_workspace_id` znaleziono w
binarce 0.159.2 obok `cli_auth_credentials_store`. Korporacyjny pakiet CA to zmienna środowiskowa
(`CODEX_CA_CERTIFICATE`, `SSL_CERT_FILE`) i przeżywa tryb isolated. Linia Assign podaje tryb i klucz,
który go wymusił.

Czego żadna flaga nie usuwa: każda sesja exec niesie około 18,6 tys. tokenów wejścia wstrzykniętego
kontekstu — lista skilli z `~/.codex/skills`, `~/.agents/skills` i `.system` (tu ~20 KB),
`~/.codex/AGENTS.md`, lista zalecanych pluginów i instrukcje multi-agent (zmierzone identycznie z
`--ignore-user-config` i bez).

**Projektowy** `.codex/config.toml` może nieść profil `default_permissions`, który czyni workspace
tylko do odczytu niezależnie od `-s`, albo serwer MCP wchodzący do kontenerów, który nie wystartuje
w sandboxie (10 s kary przy każdym runie). Etap 0 go czyta i ostrzega w obu trybach. Czy tryb
isolated nadal ładuje plik zaufanego projektu, jest niezweryfikowane: w tymczasowym repozytorium testowym
zaufanym przez `-c 'projects."<path>".trust_level="trusted"'` projektowy `model_reasoning_effort` nie
został zastosowany przy configu użytkownika (wygrał `xhigh` użytkownika) ani bez niego (2026-09-30).

**Efektywna** konfiguracja nie jest kwestią zaufania: po każdym starcie i wznowieniu dyrektor
odczytuje ją z pliku rollout sesji (`docs/commands.md`, „Sprawdzenie efektywnej konfiguracji").

## Google — `agy`

### Flagi

| Flaga | Dlaczego ma znaczenie |
| --- | --- |
| `--model <slug>` | Obowiązkowa na każdym wywołaniu (rodzina). Slug zawiera effort (`gemini-3.8-flash-high`). |
| `--effort low\|medium\|high` | Effort sesji. Musi zgadzać się ze slugiem — `…-high` z `--effort medium` przeczy samo sobie. |
| `--mode plan` | Tryb planowania tylko do odczytu — ustawienie krytyka. |
| `--mode accept-edits` | Automatycznie zatwierdza edycje, inne pytania zostawia — ustawienie buildu. |
| `--add-dir <repo>` | **Wymagane dla skilli i reguł projektu.** Tryb print nie traktuje cwd jako workspace: bez `--add-dir` worker widzi tylko 5 wbudowanych skilli. |
| `--print-timeout` | **Zawsze go ustawiaj.** Do wersji 1.1.x domyślnie było 5 minut; 1.2.8 ma domyślnie `0`, czyli czeka do końca tury. Wygaśnięcie zwraca `status:"ERROR"`, `error:"timeout waiting for response"`, exit 1 (statusu `TIMEOUT` nie ma). |
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

- **Krytyk, bramka albo recenzent** Gemini niczego nie czyta: brief zakazuje narzędzi (sięgnięcie po
  serwer MCP opróżnia odpowiedź — troubleshooting), więc cały brief idzie w `-p`, z każdym faktem i
  każdą konwencją, według której ma oceniać, zacytowaną w treści. Powyżej ~100 KB podziel recenzję
  albo oddaj rolę innej rodzinie.
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
limit argv systemu (~128 KB na argument w Linuksie: `Argument list too long`). Builderzy i
drafterzy dostają stub-wskaźnik — trzyma prompty małe i wolne od wypadków z cudzysłowami. Krytycy,
bramki i recenzenci dostają cały brief w `-p`, bo ich brief zakazuje czytania plików; powyżej ~100 KB
jest dzielony. `-p` nie czyta stdin.

### Skille

Odkrywanie: `{workspace}/.agents/skills/<nazwa>/SKILL.md` i `~/.gemini/config/skills/<nazwa>/`.
Wstrzykiwane są nazwy + opisy; model dostaje polecenie, że MUSI przeczytać odpowiedni `SKILL.md`
przed działaniem. `agy --add-dir "$REPO" --output-format json -p "/skills"` pokazuje, co worker
zobaczy, bez wydawania tury modelu. Prefiks `/<skill>` w promptcie rozwija ten skill dosłownie
(zweryfikowane: `-p "/xui-development …"` zwróciło `name` skilla i pierwszy nagłówek; koszt = cały
`SKILL.md` w tokenach wejścia).

## Claude — subagenci

`Agent` z jawnym `model` i domyślnym `subagent_type`. `subagent_type: "fork"` dziedziczy kontekst,
ale **ignoruje** `model`. Wywołanie nie ma pokrętła effortu — pokrętłem jest wybór modelu. Równolegli
piszący subagenci potrzebują `isolation: "worktree"`; ich briefy podają ścieżki względem korzenia
worktree, nigdy bezwzględne ścieżki checkoutu; wynik każdego worktree dyrektor sam włącza do
checkoutu i trzyma worktree do raportu (SKILL.md, „Roster").

| Slot | Model (2026-09-22) | Uwagi dla dyrektora |
| --- | --- | --- |
| `opus` | Opus 5.5 (`claude-opus-5-5`) | Alias wskazuje najnowszego Opusa. $4 / $20 za MTok (Opus 5: $5 / $25), odczyt cache $0.20. Według Anthropic zyskuje głównie na wieloetapowej pracy w realnym repozytorium i na code review (więcej błędów, mniej fałszywych alarmów), zużywając mniej tokenów na ukończone zadanie, i znacznie dokładniej czyta zrzuty ekranu, wykresy i diagramy. Myślenie jest zawsze włączone; przy tym samym effortcie myśli więcej niż Opus 5. Raporty pisze wprost: co zrobił i czego potrzebuje. |
| `fable` | Fable 5.1 | Najmocniejszy i najdroższy ($10 / $50). Długie tury przy trudnych zadaniach. Użytkownicy wycofali go z ról wykonawczych przez zużycie tokenów; zostaje do najtrudniejszej poprawności i dużych przebudów UI. |
| `sonnet` | Sonnet 5 | Mechaniczne buildy oparte na konwencjach. |
| `haiku` | Haiku 4.5 | Masowe edycje bez decyzji; drafter kaskady przy samym Claudzie. |

Ustawienie effortu per model w Claude Code (`modelSettings` w `settings.json`) jest kluczowane id
modelu: wpis dla `claude-opus-5` nic nie mówi o `claude-opus-5-5`. Czy w ogóle dociera do subagentów —
niezweryfikowane; route traktuje effort subagenta jako nieznany i go nie zapisuje.

## Schematy

`docs/schemas/critique-schema.json`, `gate-schema.json` i `review-schema.json` to wspólny dialekt, który
przyjmują zarówno `--output-schema` (JSON Schema, tryb ścisły: każda właściwość w `required`,
`additionalProperties:false`), jak i `--json-schema` (styl OpenAPI 3.0, odrzuca
`["integer","null"]`) — zweryfikowane na obu CLI tym samym plikiem (krytyka i bramka; recenzja
używa tych samych konstrukcji). Reguła, która to umożliwia:
**żadnych pól nullable**. `line: 0` i `escalate_reason: ""` znaczą „brak"; opcjonalne listy to puste
tablice. Wszystkie trzy mają pole `assumptions[]`, do którego blok follow-through kieruje założenia
przy wywołaniach ze schematem.

## Briefy

Zapisz brief do pliku w `.route/` i przekaż `"$(cat plik)"` z `< /dev/null`. Zewnętrzni workerzy
startują na zimno. Działający brief niesie: ścieżki bezwzględne (worker w worktree: odwołania do
plików i granice edycji względne wobec korzenia jego worktree, artefakty pod bezwzględnymi ścieżkami
`$REPO/.route/…`); jawne granice zmian; pliki
konwencji projektu; wiążące skille po nazwie; jak wygląda „gotowe" i która komenda to dowodzi;
kontrakt wyjścia. Blokowa struktura (zadanie / granice / weryfikacja / wyjście), nie proza.
Rdzeniem briefu buildu jest PLAN.md tego runu.
