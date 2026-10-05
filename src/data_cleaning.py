"""Clean the Kaggle Financial Loan Dataset and add analysis columns.

Run from the project folder:  python src/data_cleaning.py
Input : data/raw/financial_loan.xlsx
Output: data/processed/loans_clean.csv
"""
from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent.parent
RAW_FILE = ROOT / "data" / "raw" / "financial_loan.xlsx"
OUT_FILE = ROOT / "data" / "processed" / "loans_clean.csv"

REGIONS = {
    "West": ["AK", "AZ", "CA", "CO", "HI", "ID", "MT", "NV", "NM", "OR", "UT", "WA", "WY"],
    "Midwest": ["IL", "IN", "IA", "KS", "MI", "MN", "MO", "NE", "ND", "OH", "SD", "WI"],
    "South": ["AL", "AR", "DE", "DC", "FL", "GA", "KY", "LA", "MD", "MS", "NC", "OK",
              "SC", "TN", "TX", "VA", "WV"],
    "Northeast": ["CT", "ME", "MA", "NH", "NJ", "NY", "PA", "RI", "VT"],
}
STATE_TO_REGION = {s: r for r, states in REGIONS.items() for s in states}


def clean_loans(df: pd.DataFrame) -> pd.DataFrame:
    out = df.copy()

    # application_type is "INDIVIDUAL" on every row, so it carries no information
    out = out.drop(columns=["application_type"])

    # trim stray spaces in text columns
    for col in out.columns:
        if pd.api.types.is_string_dtype(out[col]):
            out[col] = out[col].str.strip()

    # dates
    out["issue_month"] = out["issue_date"].dt.to_period("M").astype(str)
    out["issue_month_num"] = out["issue_date"].dt.month

    # text -> numbers
    out["term_months"] = out["term"].str.extract(r"(\d+)")[0].astype(int)
    out["emp_length_years"] = out["emp_length"].str.extract(r"(\d+)")[0].astype(int)
    out.loc[out["emp_length"].str.contains("<"), "emp_length_years"] = 0

    # fractions -> percentages, ratios
    out["dti_pct"] = (out["dti"] * 100).round(2)
    out["int_rate_pct"] = (out["int_rate"] * 100).round(2)
    out["loan_to_income"] = (out["loan_amount"] / out["annual_income"]).round(3)

    # bands
    out["income_band"] = pd.cut(
        out["annual_income"],
        bins=[0, 30000, 50000, 75000, 100000, float("inf")],
        labels=["Under 30K", "30K-50K", "50K-75K", "75K-100K", "100K+"],
    )
    out["dti_band"] = pd.cut(
        out["dti_pct"],
        bins=[0, 10, 15, 20, 25, 30],
        labels=["0-10%", "10-15%", "15-20%", "20-25%", "25-30%"],
        include_lowest=True,
    )

    # flag (not delete) the top 1% of incomes
    cutoff = out["annual_income"].quantile(0.99)
    out["income_outlier"] = (out["annual_income"] > cutoff).astype(int)

    # region
    out["region"] = out["address_state"].map(STATE_TO_REGION)

    # 1 = Charged Off, 0 = Fully Paid, blank = Current (outcome not known yet)
    out["default_flag"] = out["loan_status"].map({"Charged Off": 1, "Fully Paid": 0})
    return out


def main() -> None:
    df = pd.read_excel(RAW_FILE)
    clean = clean_loans(df)
    OUT_FILE.parent.mkdir(parents=True, exist_ok=True)
    clean.to_csv(OUT_FILE, index=False)

    known = clean["default_flag"].notna().sum()
    print(f"Saved {OUT_FILE.name}: {clean.shape[0]:,} rows, {clean.shape[1]} columns")
    print(f"Loans with known outcome: {known:,}")
    print(f"Default rate: {clean['default_flag'].mean() * 100:.2f}%")
    print(f"Rows with no region: {clean['region'].isna().sum()}")


if __name__ == "__main__":
    main()