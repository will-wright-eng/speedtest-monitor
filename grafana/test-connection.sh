#!/bin/bash

echo "🔍 Testing Grafana Data Source Connection..."
echo ""

# Test PostgreSQL connection
echo "📊 Testing PostgreSQL connection..."
if docker-compose exec postgres pg_isready -U speedtest_user -d speedtest > /dev/null 2>&1; then
    echo "✅ PostgreSQL: Connected and responding"

    # Test if table exists and has data
    TABLE_CHECK=$(docker-compose exec postgres psql -U speedtest_user -d speedtest -t -c "SELECT COUNT(*) FROM speed_tests;" 2>/dev/null | tr -d ' \n')
    if [ "$TABLE_CHECK" -gt 0 ] 2>/dev/null; then
        echo "✅ PostgreSQL: speed_tests table has $TABLE_CHECK records"
    else
        echo "⚠️  PostgreSQL: speed_tests table exists but has no data yet"
    fi
else
    echo "❌ PostgreSQL: Connection failed"
fi

echo ""

# Test Grafana connection
echo "📈 Testing Grafana connection..."
GRAFANA_RESPONSE=$(curl -s -w "%{http_code}" "http://localhost:3000/api/health")
HTTP_CODE="${GRAFANA_RESPONSE: -3}"
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Grafana: Connected and responding"
else
    echo "❌ Grafana: Connection failed (HTTP $HTTP_CODE)"
fi

echo ""

# Test data source in Grafana
echo "🔗 Testing Grafana Data Source..."
DS_RESPONSE=$(curl -s -w "%{http_code}" -u "admin:admin" "http://localhost:3000/api/datasources")
HTTP_CODE="${DS_RESPONSE: -3}"
if [ "$HTTP_CODE" = "200" ]; then
    echo "✅ Grafana Data Sources: Accessible"
    if echo "$DS_RESPONSE" | grep -q "PostgreSQL"; then
        echo "✅ PostgreSQL Data Source: Found in Grafana"
    else
        echo "❌ PostgreSQL Data Source: Not found in Grafana"
        echo "💡 Run: make setup-grafana or ./grafana/setup-grafana.sh"
    fi
else
    echo "❌ Grafana Data Sources: Not accessible (HTTP $HTTP_CODE)"
fi

echo ""
echo "🌐 Access URLs:"
echo "  Grafana: http://localhost:3000 (admin/admin)"
echo "  PostgreSQL: localhost:5432 (speedtest_user/changeme123)"
echo ""
echo "📋 Next steps:"
echo "1. Open Grafana: http://localhost:3000"
echo "2. Go to Explore tab"
echo "3. Select PostgreSQL data source"
echo "4. Run a test query: SELECT * FROM speed_tests LIMIT 10"
echo ""
echo "🔧 Manual database access:"
echo "  make psql"
echo "  or"
echo "  docker-compose exec postgres psql -U speedtest_user -d speedtest"
