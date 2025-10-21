import pandas as pd

# Correct path where your file is stored
df = pd.read_csv(r"C:\New Volume D\Dawood\Credo Systemz Practice\SQL Worksheet\SQL Project\Urban_Mobility_Project\processed_data\scheduled_stop_times.csv")

print("Excel rows:", len(df))
