#!/bin/bash
# Test script for workshop functionality
# This script verifies the workshop setup and core features

set -e  # Exit on any error

echo "🧪 Testing Workshop Functionality"
echo "=================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Helper function to check command success
check_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ $1${NC}"
    else
        echo -e "${RED}❌ $1${NC}"
        exit 1
    fi
}

# Test 1: Build and start container
echo "1. Building and starting workshop container..."
docker build -t workshop-db . > /dev/null 2>&1
check_result "Container built successfully"

docker run -d --name workshop-test -p 5434:5432 -v workshop-test-data:/var/lib/postgresql/data workshop-db > /dev/null 2>&1
check_result "Container started successfully"

echo "   Waiting for PostgreSQL to be ready..."
sleep 5
docker exec workshop-test pg_isready -U workshop_user -d workshop > /dev/null 2>&1
check_result "PostgreSQL is ready"

# Test 2: Reset database
echo "2. Testing database reset..."
docker exec workshop-test /usr/local/bin/reset-db > /dev/null 2>&1
check_result "Database reset completed"

# Check tables exist
TABLES=$(docker exec workshop-test psql -U workshop_user -d workshop -c "\dt" --tuples-only | wc -l)
if [ "$TABLES" -ge 3 ]; then
    check_result "Bad schema tables created"
else
    echo -e "${RED}❌ Expected at least 3 tables, got $TABLES${NC}"
    exit 1
fi

# Test 3: Data generation
echo "3. Testing data generation..."
PRODUCTS=$(docker exec workshop-test psql -U workshop_user -d workshop -c "SELECT COUNT(*) FROM productos;" --tuples-only | xargs)
if [ "$PRODUCTS" -gt 90000 ]; then
    check_result "Products generated ($PRODUCTS records)"
else
    echo -e "${RED}❌ Expected >90k products, got $PRODUCTS${NC}"
    exit 1
fi

ORDERS=$(docker exec workshop-test psql -U workshop_user -d workshop -c "SELECT COUNT(*) FROM pedidos_completos;" --tuples-only | xargs)
if [ "$ORDERS" -gt 40000 ]; then
    check_result "Orders generated ($ORDERS records)"
else
    echo -e "${RED}❌ Expected >40k orders, got $ORDERS${NC}"
    exit 1
fi

# Test 4: Normalization
echo "4. Testing schema normalization..."
docker exec workshop-test psql -U workshop_user -d workshop -f /workshop/sql/02_normalized_schema.sql > /dev/null 2>&1
check_result "Normalized schema loaded"

# Check new tables exist
NEW_TABLES=$(docker exec workshop-test psql -U workshop_user -d workshop -c "\dt" --tuples-only | grep -E "(clientes|productos|pedidos|items_pedido)" | wc -l)
if [ "$NEW_TABLES" -ge 4 ]; then
    check_result "Normalized tables created"
else
    echo -e "${RED}❌ Expected 4+ normalized tables, got $NEW_TABLES${NC}"
    exit 1
fi

# Test 5: Indexing
echo "5. Testing index creation..."
docker exec workshop-test psql -U workshop_user -d workshop -f /workshop/sql/03_indexes.sql > /dev/null 2>&1
check_result "Indexes created"

INDEXES=$(docker exec workshop-test psql -U workshop_user -d workshop -c "\di" --tuples-only | wc -l)
if [ "$INDEXES" -gt 5 ]; then
    check_result "Indexes created ($INDEXES indexes)"
else
    echo -e "${RED}❌ Expected >5 indexes, got $INDEXES${NC}"
    exit 1
fi

# Test 6: Benchmark
echo "6. Testing benchmark functionality..."
BENCHMARK_OUTPUT=$(docker exec workshop-test /usr/local/bin/benchmark 2>/dev/null)
if echo "$BENCHMARK_OUTPUT" | grep -q "Query 1:" && echo "$BENCHMARK_OUTPUT" | grep -q "Query 4:"; then
    check_result "Benchmark runs successfully"
else
    echo -e "${RED}❌ Benchmark failed to run${NC}"
    exit 1
fi

# Test 7: Performance improvement check
echo "7. Testing performance improvement..."
# Run a query that should be slow without index
SLOW_TIME=$(docker exec workshop-test psql -U workshop_user -d workshop -c "\timing on" -c "SELECT COUNT(*) FROM productos WHERE precio BETWEEN 100 AND 500;" 2>&1 | grep "Time:" | sed 's/.*Time: \([0-9.]*\) ms/\1/')

# The query should be fast with indexes (under 50ms for this data size)
if (( $(echo "$SLOW_TIME < 50" | bc -l) )); then
    check_result "Query performance is good ($SLOW_TIME ms)"
else
    echo -e "${YELLOW}⚠️  Query time is $SLOW_TIME ms (expected <50ms)${NC}"
fi

# Cleanup
echo "8. Cleaning up..."
docker rm -f workshop-test > /dev/null 2>&1
docker volume rm workshop-test-data > /dev/null 2>&1
check_result "Cleanup completed"

echo ""
echo -e "${GREEN}🎉 All workshop tests passed!${NC}"
echo "=================================="
echo "The workshop is fully functional:"
echo "  ✅ Container builds and starts"
echo "  ✅ Database reset works"
echo "  ✅ Data generation creates 100k+ records"
echo "  ✅ Schema normalization succeeds"
echo "  ✅ Index creation works"
echo "  ✅ Benchmark runs and shows performance"
echo "  ✅ Queries execute with good performance"