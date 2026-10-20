-- =============================================================================
-- Source: company_dns Japan industry classification hierarchy reference data,
-- from the company_dns V4 production service:
--   https://company-dns.mediumroast.io/V4.0/japan/sic/industry_group/%25
-- 1,460 classes with their full section / division / group / class rollup.
-- Sibling of 12_company_dns_create.sql, which loads the US SIC hierarchy from
-- the same service; same pattern, one raw table and one view.
--
-- License: company_dns is Apache 2.0 (github.com/miha42-github/company_dns,
-- self-hostable via Docker). The classification content itself originates with
-- Japan's government statistics and is licensed Creative Commons Attribution
-- 4.0 International (CC BY 4.0), per the e-Stat terms of use:
-- https://www.e-stat.go.jp/en/terms-of-use
-- Credit the source when you reuse it. Still query live rather than
-- bulk-redistributing the extracted data.
--
-- Format: REST/JSON (CREATE LIGHTNING REST TABLE). The response is
-- {code, message, module, data: [1,460 flat objects of 8 string fields],
-- dependencies, total}, the same shape as the US SIC V4 endpoint, so a plain
-- explode(data) is enough -- no from_json/to_json coercion (SQL companion guide,
-- section 2).
--
-- Rate limit: YES, and the allowance depends on whether you identify yourself.
-- The limits are per caller address and set by the service operator, so they can
-- differ between deployments:
--
--   Caller                                   Allowance per address
--   ---------------------------------------  ----------------------------------
--   Identifies itself: a User-Agent with an  6,000 a minute (100 a second),
--   e-mail address or URL, such as           burst of 600
--   "MyTeam/1.0 (you@example.org)"
--   Does not identify itself: no User-Agent, 600 a minute, burst of 60. This is
--   a library default, or a name with no     raised for the event; the service
--   contact                                  default is 5 a minute, burst of 1.
--
-- A burst larger than the allowance gets HTTP 429 even when the average is low,
-- so spread requests out and cache answers on this side. A Lightning REST table
-- re-fetches on EVERY query, so the CACHE TABLE statement(s) below are required,
-- not optional. Run this script once, deliberately; do not loop it.
--   Pacing: with an identifying User-Agent (see below) run the statements at a
--   normal pace, one at a time. Without one you are on the unidentified tier, and
--   on the 5 a minute, burst of 1 default once the event ends: then wait 15
--   seconds or more before each statement marked "calls the endpoint". One visible
--   statement can send more than one HTTP request (Zetaris can retry a failing
--   fetch on a few pooled connections), so if a statement fails with a 429, wait
--   60 seconds before retrying that one statement.
--
-- Hosts: company_dns V4 is now officially served by the production host,
-- https://company-dns.mediumroast.io, and V3 is deprecated. The staging host
-- (company-dns-staging.mediumroast.io) is retired: do not use it. Zetaris fetches
-- the endpoints itself, so the Zetaris server must be able to reach the host.
--
-- Size: the response is about 420 KB, the largest of the three company_dns scripts.
--
-- User-Agent: the service requires one of the form
--     app_name user@domain.tld        for example:  zetaris dev@zetaris.com
-- that is, an app name, a space, and a contact e-mail address. Something vague, such
-- as a bare "zetaris-getting-started", a library default, or no User-Agent at all, does
-- not identify you and gets the strict limit above. Replace the
-- YOUR_APP_NAME YOUR_CONTACT_EMAIL placeholder in the statements below with your own
-- value, or run the script with scripts/run_sql.py, which fills it in from
-- ZETARIS_USER_AGENT (set it in .env.local in that same form).
--
-- Status: VERIFIED (recorded 2026-10-11). The CREATE statements and the queries
-- in 14_company_dns_japan_select.sql were run against a live Zetaris instance.
-- Written from a saved copy of the live response (HTTP 200, 1,460 rows, 8 flat
-- string fields, no nulls).
-- That run used the staging host. On 2026-10-19 the production host answered the same
-- V4 path with the same 1,460 rows, byte for byte the same size; the CREATE statements
-- have not been re-run against it.
-- =============================================================================
--
-- The four levels, with the values this endpoint returns:
--
--   level     field         example
--   --------  ------------  -------------------------------------------------
--   section   section_id    A       (letters A-T, 20 sections)
--             section_desc  AGRICULTURE AND FORESTRY   (upper case)
--   division  division_id   01      (2 digits, 99 divisions)
--             division_desc AGRICULTURE                (upper case)
--   group     group_id      011     (3 digits, 530 groups)
--             group_desc    CROP FARMING                (upper case)
--   class     class_id      0111    (4 digits, 1,460 classes, the finest level)
--             class_desc    Rice farming                (sentence case)
--
-- Expected counts, from the saved response: 1,460 classes, 20 sections, 99
-- divisions, 530 groups. These match the published structure of Japan's
-- industrial classification at its 2013 (13th) revision, but the response does
-- not state which revision it holds -- confirm with the maintainer before
-- relying on it.
--
-- Caveats:
--   1. The %25 wildcard (a literal '%') is undocumented behavior of the service:
--      the code path parameter is used in a LIKE, so one '%' matches every row.
--      The path segment in this URL is `industry_group`, but the response
--      reports "1460 class matches for [%]", so the rows are class level, not
--      group level. What the path segment selects was not tested -- other
--      segments would each be one more request against the rate limit.
--   2. The URL path says `sic` even though this is Japan's classification, not
--      the US SIC. Do not join this data to US SIC codes on class_id: both are
--      four digits, but the codes mean different things.
--   3. Every id maps to exactly one description and one parent in the saved
--      response, but descriptions are NOT unique: one group description is
--      shared by two group ids, and 15 class descriptions are shared by more
--      than one class id. Group and rank by the id, never by the description
--      (the select script has a query that lists the shared ones).
--   4. Mixed case: section, division and group descriptions are upper case, class
--      descriptions are sentence case. A case-sensitive LIKE needs the right case
--      per level; LOWER() avoids the question.
--   5. There is no V3-style compat view here. The compat views in
--      12_company_dns_create.sql exist so SQL written for the older US SIC V3
--      column names keeps working; no such SQL exists for this data.
--   6. DESCRIBE BY only accepts letters, digits, spaces and _ . - , -- see the
--      SQL companion guide.
-- =============================================================================

-- Step 0: register the logical database. (No endpoint call.)
CREATE LIGHTNING DATABASE COMPANY_DNS_JAPAN DESCRIBE BY "company_dns Japan industry classification - section, division, group, class";

-- Step 1: the raw REST table. Calls the endpoint.
CREATE LIGHTNING REST TABLE japan_raw FROM COMPANY_DNS_JAPAN REQUEST(
    endpoint "https://company-dns.mediumroast.io/V4.0/japan/sic/industry_group/%25",
    method "get",
    response_type "json",
    http_encoding "URLENCODED"
) HEADER (
    user-agent "YOUR_APP_NAME YOUR_CONTACT_EMAIL"
) BODY ();

-- Step 2: cache the raw table. Wait 15 seconds or more after Step 1. Calls the
-- endpoint. From here on, the view reads the cached copy. (Whether a
-- schemastore view reads the cached raw table has not been separately
-- confirmed -- time the first COUNT(*) in the select script: about a second
-- means cached, much longer means it re-fetched.)
CACHE TABLE company_dns_japan.japan_raw;

-- Step 3: the schemastore container that holds the view. It has no IF NOT
-- EXISTS form, so on an instance that already has it, skip this statement.
CREATE SCHEMASTORE CONTAINER company_dns_japan;

-- Step 4: flatten the array into a queryable view, one row per class.
CREATE SCHEMASTORE VIEW japan_table WITH CONTAINER company_dns_japan AS
SELECT
    item.section_id AS section_id,
    item.section_desc AS section_desc,
    item.division_id AS division_id,
    item.division_desc AS division_desc,
    item.group_id AS group_id,
    item.group_desc AS group_desc,
    item.class_id AS class_id,
    item.class_desc AS class_desc
FROM company_dns_japan.japan_raw
LATERAL VIEW explode(data) AS item;

-- =============================================================================
-- Teardown -- removes the flattened view. Commented out by default. DROP VIEW is
-- the only reliable teardown statement. The REST table and the database
-- registration are removed in the Zetaris Data Explorer (no SQL path exists --
-- see HOWTO.md, "Removing a source").
-- =============================================================================

-- DROP VIEW company_dns_japan.japan_table;
-- UNCACHE TABLE company_dns_japan.japan_raw;
