"""Step 3: clean the SCMS Delivery History dataset and add KPI columns."""
import pandas as pd
import numpy as np

RAW = "data/raw/scms_delivery_history.csv"
OUT = "data/clean/shipments_clean.csv"

df = pd.read_csv(RAW, encoding="cp1252")

# 1. Standardise column names: "Freight Cost (USD)" -> "freight_cost_usd"
df.columns = (df.columns.str.strip().str.lower()
              .str.replace(r"[^a-z0-9]+", "_", regex=True).str.strip("_"))

# 2. Parse dates (text like "2-Jun-06"; "Date Not Captured" becomes NaT)
date_cols = {
    "po_sent_to_vendor_date": "po_sent_date",
    "scheduled_delivery_date": "scheduled_date",
    "delivered_to_client_date": "delivered_date",
}
for src, dst in date_cols.items():
    df[dst] = pd.to_datetime(df[src], format="%d-%b-%y", errors="coerce")

# 3. Freight and weight: keep numbers, flag the text cases
freight_txt = df["freight_cost_usd"].astype(str)
df["freight_status"] = np.select(
    [freight_txt.str.contains("Included", case=False),
     freight_txt.str.contains("Invoiced Separately", case=False),
     freight_txt.str.startswith("See")],
    ["Included in commodity cost", "Invoiced separately", "Recorded on another line"],
    default="Reported")
df["freight_usd"] = pd.to_numeric(df["freight_cost_usd"], errors="coerce")
df["weight_kg"] = pd.to_numeric(df["weight_kilograms"], errors="coerce")
df["insurance_usd"] = pd.to_numeric(df["line_item_insurance_usd"], errors="coerce")

# 4. Fill categorical blanks
df["shipment_mode"] = df["shipment_mode"].fillna("Unknown")
df["is_internal_rdc"] = df["vendor"].eq("SCMS from RDC")

# 5. KPI columns
df["delay_days"] = (df["delivered_date"] - df["scheduled_date"]).dt.days
df["is_late"] = (df["delay_days"] > 0).astype(int)
df["is_on_time"] = 1 - df["is_late"]
df["delay_bucket"] = pd.cut(
    df["delay_days"], bins=[-np.inf, 0, 7, 30, 90, np.inf],
    labels=["On time/early", "1-7 days", "8-30 days", "31-90 days", "90+ days"])
df["lead_time_days"] = (df["delivered_date"] - df["po_sent_date"]).dt.days
df.loc[df["lead_time_days"] < 0, "lead_time_days"] = np.nan  # bad records
df["freight_pct_of_value"] = np.where(
    (df["line_item_value"] > 0) & df["freight_usd"].notna(),
    df["freight_usd"] / df["line_item_value"], np.nan)
df["freight_per_kg"] = np.where(
    (df["weight_kg"] > 0) & df["freight_usd"].notna(),
    df["freight_usd"] / df["weight_kg"], np.nan)
df["landed_cost_usd"] = (df["line_item_value"] + df["freight_usd"].fillna(0)
                         + df["insurance_usd"].fillna(0))
df["scheduled_month"] = df["scheduled_date"].dt.to_period("M").dt.to_timestamp()
df["scheduled_year"] = df["scheduled_date"].dt.year

# 6. Keep the columns the project needs and save
keep = ["id", "project_code", "country", "managed_by", "fulfill_via",
        "vendor_inco_term", "shipment_mode", "product_group",
        "sub_classification", "vendor", "manufacturing_site", "brand",
        "item_description", "line_item_quantity", "line_item_value",
        "unit_price", "pack_price", "weight_kg", "freight_usd",
        "freight_status", "insurance_usd", "po_sent_date", "scheduled_date",
        "delivered_date", "scheduled_month", "scheduled_year", "delay_days",
        "is_late", "is_on_time", "delay_bucket", "lead_time_days",
        "freight_pct_of_value", "freight_per_kg", "landed_cost_usd",
        "is_internal_rdc"]
clean = df[keep]
clean.to_csv(OUT, index=False)

print(f"Saved {len(clean):,} rows to {OUT}")
print("Missing scheduled dates:", clean["scheduled_date"].isna().sum())
print("Missing delivered dates:", clean["delivered_date"].isna().sum())
print("Freight status:\n", clean["freight_status"].value_counts())
print("Overall on-time rate:", round(clean["is_on_time"].mean() * 100, 1), "%")
