# Rozwiązywanie problemów

*Oryginał: [../troubleshooting.md](../troubleshooting.md).*

Każdy wpis poniżej zdarzył się w realnym runie route między 2026-08-16 a 2026-09-21.

## Codex godzinę siedzi na `Reading additional input from stdin...`

Każdy potwierdzony „zwis" Codexa w dwudziestu runach to było właśnie to — trzy osobne sesje, trzy
osobne diagnozy, od 19 do 75 minut straty za każdym razem. Wywołanie `codex exec` siedziało w
komendzie powłoki, która zawierała też heredoc, stdin pozostał otwarty, a Codex na niego czekał
(help mówi to wprost: przekierowany stdin jest dopisywany do promptu). Nic nie trafiło na dysk,
więc restart jest czysty.

Ta linia pojawia się także w zdrowych runach. Sygnałem zwisu jest ta linia **bez zdarzenia
`thread.started` w `.jsonl`**. Poprawka: `< /dev/null` w linii poleceń — jest na każdej linii
kanonicznej.

## `codex exec resume` odrzuca `-s` / `--color`

`error: unexpected argument '-s' found`. Podkomenda resume ma mniejszy zestaw flag: `-m`, `-c`,
`--json`, `-o`, `--output-schema`, `--last`, `--all`. Sandbox idzie przez
`-c 'sandbox_mode="workspace-write"'`. Zanim znaleziono działającą formę, każda sesja traciła na
tym dwa okna próbkowania po 8–10 minut.

## Codex dawno skończył, a dyrektor zauważył dopiero po pytaniu „jak tam?"

Worker został odpalony jako `setsid nohup run.sh … & disown` wewnątrz komendy Bash, z pustym polem
`run_in_background` narzędzia. Narzędzie wróciło po następującym po tym `sleep 15`, żadne zadanie
harnessu nie zostało zarejestrowane, a powiadomienie o zakończeniu, które obudziłoby dyrektora,
nigdy nie powstało. Dyrektor zakończył turę („druga paczka rusza") i czekał na coś, co nie mogło
nadejść. W dwóch sesjach dotyczyło to 34 z 36 odpaleń — przestoje od 0,7 do 127 minut, każdy
zakończony dopiero wiadomością użytkownika. Te same runy odpalone z `run_in_background: true`
dyrektor wznawiał 6–10 s po wyjściu workera, bez udziału człowieka.

Poprawka: tryb tła narzędzia Bash jest *jedynym* mechanizmem tła — żadnego `&`, `nohup`,
`setsid`, `disown` w komendzie. Jeśli proces musi przeżyć powłokę, ta sama komenda w tle czeka na
jego PID, żeby zadanie kończyło się razem z workerem. Nigdy nie kończ tury z żywym workerem bez
zadania dla niego. Rescue z wtyczki Codex w trybie `--background` robi to samo odłączenie
(`spawn(detached) + unref()`) i jest odpytywane przez `/codex:status`, więc tego nie naprawia.

## Własny `timeout 900` dyrektora ucięty po 10 minutach

Narzędzie Bash ogranicza komendy pierwszoplanowe do 600 s i wysyła SIGTERM; dłuższa wartość,
którą wpisałeś, jest po cichu ignorowana. Wszystko, co może trwać dłużej niż kilka minut — każde
wywołanie modelu, każdy run testów — idzie w tło.

## Zdrowy test trwający 417 sekund ubity jako zwis

Test nie emitował nic przez cały run; dwie ciche próbki po 20–25 s „udowodniły", że utknął. Reguła
ciszy ma teraz próg — `max(15 min, 2 × T_slow)` *ciągłej* ciszy, z `T_slow` zapisanym na etapie 0
— i nie jest w ogóle stosowana do runów testów.

## Każdy run testów wisi w nieskończoność bez outputu

Ubity równoległy runner testów (`timeout`, `pkill`) osieroca swoje workery, które trzymają bazy
testowe i metadata lock (`Waiting for table metadata lock`). Każdy kolejny run czeka na ten lock i
wygląda dokładnie jak zawieszony model. Odzyskanie, które zadziałało: znaleźć w bazie id
blokującego połączenia, ubić *to* połączenie po id, resztę zostawić. Zapobieganie: nigdy nie
owijaj testów w `timeout`, nigdy ich nie `pkill`, nigdy nie uruchamiaj dwóch tych samych zestawów
naraz.

## `pkill -f` zwrócił 144 i ubił nie to, co trzeba

`pkill -f "codex exec"` i `pkill -f 'artisan test'` trafiły we własną powłokę dyrektora — cztery
sesje, zawsze exit 144. Ubijaj po PID (`ps -eo pid,etime,cmd | grep '[c]odex exec'`, potem
`kill <PID>`) albo po id zadania harnessu.

## agy: exit 0, `status:"CANCELED"`, pusta odpowiedź

Worker spróbował akcji narzędzia, o którą tryb headless nie może zapytać (zwykle `RunCommand`), i
tura została anulowana: `denied_actions:[{"action":"command","display_name":"RunCommand"}]`. Popraw
brief (tylko edycje dla builderów; każdy fakt inline dla krytyków) albo dodaj reguły
`permissions.allow` — nigdy nie ponawiaj identycznie i nigdy nie wznawiaj tej rozmowy.

## agy: exit 0, `status:"SUCCESS"`, pusta odpowiedź, `denied_actions:[{"action":"mcp"}]`

Inna sygnatura niż `CANCELED` powyżej i paskudniejsza: status mówi **SUCCESS**, więc sprawdzenie
patrzące tylko na `status` uznaje, że krytyka się udała, i idzie dalej z niczym. Worker sięgnął po
narzędzie MCP skonfigurowane w projekcie (Laravel Boost, Perplexity, Playwright), tryb headless
odrzucił je automatycznie, bo nie ma jak zapytać, i tura skończyła się bez odpowiedzi. stderr
nazywa to wprost:

```
jetski: no output produced — a tool required the "mcp" permission that headless mode cannot
prompt for, so it was auto-denied.
```

`usage` pokazuje przy tym tysiące tokenów wyjściowych i myślenia — model wykonał robotę, po czym
wyrzucił ją do kosza, sięgając po narzędzie. Dlatego sprawdzenie koperty ma trzy warunki, nie
jeden: `status == "SUCCESS"` **i** `response != ""` **i** `denied_actions == []`.

Napraw to w briefie, nie w globalnej konfiguracji użytkownika: zacznij brief krytyka jawnym
zakazem — *„Ten brief jest samowystarczalny. NIE wywołuj żadnych narzędzi: nie czytaj plików, nie
uruchamiaj poleceń, nie wołaj MCP, nie przeszukuj repozytorium. Odpowiedz wyłącznie na podstawie
tekstu poniżej."* — i upewnij się, że każdy potrzebny fakt faktycznie jest w tekście.
`--dangerously-skip-permissions` też to zdejmuje, ale daje o wiele więcej uprawnień, niż powinien
mieć krytyk działający tylko do odczytu, a `agy mcp disable` zmienia setup użytkownika we
wszystkich projektach. Zacznij nową rozmowę — w tej, która nie dała odpowiedzi, nie ma czego
wznawiać.

Zmierzone na agy 1.1.28: ten sam brief, ten sam model, ten sam effort — 37 s i brak odpowiedzi bez
zakazu, 202 s i pełny werdykt z zakazem.

## agy: exit 1, `status:"ERROR"`, `error:"timeout waiting for response"`

Wygasł `--print-timeout` (domyślnie 5 minut). Status `TIMEOUT` nie istnieje. Zacznij nową rozmowę
z większym limitem i osadzonym bieżącym `git diff`; nie wchodź przez `--conversation` do tej, która
wygasła.

## agy: `flag needs an argument: -p` / `Argument list too long`

`-p` nie czyta stdin, a system ogranicza pojedynczy argument do ~128 KB. Stub-wskaźnik
(`Read .route/brief-build.md … execute it exactly`) omija jedno i drugie. Dawne przekonanie
„prompty powyżej 4 KB zwracają `status:"ERROR"`" nie potwierdziło się na 1.1.27 — prompt 34 KB
przeszedł normalnie.

## Gemini „zrobił robotę", ale nie odpalił testów i nie widział skilli

Dwie różne przyczyny. Headless `agy` nie może uruchamiać komend (zob. `CANCELED` wyżej) — testy
odpala dyrektor. A tryb print nie traktuje cwd jako workspace: bez `--add-dir "$REPO"` worker widzi
tylko wbudowane skille i żadnego z `.agents/skills` projektu. Sonda `agy --add-dir "$REPO" -p
"/skills"` z etapu 0 pokazuje dokładnie to, co worker zobaczy.

## Werdykt wg schematu nie chce się sparsować

Trzy warstwy: koperta agy opakowuje werdykt w *string* `response`; model może owinąć JSON w
znaczniki Markdown; agy dokleja klucze `toolAction`/`toolSummary`, których schemat nie deklaruje.
Zdejmij znaczniki, usuń te dwa klucze, sparsuj, zwaliduj — dopiero potem działaj. Plik `-o` Codexa
to goły werdykt.

## Monitor postępu podniósł alarm przy zdrowym runie Codeksa

W `.jsonl` Codeksa pojawiły się linie `{"type":"error", …}` o ponownym połączeniu strumienia
(HTTP 503) w środku buildu, który skończył się normalnie. Codex sam ponawia strumień; zdarzenie jest
informacją. Własny monitor dyrektora uznał każde `"type":"error"` za awarię (2026-09-09). Awarią jest
`turn.failed` albo zakończenie procesu bez `turn.completed` — tego szukaj.

## Ledger pokazał wznowiony wątek Codeksa jako dwa razy droższy

`codex exec resume` raportuje `turn.completed.usage` **narastająco dla całego wątku**, nie dla nowej
tury. Sumowanie wierszy wątku liczyło pierwsze wywołanie ponownie przy każdym wznowieniu
(2026-09-20). Ledger trzyma surowe liczniki w `raw_cumulative` i zapisuje jako tokeny wiersza
`raw[n] − raw[n−1]` — liczone z surowych liczników, nie z delty poprzedniego wiersza (ten skrót psuje
się przy drugim wznowieniu: 100, 150, 180 zamienia się w 100, 50, 130). Reguła jest w
`docs/ledger.md`.

## Testy padły na brakujących tabelach w środku runu

Inna sesja Claude Code na tej samej maszynie puściła swoje testy na wspólnej bazie `testing` i
usunęła tabele spod runu route — fałszywe czerwone bez związku z diffem (2026-09-09 w jednym
projekcie, 2026-09-20 w drugim). Zanim zaczniesz diagnozować czerwony wynik bez sensu, sprawdź, czy
nie trwa inny run testów (`ps -eo pid,etime,cmd | grep '[a]rtisan test'`); poczekaj, aż się skończy,
zamiast go zabijać. Nigdy nie startuj drugiego runu tego samego zestawu, gdy pierwszy trwa.

## Draft kaskady miał dobry kształt i złe wykończenie

Draft Luny na effortcie `low` (2026-09-17) trzymał się granic, ale upychał kod w bardzo długie
jednolinijkowce, pominął dwa testy z planu i miał jedną błędną asercję Livewire. Bramka Gemini
zażądała poprawek (confidence 0.95, ta sama diagnoza co własna próba dyrektora); jedna runda
poprawek została przyjęta. Dopisek dla draftera wymaga teraz formatowania zgodnego z repozytorium i
każdego testu z planu; bramka nadal sprawdza jedno i drugie.

## Worker wisi przy starcie bez żadnego outputu

Brak nowego pliku sesji w `~/.codex/sessions/` oznacza, że awaria nastąpiła przed startem sesji.
`codex doctor --summary` pokazuje `app-server` w tle; rozszerzenie edytora trzyma własny na tym
samym `CODEX_HOME`. Raz prawdziwą przyczyną był globalny serwer MCP wchodzący do runtime'u
kontenerów, który nie działał — 35-minutowy „zwis" naprawiony usunięciem go z globalnego configu.

## Worker padł w połowie buildu (limit, błąd API, anulowanie)

Sześć zdarzeń limitowych w trzy tygodnie; protokół działał za każdym razem, gdy go przestrzegano:

1. `git status` i `git diff` **przed czymkolwiek innym** — resztki wyglądają na skończone.
2. Zachowaj je albo zresetuj świadomie; zapisz checkpoint z `tree_state` i blokerem.
3. Wznawiaj, nie restartuj: Codex po UUID wątku, agy po `conversation_id` (tylko po turze
   `SUCCESS`), subagenci Claude z sekcją „do zrobienia po wznowieniu" w checkpoincie.
4. **Sonduj limit ponownie przed przetasowaniem rosteru.** Ten jeden raz, gdy dyrektor wnioskował
   z zapamiętanego limitu („resets 4:10am", o 8:48), przeniósł cztery partie z właściwego workera.

## Zielony run workera nie zgadza się z Twoim

Zameldowane 770/770, zmierzone 769/770. Różnice sandboxa, nieświeże cache, test, którego worker nie
odpalił. Zielony run workera to dowód, nie werdykt — commit czeka na Twój własny run.

## Playwright `fill()` nigdy nie wraca

Selektor przeniósł się na własny element i `fill()` czekał na niego w nieskończoność zamiast
zgłosić błąd. To czerwony test, który wygląda jak zwis. Popraw selektor; nie traktuj tego jako
przypadku dla watchdoga.

## Dwa projekty serwowały sobie nawzajem zasoby

Vite jednego projektu padło; serwer deweloperski drugiego zajął port 5173; pierwszy przez półtorej
godziny po cichu ładował cudzy CSS/JS. Znakiem był nieświeży `public/hot`. Nie wina route — ale to
ten rodzaj rzeczy, który wyłapuje sprawdzenie w przeglądarce, a zestaw testów nie.

## Procesy pozostałe po przerwanym runie

Pętle `until [ -s plik ]` i serwery deweloperskie z runu, który dyrektor sam przerwał, przeżyły
godzinami. `sessions` w checkpoincie i id zadań harnessu to inwentarz do posprzątania po każdym
przerwaniu; `git stash list` pokazuje pozostałe stashe `route-draft-*` po eskalowanych kaskadach.
