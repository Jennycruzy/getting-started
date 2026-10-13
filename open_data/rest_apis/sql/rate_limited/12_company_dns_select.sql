-- =============================================================================
-- Verification / example queries for 12_company_dns_create.sql
-- Assumes 12_company_dns_create.sql has already been run, including both CACHE
-- TABLE statements.
--
-- RATE LIMITED: every query below is commented out. Run them one at a time,
-- after the create script, by removing the leading "-- ". Do not run this file
-- as a whole. Reason: a Lightning REST table re-fetches on every query unless
-- cached, and it has not been confirmed that a schemastore view reads the cached
-- raw table. Run Verification 1 first and time it: about a second means the
-- views read the cache; much longer means each query is calling the endpoint,
-- and the rest of this file would spend the rate limit (200 a minute with a
-- burst of 20 by default, 5 a minute with a burst of 1 at the strictest; the
-- operator sets it). If that happens, stop and report it. If a query fails with
-- a 429, wait 60 seconds before retrying that one query.
--
-- Views (see the table in the create script's header):
--   sic_codes_table             V3 data, V3 column names
--   sic_codes_v4_table          V4 data, V4 column names
--   sic_codes_v4_compat_table   V4 data, V3 column names
--   sic_codes_v3_compat_table   V3 data, V4 column names
-- =============================================================================

-- === Verification ===

-- 1a. Row count of ONE view. Expect 1005. Run this alone first and time it (see
-- the note at the top): it is the cache test.
-- SELECT COUNT(*) FROM company_dns.sic_codes_table;

-- 1b. Only if 1a was fast: the row count of every view in one query. Expect 1005
-- for each. Then repeat the 1a timing check for sic_codes_v4_table, since the V4
-- raw table is a separate cache.
-- SELECT 'sic_codes_table' AS view_name, COUNT(*) AS row_count FROM company_dns.sic_codes_table
-- UNION ALL SELECT 'sic_codes_v4_table', COUNT(*) FROM company_dns.sic_codes_v4_table
-- UNION ALL SELECT 'sic_codes_v4_compat_table', COUNT(*) FROM company_dns.sic_codes_v4_compat_table
-- UNION ALL SELECT 'sic_codes_v3_compat_table', COUNT(*) FROM company_dns.sic_codes_v3_compat_table;

-- 2. Column names of each view. Compare against the table in the create script.
-- DESCRIBE company_dns.sic_codes_table;
-- DESCRIBE company_dns.sic_codes_v4_table;
-- DESCRIBE company_dns.sic_codes_v4_compat_table;
-- DESCRIBE company_dns.sic_codes_v3_compat_table;

-- 3. Independent check against the services, per HOWTO.md section 2. Two
-- requests, one per version, run from a shell, not Zetaris:
--   curl -s "https://company-dns.mediumroast.io/V3.0/na/sic/code/%25" | jq '.data.sics | length'   # 1005
--   curl -s "https://company-dns-staging.mediumroast.io/V4.0/na/sic/code/%25" | jq '.data | length'   # 1005

-- 4. SIC 3570 is absent from both versions. Expect zero rows from each.
-- SELECT sic_code FROM company_dns.sic_codes_table WHERE sic_code = '3570';
-- SELECT class_id FROM company_dns.sic_codes_v4_table WHERE class_id = '3570';

-- === V3 against V4: what changed ===
-- These join two different views (different raw tables), not a view against a
-- derivative of itself, so the self-join error in HOWTO.md "MISSING_ATTRIBUTES"
-- should not apply. If one of them does fail with that error, report it.

-- 5. Same set of SIC codes in both versions, compared in V3 vocabulary. Expect
-- zero rows: a row here is a code present in only one version.
-- SELECT COALESCE(a.sic_code, b.sic_code) AS sic_code,
--        a.description AS in_v3_only_description, b.description AS in_v4_only_description
-- FROM company_dns.sic_codes_table a
-- FULL OUTER JOIN company_dns.sic_codes_v4_compat_table b ON a.sic_code = b.sic_code
-- WHERE a.sic_code IS NULL OR b.sic_code IS NULL;

-- 6. For codes in both, how many rows differ in each field (V3 against V4, both
-- in V3 names). A rename alone cannot cause a difference here, because the compat
-- view already maps the names. Expect 0 everywhere if V4 only renamed the levels;
-- any non-zero count is a real content change between V3 and V4.
-- SELECT
--     SUM(CASE WHEN a.description <> b.description THEN 1 ELSE 0 END) AS description_differs,
--     SUM(CASE WHEN a.division <> b.division THEN 1 ELSE 0 END) AS division_differs,
--     SUM(CASE WHEN a.division_desc <> b.division_desc THEN 1 ELSE 0 END) AS division_desc_differs,
--     SUM(CASE WHEN a.major_group <> b.major_group THEN 1 ELSE 0 END) AS major_group_differs,
--     SUM(CASE WHEN a.major_group_desc <> b.major_group_desc THEN 1 ELSE 0 END) AS major_group_desc_differs,
--     SUM(CASE WHEN a.industry_group <> b.industry_group THEN 1 ELSE 0 END) AS industry_group_differs,
--     SUM(CASE WHEN a.industry_group_desc <> b.industry_group_desc THEN 1 ELSE 0 END) AS industry_group_desc_differs
-- FROM company_dns.sic_codes_table a
-- JOIN company_dns.sic_codes_v4_compat_table b ON a.sic_code = b.sic_code;

-- 7. The rows behind any non-zero count in query 6 (first 25).
-- SELECT a.sic_code, a.description AS v3_description, b.description AS v4_description,
--        a.major_group_desc AS v3_major_group_desc, b.major_group_desc AS v4_major_group_desc
-- FROM company_dns.sic_codes_table a
-- JOIN company_dns.sic_codes_v4_compat_table b ON a.sic_code = b.sic_code
-- WHERE a.description <> b.description OR a.major_group_desc <> b.major_group_desc
--    OR a.industry_group_desc <> b.industry_group_desc OR a.division_desc <> b.division_desc
-- ORDER BY a.sic_code
-- LIMIT 25;

-- 8. The renamed-level trap, shown on two real codes: the SAME column name,
-- division_desc, holds a different level in each version. Expect V3 to show
-- Manufacturing / Services and V4 to show the 2-digit division labels.
-- SELECT a.sic_code, a.division_desc AS v3_division_desc, b.division_desc AS v4_division_desc
-- FROM company_dns.sic_codes_table a
-- JOIN company_dns.sic_codes_v4_table b ON a.sic_code = b.class_id
-- WHERE a.sic_code IN ('3571', '7372')
-- ORDER BY a.sic_code;

-- 9. The same comparison as query 6, in V4 names: V3 data behind V4 names
-- (sic_codes_v3_compat_table) against V4 data (sic_codes_v4_table). Expect zero
-- rows if the content is identical apart from names. It also checks that the V3
-- compat view maps the levels the way the header table says.
-- SELECT a.class_id, a.class_desc AS v3_class_desc, b.class_desc AS v4_class_desc
-- FROM company_dns.sic_codes_v3_compat_table a
-- JOIN company_dns.sic_codes_v4_table b ON a.class_id = b.class_id
-- WHERE a.class_desc <> b.class_desc OR a.group_desc <> b.group_desc
--    OR a.division_desc <> b.division_desc OR a.section_desc <> b.section_desc
-- ORDER BY a.class_id;

-- === Example queries, V3 names (unchanged from 10_company_dns_sic_select.sql) ===
-- Run against sic_codes_table (V3 data). To run the same queries on V4 data, use
-- sic_codes_v4_compat_table instead: the column names are identical.

-- 10. Overview -- total SIC codes and how many distinct divisions/major groups/
-- industry groups. Expect 1005/10/83/416.
-- SELECT
--     COUNT(*) AS total_sic_codes,
--     COUNT(DISTINCT division) AS total_divisions,
--     COUNT(DISTINCT major_group) AS total_major_groups,
--     COUNT(DISTINCT industry_group) AS total_industry_groups
-- FROM company_dns.sic_codes_table;

-- 11. SIC codes per division, ranked. Manufacturing (division D) dominates.
-- SELECT division, division_desc, COUNT(*) AS sic_code_count
-- FROM company_dns.sic_codes_table
-- GROUP BY division, division_desc
-- ORDER BY sic_code_count DESC;

-- 12. The 10 most granular major groups (2-digit).
-- SELECT major_group, major_group_desc, division, COUNT(*) AS sic_code_count
-- FROM company_dns.sic_codes_table
-- GROUP BY major_group, major_group_desc, division
-- ORDER BY sic_code_count DESC
-- LIMIT 10;

-- 13. Industry-group diversity per division.
-- SELECT division, division_desc, COUNT(DISTINCT industry_group) AS distinct_industry_groups
-- FROM company_dns.sic_codes_table
-- GROUP BY division, division_desc
-- ORDER BY distinct_industry_groups DESC;

-- 14. Search: every SIC code whose description mentions "Computer".
-- SELECT sic_code, description, division_desc, major_group_desc, industry_group_desc
-- FROM company_dns.sic_codes_table
-- WHERE description LIKE '%Computer%'
-- ORDER BY sic_code;

-- 15. Case-insensitive search for "software".
-- SELECT sic_code, description, division_desc, major_group_desc, industry_group_desc
-- FROM company_dns.sic_codes_table
-- WHERE LOWER(description) LIKE '%software%'
-- ORDER BY sic_code;

-- 16. One representative SIC code per division (ROW_NUMBER, the standard
-- "top row per group" pattern).
-- SELECT division, division_desc, sic_code, description
-- FROM (
--     SELECT division, division_desc, sic_code, description,
--            ROW_NUMBER() OVER (PARTITION BY division ORDER BY description) AS rn
--     FROM company_dns.sic_codes_table
-- ) ranked
-- WHERE rn = 1
-- ORDER BY division;

-- 17. Self-consistency: each major_group maps to exactly one description.
-- Expect zero rows.
-- SELECT major_group, COUNT(DISTINCT major_group_desc) AS distinct_descriptions_for_this_major_group
-- FROM company_dns.sic_codes_table
-- GROUP BY major_group
-- HAVING COUNT(DISTINCT major_group_desc) > 1;

-- === Example queries, V4 names (against sic_codes_v4_table) ===
-- The same eight questions, ported. V4 levels: section (letter), division
-- (2-digit), group (3-digit), class (4-digit SIC code).

-- 18. Overview. Expect 1005/10/83/416.
-- SELECT
--     COUNT(*) AS total_classes,
--     COUNT(DISTINCT section_id) AS total_sections,
--     COUNT(DISTINCT division_id) AS total_divisions,
--     COUNT(DISTINCT group_id) AS total_groups
-- FROM company_dns.sic_codes_v4_table;

-- 19. Classes per section, ranked. Manufacturing (section D) dominates.
-- SELECT section_id, section_desc, COUNT(*) AS class_count
-- FROM company_dns.sic_codes_v4_table
-- GROUP BY section_id, section_desc
-- ORDER BY class_count DESC;

-- 20. The 10 divisions (2-digit) with the most classes.
-- SELECT division_id, division_desc, section_id, COUNT(*) AS class_count
-- FROM company_dns.sic_codes_v4_table
-- GROUP BY division_id, division_desc, section_id
-- ORDER BY class_count DESC
-- LIMIT 10;

-- 21. Group diversity per section.
-- SELECT section_id, section_desc, COUNT(DISTINCT group_id) AS distinct_groups
-- FROM company_dns.sic_codes_v4_table
-- GROUP BY section_id, section_desc
-- ORDER BY distinct_groups DESC;

-- 22. Search: every class whose description mentions "Computer".
-- SELECT class_id, class_desc, section_desc, division_desc, group_desc
-- FROM company_dns.sic_codes_v4_table
-- WHERE class_desc LIKE '%Computer%'
-- ORDER BY class_id;

-- 23. Case-insensitive search for "software".
-- SELECT class_id, class_desc, section_desc, division_desc, group_desc
-- FROM company_dns.sic_codes_v4_table
-- WHERE LOWER(class_desc) LIKE '%software%'
-- ORDER BY class_id;

-- 24. One representative class per section.
-- SELECT section_id, section_desc, class_id, class_desc
-- FROM (
--     SELECT section_id, section_desc, class_id, class_desc,
--            ROW_NUMBER() OVER (PARTITION BY section_id ORDER BY class_desc) AS rn
--     FROM company_dns.sic_codes_v4_table
-- ) ranked
-- WHERE rn = 1
-- ORDER BY section_id;

-- 25. Self-consistency: each division_id maps to exactly one description.
-- Expect zero rows.
-- SELECT division_id, COUNT(DISTINCT division_desc) AS distinct_descriptions_for_this_division
-- FROM company_dns.sic_codes_v4_table
-- GROUP BY division_id
-- HAVING COUNT(DISTINCT division_desc) > 1;
