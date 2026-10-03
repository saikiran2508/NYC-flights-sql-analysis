-- =============================================================
-- 05_analysis.sql
-- Business question: what drives departure delays out of New York
-- (JFK, LGA, EWR), and which carriers, routes, and conditions
-- perform best and worst?
--
-- On-time = arrived within 15 minutes of schedule (U.S. DOT definition).
-- Rates are computed over completed flights unless noted.
-- Each block starting with "-- @query" is exported to results/<name>.csv
-- =============================================================


-- @query q1_airport_kpis
-- Headline KPIs by NYC origin airport.
SELECT f.origin,
       a.name                                                         AS airport,
       COUNT(*)                                                       AS scheduled_flights,
       ROUND(100.0 * AVG(f.is_cancelled::INT), 2)                     AS cancel_rate_pct,
       ROUND(100.0 * AVG(f.is_on_time::INT), 1)                       AS on_time_pct,
       ROUND(AVG(f.dep_delay), 1)                                     AS avg_dep_delay_min,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY f.dep_delay)       AS median_dep_delay_min
FROM core.flights f
JOIN core.airports a ON a.faa = f.origin
GROUP BY f.origin, a.name
ORDER BY on_time_pct DESC;


-- @query q2_carrier_scorecard
-- Carrier scorecard, ranked by on-time performance (carriers with 1,000+ flights).
WITH carrier_stats AS (
    SELECT f.carrier,
           l.name                                        AS airline,
           COUNT(*)                                      AS flights,
           ROUND(100.0 * AVG(f.is_on_time::INT), 1)      AS on_time_pct,
           ROUND(100.0 * AVG(f.is_cancelled::INT), 2)    AS cancel_rate_pct,
           ROUND(AVG(f.arr_delay), 1)                    AS avg_arr_delay_min
    FROM core.flights f
    JOIN core.airlines l ON l.carrier = f.carrier
    GROUP BY f.carrier, l.name
    HAVING COUNT(*) >= 1000
)
SELECT RANK() OVER (ORDER BY on_time_pct DESC)                AS on_time_rank,
       carrier, airline, flights, on_time_pct, cancel_rate_pct, avg_arr_delay_min,
       ROUND(100.0 * flights / SUM(flights) OVER (), 1)       AS share_of_nyc_flights_pct
FROM carrier_stats
ORDER BY on_time_rank;


-- @query q3_monthly_trend
-- Monthly on-time trend with month-over-month change (LAG).
WITH monthly AS (
    SELECT DATE_TRUNC('month', flight_date)::DATE           AS month,
           COUNT(*)                                         AS flights,
           ROUND(100.0 * AVG(is_on_time::INT), 1)           AS on_time_pct,
           ROUND(AVG(dep_delay), 1)                         AS avg_dep_delay_min
    FROM core.flights
    GROUP BY 1
)
SELECT month, flights, on_time_pct, avg_dep_delay_min,
       on_time_pct - LAG(on_time_pct) OVER (ORDER BY month)  AS on_time_change_pts
FROM monthly
ORDER BY month;


-- @query q4_delay_by_hour
-- Delays by scheduled departure hour: how delays build through the day.
SELECT sched_dep_hour,
       COUNT(*)                                          AS flights,
       ROUND(100.0 * AVG(is_on_time::INT), 1)            AS on_time_pct,
       ROUND(AVG(dep_delay), 1)                          AS avg_dep_delay_min,
       ROUND(100.0 * AVG((dep_delay > 60)::INT), 1)      AS pct_delayed_over_1hr
FROM core.flights
WHERE dep_time IS NOT NULL
GROUP BY sched_dep_hour
HAVING COUNT(*) >= 100
ORDER BY sched_dep_hour;


-- @query q5_delay_propagation
-- Knock-on delays: does a late inbound leg make the same aircraft's next departure late?
-- LAG() finds each plane's previous flight that day.
WITH legs AS (
    SELECT tailnum, flight_date, sched_dep_time, dep_delay,
           LAG(arr_delay) OVER (PARTITION BY tailnum, flight_date
                                ORDER BY sched_dep_time)  AS prev_leg_arr_delay
    FROM core.flights
    WHERE tailnum IS NOT NULL AND dep_time IS NOT NULL
)
SELECT CASE
         WHEN prev_leg_arr_delay <= 15 THEN '1. Previous leg on time'
         WHEN prev_leg_arr_delay <= 60 THEN '2. Previous leg 16-60 min late'
         ELSE                               '3. Previous leg 60+ min late'
       END                                              AS previous_leg_status,
       COUNT(*)                                         AS flights,
       ROUND(AVG(dep_delay), 1)                         AS avg_dep_delay_min,
       ROUND(100.0 * AVG((dep_delay > 15)::INT), 1)     AS pct_departed_late
FROM legs
WHERE prev_leg_arr_delay IS NOT NULL
GROUP BY 1
ORDER BY 1;


-- @query q6_weather_impact
-- Weather impact: join each flight to the hourly weather at its origin.
SELECT CASE
         WHEN w.visib_mi < 1                       THEN '1. Low visibility (<1 mi)'
         WHEN w.precip_in > 0                      THEN '2. Precipitation'
         WHEN w.wind_mph >= 20                     THEN '3. High wind (20+ mph)'
         ELSE                                           '4. Clear conditions'
       END                                                  AS conditions,
       COUNT(*)                                             AS flights,
       ROUND(100.0 * AVG(f.is_cancelled::INT), 2)           AS cancel_rate_pct,
       ROUND(100.0 * AVG(f.is_on_time::INT), 1)             AS on_time_pct,
       ROUND(AVG(f.dep_delay), 1)                           AS avg_dep_delay_min
FROM core.flights f
JOIN core.weather w
  ON w.origin = f.origin AND w.time_hour = f.time_hour
GROUP BY 1
ORDER BY 1;


-- @query q7_worst_routes
-- Highest-volume routes with the lowest on-time rates (500+ flights).
SELECT f.origin || '-' || f.dest                         AS route,
       COALESCE(a.name, f.dest)                          AS destination,
       COUNT(*)                                          AS flights,
       ROUND(100.0 * AVG(f.is_on_time::INT), 1)          AS on_time_pct,
       ROUND(AVG(f.arr_delay), 1)                        AS avg_arr_delay_min
FROM core.flights f
LEFT JOIN core.airports a ON a.faa = f.dest
GROUP BY f.origin, f.dest, a.name
HAVING COUNT(*) >= 500
ORDER BY on_time_pct ASC
LIMIT 10;


-- @query q8_best_carrier_per_airport
-- Best and worst carrier at each NYC airport (ROW_NUMBER within origin, 1,000+ flights).
WITH by_origin AS (
    SELECT origin, carrier,
           COUNT(*)                                    AS flights,
           ROUND(100.0 * AVG(is_on_time::INT), 1)      AS on_time_pct
    FROM core.flights
    GROUP BY origin, carrier
    HAVING COUNT(*) >= 1000
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY origin ORDER BY on_time_pct DESC) AS best_rank,
           ROW_NUMBER() OVER (PARTITION BY origin ORDER BY on_time_pct ASC)  AS worst_rank
    FROM by_origin
)
SELECT r.origin,
       CASE WHEN r.best_rank = 1 THEN 'Best' ELSE 'Worst' END   AS position,
       l.name                                                   AS airline,
       r.flights, r.on_time_pct
FROM ranked r
JOIN core.airlines l ON l.carrier = r.carrier
WHERE r.best_rank = 1 OR r.worst_rank = 1
ORDER BY r.origin, position;
