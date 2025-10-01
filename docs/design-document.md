# Internet Speed Monitoring System - Design Document

## Overview

This document outlines the design and implementation of an automated internet speed monitoring system deployed on a Raspberry Pi. The system continuously measures internet connection performance and visualizes the data through a Grafana dashboard.

## Project Goals

- Automatically measure internet speed at regular intervals
- Store historical speed test data for trend analysis
- Provide real-time visualization of network performance
- Enable monitoring of ISP service quality over time
- Create a fully containerized, portable solution

## System Architecture

### High-Level Architecture

```
┌─────────────────────┐
│  Speedtest Monitor  │
│   (Python Script)   │
└──────────┬──────────┘
           │ writes metrics
           ↓
┌─────────────────────┐
│    PostgreSQL 16    │
│  (Database)         │
└──────────┬──────────┘
           │ queries data
           ↓
┌─────────────────────┐
│      Grafana        │
│   (Visualization)   │
└─────────────────────┘
```

### Component Details

#### 1. Speed Test Monitor
- **Technology**: Python 3.11
- **Key Libraries**:
  - `speedtest-cli`: Executes internet speed tests
  - `psycopg2`: PostgreSQL database adapter
  - `schedule`: Manages periodic test execution
- **Deployment**: Docker container
- **Function**:
  - Runs speed tests every 30 minutes (configurable)
  - Measures download speed, upload speed, and ping latency
  - Stores results in PostgreSQL database

#### 2. PostgreSQL
- **Version**: PostgreSQL 16
- **Purpose**: Relational database for storing speed test metrics
- **Deployment**: Docker container
- **Storage**: Persistent volume for data retention
- **Configuration**:
  - Database: `speedtest`
  - User: `speedtest_user`
  - Password-based authentication

#### 3. Grafana
- **Version**: Latest stable
- **Purpose**: Data visualization and dashboard interface
- **Deployment**: Docker container
- **Port**: 3000
- **Features**:
  - Real-time speed metrics visualization
  - Historical trend analysis
  - Native PostgreSQL data source support
  - Customizable alerting (optional)

## Data Model

### Database Schema

**Table Name**: `speed_tests`

**Columns**:
- `id` (SERIAL PRIMARY KEY): Auto-incrementing unique identifier
- `timestamp` (TIMESTAMP WITH TIME ZONE): Test execution time (default: NOW())
- `download_mbps` (NUMERIC(10,2)): Download speed in megabits per second
- `upload_mbps` (NUMERIC(10,2)): Upload speed in megabits per second
- `ping_ms` (NUMERIC(10,2)): Ping latency in milliseconds
- `server_name` (VARCHAR(255)): Speed test server name
- `server_location` (VARCHAR(255)): Server location (city, country)
- `server_sponsor` (VARCHAR(255)): Server sponsor/ISP

**Indexes**:
- Primary key on `id`
- Index on `timestamp` for efficient time-based queries

### Sample Table Creation

```sql
CREATE TABLE speed_tests (
    id SERIAL PRIMARY KEY,
    timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    download_mbps NUMERIC(10,2) NOT NULL,
    upload_mbps NUMERIC(10,2) NOT NULL,
    ping_ms NUMERIC(10,2) NOT NULL,
    server_name VARCHAR(255),
    server_location VARCHAR(255),
    server_sponsor VARCHAR(255)
);

CREATE INDEX idx_speed_tests_timestamp ON speed_tests(timestamp DESC);
```

### Sample Data Row

```sql
INSERT INTO speed_tests (download_mbps, upload_mbps, ping_ms, server_name, server_location, server_sponsor)
VALUES (125.43, 23.67, 12.5, 'New York, NY', 'New York, USA', 'Verizon');
```

## Deployment Strategy

### Containerization Approach

All components are containerized using Docker for the following benefits:

- **Isolation**: Each service runs in its own environment
- **Portability**: Easy migration between systems
- **Reproducibility**: Consistent deployment across environments
- **Resource Management**: Container-level resource controls
- **Simplified Updates**: Pull new images without system-wide changes

### Docker Compose Stack

The entire system is orchestrated using Docker Compose with three services:

1. **postgres**: Database service with persistent storage
2. **grafana**: Visualization service with persistent configuration
3. **speedtest**: Custom monitoring application

### Persistent Storage

Two Docker volumes ensure data persistence:

- `postgres-data`: Stores speed test metrics and database files
- `grafana-data`: Stores dashboards and settings

## Configuration

### Environment Variables

**PostgreSQL Container**:
- `POSTGRES_DB`: Database name (default: `speedtest`)
- `POSTGRES_USER`: Database user (default: `speedtest_user`)
- `POSTGRES_PASSWORD`: User password

**Speedtest Container**:
- `DB_HOST`: PostgreSQL host (default: `postgres`)
- `DB_PORT`: PostgreSQL port (default: `5432`)
- `DB_NAME`: Database name
- `DB_USER`: Database user
- `DB_PASSWORD`: Database password
- `TEST_INTERVAL`: Minutes between tests (default: `30`)

**Grafana Container**:
- `GF_SECURITY_ADMIN_PASSWORD`: Initial admin password

### Customizable Parameters

- **Test Frequency**: Currently 30 minutes (adjustable via `TEST_INTERVAL` environment variable)
- **Data Retention**: Can be managed via PostgreSQL table partitioning or scheduled cleanup jobs
- **Port Mappings**: All ports can be remapped if conflicts exist

## Network Architecture

All containers communicate via Docker's internal network:

- **External Access**:
  - Grafana: Port 3000 (HTTP)
  - PostgreSQL: Port 5432 (optional, for external tools)

- **Internal Communication**:
  - Speedtest → PostgreSQL: Via container name resolution
  - Grafana → PostgreSQL: Via container name resolution

## Security Considerations

### Current Implementation

- Password-based authentication for PostgreSQL
- Grafana admin password configuration
- Services isolated within Docker network
- Database access restricted to internal network by default

### Recommended Enhancements

1. **Change Default Credentials**: Update all default passwords immediately
2. **Use Strong Tokens**: Generate cryptographically secure tokens
3. **Enable HTTPS**: Configure reverse proxy (nginx/Traefik) for SSL
4. **Restrict Network Access**: Use firewall rules to limit external access
5. **Regular Updates**: Keep container images updated for security patches
6. **Backup Strategy**: Implement regular volume backups

## Monitoring & Maintenance

### Health Checks

- Monitor container status: `docker-compose ps`
- Check logs: `docker-compose logs -f [service-name]`
- Verify data flow: Check Grafana dashboard for recent data points

### Backup Procedures

```bash
# Backup PostgreSQL database using pg_dump
docker-compose exec postgres pg_dump -U speedtest_user speedtest > speedtest_backup_$(date +%Y%m%d).sql

# Backup PostgreSQL data volume (alternative method)
docker-compose stop postgres
docker run --rm -v speedtest-monitor_postgres-data:/data -v $(pwd):/backup alpine tar czf /backup/postgres-backup.tar.gz /data
docker-compose start postgres

# Backup Grafana dashboards
docker-compose stop grafana
docker run --rm -v speedtest-monitor_grafana-data:/data -v $(pwd):/backup alpine tar czf /backup/grafana-backup.tar.gz /data
docker-compose start grafana

# Restore PostgreSQL from dump
cat speedtest_backup_20231001.sql | docker-compose exec -T postgres psql -U speedtest_user speedtest
```

### Update Procedures

```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d
```

## Dashboard Design

### Suggested Panels

1. **Current Speed Gauge**
   - Type: Gauge
   - Metrics: Latest download and upload speeds
   - Thresholds: Color-coded based on expected speeds

2. **Speed Over Time**
   - Type: Time series graph
   - Metrics: Download and upload speeds
   - Time range: Last 24 hours / 7 days / 30 days

3. **Ping Latency**
   - Type: Time series graph
   - Metric: Ping response time
   - Useful for detecting network instability

4. **Speed Distribution**
   - Type: Histogram
   - Shows frequency distribution of speeds
   - Identifies typical vs. outlier performance

5. **Statistics Table**
   - Average, minimum, maximum speeds
   - Uptime percentage
   - Test count

## Future Enhancements

### Potential Features

1. **Multi-location Testing**: Add support for testing from multiple network locations
2. **ISP Comparison**: Tag data with ISP information for comparison
3. **Alerting**: Configure Grafana alerts for speed drops below thresholds
4. **Mobile App**: Grafana mobile app integration
5. **Historical Reports**: Automated weekly/monthly performance reports
6. **Cost Analysis**: Track actual vs. advertised speeds for ISP accountability
7. **Bandwidth Caps**: Monitor data usage if ISP has caps
8. **Multiple Test Servers**: Rotate through different speed test servers

### Scalability Considerations

- Current design handles single location monitoring
- Can be extended to monitor multiple sites by deploying additional speedtest containers
- PostgreSQL can handle millions of data points efficiently with proper indexing
- Consider table partitioning by date for better performance with large datasets
- Implement periodic data archival or deletion for very long-term storage

## Troubleshooting

### Common Issues

**Speedtest container repeatedly failing**:
- Check network connectivity from container
- Verify PostgreSQL is accessible: `docker-compose exec speedtest ping postgres`
- Review container logs: `docker-compose logs speedtest`
- Check database credentials match in environment variables

**No data appearing in Grafana**:
- Verify PostgreSQL data source configuration in Grafana
- Check that speedtest is writing data: `docker-compose logs speedtest`
- Verify database name and credentials match
- Test direct database query: `docker-compose exec postgres psql -U speedtest_user -d speedtest -c "SELECT COUNT(*) FROM speed_tests;"`

**High resource usage**:
- Reduce test frequency via `TEST_INTERVAL` environment variable
- Implement periodic data cleanup: Delete records older than X months
- Add table partitioning for better performance with large datasets
- Consider Raspberry Pi 4 with 4GB+ RAM for better performance

## System Requirements

### Hardware

- **Minimum**: Raspberry Pi 3 Model B+
- **Recommended**: Raspberry Pi 4 (2GB+ RAM)
- **Storage**: 16GB microSD minimum, 32GB+ recommended
- **Network**: Wired ethernet connection recommended for accurate testing

### Software

- Raspberry Pi OS (64-bit recommended)
- Docker Engine 20.10+
- Docker Compose 2.0+

## Project Structure

### Directory Layout

```
speedtest-monitor/
├── docker-compose.yml
├── README.md
├── .env.example
└── speedtest/
    ├── Dockerfile
    └── speedtest_monitor.py
```

### File Descriptions

- **docker-compose.yml**: Orchestrates all services
- **README.md**: Quick start guide and usage instructions
- **.env.example**: Template for environment variables
- **speedtest/Dockerfile**: Container definition for speed test monitor
- **speedtest/speedtest_monitor.py**: Python script that runs speed tests

## Code Implementation

### docker-compose.yml

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:16
    container_name: postgres
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    environment:
      - POSTGRES_DB=speedtest
      - POSTGRES_USER=speedtest_user
      - POSTGRES_PASSWORD=changeme123
    restart: unless-stopped
    networks:
      - monitoring
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U speedtest_user -d speedtest"]
      interval: 10s
      timeout: 5s
      retries: 5

  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    ports:
      - "3000:3000"
    volumes:
      - grafana-data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_INSTALL_PLUGINS=
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - monitoring

  speedtest:
    build: ./speedtest
    container_name: speedtest
    environment:
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=speedtest
      - DB_USER=speedtest_user
      - DB_PASSWORD=changeme123
      - TEST_INTERVAL=30
    depends_on:
      postgres:
        condition: service_healthy
    restart: unless-stopped
    networks:
      - monitoring

volumes:
  postgres-data:
  grafana-data:

networks:
  monitoring:
    driver: bridge
```

### speedtest/Dockerfile

```dockerfile
FROM python:3.11-slim

# Install system dependencies
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    postgresql-client \
    libpq-dev \
    gcc && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip install --no-cache-dir \
    speedtest-cli==2.1.3 \
    psycopg2-binary==2.9.9 \
    schedule==1.2.0

# Create app directory
WORKDIR /app

# Copy application code
COPY speedtest_monitor.py .
COPY init_db.sql .

# Run the application
CMD ["python", "-u", "speedtest_monitor.py"]
```

### speedtest/speedtest_monitor.py

```python
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
from psycopg2.extras import RealDictCursor
from datetime import datetime

# Configuration from environment variables
DB_HOST = os.getenv('DB_HOST', 'postgres')
DB_PORT = os.getenv('DB_PORT', '5432')
DB_NAME = os.getenv('DB_NAME', 'speedtest')
DB_USER = os.getenv('DB_USER', 'speedtest_user')
DB_PASSWORD = os.getenv('DB_PASSWORD')
TEST_INTERVAL = int(os.getenv('TEST_INTERVAL', '30'))  # Minutes

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
            password=DB_PASSWORD
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
    timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
    print(f"\n{'='*50}")
    print(f"Running speed test at {timestamp}")
    print(f"{'='*50}")

    try:
        # Initialize speed test
        st = speedtest.Speedtest()

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
        upload_speed = st.upload() / 1_000_000      # Convert to Mbps

        # Get ping
        ping = st.results.ping

        # Display results
        print(f"\nResults:")
        print(f"  Download: {download_speed:.2f} Mbps")
        print(f"  Upload:   {upload_speed:.2f} Mbps")
        print(f"  Ping:     {ping:.2f} ms")

        # Insert into PostgreSQL
        with db_conn.cursor() as cursor:
            cursor.execute("""
                INSERT INTO speed_tests 
                (download_mbps, upload_mbps, ping_ms, server_name, server_location, server_sponsor)
                VALUES (%s, %s, %s, %s, %s, %s)
            """, (
                round(download_speed, 2),
                round(upload_speed, 2),
                round(ping, 2),
                server_info['name'],
                f"{server_info['name']}, {server_info['country']}",
                server_info['sponsor']
            ))
            db_conn.commit()
        
        print(f"✓ Data written to PostgreSQL successfully")

    except speedtest.ConfigRetrievalError as e:
        print(f"ERROR: Failed to retrieve speed test configuration: {e}")
    except Exception as e:
        print(f"ERROR: Speed test failed: {e}")
        print(f"Error type: {type(e).__name__}")


def main():
    """Main application loop"""
    print("="*50)
    print("Internet Speed Test Monitor")
    print("="*50)
    print(f"Test interval: Every {TEST_INTERVAL} minutes")
    print(f"PostgreSQL: {DB_HOST}:{DB_PORT}/{DB_NAME}")
    print(f"User: {DB_USER}")
    print("="*50)

    # Initialize database
    init_database()

    # Run immediately on startup
    print("\nRunning initial speed test...")
    run_speedtest()

    # Schedule periodic tests
    schedule.every(TEST_INTERVAL).minutes.do(run_speedtest)

    print(f"\n✓ Speed test monitor started")
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
```

### .env.example

```bash
# PostgreSQL Configuration
POSTGRES_DB=speedtest
POSTGRES_USER=speedtest_user
POSTGRES_PASSWORD=changeme123

# Grafana Configuration
GRAFANA_ADMIN_PASSWORD=admin

# Speedtest Configuration
TEST_INTERVAL=30  # Minutes between tests
```

### README.md

```markdown
# Internet Speed Test Monitor

Automated internet speed monitoring system using Grafana and PostgreSQL on Raspberry Pi.

## Quick Start

1. Clone or create the project directory structure
2. Copy `.env.example` to `.env` and update credentials
3. Start the stack:
   ```bash
   docker-compose up -d
   ```
4. Access Grafana at `http://your-pi-ip:3000` (admin/admin)
5. Configure PostgreSQL data source in Grafana
6. Create your dashboard

## Services

- **Grafana**: Port 3000 - Visualization dashboard
- **PostgreSQL**: Port 5432 - Database
- **Speedtest**: Background service - Runs tests every 30 minutes

## Commands

```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Restart specific service
docker-compose restart speedtest

# Update images
docker-compose pull
docker-compose up -d

# Query database directly
docker-compose exec postgres psql -U speedtest_user -d speedtest
```

## Data Source Configuration

In Grafana, add PostgreSQL data source with:
- Host: `postgres:5432`
- Database: `speedtest`
- User: `speedtest_user`
- Password: `changeme123`
- TLS/SSL Mode: `disable`

## Customization

Edit `TEST_INTERVAL` in docker-compose.yml to change test frequency.
```

## Installation Steps

### Step 1: Create Project Structure

```bash
mkdir -p speedtest-monitor/speedtest
cd speedtest-monitor
```

### Step 2: Create All Files

Create each file with the content shown above in the corresponding location.

### Step 3: Set Permissions

```bash
chmod +x speedtest/speedtest_monitor.py
```

### Step 4: Update Credentials

Edit `docker-compose.yml` and change:
- `POSTGRES_PASSWORD`
- `DB_PASSWORD` (must match POSTGRES_PASSWORD)
- `GF_SECURITY_ADMIN_PASSWORD`

### Step 5: Deploy

```bash
docker-compose up -d
```

### Step 6: Verify Deployment

```bash
# Check all containers are running
docker-compose ps

# View speedtest logs
docker-compose logs -f speedtest

# Should see speed test results being logged
```

## Grafana Dashboard Configuration

### Sample SQL Query for Download Speed Time Series

```sql
SELECT
  timestamp AS "time",
  download_mbps
FROM speed_tests
WHERE $__timeFilter(timestamp)
ORDER BY timestamp
```

### Sample SQL Query for Upload Speed Time Series

```sql
SELECT
  timestamp AS "time",
  upload_mbps
FROM speed_tests
WHERE $__timeFilter(timestamp)
ORDER BY timestamp
```

### Sample SQL Query for Average Speed (Last 24h)

```sql
SELECT
  AVG(download_mbps) as avg_download,
  AVG(upload_mbps) as avg_upload,
  AVG(ping_ms) as avg_ping
FROM speed_tests
WHERE timestamp >= NOW() - INTERVAL '24 hours'
```

### Sample SQL Query for Latest Speed

```sql
SELECT
  download_mbps,
  upload_mbps,
  ping_ms,
  timestamp
FROM speed_tests
ORDER BY timestamp DESC
LIMIT 1
```

### Sample SQL Query for Recent Tests Table

```sql
SELECT
  timestamp,
  download_mbps,
  upload_mbps,
  ping_ms,
  server_sponsor
FROM speed_tests
WHERE $__timeFilter(timestamp)
ORDER BY timestamp DESC
LIMIT 20
```

### Recommended Dashboard Panels

1. **Time Series Graph** - Download/Upload over time (use queries above)
2. **Stat Panel** - Current download speed with sparkline
3. **Gauge Panel** - Latest ping latency
4. **Table Panel** - Recent test results
5. **Stat Panel** - Average speeds (24h, 7d, 30d)
6. **Stat Panel** - Min/Max speeds for time range

## Conclusion

This design provides a complete, containerized solution for monitoring internet speed performance on a Raspberry Pi. The modular architecture allows for easy customization and extension while maintaining simplicity for initial deployment.
