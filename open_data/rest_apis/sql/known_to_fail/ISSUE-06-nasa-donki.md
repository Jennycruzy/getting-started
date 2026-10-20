# Failure case: NASA DONKI (CME) — HTTP 503 from NASA's API gateway

**Status:** Known to fail — moved here after another developer could not get it working in Zetaris. On the evidence below the failure is on NASA's side, not in Zetaris or in this script, and it may be transient. Re-check the source before treating it as permanent.

**Source script:** [`06_nasa_donki_create.sql`](06_nasa_donki_create.sql) (unchanged from its last state, moved here as-is), with [`06_nasa_donki_select.sql`](06_nasa_donki_select.sql)

**Reported by:** the repo owner, from the Zetaris SQL Editor result pane; independently re-checked with `curl` on 2026-10-19 (22:51 UTC).

---

## Summary

A `CREATE LIGHTNING REST TABLE` (or a query against one) for the DONKI CME endpoint fails in Zetaris with:

```
REST API call failed: Server returned HTTP response code: 503 for URL: https://api.nasa.gov/DONKI/CME?startDate=2026-09-01&endDate=2026-09-16&api_key=DEMO_KEY
Response body: upstream connect error or disconnect/reset before headers. retried and the latest reset reason: remote connection failure
```

The same request made with plain `curl`, outside Zetaris, fails identically. A different NASA endpoint on the same gateway with the same key works. So the 503 originates at NASA's API gateway, which cannot reach the DONKI backend.

## Environment

- **Zetaris:** the SQL Editor's Result tab. The screenshot shows the request Zetaris sent: `GET`, `Content-Type: application/x-www-form-urlencoded`, no other headers, empty request body. It does not show which statement produced the error (the History tab shows 6 entries).
- **Source:** `https://api.nasa.gov/DONKI/CME`, `DEMO_KEY`, the script's date range (2026-09-01 to 2026-09-16).

## What was observed in Zetaris

The error above, surfaced verbatim from the upstream response. The `Response body:` text is the gateway's own error text, so Zetaris is relaying a real upstream failure, not generating one.

## Independent verification of the source API (via `curl`, outside Zetaris)

Run 2026-10-19, same URL as the script:

| Request | Result |
|---|---|
| `curl` DONKI CME, no extra headers | HTTP 503, 121-byte `text/plain` body, the same "upstream connect error or disconnect/reset before headers" text |
| `curl` DONKI CME with `-X GET -H 'Content-Type: application/x-www-form-urlencoded'` (what Zetaris sends) | HTTP 503, identical body |
| Control: `curl` NeoWs (`/neo/rest/v1/neo/browse?size=1`) with the same `DEMO_KEY` | HTTP 200, 13.9 KB |

The 503 responses carry `via: https/1.1 api-umbrella (ApacheTrafficServer ...)`, which is the api.data.gov gateway, and `x-ratelimit-limit: 10`. Across the three calls above `x-ratelimit-remaining` went 9, 8, 7, so **503 responses count against the key's allowance**; do not retry in a loop. (That limit differs from the 30 requests/hour recorded in the script header; the header does not state the window, so treat both as unconfirmed.)

When this script was written, the same URL returned 65 CME events (see the script header). It worked then.

## Root-cause hypothesis (unconfirmed)

NASA's gateway cannot reach the DONKI backend: an outage, a retired host or a moved service, on NASA's side. Evidence for: the identical failure with no Zetaris involved, the error text being the gateway's, and NeoWs working through the same gateway and key. It may be transient. One related observation, not a confirmed link: the DONKI documentation URL in the script header (`https://ccmc.gsfc.nasa.gov/support/DONKI-webservices.php`) returned HTTP 404 on 2026-10-19.

## What this is NOT

- **Not the top-level-array response shape.** The failure happens before any response body is parsed, so it says nothing about whether `CREATE LIGHTNING REST TABLE` accepts a bare top-level array. That question, noted in the script's caveat 1, is still untested.
- **Not Zetaris or its request headers.** `curl` with and without Zetaris's `Content-Type` header gets the same 503.
- **Not the `DEMO_KEY` or rate limiting.** NeoWs works with the same key, and a 429 would be the rate-limit response; this is a 503 with `x-ratelimit-remaining` still above zero.

## If revisiting this source

1. Check the endpoint with a single `curl` first. Do not run the script while `curl` still returns 503.
2. When `curl` returns 200 with CME events, run `06_nasa_donki_create.sql`. If it then registers and queries, move the script pair back to `sql/rate_limited/`, mark it Verified in `rest-api-sources.md`, and restore its manifest status.
3. If the create step then fails with a Zetaris-side error against a healthy endpoint, that is the original top-level-array question and the point at which to write up a Zetaris-specific failure.
4. Check whether the DONKI endpoint or documentation has moved (the header's docs link now 404s) and update the script if so.

## Suggested engineering debugging steps

None for Zetaris at this time: the failure reproduces without it. If, after the source recovers, a top-level array fails to register, capture the exact statement, the Zetaris error and `DESCRIBE` output.

## Recommended action for this package

Keep it here, marked known to fail, as a source that currently cannot be used for reasons outside this repo. Re-check it from time to time; it is the only source in the package that would test the top-level-array shape, so it is worth restoring if NASA's service comes back.

## References

- [`06_nasa_donki_create.sql`](06_nasa_donki_create.sql) — the script, with its own caveats
- [`../../HOWTO.md`](../../HOWTO.md) — "Understanding JSON response shapes", the top-level-array case
- [api.nasa.gov](https://api.nasa.gov/) — NASA's API portal
