# Polityka rosteru

*Oryginał: [../policy.md](../policy.md).*

Routing w route to spisana rubryka (zob. „Roster" w `SKILL.md` i „Jak dyrektor
decyduje" w README). Plik polityki pozwala tę rubrykę nagiąć raz, zamiast poprawiać dyrektora przy
każdym runie — „nigdy nie wybieraj tu Fable", „krytykiem jest zawsze Gemini", „to repo buduje
domyślnie Solem".

## Gdzie

| Plik | Zakres | Typowe użycie |
| --- | --- | --- |
| `route.policy.yml` w korzeniu repozytorium | projekt, commitowany | konwencje zespołu: domyślny implementator, zakazane sloty, rodzina, której zespół nie licencjonuje |
| `~/.claude/route.policy.yml` | Ty, każdy projekt | Twój budżet: „nigdy nie wydaję Fable na buildy" |

Pierwszeństwo, od najwyższego: **flagi z linii poleceń → polityka repo → polityka użytkownika →
domyślne skilla**, rozstrzygane **per klucz**: skalar, każdy wpis `effort.*` i każdy wpis
`families.*` bierze się z najwyższego poziomu, który go ustawia. Lista `deny` z wyższego poziomu
*zastępuje* niższą (pusta lista ją czyści). `families.<x>: on` znosi `off` z niższego poziomu, ale
nie sprawi, że nieobecne albo wylogowane CLI stanie się dostępne.

## Klucze

Wszystkie opcjonalne. Nazwy slotów to wartości `--model`; efforty to słownik CLI.

| Klucz | Znaczenie |
| --- | --- |
| `deny: [slot, …]` | Dyrektor nigdy nie wybiera ich sam. Jawne `--model`, `--critic` albo `--reviewer` wskazujące zakazany slot nadal wygrywa — z ostrzeżeniem w linii przydziału, bo o to poprosiłeś. |
| `implementer: slot` | Domyślny implementator, gdy brak `--model`. Bez tego decyduje rubryka. |
| `critic: slot` | Preferowany krytyk planu, używany zawsze, gdy pozwala reguła krzyżowa. |
| `reviewer: slot` | Preferowany recenzent krzyżowy dla `--review=full` i `--review=cross`. |
| `cascade_drafter: slot` | Domyślny drafter dla `--cascade` (domyślnie `luna`). |
| `critique_rounds: n` | Limit rund krytyki planu, 1–8 (domyślnie 2). `--rounds` go przebija. |
| `effort: {critique, high_stakes_critique, build, review, draft}` | Effort per etap dla workerów OpenAI i Google (domyślnie `medium`, `high`, `medium`, `high`, `medium`). Etap przyjmuje jedną wartość albo parę per rodzina (`openai:` / `google:`), gdy rodziny potrzebują różnych poziomów. Pojedyncza wartość powyżej zakresu rodziny jest przycinana do jej maksimum (Gemini: `high`) i oznaczana `(clamped)`. Subagenci Claude nie mają pokrętła. |
| `families: {openai\|google: on\|off}` | Wyłącza rodzinę, nawet jeśli jej CLI jest zainstalowane i zalogowane, albo `on`, żeby znieść `off` z niższego poziomu. Claude'a nie da się wyłączyć — jest dyrektorem. |

Przykład z komentarzami: [`../examples/route.policy.yml`](../examples/route.policy.yml).

## Jak jest stosowana

Etap 0 czyta oba pliki (jeśli są), raportuje, które znalazł i jakie są efektywne wartości, po czym
z nimi rusza dobór. Każda wartość pochodząca z polityki jest oznaczona `(policy)` w linii
przydziału, więc run zawsze pokazuje, skąd wziął się wybór:

```
Assign: implementer=sol (policy: repo default) · critic=fable (cross-family; policy critic gemini
unavailable: families.google off) · …
```

Reguła krzyżowa nie jest kluczem polityki i nie da się jej wyłączyć. Jeśli polityka czyni ją
niespełnialną (np. `critic: sol` przy `implementer: sol`), dyrektor ignoruje preferencję krytyka,
mówi to i stosuje regułę.

Pierwszeństwo jest rozstrzygane **przed** jakąkolwiek walidacją. Jawne `--model` nadpisuje zakazany
slot albo rodzinę wyłączoną polityką *dla implementatora*, z ostrzeżeniem w linii przydziału —
nigdy nie nadpisuje prawdziwej niedostępności (CLI nieobecne albo wylogowane) ani reguły krzyżowej.
Niedozwolona preferencja `critic` albo `reviewer` — jej rodzina jest wyłączona albo niedostępna, albo
sprzeciwia się jej reguła krzyżowa — jest pomijana ze zdaniem wyjaśnienia i wybierana jest dozwolona
alternatywa. Slot, którego wywołanie próbne modelu się nie udało, to inna sytuacja: run zatrzymuje
się pytaniem (SKILL.md, etap 0, krok 5).

## Co zatrzymuje pętlę

Jak nielegalna flaga, nielegalna polityka zatrzymuje pętlę pytaniem zamiast zgadywać:

- nazwa slotu spoza rosteru (`gemini-pro`, `gpt-5`);
- `cascade_drafter` inny niż `luna`, `haiku` albo `gemini`;
- `critique_rounds` spoza zakresu 1–8;
- effort, który w ogóle nie jest poziomem (`hgih`), albo wartość per rodzina spoza zakresu tej
  rodziny — Gemini bierze `low|medium|high`, model OpenAI własną listę z katalogu (Astra/Sol/Terra:
  do `ultra`, Luna: do `max`); pojedyncza wspólna wartość jest zamiast tego przycinana (zob. `effort`);
- efektywny, nienadpisany `implementer` albo `cascade_drafter`, który jest zakazany albo należy do
  wyłączonej rodziny;
- niedostępna rodzina, której wymaga flaga;
- `--cascade`, dla którego nie da się spełnić reguły rodzin (SKILL.md, „The cross-family rule").

## Format

Zwykły YAML, wcięcia dwiema spacjami, bez kotwic, bez stylu flow. Dyrektor czyta go jako tekst —
nie ma parsera do zadowolenia, tylko człowiek, dla którego ma być czytelny. Trzymaj się kluczy
powyżej; nieznane klucze są raportowane i ignorowane.
