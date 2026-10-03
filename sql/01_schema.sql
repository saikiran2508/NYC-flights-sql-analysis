-- =============================================================
-- 01_schema.sql
-- Staging (raw, all text) and clean (typed, constrained) layers
-- for the 2013 NYC departures dataset (5 related tables).
-- =============================================================

DROP SCHEMA IF EXISTS raw CASCADE;
DROP SCHEMA IF EXISTS core CASCADE;
CREATE SCHEMA raw;
CREATE SCHEMA core;

-- ---------- RAW: land the CSVs exactly as delivered ----------
CREATE TABLE raw.airlines (carrier TEXT, name TEXT);

CREATE TABLE raw.airports (
    faa TEXT, name TEXT, lat TEXT, lon TEXT, alt TEXT,
    tz TEXT, dst TEXT, tzone TEXT
);

CREATE TABLE raw.planes (
    tailnum TEXT, year TEXT, type TEXT, manufacturer TEXT, model TEXT,
    engines TEXT, seats TEXT, speed TEXT, engine TEXT
);

CREATE TABLE raw.weather (
    origin TEXT, year TEXT, month TEXT, day TEXT, hour TEXT,
    temp TEXT, dewp TEXT, humid TEXT, wind_dir TEXT, wind_speed TEXT,
    wind_gust TEXT, precip TEXT, pressure TEXT, visib TEXT, time_hour TEXT
);

CREATE TABLE raw.flights (
    year TEXT, month TEXT, day TEXT, dep_time TEXT, sched_dep_time TEXT,
    dep_delay TEXT, arr_time TEXT, sched_arr_time TEXT, arr_delay TEXT,
    carrier TEXT, flight TEXT, tailnum TEXT, origin TEXT, dest TEXT,
    air_time TEXT, distance TEXT, hour TEXT, minute TEXT, time_hour TEXT
);

-- ---------- CORE: typed tables with keys ----------
CREATE TABLE core.airlines (
    carrier      VARCHAR(2) PRIMARY KEY,
    name         TEXT NOT NULL
);

CREATE TABLE core.airports (
    faa          VARCHAR(4) PRIMARY KEY,
    name         TEXT NOT NULL,
    lat          NUMERIC(9,6),
    lon          NUMERIC(9,6),
    alt_ft       INTEGER,
    tzone        TEXT
);

CREATE TABLE core.planes (
    tailnum      VARCHAR(8) PRIMARY KEY,
    year_built   SMALLINT,
    manufacturer TEXT,
    model        TEXT,
    engines      SMALLINT,
    seats        SMALLINT
);

CREATE TABLE core.weather (
    origin       VARCHAR(4) REFERENCES core.airports(faa),
    time_hour    TIMESTAMPTZ,
    temp_f       NUMERIC(5,2),
    wind_mph     NUMERIC(6,2),
    precip_in    NUMERIC(5,2),
    visib_mi     NUMERIC(5,2),
    PRIMARY KEY (origin, time_hour)
);

CREATE TABLE core.flights (
    flight_id      SERIAL PRIMARY KEY,
    flight_date    DATE NOT NULL,
    carrier        VARCHAR(2) NOT NULL REFERENCES core.airlines(carrier),
    flight_no      INTEGER,
    tailnum        VARCHAR(8),          -- not an FK: some tails are missing from planes (see 04_data_quality.sql)
    origin         VARCHAR(4) NOT NULL REFERENCES core.airports(faa),
    dest           VARCHAR(4) NOT NULL, -- not an FK: some destinations are missing from airports
    sched_dep_hour SMALLINT,
    sched_dep_time SMALLINT,            -- HHMM local
    dep_time       SMALLINT,            -- NULL = cancelled
    dep_delay      SMALLINT,            -- minutes
    arr_delay      SMALLINT,            -- minutes
    distance_mi    INTEGER,
    time_hour      TIMESTAMPTZ,         -- scheduled hour, joins to weather
    is_cancelled   BOOLEAN GENERATED ALWAYS AS (dep_time IS NULL) STORED,
    is_on_time     BOOLEAN GENERATED ALWAYS AS (arr_delay <= 15) STORED  -- DOT definition
);
