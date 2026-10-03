-- =============================================================
-- 02_load.sql   (run with psql from the project root)
-- Loads the raw CSVs. The source marks missing values as 'NA'.
-- =============================================================

\copy raw.airlines FROM 'data/airlines.csv' WITH (FORMAT csv, HEADER true, NULL 'NA')
\copy raw.airports FROM 'data/airports.csv' WITH (FORMAT csv, HEADER true, NULL 'NA')
\copy raw.planes   FROM 'data/planes.csv'   WITH (FORMAT csv, HEADER true, NULL 'NA')
\copy raw.weather  FROM 'data/weather.csv'  WITH (FORMAT csv, HEADER true, NULL 'NA')
\copy raw.flights  FROM 'data/flights.csv'  WITH (FORMAT csv, HEADER true, NULL 'NA')
