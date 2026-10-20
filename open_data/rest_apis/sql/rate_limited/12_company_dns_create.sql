-- =============================================================================
-- Source: company_dns SIC (Standard Industrial Classification) hierarchy
-- reference data, in BOTH API versions side by side:
--   V3 (deprecated)  https://company-dns.mediumroast.io/V3.0/na/sic/code/%25
--   V4 (production)  https://company-dns.mediumroast.io/V4.0/na/sic/code/%25
-- 1,005 SIC codes in each, with their full hierarchy rollup. This script is
-- the replacement for 10_company_dns_sic_create.sql (now in ../deprecated/): it
-- reuses that script's names (database COMPANY_DNS, container company_dns, raw
-- table sic_codes_raw, view sic_codes_table), so everything built on them keeps
-- working.
--
-- License: company_dns is Apache 2.0 (github.com/miha42-github/company_dns,
-- self-hostable via Docker). Its SIC data traces back to SEC's own public SIC
-- list -- query live, don't bulk-redistribute the extracted data.
--
-- Format: REST/JSON (CREATE LIGHTNING REST TABLE). The two versions differ in
-- shape as well as in field names:
--   V3  data.sics is a dynamic-key ("map-shaped") object, one key per SIC code.
--       It needs the from_json(to_json(...)) coercion to be exploded (SQL
--       companion guide, section 3).
--   V4  data is a plain array of 1,005 flat objects, so a plain explode(data)
--       is enough (SQL companion guide, section 2).
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
-- V3 is deprecated. Steps 1-2 (the V3 raw table) and the V3 views (Steps 6 and 9) are
-- kept so that V3-shaped SQL, and the USL scripts that read company_dns.sic_codes_raw,
-- keep working. The /V3.0 path still answered on the production host when checked
-- (2026-10-19), but expect it to go away: when it does, Steps 1-2 fail, and the V3
-- views and those USL scripts need moving to the V4 data (sic_codes_v4_compat_table
-- carries it under the V3 names).
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
-- Status: VERIFIED (recorded 2026-10-11). Run end to end against a live Zetaris
-- instance: the V3 and V4 raw tables and all four views were created and
-- queried, and the USL models (open_data/usl/sql/01_sic_usl_create.sql and
-- 02_sic_edgar_usl_create.sql) were then created unchanged on top of it and
-- queried. The USL scripts read the V3 raw table (company_dns.sic_codes_raw),
-- not the V4 views.
-- That run used the staging host for V4. On 2026-10-19 the production host answered
-- the same V4 path with the same 1,005 rows, byte for byte the same size; the CREATE
-- statements have not been re-run against it.
-- =============================================================================
--
-- How the two versions name the same four levels:
--
--   level       V3 field             V4 field         example
--   ----------  -------------------  ---------------  ---------------------------
--   letter      division             section_id       D
--   (desc)      division_desc        section_desc     Manufacturing
--   2-digit     major_group          division_id      35
--   (desc)      major_group_desc     division_desc    Industrial And Commercial ...
--   3-digit     industry_group       group_id         357
--   (desc)      industry_group_desc  group_desc       Computer And Office Equipment
--   4-digit     sic_code             class_id         3571
--   (desc)      description          class_desc       Electronic Computers
--
-- CAUTION: `division_desc` means a DIFFERENT LEVEL in the two versions. In V3 it
-- is the letter level (Manufacturing); in V4 it is the 2-digit level. A V3-style
-- WHERE division_desc LIKE '%Manufacturing%' returns nothing on V4 data. This
-- is why the script builds four views (Step 5 onward), named for the data
-- version and the column naming:
--
--   view                          data  column names  use it for
--   ----------------------------  ----  ------------  -------------------------------
--   sic_codes_table               V3    V3            what every existing query, join
--                                                      and USL activation already uses
--   sic_codes_v4_table            V4    V4            V4 as the service now describes it
--   sic_codes_v4_compat_table     V4    V3            V4 data behind V3 column names, so
--                                                      V3-era SQL runs unchanged on V4
--   sic_codes_v3_compat_table     V3    V4            V3 data behind V4 column names, to
--                                                      compare the two like for like
--
-- Caveats:
--   1. The %25 wildcard (a literal '%') is undocumented behavior of the service:
--      the sic_code path parameter is used in a LIKE, so one '%' matches every
--      row. It returns all 1,005 codes in both versions.
--   2. SIC code 3570 is absent from both versions. That is why IBM (SIC 3570)
--      drops out of any inner join to these views, and why the SIC foreign key
--      in the sic_edgar_usl USL flags it.
--   3. USL: the USL models (open_data/usl/sql/) activate straight from the raw
--      V3 table (company_dns.sic_codes_raw), not from a view, so they are not
--      affected by the views below. Whether ACTIVATE USL TABLE can read a
--      schemastore view, and so activate from sic_codes_v4_compat_table, is
--      untested.
--   4. DESCRIBE BY only accepts letters, digits, spaces and _ . - , -- see the
--      SQL companion guide.
-- =============================================================================

-- Step 0: register the logical database. One database holds both versions' raw
-- tables. (No endpoint call.)
CREATE LIGHTNING DATABASE COMPANY_DNS DESCRIBE BY "company_dns SIC reference data - V3 and V4 side by side - section or division, group, class";

-- Step 1: the V3 raw table. Calls the endpoint.
CREATE LIGHTNING REST TABLE sic_codes_raw FROM COMPANY_DNS REQUEST(
    endpoint "https://company-dns.mediumroast.io/V3.0/na/sic/code/%25",
    method "get",
    response_type "json",
    http_encoding "URLENCODED"
) HEADER (
    user-agent "YOUR_APP_NAME YOUR_CONTACT_EMAIL"
) BODY ();

-- Step 2: cache the V3 raw table. Wait 15 seconds or more after Step 1. Calls
-- the endpoint.
CACHE TABLE company_dns.sic_codes_raw;

-- Step 3: the V4 raw table. Wait 15 seconds or more after Step 2. Calls the
-- endpoint. Shape: {code, message, module, data: [8 flat string fields],
-- dependencies, total}.
CREATE LIGHTNING REST TABLE sic_codes_v4_raw FROM COMPANY_DNS REQUEST(
    endpoint "https://company-dns.mediumroast.io/V4.0/na/sic/code/%25",
    method "get",
    response_type "json",
    http_encoding "URLENCODED"
) HEADER (
    user-agent "YOUR_APP_NAME YOUR_CONTACT_EMAIL"
) BODY ();

-- Step 4: cache the V4 raw table. Wait 15 seconds or more after Step 3. Calls
-- the endpoint. From here on, every view reads the cached copies. (Whether a
-- schemastore view reads the cached raw table has not been separately
-- confirmed -- time the first COUNT(*) in the select script: about a second
-- means cached, much longer means it re-fetched.)
CACHE TABLE company_dns.sic_codes_v4_raw;

-- Step 5: the schemastore container that holds the views. It has no IF NOT
-- EXISTS form, so on an instance that already has it, skip this statement.
CREATE SCHEMASTORE CONTAINER company_dns;

-- Step 6: V3 data, V3 column names. The same view 10_company_dns_sic_create.sql
-- builds, under the same name. Decodes the one dynamic-key object (data.sics)
-- by forcing Spark's inferred struct into a map so explode() can use it.
CREATE SCHEMASTORE VIEW sic_codes_table WITH CONTAINER company_dns AS
SELECT
    sic_code,
    sic_val.description AS description,
    sic_val.division AS division,
    sic_val.division_desc AS division_desc,
    sic_val.major_group AS major_group,
    sic_val.major_group_desc AS major_group_desc,
    sic_val.industry_group AS industry_group,
    sic_val.industry_group_desc AS industry_group_desc
FROM company_dns.sic_codes_raw
LATERAL VIEW explode(
    from_json(to_json(data.sics), 'map<string, struct<description:string, division:string, division_desc:string, major_group:string, major_group_desc:string, industry_group:string, industry_group_desc:string>>')
) AS sic_code, sic_val;

-- Step 7: V4 data, V4 column names. A plain explode over the flat array.
CREATE SCHEMASTORE VIEW sic_codes_v4_table WITH CONTAINER company_dns AS
SELECT
    item.section_id AS section_id,
    item.section_desc AS section_desc,
    item.division_id AS division_id,
    item.division_desc AS division_desc,
    item.group_id AS group_id,
    item.group_desc AS group_desc,
    item.class_id AS class_id,
    item.class_desc AS class_desc
FROM company_dns.sic_codes_v4_raw
LATERAL VIEW explode(data) AS item;

-- Step 8: V4 data behind the V3 column names. Run V3-era queries, joins and
-- USL activation queries against V4 unchanged by pointing them at this view.
-- Column order matches sic_codes_table.
CREATE SCHEMASTORE VIEW sic_codes_v4_compat_table WITH CONTAINER company_dns AS
SELECT
    item.class_id AS sic_code,
    item.class_desc AS description,
    item.section_id AS division,
    item.section_desc AS division_desc,
    item.division_id AS major_group,
    item.division_desc AS major_group_desc,
    item.group_id AS industry_group,
    item.group_desc AS industry_group_desc
FROM company_dns.sic_codes_v4_raw
LATERAL VIEW explode(data) AS item;

-- Step 9: V3 data behind the V4 column names, the mirror of Step 8. Lets the
-- two versions be compared in the same vocabulary. Column order matches
-- sic_codes_v4_table.
CREATE SCHEMASTORE VIEW sic_codes_v3_compat_table WITH CONTAINER company_dns AS
SELECT
    sic_val.division AS section_id,
    sic_val.division_desc AS section_desc,
    sic_val.major_group AS division_id,
    sic_val.major_group_desc AS division_desc,
    sic_val.industry_group AS group_id,
    sic_val.industry_group_desc AS group_desc,
    sic_code AS class_id,
    sic_val.description AS class_desc
FROM company_dns.sic_codes_raw
LATERAL VIEW explode(
    from_json(to_json(data.sics), 'map<string, struct<description:string, division:string, division_desc:string, major_group:string, major_group_desc:string, industry_group:string, industry_group_desc:string>>')
) AS sic_code, sic_val;

-- =============================================================================
-- Teardown -- removes the four views. Commented out by default. DROP VIEW is the
-- only reliable teardown statement. The REST tables and the database
-- registration are removed in the Zetaris Data Explorer (no SQL path exists --
-- see HOWTO.md, "Removing a source").
-- =============================================================================

-- DROP VIEW company_dns.sic_codes_v3_compat_table;
-- DROP VIEW company_dns.sic_codes_v4_compat_table;
-- DROP VIEW company_dns.sic_codes_v4_table;
-- DROP VIEW company_dns.sic_codes_table;
-- UNCACHE TABLE company_dns.sic_codes_v4_raw;
-- UNCACHE TABLE company_dns.sic_codes_raw;
