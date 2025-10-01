#!/bin/bash

# Grafana Data Source Setup Script for Speed Test Monitor
# This script helps configure Grafana with PostgreSQL data source

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

# Wait for Grafana to be ready
wait_for_grafana() {
    echo "⏳ Waiting for Grafana to be ready..."
    until curl -s ${GRAFANA_URL:-http://localhost:3000}/api/health > /dev/null; do
        echo "   Waiting for Grafana..."
        sleep 2
    done
    echo "✅ Grafana is ready!"
}

# Wait for PostgreSQL to be ready
wait_for_postgres() {
    echo "⏳ Waiting for PostgreSQL to be ready..."
    until docker-compose exec postgres pg_isready -U ${POSTGRES_USER:-speedtest_user} -d ${POSTGRES_DB:-speedtest} > /dev/null 2>&1; do
        echo "   Waiting for PostgreSQL..."
        sleep 2
    done
    echo "✅ PostgreSQL is ready!"
}

# Delete existing PostgreSQL data source
delete_existing_datasource() {
    echo "🧹 Cleaning up existing data sources..."
    curl -X DELETE -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources/name/PostgreSQL" -w "\nHTTP Status: %{http_code}\n" -s > /dev/null 2>&1
}

# Create PostgreSQL data source with primary method
create_datasource_primary() {
    echo "📊 Creating PostgreSQL data source..."

    RESPONSE=$(curl -X POST \
      -H "Content-Type: application/json" \
      -u "$GRAFANA_USER:$GRAFANA_PASS" \
      -d '{
        "name": "PostgreSQL",
        "type": "postgres",
        "url": "'${POSTGRES_HOST:-postgres}':5432",
        "user": "'${POSTGRES_USER:-speedtest_user}'",
        "secureJsonData": {
          "password": "'${POSTGRES_PASSWORD:-changeme123}'"
        },
        "database": "'${POSTGRES_DB:-speedtest}'",
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
        return 1
    fi

    return 0
}

# Create PostgreSQL data source with fallback method
create_datasource_fallback() {
    echo "⚠️  Data source creation failed. Trying alternative approach..."
    echo "📊 Attempting to create data source with alternative configuration..."

    curl -X POST \
      -H "Content-Type: application/json" \
      -u "$GRAFANA_USER:$GRAFANA_PASS" \
      -d '{
        "name": "PostgreSQL",
        "type": "postgres",
        "url": "'${POSTGRES_HOST:-postgres}':5432",
        "user": "'${POSTGRES_USER:-speedtest_user}'",
        "secureJsonData": {
          "password": "'${POSTGRES_PASSWORD:-changeme123}'"
        },
        "database": "'${POSTGRES_DB:-speedtest}'",
        "access": "proxy",
        "jsonData": {
          "sslmode": "disable"
        },
        "isDefault": true
      }' \
      "$GRAFANA_URL/api/datasources" \
      -w "\nHTTP Status: %{http_code}\n" \
      -s
}

# Get data source UID
get_datasource_uid() {
    local uid
    uid=$(curl -s -u "$GRAFANA_USER:$GRAFANA_PASS" "$GRAFANA_URL/api/datasources" | jq -r '.[] | select(.name=="PostgreSQL") | .uid')
    echo "$uid"
}

# Test data source connection
test_datasource_connection() {
    echo "🔍 Testing data source connection..."

    # Get the actual data source UID
    local datasource_uid
    datasource_uid=$(get_datasource_uid)

    if [ -z "$datasource_uid" ] || [ "$datasource_uid" = "null" ]; then
        echo "❌ Could not find PostgreSQL data source UID!"
        return 1
    fi

    echo "📊 Using data source UID: $datasource_uid"

    RESPONSE=$(curl -X POST \
      -H "Content-Type: application/json" \
      -u "$GRAFANA_USER:$GRAFANA_PASS" \
      -d '{
        "queries": [
          {
            "refId": "A",
            "datasource": {
              "type": "postgres",
              "uid": "'$datasource_uid'"
            },
            "rawSql": "SELECT COUNT(*) FROM speed_tests",
            "format": "table"
          }
        ]
      }' \
      "$GRAFANA_URL/api/ds/query" \
      -w "\nHTTP Status: %{http_code}\n" \
      -s)

    if echo "$RESPONSE" | grep -q '"status":200'; then
        echo "✅ Data source connection successful!"
        return 0
    else
        echo "❌ Data source connection failed!"
        echo "$RESPONSE"
        return 1
    fi
}

# Main setup function
setup_grafana_datasource() {
    echo "🚀 Setting up Grafana Data Source for Speed Test Monitor..."

    # Initialize Grafana connection variables
    GRAFANA_URL=${GRAFANA_URL:-http://localhost:3000}
    GRAFANA_USER=${GRAFANA_USER:-admin}
    GRAFANA_PASS=${GRAFANA_ADMIN_PASSWORD:-admin}

    # Wait for services to be ready
    wait_for_grafana
    wait_for_postgres

    # Setup data source
    delete_existing_datasource

    # Try primary method first
    if ! create_datasource_primary; then
        create_datasource_fallback
    fi

    # Test the connection
    if test_datasource_connection; then
        echo ""
        echo "🎉 Data source setup complete!"
        echo ""
        echo "📋 Next steps:"
        echo "1. Open Grafana: ${GRAFANA_URL}"
        echo "2. Login with: ${GRAFANA_USER}/${GRAFANA_ADMIN_PASSWORD:-admin}"
        echo "3. Go to Data Sources → PostgreSQL"
        echo "4. Verify the connection is working"
        echo ""
        echo "🔧 Manual configuration reference:"
        echo "- Data Source Type: PostgreSQL"
        echo "- Host: ${POSTGRES_HOST:-postgres}:5432"
        echo "- Database: ${POSTGRES_DB:-speedtest}"
        echo "- User: ${POSTGRES_USER:-speedtest_user}"
        echo "- Password: ${POSTGRES_PASSWORD:-changeme123}"
        echo "- SSL Mode: disable"
    else
        echo ""
        echo "❌ Data source setup failed!"
        echo "Please check the configuration and try again."
        exit 1
    fi
}

# Main execution
main() {
    load_env
    setup_grafana_datasource
}

# Run main function
main "$@"
