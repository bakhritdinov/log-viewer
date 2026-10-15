# Grafana /api/ds/query fixtures

Synthetic responses shaped like the VictoriaLogs datasource frames that the
legacy `GrafanaClient` parsed (columnar `schema.fields` / `data.values`, a
`labels` object column, `Time`/`ts` in epoch ms, `Line`/`message` text). No real
log data. Timestamps are based on 2026-10-15T12:00:00Z.

| File | Used for |
|---|---|
| logs_basic | three rows, levels from `level` and `severity` labels |
| logs_two_frames | rows split over frames, `ts`/`message` aliases, typed columns |
| logs_empty / logs_no_frames | empty results |
| logs_datasource_error | 200 body carrying a query error in `results.A.error` |
| logs_datasource_timeout | datasource-side timeout reported in the body |
| logs_no_time | a frame without a time column |
| discovery_phase1* | label discovery sample (found / unknown labels / no app label) |
| discovery_phase2 | `stats by (ns, app)` result rows as JSON lines |
