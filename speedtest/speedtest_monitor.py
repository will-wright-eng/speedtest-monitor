#!/usr/bin/env python3
"""
Internet Speed Test Monitor
Runs periodic speed tests and logs results to PostgreSQL
"""

import speedtest
import schedule
import time
import os
import sys
import psycopg2
from datetime import datetime

# Configuration from environment variables
DB_HOST = os.getenv("DB_HOST", "postgres")
DB_PORT = os.getenv("DB_PORT", "5432")
DB_NAME = os.getenv("DB_NAME", "speedtest")
DB_USER = os.getenv("DB_USER", "speedtest_user")
DB_PASSWORD = os.getenv("DB_PASSWORD")
TEST_INTERVAL = int(os.getenv("TEST_INTERVAL", "30"))  # Minutes

# Validate configuration
if not DB_PASSWORD:
    print("ERROR: Missing required environment variable: DB_PASSWORD")
    sys.exit(1)

# Database connection
db_conn = None


def init_database():
    """Initialize database connection and create table if needed"""
    global db_conn
    try:
        db_conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            database=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD,
        )
        print(f"Connected to PostgreSQL at {DB_HOST}:{DB_PORT}/{DB_NAME}")

        # Create table if it doesn't exist
        with db_conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS speed_tests (
                    id SERIAL PRIMARY KEY,
                    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
                    download_mbps NUMERIC(10,2) NOT NULL,
                    upload_mbps NUMERIC(10,2) NOT NULL,
                    ping_ms NUMERIC(10,2) NOT NULL,
                    server_name VARCHAR(255),
                    server_location VARCHAR(255),
                    server_sponsor VARCHAR(255)
                )
            """)
            cursor.execute("""
                CREATE INDEX IF NOT EXISTS idx_speed_tests_timestamp
                ON speed_tests(timestamp DESC)
            """)
            db_conn.commit()
            print("✓ Database schema initialized")
    except Exception as e:
        print(f"ERROR: Failed to connect to PostgreSQL: {e}")
        sys.exit(1)


def run_speedtest():
    """Execute a speed test and write results to PostgreSQL"""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"\n{'='*50}")
    print(f"Running speed test at {timestamp}")
    print(f"{'='*50}")

    try:
        # Initialize speed test
        print("Initializing speed test...")
        st = speedtest.Speedtest()

        # Try to get servers first
        print("Getting server list...")
        try:
            st.get_servers()
            print(f"Found {len(st.servers)} servers")
        except Exception as e:
            print(f"Warning: Could not get server list: {e}")
            print("Continuing with default configuration...")

        # Get best server
        print("Finding best server...")
        st.get_best_server()
        server_info = st.results.server
        print(f"Testing via: {server_info['sponsor']} ({server_info['name']})")

        # Run download test
        print("Testing download speed...")
        download_speed = st.download() / 1_000_000  # Convert to Mbps

        # Run upload test
        print("Testing upload speed...")
        upload_speed = st.upload() / 1_000_000  # Convert to Mbps

        # Get ping
        ping = st.results.ping

        # Display results
        print("\nResults:")
        print(f"  Download: {download_speed:.2f} Mbps")
        print(f"  Upload:   {upload_speed:.2f} Mbps")
        print(f"  Ping:     {ping:.2f} ms")

        # Insert into PostgreSQL
        with db_conn.cursor() as cursor:
            cursor.execute(
                """
                INSERT INTO speed_tests
                (download_mbps, upload_mbps, ping_ms, server_name, server_location, server_sponsor)
                VALUES (%s, %s, %s, %s, %s, %s)
            """,
                (
                    round(download_speed, 2),
                    round(upload_speed, 2),
                    round(ping, 2),
                    server_info["name"],
                    f"{server_info['name']}, {server_info['country']}",
                    server_info["sponsor"],
                ),
            )
            db_conn.commit()

        print("✓ Data written to PostgreSQL successfully")

    except speedtest.ConfigRetrievalError as e:
        print(f"ERROR: Failed to retrieve speed test configuration: {e}")
    except Exception as e:
        print(f"ERROR: Speed test failed: {e}")
        print(f"Error type: {type(e).__name__}")


def main():
    """Main application loop"""
    print("=" * 50)
    print("Internet Speed Test Monitor")
    print("=" * 50)
    print(f"Test interval: Every {TEST_INTERVAL} minutes")
    print(f"PostgreSQL: {DB_HOST}:{DB_PORT}/{DB_NAME}")
    print(f"User: {DB_USER}")
    print("=" * 50)

    # Initialize database
    init_database()

    # Run immediately on startup
    print("\nRunning initial speed test...")
    run_speedtest()

    # Schedule periodic tests
    schedule.every(TEST_INTERVAL).minutes.do(run_speedtest)

    print("\n✓ Speed test monitor started")
    print(f"Next test in {TEST_INTERVAL} minutes...")

    # Run scheduler
    while True:
        schedule.run_pending()
        time.sleep(60)  # Check every minute


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\nShutting down gracefully...")
        if db_conn:
            db_conn.close()
        sys.exit(0)
    except Exception as e:
        print(f"\nFATAL ERROR: {e}")
        sys.exit(1)
