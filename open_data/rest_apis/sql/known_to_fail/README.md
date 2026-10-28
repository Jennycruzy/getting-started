# Known-to-fail sources

Sources that were investigated and scripted for `open_data/rest_apis/`, but hit a blocking issue that isn't a mistake in the SQL — something in the Zetaris connector, the source API, or the interaction between them. Each source's onboarding script (unchanged from its last working state) sits here alongside an `ISSUE.md` with the full reproduction steps, evidence, and a root-cause hypothesis for engineering to debug.

These are not included in `sql/rate_limited/` or `sql/non_rate_limited/`, and are not part of `HOWTO.md`'s "Running the scripts" order. They're kept here rather than deleted so the investigation isn't lost and engineering has a concrete starting point if the underlying issue is ever fixed.

## Index

Singapore data.gov.sg PM2.5 used to be listed here. A later live run (2026-10-24, Zetaris 2.4.3.1, SQL API) passed, so its scripts moved to [`../rate_limited/`](../rate_limited/04_singapore_pm25_create.sql). Its [`ISSUE.md`](ISSUE.md) stays here as the record of the original HTTP 502, marked contradicted by a later run and not yet reconciled.

| Source | Script | Status | Summary |
|---|---|---|---|
| NASA DONKI (CME) | [`06_nasa_donki_create.sql`](06_nasa_donki_create.sql) | Known to fail | Fails with HTTP 503 ("upstream connect error ... remote connection failure") from NASA's API gateway. The same 503 comes back from plain `curl` outside Zetaris, while NeoWs works with the same key, so the failure is NASA-side and may be transient. See [`ISSUE-06-nasa-donki.md`](ISSUE-06-nasa-donki.md). |

## Adding a new known-to-fail source

1. Move the source's script pair here as-is — don't "fix" it as part of the move, since the point is to preserve the last state that hit the issue.
2. Write (or extend) `ISSUE.md`, or a separate `ISSUE-NN-<name>.md` next to the script as `ISSUE-06-nasa-donki.md` does, covering: a summary, the environment, what was observed in Zetaris, independent verification against the source API directly (ruling out what it *isn't*), a root-cause hypothesis explicitly marked as unconfirmed where it is, suggested engineering debugging steps, and a recommended action (skip, retry later, or workaround).
3. Add a row to the index table above.
4. Update `../../HOWTO.md` and `../../rest-api-sources.md` to reflect the source's new status and location.
