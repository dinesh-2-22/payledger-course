#!/usr/bin/env python3
"""
PayLedger course - Module 2: Synthetic data generator.

Generates a small (~10k row) but referentially-consistent set of raw payment
files that every downstream module depends on:

    raw_merchant_master.csv   ~60 merchants
    raw_card_master.csv       ~800 cards
    raw_transactions.csv      10,000 transactions   <-- the headline table
    raw_gateway_log.csv       ~10,000 gateway events (1 per txn + a few retries)
    dispute_memos.csv         ~200 free-text dispute memos  <-- Cortex Search corpus

Design goals (these are also teaching points later):
  * DETERMINISTIC. A fixed seed means every learner gets identical data, so the
    row-for-row dbt-vs-SQL parity check in Module 6 actually works.
  * REFERENTIALLY CONSISTENT. Every transaction points at a real card + merchant;
    every gateway row and dispute points at a real transaction.
  * BATCH-LOADED `_loaded_at`. Rows are "ingested" in daily batches so the
    watermark / delta-load pattern in Module 3 has a real MAX(_loaded_at) to anchor on.

Usage:
    pip install -r requirements.txt
    python generate_data.py                 # writes CSVs into ./data
    python generate_data.py --rows 50000    # scale the transaction count
    python generate_data.py --seed 7        # change the random seed

Output goes to ./data (gitignored). Nothing here talks to Snowflake -- loading
is handled separately by stage_and_copy.sql.
"""

from __future__ import annotations

import argparse
import csv
import os
import random
from datetime import datetime, timedelta
from pathlib import Path

try:
    from faker import Faker
except ImportError:  # pragma: no cover - friendly message for learners
    raise SystemExit(
        "Faker is not installed. Run:  pip install -r requirements.txt"
    )

# --------------------------------------------------------------------------- #
# Configuration / reference data
# --------------------------------------------------------------------------- #

DEFAULT_ROWS = 10_000          # number of raw_transactions rows
DEFAULT_SEED = 42
N_MERCHANTS = 60
N_CARDS = 800
N_DISPUTES = 200
HISTORY_DAYS = 90              # transactions are spread across the last N days
DATA_DIR = Path(__file__).parent / "data"

# (mcc_code, mcc_description) - a small slice of the real MCC list.
MCCS = [
    ("5411", "Grocery Stores & Supermarkets"),
    ("5812", "Eating Places & Restaurants"),
    ("5814", "Fast Food Restaurants"),
    ("5541", "Service Stations (Fuel)"),
    ("5912", "Drug Stores & Pharmacies"),
    ("5732", "Electronics Stores"),
    ("5999", "Miscellaneous Retail"),
    ("4899", "Cable, Satellite & Streaming"),
    ("4814", "Telecommunication Services"),
    ("7011", "Lodging - Hotels & Motels"),
    ("4121", "Taxicabs & Rideshare"),
    ("5651", "Family Clothing Stores"),
    ("5311", "Department Stores"),
    ("7995", "Betting & Casino Gaming"),
    ("6011", "ATM Cash Disbursement"),
]

# currency by merchant country (kept small + tidy on purpose)
COUNTRY_CURRENCY = {
    "US": "USD",
    "GB": "GBP",
    "DE": "EUR",
    "FR": "EUR",
    "CA": "CAD",
    "AU": "AUD",
    "JP": "JPY",
    "IN": "INR",
}
COUNTRIES = list(COUNTRY_CURRENCY.keys())

CARD_NETWORKS = ["VISA", "MASTERCARD", "AMEX", "DISCOVER"]
CARD_TYPES = ["DEBIT", "CREDIT", "PREPAID"]
CARD_STATUSES = ["ACTIVE", "ACTIVE", "ACTIVE", "ACTIVE", "BLOCKED", "EXPIRED"]  # weighted
ENTRY_MODES = ["CHIP", "CONTACTLESS", "SWIPE", "ECOM"]
GATEWAYS = ["STRIPE", "ADYEN", "CYBERSOURCE"]

# transaction_type weighted toward purchases
TXN_TYPES = (
    ["PURCHASE"] * 80 + ["REFUND"] * 8 + ["REVERSAL"] * 7 + ["TRANSFER"] * 5
)

# gateway response codes -> (message, is_approved)
RESPONSE_CODES = {
    "00": ("Approved", True),
    "05": ("Do Not Honor", False),
    "51": ("Insufficient Funds", False),
    "54": ("Expired Card", False),
    "14": ("Invalid Card Number", False),
    "61": ("Exceeds Withdrawal Limit", False),
}
# ~88% approved
RESPONSE_POOL = (["00"] * 88) + ["05", "51", "51", "54", "14", "61"] + ["05"] * 4

# Dispute memo templates. Slots get filled per-dispute so Cortex Search has
# realistic, varied free text to index (not 200 identical sentences).
DISPUTE_TEMPLATES = [
    ("FRAUD", "10.4",
     "Cardholder does not recognize this {amount} {currency} charge at {merchant} "
     "on {date}. Card was reported in the cardholder's possession at the time. "
     "Possible card-not-present fraud; recommend chargeback under reason code 10.4."),
    ("GOODS_NOT_RECEIVED", "13.1",
     "Customer states the order placed with {merchant} for {amount} {currency} was "
     "never delivered. Merchant supplied a tracking number but the carrier shows no "
     "delivery confirmation. Escalating as goods/services not received (13.1)."),
    ("DUPLICATE", "12.6",
     "Two identical {amount} {currency} charges from {merchant} posted on {date}. "
     "Cardholder confirms only one purchase was made. Investigating duplicate "
     "processing; likely a gateway retry that double-captured."),
    ("SUBSCRIPTION", "13.2",
     "Cardholder cancelled their subscription with {merchant} but was still billed "
     "{amount} {currency} on {date}. Cancellation confirmation was provided. "
     "Recurring transaction after cancellation (13.2)."),
    ("DEFECTIVE", "13.3",
     "Item purchased from {merchant} for {amount} {currency} arrived defective and "
     "the merchant refused a return. Cardholder has photos of the damaged product. "
     "Not as described / defective merchandise (13.3)."),
    ("REFUND_NOT_PROCESSED", "13.7",
     "Merchant {merchant} agreed to refund {amount} {currency} on {date} but the "
     "credit never appeared. Cardholder has email confirmation of the approved "
     "refund. Credit not processed (13.7)."),
    ("AMOUNT_MISMATCH", "12.5",
     "Cardholder was quoted a lower price but {merchant} charged {amount} {currency}. "
     "Receipt shows a different total than what posted. Incorrect transaction amount (12.5)."),
    ("UNRECOGNIZED", "10.4",
     "Charge of {amount} {currency} from {merchant} is unfamiliar to the cardholder. "
     "Billing descriptor does not match any known purchase. Requesting merchant "
     "provide proof of transaction before resolution."),
]
DISPUTE_STATUSES = ["OPEN", "UNDER_REVIEW", "RESOLVED", "CHARGEBACK"]


# --------------------------------------------------------------------------- #
# Helpers
# --------------------------------------------------------------------------- #

def write_csv(path: Path, header: list[str], rows: list[dict]) -> None:
    """Write a list of dict rows to CSV with a fixed header order."""
    with path.open("w", newline="", encoding="utf-8") as fh:
        writer = csv.DictWriter(fh, fieldnames=header)
        writer.writeheader()
        writer.writerows(rows)
    print(f"  wrote {len(rows):>6,} rows  ->  {path.name}")


def batch_loaded_at(event_ts: datetime) -> datetime:
    """
    Simulate a nightly batch ingest: a row created at `event_ts` lands in the
    warehouse during the next 02:00-03:00 load window. This gives a clean,
    monotonic-ish `_loaded_at` for the Module 3 watermark pattern.
    """
    next_day = (event_ts + timedelta(days=1)).date()
    return datetime(next_day.year, next_day.month, next_day.day, 2, 0, 0) + timedelta(
        seconds=random.randint(0, 3600)
    )


def money(low: float, high: float) -> float:
    return round(random.uniform(low, high), 2)


# --------------------------------------------------------------------------- #
# Generators (one per output file)
# --------------------------------------------------------------------------- #

def gen_merchants(fake: Faker) -> list[dict]:
    rows = []
    for i in range(1, N_MERCHANTS + 1):
        mcc_code, mcc_desc = random.choice(MCCS)
        country = random.choice(COUNTRIES)
        onboarded = fake.date_time_between(start_date="-4y", end_date="-100d")
        rows.append({
            "merchant_id": f"M{i:05d}",
            "merchant_name": fake.company(),
            "mcc_code": mcc_code,
            "mcc_description": mcc_desc,
            "merchant_country": country,
            "merchant_city": fake.city(),
            "onboarded_date": onboarded.date().isoformat(),
            "merchant_status": "ACTIVE" if random.random() > 0.1 else "INACTIVE",
            "_loaded_at": batch_loaded_at(onboarded).isoformat(sep=" "),
        })
    return rows


def gen_cards(fake: Faker) -> list[dict]:
    rows = []
    for i in range(1, N_CARDS + 1):
        issued = fake.date_time_between(start_date="-3y", end_date="-30d")
        network = random.choice(CARD_NETWORKS)
        rows.append({
            "card_id": f"C{i:06d}",
            "card_holder_name": fake.name(),
            "bin": str(random.randint(400000, 499999)) if network == "VISA"
                   else str(random.randint(510000, 559999)),
            "last_four": f"{random.randint(0, 9999):04d}",
            "card_type": random.choice(CARD_TYPES),
            "card_network": network,
            "currency_code": random.choice(list(COUNTRY_CURRENCY.values())),
            "issued_date": issued.date().isoformat(),
            "card_status": random.choice(CARD_STATUSES),
            "_loaded_at": batch_loaded_at(issued).isoformat(sep=" "),
        })
    return rows


def gen_transactions(fake: Faker, merchants: list[dict], cards: list[dict],
                     n_rows: int) -> list[dict]:
    rows = []
    start = datetime.now() - timedelta(days=HISTORY_DAYS)
    for i in range(1, n_rows + 1):
        merchant = random.choice(merchants)
        card = random.choice(cards)
        txn_type = random.choice(TXN_TYPES)
        # transaction time uniformly across the history window
        ts = start + timedelta(
            seconds=random.randint(0, HISTORY_DAYS * 24 * 3600)
        )
        merchant_currency = COUNTRY_CURRENCY[merchant["merchant_country"]]
        amount = money(1.0, 500.0) if random.random() < 0.92 else money(500.0, 4000.0)
        # most charges approve; declines are driven by the gateway later, but we
        # stamp a quick auth_status here for the raw feed
        auth_status = "APPROVED" if random.random() < 0.88 else "DECLINED"
        rows.append({
            "transaction_id": f"T{i:07d}",
            "card_id": card["card_id"],
            "merchant_id": merchant["merchant_id"],
            "transaction_type": txn_type,
            "amount": amount,
            "currency_code": merchant_currency,
            "transaction_timestamp": ts.isoformat(sep=" "),
            "auth_status": auth_status,
            "mcc_code": merchant["mcc_code"],
            "entry_mode": random.choice(ENTRY_MODES),
            "is_international": str(card["currency_code"] != merchant_currency).upper(),
            "_loaded_at": batch_loaded_at(ts).isoformat(sep=" "),
        })
    return rows


def gen_gateway_log(transactions: list[dict]) -> list[dict]:
    """One gateway event per transaction, plus a retry for ~2% of declines."""
    rows = []
    g = 0
    for txn in transactions:
        # pick a response code consistent with auth_status
        if txn["auth_status"] == "APPROVED":
            code = "00"
        else:
            code = random.choice([c for c in RESPONSE_POOL if c != "00"])
        message, approved = RESPONSE_CODES[code]
        amount = float(txn["amount"])
        gw_ts = datetime.fromisoformat(txn["transaction_timestamp"]) + timedelta(
            seconds=random.randint(1, 8)
        )

        def make_row(code: str, message: str, approved: bool, ts: datetime) -> dict:
            nonlocal g
            g += 1
            signed = amount if txn["transaction_type"] in ("PURCHASE", "TRANSFER") else -amount
            settlement = round(signed, 2) if approved else 0.0
            return {
                "gateway_log_id": f"G{g:07d}",
                "transaction_id": txn["transaction_id"],
                "gateway_name": random.choice(GATEWAYS),
                "auth_code": "".join(random.choices("ABCDEFGHJKLMNPQRSTUVWXYZ0123456789", k=6)),
                "response_code": code,
                "response_message": message,
                "gateway_timestamp": ts.isoformat(sep=" "),
                "settlement_amount": settlement,
                "interchange_fee": round(abs(settlement) * random.uniform(0.0015, 0.02), 4) if approved else 0.0,
                "scheme_fee": round(abs(settlement) * random.uniform(0.0005, 0.0015), 4) if approved else 0.0,
                "_loaded_at": batch_loaded_at(ts).isoformat(sep=" "),
            }

        rows.append(make_row(code, message, approved, gw_ts))
        # occasional retry on a decline that then approves
        if not approved and random.random() < 0.15:
            retry_ts = gw_ts + timedelta(seconds=random.randint(20, 120))
            rows.append(make_row("00", "Approved", True, retry_ts))
    return rows


def gen_disputes(fake: Faker, transactions: list[dict],
                 merchants_by_id: dict[str, dict]) -> list[dict]:
    """~200 disputes attached to random APPROVED purchases, with free-text memos."""
    eligible = [t for t in transactions
                if t["auth_status"] == "APPROVED" and t["transaction_type"] == "PURCHASE"]
    sample = random.sample(eligible, min(N_DISPUTES, len(eligible)))
    rows = []
    for i, txn in enumerate(sample, start=1):
        category, reason_code, template = random.choice(DISPUTE_TEMPLATES)
        merchant = merchants_by_id[txn["merchant_id"]]
        created = datetime.fromisoformat(txn["transaction_timestamp"]) + timedelta(
            days=random.randint(2, 25)
        )
        memo = template.format(
            amount=txn["amount"],
            currency=txn["currency_code"],
            merchant=merchant["merchant_name"],
            date=datetime.fromisoformat(txn["transaction_timestamp"]).date().isoformat(),
        )
        rows.append({
            "dispute_id": f"D{i:05d}",
            "transaction_id": txn["transaction_id"],
            "merchant_id": txn["merchant_id"],
            "card_id": txn["card_id"],
            "dispute_category": category,
            "dispute_reason_code": reason_code,
            "dispute_status": random.choice(DISPUTE_STATUSES),
            "created_date": created.date().isoformat(),
            "memo_text": memo,
        })
    return rows


# --------------------------------------------------------------------------- #
# Main
# --------------------------------------------------------------------------- #

def main() -> None:
    parser = argparse.ArgumentParser(description="Generate PayLedger mock data.")
    parser.add_argument("--rows", type=int, default=DEFAULT_ROWS,
                        help=f"number of raw_transactions rows (default {DEFAULT_ROWS:,})")
    parser.add_argument("--seed", type=int, default=DEFAULT_SEED,
                        help=f"random seed for reproducibility (default {DEFAULT_SEED})")
    parser.add_argument("--out", type=Path, default=DATA_DIR,
                        help="output directory (default ./data)")
    args = parser.parse_args()

    # Deterministic: seed BOTH random and Faker.
    random.seed(args.seed)
    Faker.seed(args.seed)
    fake = Faker()

    args.out.mkdir(parents=True, exist_ok=True)
    print(f"Generating PayLedger data (seed={args.seed}, txns={args.rows:,}) -> {args.out}")

    merchants = gen_merchants(fake)
    cards = gen_cards(fake)
    transactions = gen_transactions(fake, merchants, cards, args.rows)
    gateway = gen_gateway_log(transactions)
    merchants_by_id = {m["merchant_id"]: m for m in merchants}
    disputes = gen_disputes(fake, transactions, merchants_by_id)

    write_csv(args.out / "raw_merchant_master.csv",
              list(merchants[0].keys()), merchants)
    write_csv(args.out / "raw_card_master.csv",
              list(cards[0].keys()), cards)
    write_csv(args.out / "raw_transactions.csv",
              list(transactions[0].keys()), transactions)
    write_csv(args.out / "raw_gateway_log.csv",
              list(gateway[0].keys()), gateway)
    write_csv(args.out / "dispute_memos.csv",
              list(disputes[0].keys()), disputes)

    # A tiny manifest helps learners (and Claude Code) sanity-check what landed.
    max_loaded = max(t["_loaded_at"] for t in transactions)
    print("\nDone. Quick facts:")
    print(f"  merchants:     {len(merchants):>6,}")
    print(f"  cards:         {len(cards):>6,}")
    print(f"  transactions:  {len(transactions):>6,}")
    print(f"  gateway events:{len(gateway):>6,}")
    print(f"  disputes:      {len(disputes):>6,}")
    print(f"  MAX(_loaded_at) on transactions = {max_loaded}")
    print("  ^ this is the watermark you'll anchor the Module 3 delta-load on.")


if __name__ == "__main__":
    main()
