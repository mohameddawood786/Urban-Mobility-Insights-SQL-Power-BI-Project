--Step 1.2: Test Conversion on Scheduled Times
-- Preview scheduled times as proper DATE format
SELECT 
    stop_name,
    scheduled_time_str,
    TO_DATE(scheduled_time_str, 'HH24:MI:SS') AS scheduled_time
FROM scheduled_stop_times
WHERE ROWNUM <= 10;

-- Compute delay ignoring date
SELECT 
    stop_name,
    scheduled_time_str,
    actual_time_str,
    (TO_DATE(actual_time_str,'HH24:MI:SS') - TO_DATE(scheduled_time_str,'HH24:MI:SS')) * 24*60 AS delay_minutes
FROM actual_stop_time
WHERE ROWNUM <= 10;

-- Verify delay calculation
SELECT
    trip_id,
    stop_name,
    TO_DATE(actual_time_str, 'HH24:MI:SS') AS actual_time,
    TO_DATE(scheduled_time_str, 'HH24:MI:SS') AS scheduled_time,
    (TO_DATE(actual_time_str, 'HH24:MI:SS') - TO_DATE(scheduled_time_str, 'HH24:MI:SS')) * 24 * 60 AS computed_delay_minutes
FROM actual_stop_time
WHERE ROWNUM <= 10;

-- Categorize delay
SELECT
    trip_id,
    stop_name,
    delay_minutes,
    CASE 
        WHEN delay_minutes <= 5 THEN 'On-time'
        WHEN delay_minutes <= 15 THEN 'Minor Delay'
        ELSE 'Major Delay'
    END AS delay_category
FROM actual_stop_time
WHERE ROWNUM <= 20;

-- Only if date exists in data
SELECT
    trip_id,
    stop_name,
    TO_DATE(actual_time_str, 'HH24:MI:SS') AS actual_time,
    TO_CHAR(TO_DATE(actual_time_str, 'HH24:MI:SS'), 'DY') AS day_of_week
FROM actual_stop_time
WHERE ROWNUM <= 20;

-- Null checks
SELECT COUNT(*) AS missing_times
FROM actual_stop_time
WHERE actual_time_str IS NULL OR scheduled_time_str IS NULL;

--Check nulls / anomalies in actual_stop_time:
SELECT * 
FROM actual_stop_time
WHERE actual_time_str IS NULL OR scheduled_time_str IS NULL
   OR delay_minutes < 0 OR delay_minutes > 120;  -- Arbitrary upper limit


-- Example: explode stop_list into individual stops
SELECT
    id AS route_id,
    name AS route_name,
    TRIM(REGEXP_SUBSTR(stop_list, '[^,]+', 1, LEVEL)) AS stop_name
FROM routes_cleaned
CONNECT BY LEVEL <= REGEXP_COUNT(stop_list, ',') + 1
       AND PRIOR id = id
       AND PRIOR SYS_GUID() IS NOT NULL;
     
     
       
WITH cleaned AS (
    SELECT 
        id AS route_id,
        name AS route_name,
        -- Remove starting [ and ending ] 
        TRIM(BOTH '[' FROM TRIM(BOTH ']' FROM stop_list)) AS stops_str
    FROM routes_cleaned
)
SELECT
    route_id,
    route_name,
    -- Extract each stop using REGEXP_SUBSTR
    TRIM(BOTH '''' FROM REGEXP_SUBSTR(stops_str, '[^,]+', 1, LEVEL)) AS stop_name
FROM cleaned
CONNECT BY LEVEL <= REGEXP_COUNT(stops_str, ',') + 1
       AND PRIOR route_id = route_id
       AND PRIOR SYS_GUID() IS NOT NULL;


WITH cleaned AS (
    SELECT 
        id AS route_id,
        name AS route_name,
        -- Remove starting [ and ending ] and extra spaces
        TRIM(BOTH '[' FROM TRIM(BOTH ']' FROM stop_list)) AS stops_str
    FROM routes_cleaned
)
SELECT
    route_id,
    route_name,
    -- Remove single quotes and leading/trailing spaces
    TRIM(BOTH '''' FROM TRIM(stop_name_raw)) AS stop_name
FROM cleaned
CROSS JOIN LATERAL (
    SELECT REGEXP_SUBSTR(stops_str, '[^,]+', 1, LEVEL) AS stop_name_raw
    FROM dual
    CONNECT BY LEVEL <= REGEXP_COUNT(stops_str, ',') + 1
) t;


--Full SQL Script: Analytics-Ready Dataset

-- Step 1: Normalize routes_cleaned.stop_list
WITH routes_normalized AS (
    SELECT
        id AS route_id,
        name AS route_name,
        TRIM(BOTH '''' FROM TRIM(REGEXP_SUBSTR(
    TRIM(BOTH '[' FROM TRIM(BOTH ']' FROM DBMS_LOB.SUBSTR(stop_list, 32767, 1))),
    '[^,]+', 1, LEVEL))) AS stop_name
    FROM routes_cleaned
    CONNECT BY LEVEL <= REGEXP_COUNT(TRIM(BOTH '[' FROM TRIM(BOTH ']' FROM stop_list)), ',') + 1
           AND PRIOR id = id
           AND PRIOR SYS_GUID() IS NOT NULL
),

-- Step 2: Normalize stops_cleaned.trip_list
stops_normalized AS (
    SELECT
        id AS stop_id,
        name AS stop_name,
        TRIM(REGEXP_SUBSTR(
    TRIM(BOTH '[' FROM TRIM(BOTH ']' FROM DBMS_LOB.SUBSTR(trip_list, 32767, 1))),
    '[^,]+', 1, LEVEL)) AS trip_time_str
    FROM stops_cleaned
    CONNECT BY LEVEL <= REGEXP_COUNT(TRIM(BOTH '[' FROM TRIM(BOTH ']' FROM trip_list)), ',') + 1
           AND PRIOR id = id
           AND PRIOR SYS_GUID() IS NOT NULL
),

-- Step 3: Prepare actual_stop_time with computed delay, delay category, hour of day
actual_with_metrics AS (
    SELECT
        trip_id,
        stop_id,
        stop_name,
        route_id,
        scheduled_time_str,
        actual_time_str,
        -- Convert strings to datetime using dummy date
        TO_DATE('01-JAN-2000 ' || scheduled_time_str,'DD-MON-YYYY HH24:MI:SS') AS scheduled_time,
        TO_DATE('01-JAN-2000 ' || actual_time_str,'DD-MON-YYYY HH24:MI:SS') AS actual_time,
        ROUND((TO_DATE('01-JAN-2000 ' || actual_time_str,'DD-MON-YYYY HH24:MI:SS') -
               TO_DATE('01-JAN-2000 ' || scheduled_time_str,'DD-MON-YYYY HH24:MI:SS')) * 24 * 60, 0) AS computed_delay_minutes,
        CASE
            WHEN (TO_DATE('01-JAN-2000 ' || actual_time_str,'DD-MON-YYYY HH24:MI:SS') -
                  TO_DATE('01-JAN-2000 ' || scheduled_time_str,'DD-MON-YYYY HH24:MI:SS')) * 24 * 60 <= 5 THEN 'On-time'
            WHEN (TO_DATE('01-JAN-2000 ' || actual_time_str,'DD-MON-YYYY HH24:MI:SS') -
                  TO_DATE('01-JAN-2000 ' || scheduled_time_str,'DD-MON-YYYY HH24:MI:SS')) * 24 * 60 <= 15 THEN 'Minor Delay'
            ELSE 'Major Delay'
        END AS delay_category,
        TO_NUMBER(TO_CHAR(TO_DATE('01-JAN-2000 ' || actual_time_str,'DD-MON-YYYY HH24:MI:SS'),'HH24')) AS hour_of_day
    FROM actual_stop_time
)

-- Step 4: Final analytics-ready dataset
SELECT
    a.trip_id,
    a.stop_id,
    a.stop_name,
    a.route_id,
    r.route_name,
    a.scheduled_time,
    a.actual_time,
    a.computed_delay_minutes,
    a.delay_category,
    a.hour_of_day,
    s.trip_time_str AS scheduled_trip_time
FROM actual_with_metrics a
LEFT JOIN routes_normalized r
    ON a.route_id = r.route_id
   AND a.stop_name = r.stop_name
LEFT JOIN stops_normalized s
    ON a.stop_id = s.stop_id
   AND a.scheduled_time_str = s.trip_time_str
ORDER BY a.route_id, a.stop_id, a.scheduled_time;
