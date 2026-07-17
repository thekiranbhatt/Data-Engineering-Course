import argparse
import logging
import os
import time

import psycopg2
from dotenv import load_dotenv

from extract import (
    extract_driver,
    extract_vehicle, # Added extract vehicle 
    extract_passenger,
    extract_location,
    extract_payment_method,
    extract_promo_code,
    extract_trips_incremental,
    extract_trips_full,
    extract_lookup_dim,
    get_watermark
)
from transform import (
    derive_driver_dim,
    derive_passenger_dim,
    derive_location_dim,
    transform_trips,
)
from load import (
    truncate_warehouse,
    load_dim_driver,
    load_dim_vehicle, # Added load_dim_vehicle 
    load_dim_passenger,
    load_dim_location,
    load_dim_payment_method,
    load_dim_promo_code,
    load_fact_trips,
)

from quality import run_quality_checks


def parse_args():
    parser = argparse.ArgumentParser(description="Rides ETL pipeline (pandas)")
    parser.add_argument(
        "--full-reload",
        action="store_true",
        help="Truncate warehouse and reload all data (default: incremental)",
    )
    parser.add_argument(
        "--log-file",
        type=str,
        default="pipeline.log",
        help="Target runtime logging path",
    )
    return parser.parse_args()

def setup_logging(log_filename):
    """Dynamically configures file logging with explicit overwrite properties."""
    # Using your exact preferred logging format spacing string
    log_format = "%(asctime)s  %(levelname)s [%(filename)s:%(lineno)d] %(message)s"
    
    # Reset existing root log handlers to clear prior configs safely
    for handler in logging.root.handlers[:]:
        logging.root.removeHandler(handler)
        
    logging.basicConfig(
        level=logging.INFO,
        format=log_format,
        force=True, 
        handlers=[
            # mode="w" ensures clean, un-duplicated assignment logs every run
            logging.FileHandler(log_filename, mode="w"),
            logging.StreamHandler()
        ]
    )

logger = logging.getLogger(__name__)

load_dotenv()

SOURCE_DB_CONFIG = dict(
    host=    os.getenv("SRC_DB_HOST"),
    port =   os.getenv("SRC_DB_PORT"),
    dbname = os.getenv("SRC_DB_NAME"),
    user=    os.getenv("SRC_DB_USER"),
    password=os.getenv("SRC_DB_PASSWORD")
)
DEST_DB_CONFIG = dict(
    host=    os.getenv("DEST_DB_HOST"),
    port =   os.getenv("DEST_DB_PORT"),
    dbname = os.getenv("DEST_DB_NAME"),
    user=    os.getenv("DEST_DB_USER"),
    password=os.getenv("DEST_DB_PASSWORD")
)

def main():
    args = parse_args()
    setup_logging(args.log_file) 
    mode = 'FULL' if args.full_reload else 'INCREMENTAL'
    """
    Extract all dimension data from the source DB and load them into the target DB.
    """
    src_conn = psycopg2.connect(**SOURCE_DB_CONFIG)
    dst_conn = psycopg2.connect(**DEST_DB_CONFIG)
    try:
        # 1: Handling the truncation step immediately if a Full Reload is requested
        if mode == "FULL":
            logger.info("Full reload requested. Purging target warehouse tables...")
            truncate_warehouse(dst_conn)

        # 2: Extract and load dimension tables
        time0 = time.time()
        load_dim_driver(dst_conn, derive_driver_dim(extract_driver(src_conn)))
        load_dim_vehicle(dst_conn, extract_vehicle(src_conn))
        load_dim_passenger(dst_conn, derive_passenger_dim(extract_passenger(src_conn)))
        load_dim_location(dst_conn, derive_location_dim(extract_location(src_conn)))
        load_dim_payment_method(dst_conn, extract_payment_method(src_conn))
        load_dim_promo_code(dst_conn, extract_promo_code(src_conn))
        logger.info(f"Dimention table load completed on {time.time() - time0:.2f}s")

        # 3: Pull lookups into memory
        time0 = time.time()
        lookups = extract_lookup_dim(dst_conn)
        logger.info(f"Lookup table extraction completed on {time.time() - time0:.2f}s")
        
        # 4: Stream incremental or full trip records
        time0 = time.time()
        if mode == 'INCREMENTAL':
            watermark = get_watermark(dst_conn)
            trips_df = extract_trips_incremental(src_conn, watermark)
        else:
            trips_df = extract_trips_full(src_conn)
        logger.info(f"Trip extraction  completed on {time.time() - time0:.2f}s")

        # 5. Transform staging elements
        time0 = time.time()
        fact_df = transform_trips(trips_df, lookups)
        logger.info(f"Transformation completed on {time.time() - time0:.2f}s")

        # 6. Safety check for empty data streams
        if fact_df is None or fact_df.empty:
            logger.info("No new streaming records found. Pipeline finishing gracefully.")
            return

        # 7. Quality Gates
        time0 = time.time()
        run_quality_checks(fact_df)
        logger.info(f"Quality Check completed on {time.time() - time0:.2f}s")

        # 8. Load Fact table
        time0 = time.time()
        load_fact_trips(dst_conn, fact_df)
        logger.info(f"Trip table load completed on {time.time() - time0:.2f}s")
    finally:
        src_conn.close()
        dst_conn.close()
        logger.info("Database handles closed successfully.")

if __name__ == "__main__":
    main()
