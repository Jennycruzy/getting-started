-- =============================================================================
-- Source: PLACES: Census Tract Data (GIS Friendly Format), 2025 release
-- Source id: yjkw-uj5s
-- Docs: https://data.cdc.gov/Health-Status/PLACES-Census-Tract-Data-GIS-Friendly-Format-2025-/yjkw-uj5s (query syntax: https://dev.socrata.com/docs/queries/)
-- Format: bare top-level JSON array; columns are read directly
-- Source count checked 2026-10-26: 71. Montgomery County, AL (FIPS 01101) tracts. Recheck before running.
-- License: Public domain. CDC: most information on its websites "is not subject to copyright, is in the public domain, and may be freely used or reproduced without obtaining copyright permission" (https://www.cdc.gov/other/agencymaterials.html); the dataset's own metadata also labels it Public Domain.
-- Status: Verified 2026-10-26 on Zetaris 2.4.3.1: every statement here and both select queries ran; the records view returned 71 rows.
-- Anonymous requests may be throttled; cache each raw table and stop on HTTP 429.
-- =============================================================================
CREATE LIGHTNING DATABASE CDC_PLACES_TRACTS_REST DESCRIBE BY "Fieldwork discovered public source";
CREATE SCHEMASTORE CONTAINER cdc_places_tracts;
CREATE LIGHTNING REST TABLE source_raw_p0 FROM CDC_PLACES_TRACTS_REST REQUEST (endpoint "https://data.cdc.gov/resource/yjkw-uj5s.json?%24where=countyfips%3D%2701101%27&%24select=tractfips%2Ccountyfips%2Ctotalpopulation%2Ctotalpop18plus%2Ccasthma_crudeprev%2Cbphigh_crudeprev%2Cdiabetes_crudeprev&%24limit=50000", method "GET", response_type "JSON", http_encoding "URLENCODED") HEADER () BODY ();
CACHE TABLE cdc_places_tracts_rest.source_raw_p0;
CREATE SCHEMASTORE VIEW records WITH CONTAINER cdc_places_tracts AS
SELECT tractfips, countyfips, totalpopulation, totalpop18plus, casthma_crudeprev, bphigh_crudeprev, diabetes_crudeprev FROM cdc_places_tracts_rest.source_raw_p0;
