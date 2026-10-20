-- =============================================================================
-- Verification / example queries for 14_company_dns_japan_create.sql
-- Assumes 14_company_dns_japan_create.sql has already been run, including its
-- CACHE TABLE statement.
--
-- RATE LIMITED: every query below is commented out. Run them one at a time,
-- after the create script, by removing the leading "-- ". Do not run this file
-- as a whole. Reason: a Lightning REST table re-fetches on every query unless
-- cached, and it has not been confirmed that a schemastore view reads the cached
-- raw table. Run Verification 1 first and time it: about a second means the view
-- reads the cache; much longer means each query is calling the endpoint, and the
-- rest of this file would spend the rate limit (6,000 a minute with a
-- burst of 600 if you send an identifying User-Agent, 600 a minute with a burst
-- of 60 if not, raised for the event; the service default is 5 a minute, burst
-- of 1). If that happens, stop and report it. If a query fails with a 429, wait
-- 60 seconds before retrying that one query.
--
-- View: company_dns_japan.japan_table, one row per class. Levels: section
-- (letter), division (2 digits), group (3 digits), class (4 digits). Expected
-- values below come from a saved copy of the live response.
-- =============================================================================

-- === Verification ===

-- 1. Row count. Expect 1460. Run this alone first and time it (see above): it is
-- the cache test.
-- SELECT COUNT(*) FROM company_dns_japan.japan_table;

-- 2. Column names and types. Expect the eight string columns section_id,
-- section_desc, division_id, division_desc, group_id, group_desc, class_id,
-- class_desc.
-- DESCRIBE company_dns_japan.japan_table;

-- 3. Independent check against the service, per HOWTO.md section 2. One request,
-- run from a shell, not Zetaris:
--   curl -s -A "app_name user@domain.tld" "https://company-dns.mediumroast.io/V4.0/japan/sic/industry_group/%25" | jq '.data | length'   # 1460

-- === Diagnostics === (run if the view fails or the count does not match)
-- SELECT * FROM company_dns_japan.japan_raw;
-- DESCRIBE company_dns_japan.japan_raw;

-- === Example queries ===
-- Run these against japan_table to confirm the flattened data is correct and
-- usable, not just present. They mirror the US SIC examples in
-- 12_company_dns_select.sql: overview counts, breakdowns at each level, two
-- lookup/search queries, a window function, and a self-consistency check.

-- 4. Overview -- total classes and how many distinct sections, divisions and
-- groups they roll up into. Expect 1460 / 20 / 99 / 530.
-- SELECT
--     COUNT(*) AS total_classes,
--     COUNT(DISTINCT section_id) AS total_sections,
--     COUNT(DISTINCT division_id) AS total_divisions,
--     COUNT(DISTINCT group_id) AS total_groups
-- FROM company_dns_japan.japan_table;

-- 5. Classes per section, ranked. Expect E (MANUFACTURING) first with 595, then
-- I (WHOLESALE AND RETAIL TRADE) with 202.
-- SELECT section_id, section_desc, COUNT(*) AS class_count
-- FROM company_dns_japan.japan_table
-- GROUP BY section_id, section_desc
-- ORDER BY class_count DESC;

-- 6. The 10 divisions (2-digit) with the most classes. Expect division 11
-- (MANUFACTURE OF TEXTILE PRODUCTS) first with 66, then 21 (ceramic, stone and
-- clay products) with 46.
-- SELECT division_id, division_desc, section_id, COUNT(*) AS class_count
-- FROM company_dns_japan.japan_table
-- GROUP BY division_id, division_desc, section_id
-- ORDER BY class_count DESC
-- LIMIT 10;

-- 7. Group diversity per section -- which section spans the most distinct
-- groups. Expect E first with 177.
-- SELECT section_id, section_desc, COUNT(DISTINCT group_id) AS distinct_groups
-- FROM company_dns_japan.japan_table
-- GROUP BY section_id, section_desc
-- ORDER BY distinct_groups DESC;

-- 8. Search: classes whose description mentions "Computer", case-sensitive as
-- written (class descriptions are sentence case; see query 9 for a
-- case-insensitive variant). Expect 1 row.
-- SELECT class_id, class_desc, section_desc, division_desc, group_desc
-- FROM company_dns_japan.japan_table
-- WHERE class_desc LIKE '%Computer%'
-- ORDER BY class_id;

-- 9. The same search, case-insensitive, for "software". Expect 4 rows, including
-- 3911 (Custom software services) and 3912 (Embedded software services). LOWER()
-- is the safe habit here because the section, division and group descriptions
-- are upper case and the class descriptions are sentence case.
-- SELECT class_id, class_desc, section_desc, division_desc, group_desc
-- FROM company_dns_japan.japan_table
-- WHERE LOWER(class_desc) LIKE '%software%'
-- ORDER BY class_id;

-- 10. One representative class per section -- the alphabetically-first
-- description in each section, via ROW_NUMBER() (the standard "top row per
-- group" window-function pattern). Expect 20 rows; section A's is 0122 (Beef
-- cattle farming).
-- SELECT section_id, section_desc, class_id, class_desc
-- FROM (
--     SELECT section_id, section_desc, class_id, class_desc,
--            ROW_NUMBER() OVER (PARTITION BY section_id ORDER BY class_desc) AS rn
--     FROM company_dns_japan.japan_table
-- ) ranked
-- WHERE rn = 1
-- ORDER BY section_id;

-- 11. Self-consistency: each division_id maps to exactly one description, and
-- each group_id to exactly one division. Expect zero rows from both.
-- SELECT division_id, COUNT(DISTINCT division_desc) AS distinct_descriptions
-- FROM company_dns_japan.japan_table
-- GROUP BY division_id
-- HAVING COUNT(DISTINCT division_desc) > 1;
-- SELECT group_id, COUNT(DISTINCT division_id) AS distinct_parent_divisions
-- FROM company_dns_japan.japan_table
-- GROUP BY group_id
-- HAVING COUNT(DISTINCT division_id) > 1;

-- 12. Descriptions shared by more than one id -- the reason to group and rank by
-- id, never by description (see caveat 3 in the create script). Expect 1 row
-- from the first query (a group description used by two group ids) and 15 rows
-- from the second (class descriptions used by more than one class id).
-- SELECT group_desc, COUNT(DISTINCT group_id) AS group_ids
-- FROM company_dns_japan.japan_table
-- GROUP BY group_desc
-- HAVING COUNT(DISTINCT group_id) > 1;
-- SELECT class_desc, COUNT(DISTINCT class_id) AS class_ids
-- FROM company_dns_japan.japan_table
-- GROUP BY class_desc
-- HAVING COUNT(DISTINCT class_id) > 1
-- ORDER BY class_ids DESC, class_desc;
