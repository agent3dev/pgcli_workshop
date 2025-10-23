#!/bin/bash

echo "⏱️  Running performance benchmark..."
echo "=========================================="
echo ""

psql -U $PGUSER -d $PGDATABASE << 'EOF'
-- Enable timing
\timing on

\echo '=== Query 1: Text Search (LIKE) ==='
SELECT COUNT(*) FROM productos
WHERE descripcion LIKE '%laptop%' OR nombre LIKE '%laptop%';

\echo ''
\echo '=== Query 2: Price Range ==='
SELECT COUNT(*) FROM productos
WHERE precio BETWEEN 100 AND 500;

\echo ''
\echo '=== Query 3: Recent Orders ==='
SELECT COUNT(*) FROM pedidos_completos
WHERE fecha_pedido > CURRENT_DATE - INTERVAL '30 days';

\echo ''
\echo '=== Query 4: Category Filter ==='
SELECT COUNT(*) FROM productos
WHERE categoria_id = 1 AND stock > 0;

\timing off
EOF

echo ""
echo "=========================================="
echo "✅ Benchmark complete!"
echo ""
echo "Tip: Run this on bad schema, then normalize and add indexes to compare performance"
