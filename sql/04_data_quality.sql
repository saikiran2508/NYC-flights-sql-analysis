-- =============================================================
-- 04_data_quality.sql
-- Validation checks run after loading. Each returns one row.
-- =============================================================

-- DQ1: Row counts carried from raw to core (should match)
SELECT 'flights' AS tbl,
       (SELECT COUNT(*) FROM raw.flights)  AS raw_rows,
       (SELECT COUNT(*) FROM core.flights) AS core_rows
UNION ALL
SELECT 'weather', (SELECT COUNT(*) FROM raw.weather), (SELECT COUNT(*) FROM core.weather);

-- DQ2: Missing values in key flight fields
SELECT COUNT(*)                                       AS total_flights,
       COUNT(*) FILTER (WHERE dep_time IS NULL)       AS no_departure_cancelled,
       COUNT(*) FILTER (WHERE dep_time IS NOT NULL
                          AND arr_delay IS NULL)      AS departed_no_arrival_delay,
       COUNT(*) FILTER (WHERE tailnum IS NULL)        AS missing_tailnum
FROM core.flights;

-- DQ3: Orphan keys -- flights referencing planes / airports not in the dimension tables
SELECT
    (SELECT COUNT(*) FROM core.flights f
      WHERE f.tailnum IS NOT NULL
        AND NOT EXISTS (SELECT 1 FROM core.planes p WHERE p.tailnum = f.tailnum))  AS flights_unknown_tail,
    (SELECT COUNT(DISTINCT f.dest) FROM core.flights f
      LEFT JOIN core.airports a ON a.faa = f.dest
      WHERE a.faa IS NULL)                                                         AS unknown_dest_airports,
    (SELECT STRING_AGG(DISTINCT f.dest, ', ') FROM core.flights f
      LEFT JOIN core.airports a ON a.faa = f.dest
      WHERE a.faa IS NULL)                                                         AS unknown_dest_codes;

-- DQ4: Flights whose scheduled hour has no matching weather reading
SELECT COUNT(*) AS flights_without_weather
FROM core.flights f
LEFT JOIN core.weather w
       ON w.origin = f.origin AND w.time_hour = f.time_hour
WHERE w.origin IS NULL;
