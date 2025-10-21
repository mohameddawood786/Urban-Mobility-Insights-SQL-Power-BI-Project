# python_scripts/prepare_data.py
import os, ast, random
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
import sqlite3

BASE = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
RAW = os.path.join(BASE, "raw_data")
OUT = os.path.join(BASE, "processed_data")
DB = os.path.join(BASE, "sql_db", "urban_mobility.db")
os.makedirs(OUT, exist_ok=True)
os.makedirs(os.path.dirname(DB), exist_ok=True)

# ---------- helper functions ----------
def parse_list_column(df, col):
    """Convert string like "['06:18:08','07:00:00']" -> Python list"""
    if col not in df.columns:
        return df
    def safe_parse(x):
        if pd.isna(x): return []
        try:
            return ast.literal_eval(x)
        except Exception:
            # fallback: remove brackets and split
            s = str(x).strip()
            s = s.strip("[]")
            if not s:
                return []
            return [i.strip().strip("'\"") for i in s.split(",") if i.strip()]
    df[col] = df[col].apply(safe_parse)
    return df

def to_timeobj(t):
    if pd.isna(t) or t=='':
        return None
    # some times may have hh:mm:ss or hh:mm format
    for fmt in ("%H:%M:%S","%H:%M"):
        try:
            return datetime.strptime(t, fmt).time()
        except:
            pass
    return None

def time_to_minutes(t):
    return t.hour*60 + t.minute if t else None

def generate_delay_minutes(sched_time, route_bias=0):
    """Generate integer minutes delay. Peak hours heavier."""
    if sched_time is None:
        return 0
    h = sched_time.hour
    r = np.random.rand()
    # peak windows 7-10, 17-20
    if 7 <= h <= 10 or 17 <= h <= 20:
        delay = int(max(0, np.random.normal(loc=8, scale=5)))
    else:
        delay = int(max(0, np.random.normal(loc=3, scale=3)))
    # occasional big incident
    if r < 0.01:
        delay += random.randint(20, 90)
    # route bias
    delay += int(route_bias)
    return delay

# ---------- Step A: load CSVs ----------
print("Loading CSVs from raw_data...")
agg_path = os.path.join(RAW, "aggregated.csv")
routes_path = os.path.join(RAW, "routes.csv")
stops_path = os.path.join(RAW, "stops.csv")
gtfs_stops_path = os.path.join(RAW, "stops.txt")  # optional
opencity_path = os.path.join(RAW, "opencity_public_transport.xlsx")  # optional

# read whichever exist, if missing raise helpful msg
if not os.path.exists(agg_path) or not os.path.exists(routes_path) or not os.path.exists(stops_path):
    raise SystemExit("Make sure aggregated.csv, routes.csv and stops.csv are in raw_data/ folder.")

agg = pd.read_csv(agg_path)
routes = pd.read_csv(routes_path)
stops = pd.read_csv(stops_path)

# ---------- Step B: parse list columns ----------
for df,col in [(agg,"trip_list"), (routes,"trip_list"), (routes,"stop_list"), (stops,"trip_list"), (stops,"route_list")]:
    if col in df.columns:
        df = parse_list_column(df, col)
        if df is agg: agg = df
        if df is routes: routes = df
        if df is stops: stops = df

# normalize column names for merging (strip)
agg.columns = [c.strip() for c in agg.columns]
routes.columns = [c.strip() for c in routes.columns]
stops.columns = [c.strip() for c in stops.columns]

# ---------- Step C: build lookup dict from routes for matching trip times to route+stop ----------
print("Indexing routes for quick lookup...")
# create route records with (route_id, route_name, stop_list, trip_list)
route_records = []
for i,row in routes.iterrows():
    route_id = str(row.get("id", row.get("name",""))).strip()
    route_name = row.get("name", "")
    stop_list = row.get("stop_list", []) if "stop_list" in row else []
    trip_list = row.get("trip_list", []) if "trip_list" in row else []
    route_records.append({
        "route_id": route_id,
        "route_name": route_name,
        "stop_list": [s.strip() for s in stop_list],
        "trip_list": [t.strip() for t in trip_list]
    })

# map: time -> list of route indices that have that time
time_to_routes = {}
for idx,r in enumerate(route_records):
    for t in r["trip_list"]:
        time_to_routes.setdefault(t, []).append(idx)

# build mapping stop_name -> possible route indices (for speed)
stop_to_routes = {}
for idx,r in enumerate(route_records):
    for s in r["stop_list"]:
        stop_to_routes.setdefault(s, set()).add(idx)

# ---------- Step D: build scheduled_stop_times from aggregated.csv (exploded) ----------
print("Building scheduled_stop_times from aggregated.csv...")
rows = []
for i,row in agg.iterrows():
    stop_name = row.get("name") or row.get("stop_name")
    triplist = row.get("trip_list", []) if "trip_list" in row else []
    # make sure triplist parsed
    for t in triplist:
        tstr = t.strip()
        scheduled_time = to_timeobj(tstr)
        # try to assign route by seeing which route with that time also has this stop
        assigned_route = None
        candidates = time_to_routes.get(tstr, [])
        if candidates:
            # find candidate whose stop_list contains this stop
            found = None
            for c in candidates:
                if stop_name in route_records[c]["stop_list"]:
                    found = c
                    break
            if found is not None:
                assigned_route = route_records[found]["route_id"]
        # fallback: pick any route that serves the stop (if available)
        if not assigned_route:
            poss = stop_to_routes.get(stop_name, set())
            if len(poss) > 0:
                # pick the first
                assigned_route = route_records[list(poss)[0]]["route_id"]
        rows.append({
            "stop_name": stop_name,
            "scheduled_time": scheduled_time,
            "scheduled_time_str": tstr,
            "route_id": assigned_route
        })

sched_df = pd.DataFrame(rows)
# add stop_id if stops.csv has id column
if "id" in stops.columns:
    # map stop_name -> id (note: may need manual cleaning)
    map_name_to_id = {str(r["name"]).strip(): r["id"] for _,r in stops.iterrows()}
    sched_df["stop_id"] = sched_df["stop_name"].map(map_name_to_id)
else:
    sched_df["stop_id"] = None

# order and drop entries without time
sched_df = sched_df.dropna(subset=["scheduled_time"])
sched_df = sched_df.sort_values(["stop_name","scheduled_time"])
sched_df.reset_index(drop=True, inplace=True)

# generate a synthetic trip_id using route + scheduled_time (ensures uniqueness)
def make_trip_id(row):
    rid = row["route_id"] if row["route_id"] else "routeX"
    return f"{rid}__{row['scheduled_time_str']}"
sched_df["trip_id"] = sched_df.apply(make_trip_id, axis=1)

# ---------- Step E: simulate actual_stop_times (delays) ----------
print("Simulating actual_stop_times (delays)...")
# small route bias map: randomly mark some routes as high-delay
unique_routes = [r["route_id"] for r in route_records if r["route_id"]]
route_bias = {}
for r in unique_routes:
    if random.random() < 0.15:  # 15% routes slightly worse
        route_bias[r] = random.uniform(1.5, 4.5)
    else:
        route_bias[r] = 0.0

actual_rows = []
for _,r in sched_df.iterrows():
    sched_time = r["scheduled_time"]
    rid = r["route_id"]
    bias = route_bias.get(rid, 0.0)
    delay = generate_delay_minutes(sched_time, bias)
    # scheduled_time is a datetime.time; create a datetime for today to add minutes
    dt_sched = datetime.combine(datetime.today(), sched_time)
    dt_actual = dt_sched + timedelta(minutes=delay)
    actual_rows.append({
        "trip_id": r["trip_id"],
        "route_id": rid,
        "stop_id": r["stop_id"],
        "stop_name": r["stop_name"],
        "scheduled_time": r["scheduled_time_str"],
        "scheduled_time_obj": sched_time,
        "actual_time_str": dt_actual.strftime("%H:%M:%S"),
        "actual_time_obj": dt_actual.time(),
        "delay_minutes": delay
    })

actual_df = pd.DataFrame(actual_rows)

# ---------- Step F: use GTFS stops.txt to get lat/lon if available and merge ----------
if os.path.exists(gtfs_stops_path):
    print("Found GTFS stops.txt — extracting lat/lon info...")
    try:
        gtfs_stops = pd.read_csv(gtfs_stops_path)
        # GTFS usually uses 'stop_id','stop_name','stop_lat','stop_lon'
        name_to_coords = {}
        for _,r in gtfs_stops.iterrows():
            name_to_coords[str(r.get("stop_name")).strip()] = (r.get("stop_lat"), r.get("stop_lon"))
        actual_df["stop_lat"] = actual_df["stop_name"].map(lambda n: name_to_coords.get(n, (None,None))[0])
        actual_df["stop_lon"] = actual_df["stop_name"].map(lambda n: name_to_coords.get(n, (None,None))[1])
    except Exception as e:
        print("Error reading GTFS stops.txt:", e)

# ---------- Step G: build stop_accessibility using opencity if present, else random assignment ----------
print("Building stop_accessibility.csv ...")
access_df = pd.DataFrame()
if os.path.exists(opencity_path):
    try:
        oc = pd.read_excel(opencity_path, engine="openpyxl")
        # Try to find overall percents from OpenCity — this is heuristics, fallback to random
        # We'll just sample some plausible percentages (if file contains rows)
        percent_shelter = 0.6
        percent_wheelchair = 0.35
        percent_lighting = 0.7
    except Exception:
        percent_shelter = 0.6
        percent_wheelchair = 0.35
        percent_lighting = 0.7
else:
    percent_shelter = 0.6
    percent_wheelchair = 0.35
    percent_lighting = 0.7

# build accessibility for unique stops in sched_df
unique_stops = sorted(sched_df["stop_name"].dropna().unique())
ac_rows = []
for s in unique_stops:
    ac_rows.append({
        "stop_name": s,
        "wheelchair_accessible": random.random() < percent_wheelchair,
        "shelter": random.random() < percent_shelter,
        "lighting": random.random() < percent_lighting
    })
access_df = pd.DataFrame(ac_rows)

# try map to stop_id if available
if "id" in stops.columns:
    name_to_id2 = {str(r["name"]).strip(): r["id"] for _,r in stops.iterrows()}
    access_df["stop_id"] = access_df["stop_name"].map(name_to_id2)
else:
    access_df["stop_id"] = None

# ---------- Step H: save processed CSVs ----------
print("Saving processed CSVs...")
sched_out = os.path.join(OUT, "scheduled_stop_times.csv")
actual_out = os.path.join(OUT, "actual_stop_times.csv")
access_out = os.path.join(OUT, "stop_accessibility.csv")
stops_out = os.path.join(OUT, "stops_cleaned.csv")
routes_out = os.path.join(OUT, "routes_cleaned.csv")

sched_df.to_csv(sched_out, index=False)
actual_df.to_csv(actual_out, index=False)
access_df.to_csv(access_out, index=False)
# save initial stops/routes cleaned for reference
stops.to_csv(stops_out, index=False)
routes.to_csv(routes_out, index=False)

print("Files saved to processed_data/:")
print(" -", sched_out)
print(" -", actual_out)
print(" -", access_out)

# ---------- Step I: write to SQLite DB ----------
print("Writing tables to SQLite DB:", DB)
conn = sqlite3.connect(DB)
sched_df.to_sql("scheduled_stop_times", conn, if_exists="replace", index=False)
actual_df.to_sql("actual_stop_times", conn, if_exists="replace", index=False)
access_df.to_sql("stop_accessibility", conn, if_exists="replace", index=False)
stops.to_sql("stops_raw", conn, if_exists="replace", index=False)
routes.to_sql("routes_raw", conn, if_exists="replace", index=False)
conn.close()
print("Done. SQLite DB created at:", DB)
