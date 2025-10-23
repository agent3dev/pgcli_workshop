-- ❌ SLOW QUERIES (Without indexes)
-- Use these to see the performance problems

\echo '=========================================='
\echo 'SLOW QUERIES (No indexes)'
\echo '=========================================='
\echo ''

-- Enable timing
\timing on

-- Query 1: Full-text search with LIKE (Sequential Scan)
\echo '=== Query 1: Text Search with LIKE ==='
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE descripcion LIKE '%laptop%'
   OR nombre LIKE '%laptop%';

\echo ''

-- Query 2: Price range without index
\echo '=== Query 2: Price Range (No Index) ==='
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE precio BETWEEN 100 AND 500
ORDER BY precio;

\echo ''

-- Query 3: Recent orders without date index
\echo '=== Query 3: Recent Orders (No Index) ==='
EXPLAIN ANALYZE
SELECT * FROM pedidos
WHERE fecha_pedido > CURRENT_DATE - INTERVAL '30 days'
ORDER BY fecha_pedido DESC
LIMIT 100;

\echo ''

-- Query 4: Category filter without index
\echo '=== Query 4: Category + Stock (No Index) ==='
EXPLAIN ANALYZE
SELECT nombre, precio, stock
FROM productos
WHERE categoria_id = 1 AND stock > 0
ORDER BY precio;

\echo ''

-- Query 5: Case-insensitive email search
\echo '=== Query 5: Email Search (No Index) ==='
EXPLAIN ANALYZE
SELECT * FROM clientes
WHERE LOWER(email) = 'juan@ejemplo.com';

\timing off

\echo ''
\echo '=========================================='
\echo 'Notice:'
\echo '  - Sequential Scans (Seq Scan)'
\echo '  - High costs'
\echo '  - Slow execution times'
\echo '=========================================='
