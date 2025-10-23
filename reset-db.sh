#!/bin/bash
set -e

# Parse arguments
PRODUCTS=500000
ORDERS=200000

while [[ $# -gt 0 ]]; do
  case $1 in
    -p|--products)
      PRODUCTS="$2"
      shift 2
      ;;
    -o|--orders)
      ORDERS="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: $0 [-p NUM] [-o NUM]"
      exit 1
      ;;
  esac
done

echo "🔄 Resetting database to BAD schema (products: $PRODUCTS, orders: $ORDERS)..."

# Drop everything
psql -U $PGUSER -d $PGDATABASE << 'EOF'
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
GRANT ALL ON SCHEMA public TO workshop_user;
GRANT ALL ON SCHEMA public TO public;
EOF

# Install extensions
echo "📦 Installing extensions..."
psql -U $PGUSER -d $PGDATABASE -f /workshop/sql/00_extensions.sql

# Create bad schema
echo "📋 Creating bad schema..."
psql -U $PGUSER -d $PGDATABASE -f /workshop/sql/01_bad_schema.sql

# Generate bad data
echo "📊 Generating bad data (this may take a minute)..."
python3 /workshop/scripts/generate_bad_data.py --products ${PRODUCTS:-500000} --orders ${ORDERS:-200000}

echo ""
echo "✅ Database reset complete!"
echo ""
echo "Statistics:"
psql -U $PGUSER -d $PGDATABASE << EOF
SELECT
    'productos_bad' as table_name,
    pg_size_pretty(pg_total_relation_size('productos_bad')) as size,
    (SELECT count(*) FROM productos_bad) as rows
UNION ALL
SELECT
    'pedidos_completos' as table_name,
    pg_size_pretty(pg_total_relation_size('pedidos_completos')) as size,
    (SELECT count(*) FROM pedidos_completos) as rows
UNION ALL
SELECT
    'pedidos_bad' as table_name,
    pg_size_pretty(pg_total_relation_size('pedidos_bad')) as size,
    (SELECT count(*) FROM pedidos_bad) as rows;
EOF
