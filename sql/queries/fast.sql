-- ✅ FAST QUERIES (With indexes)
-- Use these after creating indexes

\echo '=========================================='
\echo 'FAST QUERIES (With indexes)'
\echo '=========================================='
\echo ''

-- Enable timing
\timing on

-- Query 1: Full-text search with GIN index
\echo '=== Query 1: Text Search with GIN ==='
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE to_tsvector('spanish', nombre || ' ' || descripcion)
      @@ to_tsquery('spanish', 'laptop');

\echo ''

-- Query 2: Price range with B-Tree index
\echo '=== Query 2: Price Range (With Index) ==='
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE precio BETWEEN 100 AND 500
ORDER BY precio;

\echo ''

-- Query 3: Recent orders with date index
\echo '=== Query 3: Recent Orders (With Index) ==='
EXPLAIN ANALYZE
SELECT * FROM pedidos
WHERE fecha_pedido > CURRENT_DATE - INTERVAL '30 days'
ORDER BY fecha_pedido DESC
LIMIT 100;

\echo ''

-- Query 4: Category filter with composite index
\echo '=== Query 4: Category + Stock (Composite Index) ==='
EXPLAIN ANALYZE
SELECT nombre, precio, stock
FROM productos
WHERE categoria_id = 1 AND stock > 0
ORDER BY precio;

\echo ''

-- Query 5: Partial index usage
\echo '=== Query 5: Active Products (Partial Index) ==='
EXPLAIN ANALYZE
SELECT nombre, precio
FROM productos
WHERE activo = true AND stock > 0 AND precio < 200
ORDER BY precio;

\timing off

\echo ''
\echo '=========================================='
\echo 'Notice:'
\echo '  - Index Scans (Index Scan, Bitmap Index Scan)'
\echo '  - Much lower costs'
\echo '  - Fast execution times!'
\echo '=========================================='
