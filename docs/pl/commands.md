# Komendy uruchamiania

*Oryginał: [../commands.md](../commands.md).*

Przeczytaj to przed pierwszym zewnętrznym uruchomieniem w runie. `SKILL.md` trzyma niezmienniki;
ten plik trzyma dokładne linie.

## Zasady uruchamiania

- Każda tura modelu przez zewnętrzne CLI (`codex exec`, `agy -p`, które dociera do modelu) i każdy
  run testów idzie przez tryb tła narzędzia Bash (`run_in_background: true`), stdout i stderr
  przekierowane pod `.route/`. Krótkie sprawdzenia bez tury modelu (`codex login status`,
  `codex doctor`, `codex sandbox -- …`, `agy models`, `agy --version`, sonda `/skills`) idą na
  pierwszym planie, tak samo jak sprawdzenie efektywnej konfiguracji (poniżej). Workerzy Claude idą zamiast tego przez narzędzie `Agent` (sekcja „Subagenci
  Claude"). **Nigdy nie odłączaj w
  shellu** — bez końcowego `&`, `nohup`, `setsid`, `disown`: narzędzie wraca od razu, nie powstaje
  zadanie harnessu i powiadomienie o zakończeniu, które budzi dyrektora, nigdy nie przychodzi. Na
  proces, który musi przeżyć shell, czeka ta sama komenda w tle
  (`until ! kill -0 "$PID"; do sleep 20; done`).
- **Tryb konfiguracji Codeksa.** Każda linia Codeksa, exec i resume, niesie `--ignore-user-config`
  (**isolated**, domyślnie): `$CODEX_HOME/config.toml` nie jest czytany, więc jego serwery MCP,
  pluginy, domyślny effort, `personality`, `service_tier` i przede wszystkim
  `approvals_reviewer = "auto_review"` nigdy nie docierają do workera; uwierzytelnianie nadal
  pochodzi z `CODEX_HOME`. Etap 0 przełącza na **pinned**, gdy ten plik ustawia klucz połączenia albo
  uwierzytelniania (`docs/workers.md`, „Tryby konfiguracji"): linie niosą wtedy przypięcia z 3.2
  (sekcja „Tryb pinned"). Nigdy oba naraz — nadpisanie MCP serwera, który zdefiniował ignorowany
  plik, kończy się błędem przy starcie (`docs/troubleshooting.md`).
- **Szczebel 3** (`docs/sandbox-and-preflight.md`): każda linia tego workera, łącznie ze
  wznowieniami, dodaje `-c approvals_reviewer="auto_review"` — na 0.159.2 samo to zmienia
  `approval_policy` z `never` na `on-request` z automatyczną recenzją (zweryfikowane na exec i
  resume). `--approve-for-me` to forma flagi; implikuje `workspace-write` i nie łączy się z `-s`.
- Briefy są plikami; prompt to `"$(cat file)"`; **stdin zamknięty przez `< /dev/null`** — otwarty
  stdin (heredoc w tej samej komendzie) to jedyna potwierdzona przyczyna „zawieszonego" Codeksa.
- Linie poniżej to **szablony** z domyślnymi wartościami etapów. Przy każdym uruchomieniu i
  wznowieniu podstaw efektywny model i effort etapu po rozstrzygnięciu polityki (Gemini: sufiks
  sluga i `--effort` razem).

## Codex

```bash
# krytyka — read-only, kontekst osadzony w briefie
codex exec -m gpt-6.1-sol -s read-only --color never --json --ignore-user-config -c model_reasoning_effort=medium \
  --output-schema .route/critique-schema.json -o .route/critique.json \
  "$(cat .route/brief-critique.md)" < /dev/null > .route/critique.jsonl 2> .route/critique.stderr.log
#   wysoka stawka: -m gpt-6-astra -c model_reasoning_effort=high

# build — workspace-write
codex exec -m gpt-6.1-sol -s workspace-write --color never --json --ignore-user-config -c model_reasoning_effort=medium \
  -o .route/build.txt "$(cat .route/brief-build.md)" < /dev/null > .route/build.jsonl 2> .route/build.stderr.log

# wznowienie buildera — BEZ -s / --color / -C; sandbox przez -c; ZAWSZE UUID wątku z
# thread.started.thread_id w .jsonl runu. --last jest zakazane: bierze najnowszą
# sesję w cwd, niezależnie od tego, kto ją zaczął. Przed nim zapisz offset rollout (Odczyt wyników).
codex exec resume <THREAD_UUID> --ignore-user-config --json -m gpt-6.1-sol -c 'sandbox_mode="workspace-write"' \
  -c model_reasoning_effort=medium -o .route/fix1.txt \
  "$(cat .route/brief-fix1.md)" < /dev/null > .route/fix1.jsonl 2> .route/fix1.stderr.log
# krytyk, bramka albo recenzent zachowuje swoją rolę przy wznowieniu: read-only i swój schemat
codex exec resume <THREAD_UUID> --ignore-user-config --json -m gpt-6.1-sol -c 'sandbox_mode="read-only"' \
  -c model_reasoning_effort=medium \
  --output-schema .route/critique-schema.json -o .route/critique-r2.json \
  "$(cat .route/brief-critique-r2.md)" < /dev/null > .route/critique-r2.jsonl 2> .route/critique-r2.stderr.log

# runda poprawek wizualnych dla buildera Codex — zrzuty ekranu jako załączniki. Użyj --image=<png>[,<png>…]
# (albo --image <png> przed pozostałymi flagami): goły „-i shot.png" tuż przed promptem bierze
# prompt za drugi plik („No prompt provided via stdin", exit 1).
codex exec resume <THREAD_UUID> --ignore-user-config --json -m gpt-6.1-sol -c 'sandbox_mode="workspace-write"' \
  -c model_reasoning_effort=medium -o .route/fix2.txt \
  --image=.route/evidence/01-desktop-light.png,.route/evidence/03-mobile-light.png \
  "$(cat .route/brief-fix2.md)" < /dev/null > .route/fix2.jsonl 2> .route/fix2.stderr.log

# recenzja krzyżowa — read-only, z kontraktem: brief niesie specyfikację, PLAN.md, kryteria
# akceptacji, diff (w treści poniżej 40 KB, inaczej ścieżka; z nieśledzonymi plikami) i regułę
# werdyktu „approve wtedy i tylko wtedy, gdy nie ma znalezisk blocking ani major i każdy punkt planu
# jest zrobiony; drobne uwagi nigdy nie zmieniają werdyktu";
# effort = etap `review` (domyślnie high)
codex exec -m gpt-6.1-sol -s read-only --color never --json --ignore-user-config -c model_reasoning_effort=high \
  --output-schema .route/review-schema.json -o .route/review.json \
  "$(cat .route/brief-review.md)" < /dev/null > .route/review.jsonl 2> .route/review.stderr.log
# `codex exec review --uncommitted` ma własny wbudowany kontrakt i nie widzi planu: ręczny dodatek,
# nigdy recenzent krzyżowy.

# wywołanie próbne modelu (etap 0, krok 5) — jedno na slug, gdy .route/model-probes.json nie ma
# świeżego sukcesu
codex exec -m gpt-6.1-sol -s read-only --color never --json --ignore-user-config -c model_reasoning_effort=low \
  -o .route/probe-gpt-6.1-sol.txt "Reply with exactly: OK" \
  < /dev/null > .route/probe-gpt-6.1-sol.jsonl 2> .route/probe-gpt-6.1-sol.stderr.log
#   sukces = exit 0 i plik -o mówi OK; wtedy zapis w .route/model-probes.json:
#   {"gpt-6.1-sol": {"ok": true, "probed_at": "<czas ISO>", "codex_version": "<codex --version>",
#                    "identity": "<identity z $CODEX_HOME/models_cache.json>", "config_mode": "isolated"}}

# drafter kaskady
codex exec -m gpt-6-luna -s workspace-write --color never --json --ignore-user-config -c model_reasoning_effort=medium \
  -o .route/draft.txt "$(cat .route/brief-draft.md)" < /dev/null > .route/draft.jsonl 2> .route/draft.stderr.log
```

### Tryb pinned

Gdy etap 0 wybrał `pinned`, zrób jedną podmianę na każdej linii powyżej: zamień
`--ignore-user-config` na `-c approvals_reviewer="user"`, a na liniach read-only (krytyka,
bramka, recenzja, wywołanie próbne i ich wznowienia) dodaj też `-c mcp_servers.<name>.enabled=false`
dla każdego `[mcp_servers.<name>]` w `$CODEX_HOME/config.toml` (tu `perplexity` i `playwright`).
Writerzy zachowują serwery MCP z pliku, a każdy inny klucz pliku dociera do każdego workera; etap 0
raportuje te, które zmieniają szczebel albo koszt. Na przykład:

```bash
codex exec -m gpt-6.1-sol -s read-only --color never --json -c approvals_reviewer="user" -c model_reasoning_effort=medium \
  -c mcp_servers.perplexity.enabled=false -c mcp_servers.playwright.enabled=false \
  --output-schema .route/critique-schema.json -o .route/critique.json \
  "$(cat .route/brief-critique.md)" < /dev/null > .route/critique.jsonl 2> .route/critique.stderr.log
```

### Równoległe workery Codeksa

Tylko dla podziału, który plan czyni równoległym (SKILL.md, „Roster"). Dyrektor tworzy każdy worktree
przed startem, z `HEAD`; worker działa w nim z `-C`. Artefakty mają ścieżki bezwzględne, bo
wznowienie poniżej biegnie z katalogu worktree. Własne `--worktree` Codeksa nie jest używane: nie da
się go połączyć z `--ignore-user-config`.

```bash
REPO="$(git rev-parse --show-toplevel)"
git worktree add --detach "$REPO/.route/worktrees/part-a" HEAD        # po jednym na część; zapisz HEAD jako baseline

codex exec -C "$REPO/.route/worktrees/part-a" -m gpt-6.1-sol -s workspace-write --color never --json \
  --ignore-user-config -c model_reasoning_effort=medium -o "$REPO/.route/part-a.txt" \
  "$(cat "$REPO/.route/brief-part-a.md")" < /dev/null > "$REPO/.route/part-a.jsonl" 2> "$REPO/.route/part-a.stderr.log"

# wznowienie: codex exec resume nie ma -C i biegnie w cwd shella, więc startuj je z worktree
cd "$REPO/.route/worktrees/part-a" && codex exec resume <THREAD_UUID> --ignore-user-config --json -m gpt-6.1-sol \
  -c 'sandbox_mode="workspace-write"' -c model_reasoning_effort=medium -o "$REPO/.route/part-a-fix1.txt" \
  "$(cat "$REPO/.route/brief-part-a-fix1.md")" < /dev/null > "$REPO/.route/part-a-fix1.jsonl" 2> "$REPO/.route/part-a-fix1.stderr.log"

# przy raporcie, po ostatniej integracji
git worktree remove --force "$REPO/.route/worktrees/part-a" && git worktree prune
```

Granice edycji z briefu są względne wobec korzenia worktree. Integracja, commit `route-integrated`,
którego SHA staje się `baseline` sesji, i sprawdzenie `HEAD == baseline` przed następną deltą są w
SKILL.md, „Roster". Zweryfikowane na 0.159.2 z dwoma równoległymi writerami: każdy pisał tylko we
własnym worktree, checkout został czysty, wznowienie uruchomione z checkoutu działało w checkoucie
(więc nigdy tak nie rób), a uruchomione z worktree działało w worktree.

## agy

```bash
# --add-dir "$REPO" przy każdym wywołaniu, inaczej worker nie widzi skilli ani reguł projektu.
# Stuby mogą zaczynać się od "/<skill>", żeby wymusić wczytanie wiążącego skilla.
REPO="$(git rev-parse --show-toplevel)"

# krytyka — tryb plan, read-only, bez shella. CAŁY brief idzie w -p (bez stuba-wskaźnika: brief
# zakazuje czytania plików), zaczyna się akapitem „bez narzędzi"; werdykt to JSON wewnątrz
# payload.response. Ten sam kształt dla bramki (gate-schema) i recenzji (review-schema). Brief ponad
# ~100 KB dzieli się na części, każda to pełny brief dla swojego wycinka, jedno wywołanie na część;
# części łączy się tak, jak mówi sekcja „Briefs" w SKILL.md (wszystkie akceptują, findings to suma;
# bramki i recenzje łączą też pokrycie planu: done to suma, missing = punkty, których żadna część
# nie zgłosiła jako zrobione).
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

### Sprawdzenie efektywnej konfiguracji

Po każdym starcie Codeksa (gdy `thread.started` jest już w `.jsonl`) i po każdym wznowieniu potwierdź,
z czym worker naprawdę działa. Codex zapisuje plik rollout na wątek,
`$CODEX_HOME/sessions/YYYY/MM/DD/rollout-<time>-<thread_id>.jsonl`, z jednym rekordem `turn_context`
na turę: `model`, `effort`, `sandbox_policy`, `approval_policy`, `approvals_reviewer` i
`permission_profile`, który wylicza dostęp do sieci i każdy zapisywalny korzeń. Przed wznowieniem
zapisz liczbę linii rollout jako `rollout_offset` sesji (`wc -l < "$R"`); sprawdzenie czyta pierwszy
`turn_context` po nim, więc rekord wcześniejszej tury nigdy nie uchodzi za rekord wznowionej (start
używa 0). Uruchom je na pierwszym planie; czeka najwyżej dwie minuty:

```bash
# Sprawdzenie efektywnej konfiguracji. Ustaw THREAD (thread.started.thread_id), OFFSET (linie rollout
# przed tym startem albo wznowieniem; 0 dla startu) i oczekiwane wartości, potem uruchom na pierwszym
# planie (<= 2 min). Wypisuje OK, MISMATCH <pola> albo MISSING; wszystko poza OK zatrzymuje workera.
TC=""
for i in $(seq 25); do            # 24 oczekiwania po 5 s, potem jeszcze jeden odczyt (rollout przeżywa proces)
  R=$(find "${CODEX_HOME:-$HOME/.codex}/sessions" -name "rollout-*-$THREAD.jsonl")
  if [ "$(printf '%s' "$R" | grep -c .)" = 1 ]; then
    TC=$(tail -n +$((OFFSET + 1)) "$R" | grep -m1 '"type":"turn_context"')
  fi
  [ -n "$TC" ] || [ "$i" = 25 ] && break
  sleep 5
done
[ -z "$TC" ] && echo MISSING || printf '%s\n' "$TC" | jq -r \
  --arg model "$MODEL" --arg effort "$EFFORT" --arg sandbox "$SANDBOX" \
  --arg approval "$APPROVAL" --arg reviewer "$REVIEWER" --arg root "$ROOT" '
  .payload as $p | ($p.permission_profile // {}) as $pp
  | [ (if $p.model != $model then "model=\($p.model)" else empty end),
      (if $p.effort != $effort then "effort=\($p.effort)" else empty end),
      (if $p.sandbox_policy.type != $sandbox then "sandbox=\($p.sandbox_policy.type)" else empty end),
      (if $p.approval_policy != $approval then "approval_policy=\($p.approval_policy)" else empty end),
      (if $p.approvals_reviewer != $reviewer then "approvals_reviewer=\($p.approvals_reviewer)" else empty end),
      (if $sandbox == "danger-full-access" then
         (if $pp.type != "disabled" then "permission_profile=\($pp.type)" else empty end)
       elif $pp.type != "managed" or $pp.file_system.type != "restricted"
            or ($pp.file_system.entries | type) != "array" then
         "permission_profile=\($pp.type)/\($pp.file_system.type // "none")"
       else
         (if $pp.network != "restricted" then "network=\($pp.network)" else empty end),
         (if ($p.sandbox_policy | has("network_access")) then
            (if $p.sandbox_policy.network_access != false then "network_access=\($p.sandbox_policy.network_access)" else empty end)
          elif $sandbox != "read-only" then "network_access=missing" else empty end),
         ([$pp.file_system.entries[] | select(.access == "write")
           | if .path.type == "path" then .path.path else "special:\(.path.value.kind)" end
           | select(. != "special:slash_tmp" and . != "special:tmpdir")] as $w
          | if $sandbox == "read-only" then (if $w != [] then "writable=\($w | join(","))" else empty end)
            elif $w != [$root] then "writable=\($w | join(","))" else empty end)
       end) ]
  | if length == 0 then "OK" else "MISMATCH " + join(" ") end' || echo "MISMATCH malformed"
```

Oczekiwane wartości (`ROOT` = katalog, w którym worker pisze: checkout albo jego worktree dla workera
równoległego; puste dla read-only):

| Rola | `SANDBOX` | `APPROVAL` | `REVIEWER` | Sieć | Korzenie zapisu |
| --- | --- | --- | --- | --- | --- |
| krytyk, bramka, recenzent, wywołanie próbne | `read-only` | `never` | `user` | restricted | brak |
| builder, drafter, poprawki — szczebel 1 | `workspace-write` | `never` | `user` | restricted | tylko `ROOT` |
| szczebel 3 | `workspace-write` | `on-request` | `auto_review` | restricted | tylko `ROOT` |
| szczebel 4 | `danger-full-access` | `never` | `user` | niesprawdzane (`permission_profile.type: disabled`) | niesprawdzane |

`/tmp` i `$TMPDIR` są zapisywalnymi specjalnymi ścieżkami w każdym profilu z sandboxem i są
dozwolone; każda inna zapisywalna ścieżka specjalna (na przykład korzeń systemu plików) to
niezgodność. Tryb pinned daje te same wiersze — po to są przypięcia. Wiersz ledgera tego wywołania
dostaje sprawdzone pola jako `effective_config`.

Zweryfikowane na 0.159.2 na prawdziwych rollout — read-only, szczebel 1, szczebel 3 na exec i resume,
writer w worktree i jego wznowiona poprawka, szczebel 4, wznowienie na effortcie `medium` po starcie
na domyślnym effortcie katalogu — oraz na zmienionych kopiach: nieaktualny offset, zły effort,
`network_access: true`, sprzeczne pola sieci, brakująca albo nieograniczona sekcja systemu plików,
zapisywalny korzeń specjalny, ucięty JSON, brak rekordu, dwa rollout dla jednego id.

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
