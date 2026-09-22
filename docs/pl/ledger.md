# Ledger kosztów

*Oryginał: [../ledger.md](../ledger.md).*

`.route/ledger.jsonl`, jedna linia na wywołanie modelu, dopisywana zaraz po odczytaniu jego wyniku:

```
{ts, run_id, stage, cli, family, model_requested, effort, service_tier_requested,
 service_tier_observed, session_id, duration_s, input_tokens, cached_input_tokens,
 cache_write_input_tokens, output_tokens, reasoning_tokens, total_tokens, denied_actions,
 exit_code, status, outcome}
```

## Źródła

| CLI | Skąd liczby |
| --- | --- |
| Codex | ostatnie `turn.completed.usage` w `.jsonl`: `input_tokens`, `cached_input_tokens`, `cache_write_input_tokens`, `output_tokens`, `reasoning_output_tokens` → `reasoning_tokens` |
| agy | `usage` z koperty: `input_tokens`, `output_tokens`, `thinking_tokens` → `reasoning_tokens`, `cache_read_tokens` → `cached_input_tokens`, `total_tokens`; do tego `duration_seconds`, `denied_actions[].action` |
| Subagent Claude | linia zakończenia narzędzia Agent |

Brak → `null`, nigdy szacunek. `codex exec review` raportuje zerowe usage, więc jego pola tokenów to
`null`.

**`codex exec resume` raportuje usage narastająco dla całego wątku.** Wiersz wznowionego wywołania
to jego `turn.completed.usage` minus poprzedni wiersz tego samego wątku; ostatni wiersz wątku to jego
suma. Sumowanie surowych wierszy liczy pierwsze wywołanie ponownie przy każdym wznowieniu.

Codex działa na standardowym tierze (`service_tier` nieustawiony — profil `fast` istnieje do pracy
interaktywnej); obsłużony tier nie jest nigdzie zapisywany, więc `service_tier_observed` to zawsze
`null`. Sum tokenów nigdy nie przedstawia się jako kosztu subskrypcji.

Zmiana workera w trakcie runu dostaje własny wiersz z `outcome: "swapped: <powód>"` przy porzuconym
wywołaniu.

## Tabela raportu

`Stage | Who (model@effort) | Wall | In | Out | Result`, sumy per rodzina, linia kaskady, jeśli
działała (`cascade: accepted at round N | escalated after N — koszt draftu+bramki vs koszt
eskalacji`), i linia gwarancji (tryb review, testy, szczebel sandboxa, co pominięto albo
zdegradowano).
