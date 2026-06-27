"""
query_drivers.py
----------------
Week 2 Assignment — Python + PostgreSQL

Your task: complete each function marked with TODO.
Run the script when done:  python query_drivers.py

Expected output:
    Driver                    Completed Rides
    ------------------------------------------
    Alice Johnson                          12
    Bob Smith                               9
    ...
    ------------------------------------------
    Total drivers:                         15
"""

import os
import psycopg2
from dotenv import load_dotenv


# The SQL query is provided — do not change it.
SQL = """
    SELECT
        d.name              AS driver_name,
        COUNT(t.trip_id)    AS completed_rides
    FROM drivers d
    LEFT JOIN trips t
        ON t.driver_id = d.driver_id
        AND t.status = 'completed'
    GROUP BY d.driver_id, d.name
    ORDER BY completed_rides DESC;
"""


# ─── TASK 1 ───────────────────────────────────────────────────────────────────
def load_config() -> dict:
    """
    Load database credentials from a .env file.

    Steps:
      1. Call load_dotenv() to read the .env file.
      2. Use os.getenv() to read each variable and store it in a dict.

    The .env file should contain:
        DB_HOST=...
        DB_PORT=...
        DB_NAME=...
        DB_USER=...
        DB_PASSWORD=...

    Returns:
        dict with keys: host, port, dbname, user, password
    """
    # Load environment variables from the .env file
    load_dotenv()

    # Build and return the configuration dictionary mapped to psycopg2 arguments
    return {
        "host": os.getenv("DB_HOST"),
        "port": os.getenv("DB_PORT"),
        "dbname": os.getenv("DB_NAME"),
        "user": os.getenv("DB_USER"),
        "password": os.getenv("DB_PASSWORD")
    }


# ─── TASK 2 ───────────────────────────────────────────────────────────────────
def get_connection(config: dict):
    """
    Open and return a psycopg2 database connection.

    Args:
        config: dict returned by load_config()

    Returns:
        psycopg2 connection object

    Hint: psycopg2.connect(host=..., port=..., dbname=..., user=..., password=...)
          Use ** to unpack the config dict directly.
    """
    # Unpack the config dictionary directly into the connect method
    return psycopg2.connect(**config)


# ─── TASK 3 ───────────────────────────────────────────────────────────────────
def fetch_drivers(conn) -> list:
    """
    Execute the SQL query and return all rows.

    Args:
        conn: open psycopg2 connection

    Returns:
        list of tuples — each tuple is (driver_name, completed_rides)

    Steps:
      1. Open a cursor with conn.cursor()
      2. Call cur.execute(SQL)
      3. Fetch all rows with cur.fetchall()
      4. Close the cursor and return the rows
    """
    
    cur = conn.cursor()  # Opening the database cursor
    # Executing the SQL query
    cur.execute(SQL)
    
    rows = cur.fetchall()  # retrieving all rows from our query that has been executed
    
    cur.close() # closing the cursor
    
    return rows


# ─── TASK 4 ───────────────────────────────────────────────────────────────────
def print_results(rows: list) -> None:
    """
    Print the query results as a formatted table.

    Args:
        rows: list of (driver_name, completed_rides) tuples

    Expected format (column widths: name = 25 left, rides = 15 right):

        Driver                    Completed Rides
        ------------------------------------------
        Alice Johnson                          12
        ------------------------------------------
        Total drivers:                         15

    Hints:
        - f"{value:<25}"  left-aligns in 25 chars
        - f"{value:>15}"  right-aligns in 15 chars
    """
    print(f"{'Driver':<25}{'Completed Rides':>15}") # print the header
    print("-" * 40)

    
    for name, rides in rows: # # Loop over rows and print each driver_name and completed_rides
        print(f"{name:<25}{rides:>15}")

    # Print a footer with the total number of drivers
    print("-" * 40)
    print(f"{'Total drivers:':<25}{len(rows):>15}")


# ─────────────────────────────────────────────────────────────────────────────
def main():
    config = load_config()
    # print(config)

    try:
        conn = get_connection(config)
        # Uncomment for debugging        
        # cur = conn.cursor()
        # cur.execute("SELECT current_database()")
        # print(cur.fetchall())
        # cur.execute("SELECT datname FROM pg_database")
        # print(cur.fetchall())
    except psycopg2.OperationalError as e:
        print(f"Connection failed: {e}")
        return
    
    rows = fetch_drivers(conn)
    print_results(rows)

    conn.close()


if __name__ == "__main__":
    main()
