import pandas as pd
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
from sklearn.linear_model import LogisticRegression
from sklearn.model_selection import train_test_split
from sklearn.metrics import roc_auc_score

df = pd.read_csv("data/clean/shipments_clean.csv",
                 parse_dates=["scheduled_date", "delivered_date", "scheduled_month"])
sns.set_theme(style="whitegrid")

# 1. Delay distribution
fig, ax = plt.subplots(figsize=(8, 4))
sns.histplot(df["delay_days"].clip(-60, 120), bins=60, ax=ax)
ax.axvline(0, color="red", linestyle="--")
ax.set(title="Delivery delay distribution (days vs schedule)",
       xlabel="Delay days (negative = early)", ylabel="Order lines")
fig.tight_layout(); fig.savefig("images/delay_distribution.png", dpi=150)

# 2. Does shipment mode affect delay? (Kruskal-Wallis)
groups = [g["delay_days"].dropna() for _, g in df.groupby("shipment_mode") if len(g) >= 30]
h, p = stats.kruskal(*groups)
print(f"Kruskal-Wallis delay by shipment mode: H={h:.1f}, p={p:.4g}")

# 3. RDC vs Direct Drop on-time (chi-square)
table = pd.crosstab(df["fulfill_via"], df["is_on_time"])
chi2, p_chi, _, _ = stats.chi2_contingency(table)
print(f"Chi-square channel vs on-time: chi2={chi2:.1f}, p={p_chi:.4g}")

# 4. Does weight explain freight cost? (Spearman)
cost = df[(df["freight_usd"] > 0) & (df["weight_kg"] > 0)]
rho, p_rho = stats.spearmanr(cost["weight_kg"], cost["freight_usd"])
print(f"Spearman weight vs freight: rho={rho:.2f}, p={p_rho:.4g}")
fig, ax = plt.subplots(figsize=(7, 5))
sns.scatterplot(data=cost, x="weight_kg", y="freight_usd", hue="shipment_mode", alpha=0.5, s=15, ax=ax)
ax.set(xscale="log", yscale="log", title="Freight cost vs weight by mode",
       xlabel="Weight (kg, log)", ylabel="Freight (USD, log)")
fig.tight_layout(); fig.savefig("images/freight_vs_weight.png", dpi=150)

# 5. Monthly on-time trend
trend = df.groupby("scheduled_month")["is_on_time"].mean().rolling(3).mean()
fig, ax = plt.subplots(figsize=(9, 4))
(trend * 100).plot(ax=ax)
ax.set(title="On-time delivery %, 3-month rolling average", xlabel="", ylabel="On-time %")
fig.tight_layout(); fig.savefig("images/otd_trend.png", dpi=150)

# 6. What predicts a late delivery? (logistic regression)
features = ["shipment_mode", "fulfill_via", "product_group", "vendor_inco_term"]
X = pd.get_dummies(df[features].fillna("Unknown"), drop_first=True)
X["log_value"] = np.log1p(df["line_item_value"].clip(lower=0))
y = df["is_late"]
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.25, random_state=42, stratify=y)
clf = LogisticRegression(max_iter=1000, class_weight="balanced").fit(X_train, y_train)
auc = roc_auc_score(y_test, clf.predict_proba(X_test)[:, 1])
print(f"Late-delivery model AUC: {auc:.2f}")
coefs = pd.Series(clf.coef_[0], index=X.columns).sort_values()
print("Raise risk of lateness:\n", coefs.tail(5).round(2))
print("Lower risk of lateness:\n", coefs.head(5).round(2))
