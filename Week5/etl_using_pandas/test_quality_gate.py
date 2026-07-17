"""
Defensive testing script for the Week 5 data quality gate.

This script tests quality.py by feeding it an isolated, synthetic 
DataFrame. This allows us to safely verify that our validation rules 
will halt the pipeline if bad metrics occur, without needing to inject 
corrupted data into our actual production database.
"""
import logging
import pandas as pd
from quality import run_quality_checks, DataQualityError

# To automate our second bad/rows log file generation
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)s [%(filename)s:%(lineno)d] %(message)s",
    handlers=[
        logging.FileHandler("run2_data_data.log", mode="w"),
        logging.StreamHandler()
    ]
)

# Synthetic test data matched exactly to our active columns 
mock_corrupted_data = pd.DataFrame([{
    "source_trip_id": 49403,
    "date_key": 20261120,
    "driver_key": 1,
    "passenger_key": 1,
    "pickup_location_key": 1,
    "dropoff_location_key": 2,
    "payment_method_key": 1,
    "promo_code_key": 3,
    "base_fare": 45.0,
    "tip_amount": 0.0,
    "discount_amount": 0.0,
    "fare_amount": -205.00,  # Negative value to trigger our quality rules
    "distance_km": 15.0,
    "status": "completed",   # Preserved so check_completed_have_duration executes
    "duration_minutes": 20.0,
    "driver_rating": 4.0,
    "passenger_rating": 5.0,
    "surge_multiplier": 1.2,
    "requested_at": pd.Timestamp("2026-11-20 14:30:00"),
}])

print("Testing quality gate rules against a simulated negative fare amount...")
try:
    run_quality_checks(mock_corrupted_data)
    print("CRITICAL FAILURE: The quality gate failed to catch the data anomaly!")
except DataQualityError as exception_message:
    # Captures our expected error text inside run2_data_error.log
    logging.error(f"Data Quality Gate Halt: {str(exception_message)}")
    print("Success: The quality gate correctly caught the anomaly and generated our log file.")
