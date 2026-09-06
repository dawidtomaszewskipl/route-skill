# route

*Wersja polska. Oryginał: [README.md](README.md). Dokumentacja po polsku: [docs/pl/](docs/pl/).*

Pętla budowania wielomodelowego dla [Claude Code](https://claude.com/claude-code), zapakowana jako skill.

`/route` zamienia model sesji w **dyrektora**. Dyrektor prowadzi wywiad, aż specyfikacja nie ma
luk, pisze plan, oddaje go do rozszarpania modelowi **innego dostawcy**, przekazuje ocalały plan
workerowi dopasowanemu do zadania i dopiero wtedy zatwierdza wynik. Kierujesz zespołem zamiast
patrzeć, jak jeden model robi wszystko.

Workerzy stoją za trzema CLI:

| Rodzina | Dostęp przez | Typowi członkowie |
| --- | --- | --- |
| Claude | subagenci Claude Code | Fable 5.1, Opus 5, Sonnet, Haiku |
| OpenAI | `codex exec` ([Codex CLI](https://developers.openai.com/codex/cli)) | GPT-6 Astra, GPT-5.6 Sol / Terra / Luna |
| Google | `agy` (Antigravity CLI) | Gemini 3.8 Flash |

## Po co

Z rozdzielenia ról wynikają rzeczy, które nie wynikają z jednej długiej rozmowy:

- **Plany są atakowane, zanim powstanie kod.** Krytyk zawsze pochodzi od innego dostawcy, bo modele
  jednej rodziny mają wspólne martwe pola. Złapanie złego planu kosztuje jedno wywołanie; złapanie
  go po buildzie kosztuje build.
- **Praca ląduje we właściwej puli.** Limity subskrypcji są per dostawca. Duży, dobrze opisany
  kawałek może pójść do bezczynnej puli, a pula, którą właśnie zużywasz, obsłuży to, co wymaga
  osądu.
- **Drabina eskalacji jest jawna.** Nic po cichu nie dostaje pełnego dostępu do Twojej maszyny,
  bo tak było wygodniej.
- **Najpierw tanio — gdy o to poprosisz.** `--cascade` pozwala tańszemu modelowi zrobić draft, a
  bramka mechaniczna + krytyk innego dostawcy decydują, czy przyjąć, czy eskalować — wzorzec
  *cascade* z Project HydraFusion GitHuba.
- **Każdy run da się wznowić i rozliczyć.** Plik checkpointu przeżywa ściany limitów i crashe;
  ledger zapisuje, ile kosztował każdy etap.

## Instalacja

```bash
git clone https://github.com/dawidtomaszewskipl/route-skill.git
cd route-skill
./install.sh            # kopiuje SKILL.md i docs/ do ~/.claude/skills/route/
```

Albo ręcznie:

```bash
mkdir -p ~/.claude/skills/route
cp -R SKILL.md docs ~/.claude/skills/route/
```

Per projekt zamiast globalnie: skopiuj do `<projekt>/.claude/skills/route/`.

### Wymagania

Sam Claude Code wystarczy — pętla degraduje się do workerów Claude, a krytyka planu spada do jednej
rodziny (słabsza, ale pętla działa). Dla pełnego rosteru:

- **Codex CLI ≥ 0.153.1** (GPT-6 Astra) — `npm i -g @openai/codex`, potem `codex login`.
  Sprawdź przez `codex doctor`.
- **Antigravity CLI ≥ 1.1.27** (`agy`; raportuje odmówione akcje) — instalacja z Google
  Antigravity, potem `agy models` dla potwierdzenia logowania.

## Użycie

```
/route dodaj soft-delete dla faktur
/route --model=sol --review=cross przenieś job raportowy na kolejkę
/route --model=gemini --skip-tests przegeneruj dokumentację API
/route --cascade --model=fable dodaj politykę retry do webhooka płatności
/route --resume
```

### Flagi

| Flaga | Efekt |
| --- | --- |
| `--model=<worker>` | Wybór implementatora: `sonnet`, `opus`, `fable`, `haiku`, `astra`, `sol`, `terra`, `luna`, `gemini`, `self`. Bez flagi wybiera dyrektor i ogłasza wybór. |
| `--review` / `--review=full` | Dyrektor czyta diff **i** uruchamia recenzenta z innej rodziny. |
| `--review=self` | Tylko dyrektor czyta diff. |
| `--review=cross` | Tylko recenzent z innej rodziny; dyrektor czyta jego znaleziska i wyrywkowo sprawdza. |
| *(brak `--review`)* | Brak etapu review. Testy nadal bramkują run. |
| `--skip-tests` | Zdejmuje obowiązek testów. |
| `--cascade[=luna\|haiku\|gemini]` | Tani drafter buduje pierwszy; testy plus bramka innego dostawcy przyjmują albo eskalują do implementatora. Zob. [cascade](docs/pl/cascade.md). |
| `--resume` | Kontynuacja runu zapisanego w `.route/CHECKPOINT.md`. |

Review jest opcjonalne; **krytyka planu nigdy**. Nieznana wartość flagi zatrzymuje pętlę pytaniem,
zamiast po cichu przełączyć się na coś, o co nie prosiłeś.

### Pętla

0. **Walidacja** — flagi, wersje CLI, skille projektu, zasięg sandboxa, czyste drzewo — przed
   pierwszym wywołaniem modelu.
1. **Wywiad** — jedno pytanie naraz, aż specyfikacja nie ma luk.
2. **Przydział** — jedna linia z implementatorem, krytykiem, trybem review, szczeblem sandboxa i
   (z `--cascade`) drafterem. Poprawiasz jednym słowem.
3. **Plan** — `.route/PLAN.md`.
4. **Krytyka** — plan idzie do innego dostawcy (najwyżej trzy rundy). Wysoka stawka dostaje
   trzeciego.
5. **Build** — albo draft + bramka z `--cascade`. Jeden piszący naraz.
6. **Review** — wg flagi.
7. **Fix** — znaleziska i czerwone testy wracają do buildera (najwyżej trzy rundy, potem checkpoint
   i decyzja wracają do Ciebie).
8. **Akceptacja** — dyrektor sam odpala testy i commituje.
9. **Raport** — kto co zrobił, ile to kosztowało, które gwarancje zaszły, które pominięto.

## Dokumentacja

- [Workerzy i mechanika CLI](docs/pl/workers.md) — jak wywoływana jest każda rodzina, katalogi
  modeli, pokrętła effortu, wznawianie, wyjście strukturalne, widoczność skilli.
- [Sandbox i pre-flight](docs/pl/sandbox-and-preflight.md) — czego worker w sandboxie naprawdę
  nie sięgnie, jak to sprawdzić za darmo i drabina eskalacji.
- [Kaskada](docs/pl/cascade.md) — protokół draft → bramka → akceptacja/eskalacja.
- [Checkpoint](docs/pl/checkpoint.md) — wznawialny stan runu i jak używa go `--resume`.
- [Rozwiązywanie problemów](docs/pl/troubleshooting.md) — każda awaria widziana w realnych
  runach, z poprawką, która zadziałała.
- [Schematy](docs/schemas/) — schematy werdyktów krytyki i bramki, w jednym dialekcie
  akceptowanym przez oba CLI.

## Założenia projektowe

**Dyrektor nie pisze kodu.** Jego robotą jest specyfikacja, plan, przydział i werdykt. To
rozdzielenie sprawia, że krytyka jest adwersarialna, a nie samozadowolona.

**Nigdy dwóch piszących workerów w jednym checkoucie.** Zewnętrzne CLI i subagenci kolidują na
plikach i na `.git/index.lock`. Równolegli subagenci Claude dostają własne worktree; zewnętrzni
workerzy mają wyłączność na checkout na czas runu.

**Akceptacja należy wyłącznie do dyrektora.** Zielony run workera to dowód, nie werdykt.

**Dowody ponad założenia.** Wersja 3 została przebudowana na podstawie logów dwudziestu
rzeczywistych runów i adwersarialnych krytyk własnego planu przez GPT-6 Astra i Gemini 3.8 Flash —
tej samej pętli, którą zaleca. Kanoniczne linie poleceń to te, które naprawdę zostały uruchomione.

## Changelog

Zob. [CHANGELOG.md](CHANGELOG.md) — od projektowego poprzednika z 16 sierpnia 2026 do bieżącego
wydania.

## Licencja

MIT — zob. [LICENSE](LICENSE).
