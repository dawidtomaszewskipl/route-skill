# Sandbox i pre-flight

*Oryginał: [../sandbox-and-preflight.md](../sandbox-and-preflight.md).*

Przekazanie zadania zewnętrznemu workerowi zawodzi w jeden konkretny, możliwy do uniknięcia
sposób: worker przyjmuje brief, pracuje jakiś czas, po czym melduje, że nie mógł uruchomić komendy
weryfikacyjnej projektu — bo nigdy nie miał do niej dostępu. Twoja powłoka miała. Sandbox, w
którym działa worker, nie.

Sprawdź najpierw. To nic nie kosztuje.

## Sprawdź zasięg workera bez wywoływania modelu

`codex sandbox` uruchamia dowolną komendę pod tą samą polityką sandboxa, którą zastosowałby
`codex exec`, bez modelu w pętli:

```bash
codex sandbox -- <komenda weryfikacyjna projektu>                                   # read-only
codex sandbox -c 'sandbox_mode="workspace-write"' -- <komenda weryfikacyjna projektu>  # builder
```

W projekcie, którego komenda testowa wchodzi do kontenerów:

```
$ codex sandbox -- bash -lc 'vendor/bin/sail ps >/dev/null 2>&1; echo "exit=$?"'
exit=1
$ vendor/bin/sail ps >/dev/null 2>&1; echo "exit=$?"
exit=0
```

To całe ustalenie, zdobyte zanim powstał jakikolwiek brief.

## Czego sandbox odmawia — inwentarz Sola z realnych runów

- **Runtime'y kontenerów i gniazda demonów.** `permission denied while trying to connect to
  /var/run/docker.sock`, `sudo` zablokowane przez `no_new_privileges`. Wszystko, co wchodzi do
  kontenera (`docker compose`, `podman`, Laravel Sail), wewnątrz zawodzi, na zewnątrz działa.
- **Sieć.** DNS nie rozwiązuje nazw: brak instalacji zależności, pobierania paczek, `ctx7`.
  Wszystko nowe instaluj sam przed przekazaniem.
- **Tabela procesów hosta.** Worker kiedyś zameldował, że serwer leży, choć działał na hoście.
- **Zapisy poza workspace** pod `workspace-write`; wszystkie zapisy pod `read-only` — w tym raz
  `.git` tylko do odczytu (`Unable to create '.git/index.lock'`). Licz się z tym, że commit
  zrobisz sam.
- **`/tmp` jest niewiarygodny.** Trzy sprzeczne obserwacje: samodzielny `codex sandbox`
  (read-only) nie pokazał `/tmp` w ogóle; sesja `codex exec -s read-only` katalog widziała; krytycy
  w sierpniu nie mogli odczytać briefów tam położonych („PLAN.md does not exist"). Nigdy na nim nie
  polegaj — briefy, plany i wyniki żyją w `.route/` wewnątrz workspace, wykluczonym przez
  `.git/info/exclude`.

## Sonda sandboxa potrafi kłamać kodem wyjścia

Wewnątrz sandboxa zapis poza workspace melduje sukces *i czyta się jak prawdziwy*:

```
$ codex sandbox -- bash -c 'touch ~/.__probe; echo "exit=$?"; ls -la ~/.__probe'
exit=0
-rw-r--r-- 1 user user 0 Sep  3 11:11 /home/user/.__probe
$ ls -la ~/.__probe            # z zewnątrz
ls: cannot access '/home/user/.__probe': No such file or directory
```

Zapis wylądował w nakładce, która wyparowała razem z sandboxem. **Oceniaj sondę po skutku
widocznym z zewnątrz** albo po semantycznym wyniku komendy, która naprawdę potrzebuje zasobu —
nigdy po jej własnym kodzie wyjścia.

## Sprawdź runtime, nie tylko sandbox

`codex doctor --summary` pokrywa drugą połowę — czy worker w ogóle wystartuje: tryb auth i
osiągalność dostawcy (wygasłe logowania, ściany limitów), wersja zainstalowana vs najnowsza oraz
działający w tle `app-server` — zwykła przyczyna workera, który wisi przy starcie bez outputu.

## Konfiguracja projektu potrafi unieważnić Twoje flagi

`.codex/config.toml` projektu jest ładowany przez każde `codex exec` w tym katalogu. Dwie rzeczy
widziane w praktyce:

- `default_permissions = "<profil>"` z sekcją systemu plików tylko do odczytu — pozostałość po
  starszym workflow — uczyniła workspace tylko do odczytu niezależnie od `-s workspace-write`.
- Serwer MCP wchodzący do kontenerów (`command = "vendor/bin/sail"`) nie wystartuje w sandboxie i
  kosztuje swój `startup_timeout_sec` przy każdym runie.

Etap 0 czyta plik i ostrzega; poprawka należy do projektu, nie do skilla.

## Drabina eskalacji

Wchodź po jednym szczeblu, tylko z nieudanym pre-flightem, na który możesz wskazać, i wymieniaj
szczebel w linii przydziału.

1. **`-s workspace-write`** — domyślny. Repo zapisywalne, sieć wyłączona, brak gniazd.
2. **Podział pracy.** Zewnętrzny worker tylko edytuje; build, testy i sprawdzenie w przeglądarce
   robisz w swojej powłoce i przekazujesz wyniki. Jedno przekazanie na rundę poprawek, zero
   dodatkowego promienia rażenia. Dla workera Gemini to nie jest opcja, tylko konieczność: headless
   `agy` anuluje run przy pierwszej odmówionej komendzie.
3. **`--approve-for-me`** — prośby workera o eskalację ocenia automatyczny recenzent pod
   workspace-write, więc pojedyncze komendy mogą zostać zatwierdzone bez pełnego dostępu na cały
   run. Delegujesz decyzję modelowi — powiedz to wprost.
4. **`-s danger-full-access`** — udokumentowane wyjście awaryjne, gdy plan naprawdę zależy od
   runtime'u kontenerów. Wersja częściowa nie istnieje: gałki drobnoziarniste
   (`sandbox_workspace_write.writable_roots`, `network_access`) obejmują ścieżki i sieć, nie gniazda
   unixowe — dodanie `/var/run` do `writable_roots` psuje sandbox (`bwrap: Can't mkdir /run/.git:
   Permission denied`) zamiast otworzyć gniazdo, a gniazdo dockera to i tak root na hoście. Per
   run, per projekt, po nieudanym pre-flighcie, ogłoszone przed startem, nigdy w globalnym configu.

`--dangerously-bypass-approvals-and-sandbox` nie jest szczeblem: zdejmuje też zatwierdzenia i jest
przeznaczone dla hostów sandboxowanych zewnętrznie.

## agy nie ma sandboxa — ma uprawnienia

Tryb headless Antigravity odmawia każdej akcji narzędzia, która wymagałaby pytania, i anuluje turę
(`status:"CANCELED"`, `denied_actions`, exit 0). `--mode plan` dla krytyków, `--mode accept-edits`
dla builderów tylko edytujących, `--add-dir "$REPO"`, żeby worker w ogóle widział projekt. Zaufanie
do workspace (`trustedWorkspaces` w `~/.gemini/antigravity-cli/settings.json`) musi obejmować repo;
objawem braku jest sonda `/skills` z etapu 0 pokazująca zero skilli workspace przy zapełnionym
`.agents/skills/`.

## Przed buildem, niezależnie od szczebla

Czyste drzewo robocze — najpierw commit albo stash. Piszący worker, który przekroczy czas, padnie,
trafi na limit albo zostanie anulowany, zostawia po sobie wiarygodnie wyglądające
półimplementacje, a bez punktu odniesienia nie odróżnisz jego pracy od swojej. `.route/` jest
wykluczony przez `.git/info/exclude`, więc nigdy nie brudzi drzewa, a `git stash -u` go nie rusza;
nigdy `git clean -x` w checkoucie route.
