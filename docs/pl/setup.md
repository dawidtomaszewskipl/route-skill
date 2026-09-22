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
| Wiersz rubryki | pierwszy pasujący wiersz w sekcji „Roster" w SKILL.md | wykonawca |
| Stawka | uprawnienia/autoryzacja, pieniądze, destrukcyjne migracje, współbieżność, spójność danych | Astra jako krytyk, drugi krytyk, `--review` |
| UI widoczne dla użytkownika | widoki, komponenty, układ, style | `opus`, kontrola wizualna |
| Zasięg testów | które zestawy pokrywają zmieniany kod; czy są testy przeglądarkowe | zakres testów |
| Rozmiar | ile plików i podsystemów | `sol`/`gemini` dla dużej samodzielnej pracy, `self` dla drobnej |
| Dojrzałość planu | ustalony plan czy pomysł | rundy, `--plan-only` |

## Pytania

Pytaj tylko o to, co nadal jest otwarte po flagach, słowach użytkownika i polityce. Pomiń pytanie,
którego jedyna dopuszczalna odpowiedź jest już znana. Najwyżej 4 pytania na wywołanie
`AskUserQuestion` i 2 wywołania łącznie; pierwsze wywołanie niesie pytania, które zmieniają najwięcej.

| # | Pytanie (nagłówek) | Opcje, rekomendowana pierwsza | Rekomendowana, gdy |
| --- | --- | --- | --- |
| 0 | Zadania (`Zadania`) | jeden run · osobne runy po kolei · teraz tylko pierwsze zadanie | osobne runy, gdy zadania nie dzielą plików; jeden run, gdy jedno potrzebuje drugiego |
| 1 | Wykonawca (`Wykonawca`) | wybór rubryki · domyślny z polityki · `astra` · `sol` | wiersz rubryki dla zadania; pokaż domyślny z polityki, gdy się różni |
| 2 | Krytyk planu (`Krytyk`) | domyślny z innej rodziny · `astra` · `gemini` · dwóch krytyków | `astra` + trzecia rodzina przy wysokiej stawce |
| 3 | Rundy krytyki (`Rundy`) | 2 · 1 · 4 | 1 dla ustalonego planu; 4 dla planu z dużą ilością decyzji albo wysoką stawką |
| 4 | Review (`Review`) | brak · `cross` · `full` · `self` | `cross` albo `full` przy wysokiej stawce; brak dla pracy mechanicznej |
| 5 | Testy (`Testy`) | testy pokrywające zmianę, bez przeglądarki · + testy przeglądarkowe · pomiń | przeglądarka tylko, gdy zadanie zmienia przepływ pokryty zestawem przeglądarkowym |
| 6 | Tryb (`Tryb`) | pełny run · `--plan-only` · `--cascade` | plan-only, gdy prompt prosi o plan albo zadanie jest pomysłem; kaskada dla dużej pracy mechanicznej |

Opis każdej opcji mówi dlaczego, jednym zdaniem związanym z zadaniem: „pieniądze + współbieżność →
twarda poprawność", „3 widoki Blade i modal → UI, decydują zrzuty ekranu". Użyj pola `preview`, gdy
dwie opcje najlepiej porównać na krótkiej linii flag.

Przy osobnych runach pytania 1–6 zadaje się per zadanie tylko tam, gdzie rekomendacje się różnią;
o wspólne pyta się raz.

## Wynik

```
Setup: /route --model=opus --critic=astra,gemini --rounds=2 --review=cross <zadanie>
Assign: implementer=opus (user, setup; rubric: UI) · critic=astra (user, setup) · …
```

Osobne runy: jedna linia flag na zadanie, w kolejności, potem startuje pierwszy run; następny
startuje po raporcie poprzedniego (jeden piszący naraz). Linie flag trafiają do pola `flags`
checkpointu, więc `--resume` nie pyta ponownie.
