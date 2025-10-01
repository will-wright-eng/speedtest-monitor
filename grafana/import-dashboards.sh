#!/bin/bash

# Import Dashboards Script for Speed Test Monitor
# This script imports both the original and enhanced dashboards

# Load environment variables from .env file
load_env() {
    if [ -f "$(dirname "$0")/../.env" ]; then
        set -a
        source "$(dirname "$0")/../.env"
        set +a
        echo "📋 Loaded environment variables from .env file"
    else
        echo "⚠️  No .env file found. Using default values."
    fi
}

# Load environment variables
load_env

GRAFANA_URL=${GRAFANA_URL:-http://localhost:3000}
GRAFANA_USER=${GRAFANA_USER:-admin}
GRAFANA_PASS=${GRAFANA_ADMIN_PASSWORD:-admin}

echo "🚀 Importing Speed Test Monitor Dashboards..."

# Function to import dashboard
import_dashboard() {
    local dashboard_file="$1"
    local dashboard_name="$2"

    echo "📊 Importing $dashboard_name..."

    RESPONSE=$(curl -X POST \
      -H "Content-Type: application/json" \
      -u "$GRAFANA_USER:$GRAFANA_PASS" \
      -d @$(dirname "$0")/$dashboard_file \
      "$GRAFANA_URL/api/dashboards/db" \
      -w "\nHTTP Status: %{http_code}\n" \
      -s)

    echo "$RESPONSE"

    # Check if dashboard already exists and try to update it
    if echo "$RESPONSE" | grep -q "version-mismatch"; then
        echo "⚠️  Dashboard already exists. Attempting to update..."
        # Update the dashboard by setting overwrite to true
        DASHBOARD_JSON=$(cat $(dirname "$0")/$dashboard_file)
        echo "$DASHBOARD_JSON" | jq '.overwrite = true' | curl -X POST \
          -H "Content-Type: application/json" \
          -u "$GRAFANA_USER:$GRAFANA_PASS" \
          -d @- \
          "$GRAFANA_URL/api/dashboards/db" \
          -w "\nHTTP Status: %{http_code}\n" \
          -s
    fi

    echo ""
}

# Import original dashboard
import_dashboard "grafana-dashboard.json" "Speed Test Monitor (Original)"

# Import enhanced dashboard
import_dashboard "enhanced-dashboard.json" "Enhanced Speed Test Monitor"

echo "🎉 Dashboard import complete!"
echo ""
echo "📋 Available Dashboards:"
echo "1. Speed Test Monitor (Original): $GRAFANA_URL/d/speedtest-monitor/speed-test-monitor"
echo "2. Enhanced Speed Test Monitor: $GRAFANA_URL/d/enhanced-speedtest-monitor/f09f9a80-enhanced-speed-test-monitor"
echo ""
echo "🔧 Login with: $GRAFANA_USER/$GRAFANA_ADMIN_PASSWORD"
