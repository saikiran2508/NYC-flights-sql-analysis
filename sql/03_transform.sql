-- =============================================================
-- 03_transform.sql
-- Cast, clean, and de-duplicate raw data into the core layer.
-- =============================================================

INSERT INTO core.airlines (carrier, name)
SELECT TRIM(carrier), TRIM(name)
FROM raw.airlines;

INSERT INTO core.airports (faa, name, lat, lon, alt_ft, tzone)
SELECT faa, name, lat::NUMERIC, lon::NUMERIC, alt::INTEGER, tzone
FROM raw.airports;

INSERT INTO core.planes (tailnum, year_built, manufacturer, model, engines, seats)
SELECT tailnum, year::SMALLINT, manufacturer, model, engines::SMALLINT, seats::SMALLINT
FROM raw.planes;

-- Guard against duplicate (origin, hour) readings: keep one per hour.
-- (3 local-time duplicates exist around the DST change; they are distinct in UTC.)
INSERT INTO core.weather (origin, time_hour, temp_f, wind_mph, precip_in, visib_mi)
SELECT origin, time_hour, temp_f, wind_mph, precip_in, visib_mi
FROM (
    SELECT origin,
           time_hour::TIMESTAMPTZ                  AS time_hour,
           temp::NUMERIC                           AS temp_f,
           wind_speed::NUMERIC                     AS wind_mph,
           precip::NUMERIC                         AS precip_in,
           visib::NUMERIC                          AS visib_mi,
           ROW_NUMBER() OVER (PARTITION BY origin, time_hour::TIMESTAMPTZ
                              ORDER BY temp::NUMERIC NULLS LAST) AS rn
    FROM raw.weather
) w
WHERE rn = 1;

INSERT INTO core.flights (
    flight_date, carrier, flight_no, tailnum, origin, dest,
    sched_dep_hour, sched_dep_time, dep_time, dep_delay, arr_delay,
    distance_mi, time_hour
)
SELECT MAKE_DATE(year::INT, month::INT, day::INT),
       carrier,
       flight::INT,
       tailnum,
       origin,
       dest,
       hour::SMALLINT,
       sched_dep_time::SMALLINT,
       dep_time::SMALLINT,
       dep_delay::SMALLINT,
       arr_delay::SMALLINT,
       distance::INT,
       time_hour::TIMESTAMPTZ
FROM raw.flights;

CREATE INDEX idx_flights_carrier   ON core.flights (carrier);
CREATE INDEX idx_flights_origin_th ON core.flights (origin, time_hour);
CREATE INDEX idx_flights_tail_date ON core.flights (tailnum, flight_date, sched_dep_time);

ANALYZE;
