#!/bin/bash
set -e

echo "🔄 Resetting database to BAD schema..."

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
python3 /workshop/scripts/generate_bad_data.py

echo ""
echo "✅ Database reset complete!"
echo ""
echo "Statistics:"
psql -U $PGUSER -d $PGDATABASE << 'EOF'
SELECT
    tablename,
    pg_size_pretty(pg_total_relation_size(tablename::text)) as size,
    (SELECT count(*) FROM pedidos_completos) as rows
FROM pg_tables
WHERE schemaname = 'public' AND tablename = 'pedidos_completos';
EOF
