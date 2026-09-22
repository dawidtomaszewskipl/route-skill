# Setup

*Oryginał: [../setup.md](../setup.md).*

`--setup` zastępuje pamiętanie flag krótkim kwestionariuszem. Dyrektor czyta prompt, rekomenduje
konfigurację na podstawie tego, czym jest zadanie, i pyta. Odpowiedzią jest linia flag, której można
użyć następnym razem.

## Czytanie wejścia

- **Treść zadania** po zdjęciu flag.
- **Plan, jeśli jest:** wklejony wynik `/plan` z Claude Code, ścieżka do pliku z planem albo istniejący
  `.route/PLAN.md`. Plan zmienia rekomendacje: jego kroki są zadaniami, a plan już ustalony obniża
  wartość dodatkowych rund krytyki.
- **Kilka zadań** („zrób A, potem B", lista numerowana, fazy planu) jest rozpisywanych osobno, każde z:

| Cecha | Jak oceniana | Na co wpływa |
| --- | --- | --- |
| Stawka | uprawnienia/autoryzacja, pieniądze, destrukcyjne migracje, współbieżność, spójność danych | wiersz 1 rubryki, Astra jako krytyk, drugi krytyk, `--review` |
| UI widoczne dla użytkownika | widoki, komponenty, układ, style | `opus`, kontrola wizualna |
| Wiersz rubryki | sekcja „Roster" w SKILL.md, oceniana po kolei — najpierw stawka | wykonawca |
| Zasięg testów | które zestawy pokrywają zmieniany kod; czy są testy przeglądarkowe; czy dotyka wspólnego kodu | `--tests` |
| Rozmiar | ile plików i podsystemów | `sol`/`gemini` dla dużej samodzielnej pracy, `self` dla drobnej |
| Dojrzałość planu | ustalony plan czy pomysł | rundy, `--plan-only` |

## Pytania

Pytaj przez `AskUserQuestion`, najwyżej 4 pytania na wywołanie, w **dwóch krokach**, bo późniejsze
opcje zależą od wcześniejszych odpowiedzi (wykonawca decyduje, którzy krytycy są z innej rodziny;
tryb decyduje, czy review jest dozwolone).

**Wartości z polityki to wartości domyślne, nie odpowiedzi.** Pokaż je — „opus (domyślny z polityki)"
— a gdy rubryka rekomenduje dla tego zadania coś innego, zrób z wyboru rubryki opcję rekomendowaną i
powiedz dlaczego. Pomijaj tylko pytania, na które odpowiedziały już flagi albo słowa użytkownika, i
pytania z jedną dopuszczalną opcją.

**Krok 1 — kształt pracy**

| Pytanie (nagłówek) | Opcje, rekomendowana pierwsza | Rekomendowana, gdy |
| --- | --- | --- |
| Zadania (`Zadania`) — tylko przy kilku zadaniach | osobne runy po kolei · jeden run · teraz tylko pierwsze zadanie | osobne, gdy zadania nie dzielą plików; jeden run, gdy jedno potrzebuje drugiego |
| Tryb (`Tryb`) | pełny run · `--plan-only` · `--cascade` | plan-only, gdy prompt prosi o plan albo zadanie jest pomysłem; kaskada dla dużej pracy mechanicznej |
| Wykonawca (`Wykonawca`) | wybór rubryki · domyślny z polityki (gdy inny) · `astra` · `sol` | wiersz rubryki dla zadania |

**Krok 2 — liczony z odpowiedzi z kroku 1**

| Pytanie (nagłówek) | Opcje, rekomendowana pierwsza | Rekomendowana, gdy |
| --- | --- | --- |
| Krytyk (`Krytyk`) | domyślny z innej rodziny · `astra` · `gemini` · dwóch krytyków | tylko rodziny inne niż wybranego wykonawcy (i draftera przy kaskadzie); `astra` + trzecia rodzina przy wysokiej stawce |
| Rundy (`Rundy`) | 2 · 1 · 4 | 1 dla ustalonego planu; 4 dla planu z dużą ilością decyzji albo wysoką stawką |
| Review (`Review`) — nie przy `--plan-only` | brak · `cross` · `full` · `self` | `cross` albo `full` przy wysokiej stawce; brak dla pracy mechanicznej |
| Testy (`Testy`) | `covering` · `browser` · `full` · pomiń | `browser`, gdy zadanie zmienia przepływ pokryty zestawem przeglądarkowym; `full`, gdy dotyka wspólnego kodu (sekcja „Test scope" w SKILL.md); pominięcie nigdy nie jest rekomendowane, a przy kaskadzie jest niedozwolone |

Opis każdej opcji mówi dlaczego, jednym zdaniem związanym z zadaniem: „pieniądze + współbieżność →
twarda poprawność", „3 widoki Blade i modal → UI, decydują zrzuty ekranu". Użyj pola `preview`, gdy
dwie opcje najlepiej porównać na krótkiej linii flag.

**Osobne runy:** po kroku 1 krok 2 zadaje się per zadanie tylko tam, gdzie rekomendacje się różnią —
do dwóch wywołań na zadanie; o wspólne pyta się raz. Wszystko, na co nie padła odpowiedź, bierze
opcję rekomendowaną, a linia flag to zaznacza.

## Wynik

```
Setup: /route --model=opus --critic=astra,gemini --rounds=2 --review=cross --tests=covering <zadanie>
Assign: implementer=opus (user, setup; rubric: UI) · critic=astra (user, setup) · …
```

Każda odpowiedź ma swoją flagę, więc linia jest kompletna i nadaje się do ponownego użycia. Osobne
runy: jedna linia na zadanie, w kolejności, zapisane w checkpoincie jako `tasks` z `current_task`;
startuje pierwszy run, a każdy następny po raporcie poprzedniego — `--resume` przy `stage: report`
bierze następne zadanie z kolejki (jeden piszący naraz).
