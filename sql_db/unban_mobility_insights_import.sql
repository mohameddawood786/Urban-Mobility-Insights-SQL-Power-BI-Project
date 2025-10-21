-- 1) scheduled_stop_times (times stored as strings - easy to import)
CREATE TABLE scheduled_stop_times (
  stop_name         VARCHAR2(200),
  scheduled_time_str VARCHAR2(8),
  route_id          VARCHAR2(50),
  stop_id           NUMBER,
  trip_id           VARCHAR2(120)
);

-- 2) actual_stop_time (imported simulated actual times + delay)
CREATE TABLE actual_stop_time (
  trip_id           VARCHAR2(120),
  route_id          VARCHAR2(50),
  stop_id           NUMBER,
  stop_name         VARCHAR2(200),
  scheduled_time_str VARCHAR2(8),
  actual_time_str   VARCHAR2(8),
  delay_minutes     NUMBER,
  stop_lat          NUMBER(9,6),
  stop_lon          NUMBER(9,6)
);

-- 3) stop_accessibility
CREATE TABLE stop_accessibility (
  stop_name         VARCHAR2(200),
  wheelchair_accessible VARCHAR2(5),
  shelter           VARCHAR2(5),
  lighting          VARCHAR2(5),
  stop_id           NUMBER
);

-- 4) routes_cleaned (trip_list, stop_list may be long -> CLOB)
CREATE TABLE routes_cleaned (
  name              VARCHAR2(100),
  full_name         VARCHAR2(255),
  trip_count        NUMBER,
  trip_list         CLOB,
  stop_count        NUMBER,
  stop_list         CLOB,
  id                VARCHAR2(100),
  direction_id      NUMBER
);

-- 5) stops_cleaned
CREATE TABLE stops_cleaned (
  name              VARCHAR2(200),
  trip_count        NUMBER,
  trip_list         CLOB,
  route_count       NUMBER,
  route_list        CLOB,
  id                NUMBER
);

SELECT * FROM scheduled_stop_times;
SELECT * FROM actual_stop_time;
SELECT * FROM stop_accessibility;
SELECT * FROM routes_cleaned;
SELECT * FROM stops_cleaned;