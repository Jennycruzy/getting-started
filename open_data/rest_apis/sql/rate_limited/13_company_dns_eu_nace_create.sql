-- =============================================================================
-- Source: company_dns EU industry classification (NACE) hierarchy reference
-- data, from the company_dns V4 staging service:
--   https://company-dns-staging.mediumroast.io/V4.0/eu/sic/class/%25
-- 615 classes with their full section / division / group / class rollup. Sibling
-- of 12_company_dns_create.sql, which loads the US SIC hierarchy from the same
-- service; same pattern, one raw table and one view.
--
-- License: company_dns is Apache 2.0 (github.com/miha42-github/company_dns,
-- self-hostable via Docker). The classification content itself originates with
-- Eurostat, the EU's statistical office, and is licensed Creative Commons
-- Attribution 4.0 International (CC BY 4.0):
-- https://ec.europa.eu/eurostat/help/copyright-notice
-- Credit Eurostat when you reuse it. Still query live rather than
-- bulk-redistributing the extracted data.
--
-- Format: REST/JSON (CREATE LIGHTNING REST TABLE). The response is
-- {code, message, module, data: [615 flat objects of 8 string fields],
-- dependencies, total}, the same shape as the US SIC V4 endpoint, so a plain
-- explode(data) is enough -- no from_json/to_json coercion (SQL companion guide,
-- section 2).
--
-- Rate limit: YES. The operator of the service sets the limits, so they differ
-- between deployments. The built-in defaults are 200 requests a minute with a
-- burst of 20 (standard), and 5 a minute with a burst of 1 (strictest). A burst
-- larger than the allowance gets HTTP 429 even when the average is low, so
-- spread requests out and cache answers on this side. A Lightning REST table
-- re-fetches on EVERY query, so the CACHE TABLE statement below is required,
-- not optional. Run this script once, deliberately; do not loop it.
--   Pacing: if you do not know the tier, assume the strictest (one request every
--   12 seconds, no bursts). Wait 15 seconds or more before each statement
--   marked "calls the endpoint" below, and run statements one at a time. One
--   visible statement can send more than one HTTP request (Zetaris can retry a
--   failing fetch on a few pooled connections), so if a statement fails with a
--   429, wait 60 seconds before retrying that one statement. If you also run
--   12_company_dns_create.sql or 14_company_dns_japan_create.sql, leave a few
--   minutes between the scripts: they call the same service.
--
-- Hosts: the staging hostname resolves from inside the lab network and from
-- outside it; Zetaris fetches the endpoint itself.
--
-- Before running: this script uses the repo's user-agent placeholder. Replace
-- YOUR_APP_NAME YOUR_CONTACT_EMAIL with your own value, or run it with
-- scripts/run_sql.py, which fills it in from ZETARIS_USER_AGENT.
--
-- Status: VERIFIED (recorded 2026-10-11). The CREATE statements and the queries
-- in 13_company_dns_eu_nace_select.sql were run against a live Zetaris instance.
-- Written from a saved copy of the live response (HTTP 200, 615 rows, 8 flat
-- string fields, no nulls).
-- =============================================================================
--
-- The four levels, with the values this endpoint returns:
--
--   level     field         example
--   --------  ------------  -------------------------------------------------
--   section   section_id    A       (letters A-U, 21 sections)
--             section_desc  AGRICULTURE, FORESTRY AND FISHING   (upper case)
--   division  division_id   01      (2 digits, 88 divisions)
--             division_desc Crop and animal production, hunting and related ...
--   group     group_id      01.1    (dotted, 272 groups)
--             group_desc    Growing of non-perennial crops
--   class     class_id      01.11   (dotted, 615 classes, the finest level)
--             class_desc    Growing of cereals (except rice), leguminous crops ...
--
-- Expected counts, from the saved response: 615 classes, 21 sections, 88
-- divisions, 272 groups. These match the published structure of NACE Rev. 2,
-- but the response does not state which revision it holds -- confirm with the
-- maintainer before relying on it.
--
-- Caveats:
--   1. The %25 wildcard (a literal '%') is undocumented behavior of the service:
--      the code path parameter is used in a LIKE, so one '%' matches every row.
--      The path segment `class` in this URL is what the caller asked to search
--      by; the response reports "615 class matches for [%]", so the rows are
--      class level. Other path segments (group, division, section) were not
--      tried -- each would be one more request against the rate limit.
--   2. The URL path says `sic` even though this is NACE, not the US SIC. Do not
--      join this data to US SIC codes on class_id: the code formats differ
--      (NACE class codes are dotted, such as 01.11, US SIC codes are four digits).
--   3. Every id maps to exactly one description and one parent, and every
--      description is unique, in the saved response, so the hierarchy is
--      internally consistent (see the self-consistency query in the select
--      script).
--   4. Mixed case: section_desc is upper case, while division, group and class
--      descriptions are sentence case. A case-sensitive LIKE needs the right
--      case per level; LOWER() avoids the question.
--   5. There is no V3-style compat view here. The compat views in
--      12_company_dns_create.sql exist so SQL written for the older US SIC V3
--      column names keeps working; no such SQL exists for this data.
--   6. DESCRIBE BY only accepts letters, digits, spaces and _ . - , -- see the
--      SQL companion guide.
-- =============================================================================

-- Step 0: register the logical database. (No endpoint call.)
CREATE LIGHTNING DATABASE COMPANY_DNS_EU DESCRIBE BY "company_dns EU NACE classification - section, division, group, class";

-- Step 1: the raw REST table. Calls the endpoint.
CREATE LIGHTNING REST TABLE nace_raw FROM COMPANY_DNS_EU REQUEST(
    endpoint "https://company-dns-staging.mediumroast.io/V4.0/eu/sic/class/%25",
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
CACHE TABLE company_dns_eu.nace_raw;

-- Step 3: the schemastore container that holds the view. It has no IF NOT
-- EXISTS form, so on an instance that already has it, skip this statement.
CREATE SCHEMASTORE CONTAINER company_dns_eu;

-- Step 4: flatten the array into a queryable view, one row per NACE class.
CREATE SCHEMASTORE VIEW nace_table WITH CONTAINER company_dns_eu AS
SELECT
    item.section_id AS section_id,
    item.section_desc AS section_desc,
    item.division_id AS division_id,
    item.division_desc AS division_desc,
    item.group_id AS group_id,
    item.group_desc AS group_desc,
    item.class_id AS class_id,
    item.class_desc AS class_desc
FROM company_dns_eu.nace_raw
LATERAL VIEW explode(data) AS item;

-- =============================================================================
-- Teardown -- removes the flattened view. Commented out by default. DROP VIEW is
-- the only reliable teardown statement. The REST table and the database
-- registration are removed in the Zetaris Data Explorer (no SQL path exists --
-- see HOWTO.md, "Removing a source").
-- =============================================================================

-- DROP VIEW company_dns_eu.nace_table;
-- UNCACHE TABLE company_dns_eu.nace_raw;
