-- 1. Average Delay per Stop
-- What: Identifies which stops face the longest average delays.
-- How: Grouped trips by stop and calculated average & max delay.

SELECT
    stop_name,
    COUNT(*) AS total_trips,
    ROUND(AVG(delay_minutes),2) AS avg_delay_minutes,
    MAX(delay_minutes) AS max_delay
FROM actual_stop_time
GROUP BY stop_name
ORDER BY max_delay DESC;


-- 2. Average Delay per Route
-- What: Finds the most unreliable routes overall.
-- How: Grouped trips by route_id and computed delay averages.

SELECT
    route_id,
    COUNT(*) AS total_trips,
    ROUND(AVG(delay_minutes),2) AS avg_delay_minutes,
    MAX(delay_minutes) AS max_delay
FROM actual_stop_time
GROUP BY route_id
ORDER BY avg_delay_minutes DESC;


-- 3. Delay Category Distribution
-- What: Shows how trips are distributed into On-time, Minor Delay, Major Delay.
-- How: Used CASE to classify delays into categories.

SELECT
    CASE
        WHEN delay_minutes <= 5 THEN 'On-time'
        WHEN delay_minutes <= 15 THEN 'Minor Delay'
        ELSE 'Major Delay'
    END AS delay_category,
    COUNT(*) AS trips
FROM actual_stop_time
GROUP BY
    CASE
        WHEN delay_minutes <= 5 THEN 'On-time'
        WHEN delay_minutes <= 15 THEN 'Minor Delay'
        ELSE 'Major Delay'
    END
ORDER BY trips DESC;


-- 4. Peak Hour Analysis
-- What: Shows how delays vary by time of day.
-- How: Extracted the hour from scheduled_time_str and averaged delays.

SELECT
    SUBSTR(scheduled_time_str,1,2) AS hour_of_day,
    COUNT(*) AS trips,
    ROUND(AVG(delay_minutes),2) AS avg_delay
FROM actual_stop_time
GROUP BY SUBSTR(scheduled_time_str,1,2)
ORDER BY hour_of_day;


-- 5. Accessibility Insights (Per Stop)
-- What: Checks if poor accessibility stops also have higher delays.
-- How: Joined actual_stop_time with stop_accessibility.

SELECT a.stop_name,
       ROUND(AVG(a.delay_minutes),2) AS avg_delay,
       sa.wheelchair_accessible,
       sa.shelter,
       sa.lighting
FROM actual_stop_time a
LEFT JOIN stop_accessibility sa
  ON a.stop_name = sa.stop_name
GROUP BY a.stop_name, sa.wheelchair_accessible, sa.shelter, sa.lighting
ORDER BY avg_delay DESC;


-- 6. Geospatial Delay Hotspots
-- What: Enables mapping stops with high delays on a city map.
-- How: Grouped by stop lat/lon and calculated average delays.

SELECT stop_name, stop_lat, stop_lon, ROUND(AVG(delay_minutes),2) AS avg_delay
FROM actual_stop_time
GROUP BY stop_name, stop_lat, stop_lon;


-- 7. Route Reliability Ranking
-- What: Ranks routes by on-time performance and delay percentage.
-- How: Counted delayed trips (>5 mins) and compared with total trips.

SELECT route_id,
       COUNT(*) AS total_trips,
       SUM(CASE WHEN delay_minutes > 5 THEN 1 ELSE 0 END) AS delayed_trips,
       ROUND(100 * SUM(CASE WHEN delay_minutes > 5 THEN 1 ELSE 0 END) / COUNT(*),2) AS pct_delayed
FROM actual_stop_time
GROUP BY route_id
ORDER BY pct_delayed DESC;


-- 8. Punctuality Insights (Early vs On-time vs Late)
-- What: Measures early arrivals, on-time trips, and late arrivals separately.
-- How: Classified trips using delay thresholds.

SELECT
  CASE 
    WHEN delay_minutes < -2 THEN 'Early'
    WHEN delay_minutes BETWEEN -2 AND 5 THEN 'On-time'
    ELSE 'Late'
  END AS punctuality_status,
  COUNT(*) AS trips
FROM actual_stop_time
GROUP BY
  CASE 
    WHEN delay_minutes < -2 THEN 'Early'
    WHEN delay_minutes BETWEEN -2 AND 5 THEN 'On-time'
    ELSE 'Late'
  END;


-- 9. Stop-Level Bottlenecks
-- What: Identifies the top 10 worst-performing stops.
-- How: Filtered high-trip stops and ranked by average delay.

SELECT stop_name,
       ROUND(AVG(delay_minutes),2) AS avg_delay,
       COUNT(*) AS trips
FROM actual_stop_time
GROUP BY stop_name
HAVING COUNT(*) > 100
ORDER BY avg_delay DESC
FETCH FIRST 10 ROWS ONLY;


-- 10. Day-of-Week Trends
-- What: Compares weekday vs weekend service reliability.
-- How: Extracted day-of-week from scheduled_time_str.

SELECT TO_CHAR(TO_DATE(scheduled_time_str,'HH24:MI:SS'),'DAY') AS day_of_week,
       ROUND(AVG(delay_minutes),2) AS avg_delay,
       COUNT(*) AS trips
FROM actual_stop_time
GROUP BY TO_CHAR(TO_DATE(scheduled_time_str,'HH24:MI:SS'),'DAY')
ORDER BY avg_delay DESC;


-- 11. Stop Bottleneck Analysis (Interchange Stops)
-- What: Tests if stops with multiple routes suffer more delays.
-- How: Joined stops_cleaned with actual_stop_time and compared route_count.

SELECT 
    s.name AS stop_name,
    s.route_count,
    COUNT(a.trip_id) AS trips,
    NVL(ROUND(AVG(a.delay_minutes),2), 0) AS avg_delay
FROM stops_cleaned s
LEFT JOIN actual_stop_time a 
  ON s.id = a.stop_id
GROUP BY s.name, s.route_count
ORDER BY avg_delay DESC;


-- 12. Accessibility Equity Impact
-- What: Compares average delays between accessible and non-accessible stops.
-- How: Aggregated average delays by wheelchair accessibility flag.

SELECT sa.wheelchair_accessible,
       ROUND(AVG(a.delay_minutes),2) AS avg_delay,
       COUNT(*) AS trips
FROM actual_stop_time a
JOIN stop_accessibility sa
  ON a.stop_id = sa.stop_id
GROUP BY sa.wheelchair_accessible;


-- 13. High-Coverage Routes Impact
-- What: Analyzes whether routes with many stops have higher delays.
-- How: Used routes_cleaned stop_count with average delays.

SELECT r.name AS route_name,
       r.stop_count,
       ROUND(AVG(a.delay_minutes),2) AS avg_delay
FROM routes_cleaned r
LEFT JOIN actual_stop_time a
  ON r.id = a.route_id
GROUP BY r.name, r.stop_count
ORDER BY r.stop_count DESC;


-- 14. Direction-Based Delay Analysis
-- What: Compares inbound vs outbound route delays.
-- How: Grouped by direction_id and averaged delays.

SELECT r.direction_id,
       ROUND(AVG(a.delay_minutes),2) AS avg_delay,
       COUNT(*) AS trips
FROM routes_cleaned r
JOIN actual_stop_time a
  ON r.id = a.route_id
GROUP BY r.direction_id
ORDER BY avg_delay DESC;


SELECT 
  ROUND(
    COUNT(CASE WHEN delay_minutes <= 5 THEN 1 END) * 100.0 / COUNT(*), 
    2
  ) AS pct_on_time
FROM actual_stop_time;