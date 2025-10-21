# 🚦 Urban Mobility Insights – SQL & Power BI Project

## 📘 Overview
Urban cities often face daily challenges like traffic congestion, inefficient public transport, and unpredictable commute times.  
This project provides **data-driven insights** into urban mobility patterns using **SQL** for analysis and **Power BI** for visualization — enabling city planners and decision-makers to improve transit efficiency.

---

## 🚦 Problem Statement
Public transportation inefficiency leads to **longer travel times**, **reduced productivity**, and **poor commuter satisfaction**.  
With rapid urbanization, cities need **data-backed solutions** to optimize transit routes and reduce congestion.

---

## 🎯 Objective
To analyze transportation datasets and identify **delay hotspots**, **peak congestion hours**, and **underperforming routes**, helping stakeholders make informed operational and policy decisions.

---

## 🧾 Dataset Description
- **Type:** Simulated multi-source dataset (ride-sharing, bus, metro, and traffic data)  
- **Columns:** `Trip_ID`, `Route_ID`, `Pickup_Time`, `Drop_Time`, `Distance`, `Delay_Minutes`, `Fare`, `Zone`, `Vehicle_Type`  
- **Volume:** ~50,000 records across multiple city zones  
- **Purpose:** To replicate real-world transit analytics for performance optimization

---

## 🛠️ Tools & Technologies
- **SQL:** Data extraction, cleaning, transformation, and KPI calculation  
- **Power BI:** Dashboard creation and visualization  
- **Excel:** Initial preprocessing and pivot analysis  
- **Python (Pandas, Matplotlib):** Exploratory data validation  

---

## 🔍 Methodology

### 1️⃣ Data Cleaning & Preparation
- Removed duplicates and standardized timestamps  
- Converted location data into zone clusters  

### 2️⃣ SQL Analysis
- Aggregated trip durations, delays, and route efficiency metrics  
- Identified peak congestion periods and top 10 underperforming routes  

### 3️⃣ Visualization in Power BI
- Designed KPI cards (avg. delay time, on-time rate, busiest route)  
- Created heatmaps, trend lines, and comparative route analysis visuals  
- Added dynamic filters (zone, vehicle type, time period)  

### 4️⃣ Insights Compilation
- Interpreted visual outputs into actionable recommendations  

---

## 📊 Key Insights & Results
- 🚗 **Evening peak (5–8 PM)** showed a **35% increase in average trip duration** compared to off-peak hours  
- 🚌 **Route 12A** consistently recorded **25% more delays**, indicating scheduling inefficiencies  
- 🌇 **Metro utilization** was **20% lower on weekends**, suggesting off-peak optimization opportunities  
- ⚙️ Recommended interventions could reduce average commute times by **15–20%**

---

## 📈 Dashboard Preview
<img width="1136" height="643" alt="Screenshot 2025-09-14 231113" src="https://github.com/user-attachments/assets/4ac6bb1d-25fc-492a-a89e-0df9672354e7" />


---

## 🧩 How to Recreate the Project
1. **Clone this repository**  
   ```bash
   git clone https://github.com/mohameddawood786/Urban-Mobility-Insights-SQL-Power-BI-Project.git
