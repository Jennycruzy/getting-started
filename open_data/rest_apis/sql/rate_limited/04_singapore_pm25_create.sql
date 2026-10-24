-- =============================================================================
-- Source: Singapore data.gov.sg -- PM2.5 (air quality) real-time API.
-- Moved from sql/known_to_fail/ on 2026-10-24 after a live run passed
-- (see Status below). The original HTTP 502 write-up stays at
-- ../known_to_fail/ISSUE.md as the record of the earlier run.
--
-- License: Singapore Open Data Licence (SODL) v1.0 --
-- https://data.gov.sg/open-data-licence -- worldwide, perpetual,
-- royalty-free, CC-BY-equivalent. Attribution required, e.g.:
-- "Contains information from data.gov.sg accessed on {date} which is
-- made available under the terms of the Singapore Open Data Licence
-- version 1.0."
--
-- Format: REST/JSON, top-level object, array-of-structs with a fixed
-- (non-array) nested struct per item -- see the SQL companion guide
-- for the general shape taxonomy.
--
-- Docs: https://guide.data.gov.sg/developer-guide/real-time-apis
--
-- Rate limit: no key needed for testing; documented as 5
-- requests/minute, though the actual burst limit observed is much
-- tighter -- see caveat 4.
--
-- Before running: sanity-check the endpoint returns something sane:
--   curl -s "https://api-open.data.gov.sg/v2/real-time/api/pm25?date=2026-09-18" | python3 -m json.tool | head -30
--
-- Status: live-tested and confirmed working (2026-10-24) on Zetaris
-- 2.4.3.1 (local Docker bundle, statements sent through the SQL API, one
-- at a time, 10-15 seconds apart): the database, container, base table,
-- CACHE TABLE, all three views, and all 8 example queries in the select
-- script ran successfully. Per-region average/min/max from example query
-- 2 match the same figures computed directly from the curl response.
-- The earlier HTTP 502 (cloud SQL Workspace, 2026-09-19) did not
-- reproduce in this environment; see caveat 4. The Data Explorer
-- preview path in the cloud SQL Workspace was not re-tested.
-- =============================================================================
--
-- Caveats:
--   1. The response is a top-level object: {code, data: {regionMetadata,
--      items}, errorMsg}. Both `regionMetadata` and `items` are arrays,
--      one level under `data` rather than at the top level. `items` is
--      one row per reading timestamp, with a fixed struct of per-region
--      values (not an array) -- unlike an array-of-structs, there's no
--      inner explode() needed for the per-region breakdown, just
--      dot-access into the fixed pm25_one_hourly struct.
--   2. An earlier version of this script selected a
--      `pm25_one_hourly.national` field that does not exist in the real
--      response -- `pm25_one_hourly` only ever has the 5 region keys
--      (east, west, north, south, central), confirmed by inspecting
--      every key across a full day of readings. There is no single
--      national figure provided by this endpoint; it has to be
--      computed (e.g. an average across the 5 regions), not read off a
--      field that isn't there. See the select script for the computed
--      replacement.
--   3. Without a `date` parameter, this endpoint returns only the
--      single latest reading. Adding `?date=YYYY-MM-DD` returns every
--      hourly reading published for that calendar day (24 items for a
--      complete past day, confirmed via curl). This script uses a
--      fixed past date (2026-09-18) so the example is reproducible.
--   4. A plain GET needs no special header or authentication at all --
--      confirmed via repeated curl testing. The endpoint's real burst
--      limit is much tighter than documented: about 5-6 requests within
--      5-8 seconds trips a 429, which clears after about 30 seconds.
--      On 2026-09-19 a single CREATE LIGHTNING REST TABLE in the cloud
--      SQL Workspace returned HTTP 502 (../known_to_fail/ISSUE.md). On
--      2026-10-24 (Zetaris 2.4.3.1, SQL API) the same statement
--      succeeded, and the rate limit behaved as follows:
--        - Uncached, every query re-fetched the endpoint: 8 identical
--          SELECTs sent back to back returned 6 successes, then
--          "REST API call failed: Server returned HTTP response code:
--          429" on the 7th and 8th. The source's 429 came through as a
--          429, not a 502.
--        - After CACHE TABLE, 8 and then 20 identical SELECTs sent back
--          to back all succeeded, each in about 0.1-0.25 s instead of
--          about 0.4 s. The cache stopped the re-fetching.
--      Hence the CACHE TABLE step straight after the base table below.
--      Run the statements one at a time and wait about 30 seconds after
--      any 429 before retrying.
--   5. The long-format view (pm25_readings_long_table) used to be five
--      SELECTs from pm25_readings_table joined by UNION ALL. On
--      2026-10-24 that CREATE SCHEMASTORE VIEW failed with
--      MISSING_ATTRIBUTES.RESOLVED_ATTRIBUTE_APPEAR_IN_OPERATION, the
--      same error the SQL companion guide section 4 describes for a
--      view referenced more than once in one query. The view below
--      builds the same 120 rows (24 readings x 5 regions) in one pass
--      with LATERAL VIEW stack(), reading the base table once.
-- =============================================================================

-- Step 0: Lightning database for this source.
CREATE LIGHTNING DATABASE SG_DATAGOVSG_REST DESCRIBE BY "Singapore data.gov.sg real-time API REST source";

-- Step 1: schemastore container. Run once -- comment out on a re-run
-- if it already exists in your environment.
CREATE SCHEMASTORE CONTAINER singapore;

-- PM2.5 -- a full day of hourly readings, 2026-09-18 (24 hours, 5 regions)
CREATE LIGHTNING REST TABLE pm25_readings_20260918 FROM SG_DATAGOVSG_REST REQUEST(
    endpoint "https://api-open.data.gov.sg/v2/real-time/api/pm25?date=2026-09-18",
    method "get",
    response_type "json",
    http_encoding "URLENCODED"
) HEADER (
) BODY ();

-- Cache the raw REST table before running anything else against it --
-- see caveat 4.
CACHE TABLE sg_datagovsg_rest.pm25_readings_20260918;

-- Wide-format view -- one row per hourly reading, one column per region.
CREATE SCHEMASTORE VIEW pm25_readings_table WITH CONTAINER singapore AS
SELECT
    item.date AS reading_date,
    item.timestamp AS reading_timestamp,
    item.`updatedTimestamp` AS updated_timestamp,
    item.readings.pm25_one_hourly.north AS pm25_north,
    item.readings.pm25_one_hourly.south AS pm25_south,
    item.readings.pm25_one_hourly.east AS pm25_east,
    item.readings.pm25_one_hourly.west AS pm25_west,
    item.readings.pm25_one_hourly.central AS pm25_central
FROM sg_datagovsg_rest.pm25_readings_20260918
LATERAL VIEW explode(data.items) AS item;

-- Region reference view -- name and coordinates, a static lookup table
-- that pairs naturally with the readings above.
CREATE SCHEMASTORE VIEW pm25_regions_table WITH CONTAINER singapore AS
SELECT
    region.name AS region_name,
    region.`labelLocation`.latitude AS latitude,
    region.`labelLocation`.longitude AS longitude
FROM sg_datagovsg_rest.pm25_readings_20260918
LATERAL VIEW explode(data.regionMetadata) AS region;

-- Long-format cross-region view -- one row per (timestamp, region) pair
-- instead of one column per region, which makes GROUP BY region,
-- ORDER BY value, and per-hour ranking queries more natural than
-- pivoting on 5 separate columns every time. Built in one pass with
-- stack() rather than five UNION ALL branches -- see caveat 5.
CREATE SCHEMASTORE VIEW pm25_readings_long_table WITH CONTAINER singapore AS
SELECT
    item.timestamp AS reading_timestamp,
    r.region,
    r.pm25
FROM sg_datagovsg_rest.pm25_readings_20260918
LATERAL VIEW explode(data.items) AS item
LATERAL VIEW stack(5,
    'north',   item.readings.pm25_one_hourly.north,
    'south',   item.readings.pm25_one_hourly.south,
    'east',    item.readings.pm25_one_hourly.east,
    'west',    item.readings.pm25_one_hourly.west,
    'central', item.readings.pm25_one_hourly.central
) r AS region, pm25;

-- =============================================================================
-- Teardown -- removes the flattened views this script created.
-- Commented out by default. See the SQL companion guide for why
-- DROP VIEW is the only reliable teardown statement, and how to remove
-- the underlying REST table and database registration (Zetaris Data
-- Explorer -- no SQL path exists). This database may be shared with
-- other data.gov.sg real-time sources if any are added later.
-- =============================================================================

-- DROP VIEW singapore.pm25_readings_long_table;
-- DROP VIEW singapore.pm25_regions_table;
-- DROP VIEW singapore.pm25_readings_table;
-- UNCACHE TABLE sg_datagovsg_rest.pm25_readings_20260918;
