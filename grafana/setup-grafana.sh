#!/bin/bash

# Grafana Setup Script for Speed Test Monitor
# This script helps configure Grafana with PostgreSQL data source and dashboard

echo "🚀 Setting up Grafana for Speed Test Monitor..."

# Wait for Grafana to be ready
echo "⏳ Waiting for Grafana to be ready..."
until curl -s http://localhost:3000/api/health > /dev/null; do
    echo "   Waiting for Grafana..."
    sleep 2
done
echo "✅ Grafana is ready!"

# Wait for PostgreSQL to be ready
echo "⏳ Waiting for PostgreSQL to be ready..."
until docker-compose exec postgres pg_isready -U speedtest_user -d speedtest > /dev/null 2>&1; do
    echo "   Waiting for PostgreSQL..."
    sleep 2
done
echo "✅ PostgreSQL is ready!"

# Create PostgreSQL data source
echo "📊 Creating PostgreSQL data source..."

# Get Grafana API key (we'll use basic auth for now)
GRAFANA_URL="http://localhost:3000"
GRAFANA_USER="admin"
GRAFANA_PASS="admin"

# Clean up any existing PostgreSQL data source
echo "🧹 Cleaning up existing data sources..."
curl -X DELETE -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/name/PostgreSQL" -w "\nHTTP Status: %{http_code}\n" -s > /dev/null 2>&1

# Create data source with PostgreSQL configuration
echo "📊 Creating PostgreSQL data source..."
RESPONSE=$(curl -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d '{
    "name": "PostgreSQL",
    "type": "postgres",
    "url": "postgres:5432",
    "user": "speedtest_user",
    "password": "changeme123",
    "database": "speedtest",
    "access": "proxy",
    "jsonData": {
      "sslmode": "disable"
    },
    "isDefault": true
  }' \
  "$GRAFANA_URL/api/datasources" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s)

echo "$RESPONSE"

# Check if the response contains an error
if echo "$RESPONSE" | grep -q "bad request data"; then
  echo "⚠️  Data source creation failed. Trying alternative approach..."
  echo "📊 Attempting to create data source with connection string format..."
  curl -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -d '{
      "name": "PostgreSQL",
      "type": "postgres",
      "url": "postgresql://speedtest_user:changeme123@postgres:5432/speedtest",
      "access": "proxy",
      "jsonData": {
        "sslmode": "disable"
      },
      "isDefault": true
    }' \
    "$GRAFANA_URL/api/datasources" \
    -w "\nHTTP Status: %{http_code}\n" \
    -s
fi

echo ""
echo "📈 Importing Speed Test Dashboard..."

# Import dashboard
DASHBOARD_RESPONSE=$(curl -X POST \
  -H "Content-Type: application/json" \
  -u "$GRAFANA_USER:$GRAFANA_PASS" \
  -d @$(dirname "$0")/grafana-dashboard.json \
  "$GRAFANA_URL/api/dashboards/db" \
  -w "\nHTTP Status: %{http_code}\n" \
  -s)

echo "$DASHBOARD_RESPONSE"

# Check if dashboard already exists and try to update it
if echo "$DASHBOARD_RESPONSE" | grep -q "version-mismatch"; then
  echo "⚠️  Dashboard already exists. Attempting to update..."
  # Update the dashboard by setting overwrite to true
  DASHBOARD_JSON=$(cat $(dirname "$0")/grafana-dashboard.json)
  echo "$DASHBOARD_JSON" | jq '.overwrite = true' | curl -X POST \
    -H "Content-Type: application/json" \
    -u "$GRAFANA_USER:$GRAFANA_PASS" \
    -d @- \
    "$GRAFANA_URL/api/dashboards/db" \
    -w "\nHTTP Status: %{http_code}\n" \
    -s
fi

echo ""
echo "🎉 Setup complete!"
echo ""
echo "📋 Next steps:"
echo "1. Open Grafana: http://localhost:3000"
echo "2. Login with: admin/admin"
echo "3. Go to Dashboards → Speed Test Monitor"
echo "4. Verify the PostgreSQL data source is working"
echo ""
echo "🔧 If you need to manually configure:"
echo "- Data Source Type: PostgreSQL"
echo "- Host: postgres:5432"
echo "- Database: speedtest"
echo "- User: speedtest_user"
echo "- Password: changeme123"
echo "- SSL Mode: disable"
