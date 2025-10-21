--Aggregations to create in SQL

-- A. stop_agg: stop-level aggregates
CREATE TABLE stop_agg AS
a

-- B. route_agg: route-level aggregates
CREATE TABLE route_agg AS
SELECT route_id,
       COUNT(*) AS total_trips,
       ROUND(AVG(delay_minutes),2) AS avg_delay,
       SUM(CASE WHEN delay_minutes > 5 THEN 1 ELSE 0 END) AS delayed_trips,
       ROUND(100 * SUM(CASE WHEN delay_minutes > 5 THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0),2) AS pct_delayed
FROM actual_stop_time
GROUP BY route_id;

-- C. hourly_agg: hour-of-day aggregates
CREATE TABLE hourly_agg AS
SELECT SUBSTR(scheduled_time_str,1,2) AS hour_of_day,
       COUNT(*) AS trips,
       ROUND(AVG(delay_minutes),2) avg_delay
FROM actual_stop_time
GROUP BY SUBSTR(scheduled_time_str,1,2);

-- D. punctuality_agg: distribution for categories
CREATE TABLE punctuality_agg AS
SELECT CASE WHEN delay_minutes < -2 THEN 'Early'
            WHEN delay_minutes BETWEEN -2 AND 5 THEN 'On-time'
            ELSE 'Late'
       END AS punctuality_status,
       COUNT(*) AS trips
FROM actual_stop_time
GROUP BY CASE WHEN delay_minutes < -2 THEN 'Early'
              WHEN delay_minutes BETWEEN -2 AND 5 THEN 'On-time'
              ELSE 'Late' END;

-- E. scheduled_vs_actual_trip (improved; handles single-stop trips and midnight)
CREATE TABLE trip_duration_agg AS
WITH scheduled AS (
   SELECT trip_id,
          COUNT(*) AS scheduled_points,
          MIN(TO_DATE(scheduled_time_str,'HH24:MI:SS')) AS s_min,
          MAX(TO_DATE(scheduled_time_str,'HH24:MI:SS')) AS s_max
   FROM scheduled_stop_times
   GROUP BY trip_id
),
actual AS (
   SELECT trip_id,
          COUNT(*) AS actual_points,
          MIN(TO_DATE(actual_time_str,'HH24:MI:SS')) AS a_min,
          MAX(TO_DATE(actual_time_str,'HH24:MI:SS')) AS a_max
   FROM actual_stop_time
   GROUP BY trip_id
)
SELECT s.trip_id,
       s.scheduled_points, a.actual_points,
       -- convert to minutes and handle midnight by adding 1 day if end < start
       ((CASE WHEN s.s_max < s.s_min THEN s.s_max + 1 ELSE s.s_max END) - s.s_min)*24*60 AS scheduled_min,
       ((CASE WHEN a.a_max < a.a_min THEN a.a_max + 1 ELSE a.a_max END) - a.a_min)*24*60 AS actual_min,
       ROUND((((CASE WHEN a.a_max < a.a_min THEN a.a_max + 1 ELSE a.a_max END) - a.a_min) -
              ((CASE WHEN s.s_max < s.s_min THEN s.s_max + 1 ELSE s.s_max END) - s.s_min)) * 24*60,2) AS extra_delay_min
FROM scheduled s JOIN actual a ON s.trip_id = a.trip_id
WHERE s.scheduled_points > 1 AND a.actual_points > 1;
