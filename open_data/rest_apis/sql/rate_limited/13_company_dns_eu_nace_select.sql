-- =============================================================================
-- Verification / example queries for 13_company_dns_eu_nace_create.sql
-- Assumes 13_company_dns_eu_nace_create.sql has already been run, including its
-- CACHE TABLE statement.
--
-- RATE LIMITED: every query below is commented out. Run them one at a time,
-- after the create script, by removing the leading "-- ". Do not run this file
-- as a whole. Reason: a Lightning REST table re-fetches on every query unless
-- cached, and it has not been confirmed that a schemastore view reads the cached
-- raw table. Run Verification 1 first and time it: about a second means the view
-- reads the cache; much longer means each query is calling the endpoint, and the
-- rest of this file would spend the rate limit (200 a minute with a burst of 20
-- by default, 5 a minute with a burst of 1 at the strictest; the operator sets
-- it). If that happens, stop and report it. If a query fails with a 429, wait 60
-- seconds before retrying that one query.
--
-- View: company_dns_eu.nace_table, one row per NACE class. Levels: section
-- (letter), division (2 digits), group (dotted, 01.1), class (dotted, 01.11).
-- Expected values below come from a saved copy of the live response.
-- =============================================================================

-- === Verification ===

-- 1. Row count. Expect 615. Run this alone first and time it (see above): it is
-- the cache test.
-- SELECT COUNT(*) FROM company_dns_eu.nace_table;

-- 2. Column names and types. Expect the eight string columns section_id,
-- section_desc, division_id, division_desc, group_id, group_desc, class_id,
-- class_desc.
-- DESCRIBE company_dns_eu.nace_table;

-- 3. Independent check against the service, per HOWTO.md section 2. One request,
-- run from a shell, not Zetaris:
--   curl -s "https://company-dns-staging.mediumroast.io/V4.0/eu/sic/class/%25" | jq '.data | length'   # 615

-- === Diagnostics === (run if the view fails or the count does not match)
-- SELECT * FROM company_dns_eu.nace_raw;
-- DESCRIBE company_dns_eu.nace_raw;

-- === Example queries ===
-- Run these against nace_table to confirm the flattened data is correct and
-- usable, not just present. They mirror the US SIC examples in
-- 12_company_dns_select.sql: overview counts, breakdowns at each level, two
-- lookup/search queries, a window function, and a self-consistency check.

-- 4. Overview -- total classes and how many distinct sections, divisions and
-- groups they roll up into. Expect 615 / 21 / 88 / 272.
-- SELECT
--     COUNT(*) AS total_classes,
--     COUNT(DISTINCT section_id) AS total_sections,
--     COUNT(DISTINCT division_id) AS total_divisions,
--     COUNT(DISTINCT group_id) AS total_groups
-- FROM company_dns_eu.nace_table;

-- 5. Classes per section, ranked. Expect C (MANUFACTURING) first with 230, then
-- G (WHOLESALE AND RETAIL TRADE; REPAIR OF MOTOR VEHICLES AND MOTORCYCLES) with 91.
-- SELECT section_id, section_desc, COUNT(*) AS class_count
-- FROM company_dns_eu.nace_table
-- GROUP BY section_id, section_desc
-- ORDER BY class_count DESC;

-- 6. The 10 divisions (2-digit) with the most classes. Expect division 46
-- (wholesale trade) first with 48, then 47 (retail trade) with 37.
-- SELECT division_id, division_desc, section_id, COUNT(*) AS class_count
-- FROM company_dns_eu.nace_table
-- GROUP BY division_id, division_desc, section_id
-- ORDER BY class_count DESC
-- LIMIT 10;

-- 7. Group diversity per section -- which section spans the most distinct
-- groups. Expect C first with 95.
-- SELECT section_id, section_desc, COUNT(DISTINCT group_id) AS distinct_groups
-- FROM company_dns_eu.nace_table
-- GROUP BY section_id, section_desc
-- ORDER BY distinct_groups DESC;

-- 8. Search: classes whose description mentions "Computer", case-sensitive as
-- written (class descriptions are sentence case; see query 9 for a
-- case-insensitive variant). Expect 3 rows.
-- SELECT class_id, class_desc, section_desc, division_desc, group_desc
-- FROM company_dns_eu.nace_table
-- WHERE class_desc LIKE '%Computer%'
-- ORDER BY class_id;

-- 9. The same search, case-insensitive, for "software". Expect 3 rows. LOWER()
-- is the safe habit here because section descriptions are upper case and the
-- other levels are sentence case.
-- SELECT class_id, class_desc, section_desc, division_desc, group_desc
-- FROM company_dns_eu.nace_table
-- WHERE LOWER(class_desc) LIKE '%software%'
-- ORDER BY class_id;

-- 10. One representative class per section -- the alphabetically-first
-- description in each section, via ROW_NUMBER() (the standard "top row per
-- group" window-function pattern). Expect 21 rows.
-- SELECT section_id, section_desc, class_id, class_desc
-- FROM (
--     SELECT section_id, section_desc, class_id, class_desc,
--            ROW_NUMBER() OVER (PARTITION BY section_id ORDER BY class_desc) AS rn
--     FROM company_dns_eu.nace_table
-- ) ranked
-- WHERE rn = 1
-- ORDER BY section_id;

-- 11. Self-consistency: each division_id maps to exactly one description, and
-- each group_id to exactly one division. Expect zero rows from both.
-- SELECT division_id, COUNT(DISTINCT division_desc) AS distinct_descriptions
-- FROM company_dns_eu.nace_table
-- GROUP BY division_id
-- HAVING COUNT(DISTINCT division_desc) > 1;
-- SELECT group_id, COUNT(DISTINCT division_id) AS distinct_parent_divisions
-- FROM company_dns_eu.nace_table
-- GROUP BY group_id
-- HAVING COUNT(DISTINCT division_id) > 1;

-- 12. Descriptions shared by more than one id. Expect zero rows: unlike the
-- Japan data, every NACE description is unique at every level.
-- SELECT class_desc, COUNT(DISTINCT class_id) AS class_ids
-- FROM company_dns_eu.nace_table
-- GROUP BY class_desc
-- HAVING COUNT(DISTINCT class_id) > 1;
