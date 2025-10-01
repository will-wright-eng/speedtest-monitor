# Internet Speed Test Monitor

Automated internet speed monitoring system using Grafana and PostgreSQL on Raspberry Pi.

## Quick Start

1. Clone or create the project directory structure
2. Update credentials in `docker-compose.yml` if needed
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

### Using Makefile (Recommended)

```bash
# Show all available commands
make help

# Quick setup and start
make setup

# Start services
make up

# View logs
make logs

# Stop services
make down

# Restart specific service
make restart-speedtest

# Update and restart
make update

# Check service health
make health
```

### Using Docker Compose Directly

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
- Password: `changeme123` (or your custom password)
- TLS/SSL Mode: `disable`

## Makefile Commands

The project includes a comprehensive Makefile with convenient commands:

### Basic Operations
- `make help` - Show all available commands
- `make setup` - Initial setup (copy .env.example and start services)
- `make up` - Start all services
- `make down` - Stop all services
- `make restart` - Restart all services

### Monitoring
- `make logs` - View logs from all services
- `make logs-speedtest` - View speedtest logs only
- `make status` - Show container status
- `make health` - Check service health

### Development
- `make build` - Build the speedtest container
- `make test` - Run a single speed test manually
- `make shell-speedtest` - Open shell in speedtest container

### Data Management
- `make backup` - Backup all persistent data
- `make restore-postgres BACKUP_FILE=filename.tar.gz` - Restore PostgreSQL
- `make restore-grafana BACKUP_FILE=filename.tar.gz` - Restore Grafana

### Maintenance
- `make update` - Pull latest images and restart
- `make clean` - Remove all containers and data (WARNING: destructive)
- `make urls` - Show service URLs

## Customization

Edit `TEST_INTERVAL` in docker-compose.yml to change test frequency.

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

### Recommended Dashboard Panels

1. **Time Series Graph** - Download/Upload over time (use queries above)
2. **Stat Panel** - Current download speed with sparkline
3. **Gauge Panel** - Latest ping latency
4. **Table Panel** - Recent test results
5. **Stat Panel** - Average speeds (24h, 7d, 30d)

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

## Backup Procedures

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

## Update Procedures

```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d
```
