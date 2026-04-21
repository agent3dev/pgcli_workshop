-- ══════════════════════════════════════════════════════════════
-- performance_demo.sql — BEFORE vs AFTER INDEX
-- Run this to see the real impact of indexes on 100k rows.
-- ══════════════════════════════════════════════════════════════

\timing on

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'DEMO: Query performance WITHOUT indexes'
\echo '══════════════════════════════════════════════════════'

-- Make sure no indexes exist from a previous run
DROP INDEX IF EXISTS idx_productos_precio;
DROP INDEX IF EXISTS idx_productos_busqueda;
DROP INDEX IF EXISTS idx_productos_nombre_trgm;
DROP INDEX IF EXISTS idx_productos_activos_stock;
DROP INDEX IF EXISTS idx_pedidos_fecha;
DROP INDEX IF EXISTS idx_productos_categoria_precio;

\echo ''
\echo '── Query 1: Price range ─────────────────────────────'
\echo 'SELECT COUNT(*) FROM productos WHERE precio BETWEEN 100 AND 500;'
EXPLAIN ANALYZE SELECT COUNT(*) FROM productos WHERE precio BETWEEN 100 AND 500;

\echo ''
\echo '── Query 2: Full-text search ────────────────────────'
\echo 'SELECT COUNT(*) FROM productos WHERE nombre ILIKE ''%gaming%'';'
EXPLAIN ANALYZE SELECT COUNT(*) FROM productos WHERE nombre ILIKE '%gaming%';

\echo ''
\echo '── Query 3: Active products sorted by price ─────────'
\echo 'SELECT producto_id, nombre, precio FROM productos WHERE activo = true ORDER BY precio LIMIT 20;'
EXPLAIN ANALYZE SELECT producto_id, nombre, precio FROM productos WHERE activo = true ORDER BY precio LIMIT 20;

\echo ''
\echo '── Query 4: Recent orders ───────────────────────────'
\echo 'SELECT * FROM pedidos WHERE fecha_pedido > NOW() - INTERVAL ''30 days'';'
EXPLAIN ANALYZE SELECT * FROM pedidos WHERE fecha_pedido > NOW() - INTERVAL '30 days';

\echo ''
\echo '── Query 5: Orders JOIN clients (no FK index) ───────'
\echo 'SELECT c.nombre, COUNT(p.pedido_id) FROM clientes c LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id GROUP BY c.cliente_id LIMIT 10;'
EXPLAIN ANALYZE
SELECT c.nombre, COUNT(p.pedido_id)
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre
ORDER BY COUNT DESC LIMIT 10;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'Now creating indexes...'
\echo '══════════════════════════════════════════════════════'
\echo ''

CREATE INDEX idx_productos_precio          ON productos(precio);
CREATE INDEX idx_productos_categoria_precio ON productos(categoria_id, precio);
CREATE INDEX idx_productos_activos_stock    ON productos(precio) WHERE activo = true AND stock > 0;
CREATE INDEX idx_pedidos_fecha             ON pedidos(fecha_pedido DESC);
CREATE INDEX IF NOT EXISTS idx_pedidos_cliente ON pedidos(cliente_id);

CREATE INDEX idx_productos_busqueda ON productos
    USING GIN(to_tsvector('spanish', nombre || ' ' || descripcion));

CREATE INDEX idx_productos_nombre_trgm ON productos
    USING GIN(nombre gin_trgm_ops);

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'DEMO: Same queries WITH indexes'
\echo '══════════════════════════════════════════════════════'

\echo ''
\echo '── Query 1: Price range ─────────────────────────────'
EXPLAIN ANALYZE SELECT COUNT(*) FROM productos WHERE precio BETWEEN 100 AND 500;

\echo ''
\echo '── Query 2: Full-text search (trigram) ──────────────'
EXPLAIN ANALYZE SELECT COUNT(*) FROM productos WHERE nombre ILIKE '%gaming%';

\echo ''
\echo '── Query 3: Active products sorted by price ─────────'
EXPLAIN ANALYZE SELECT producto_id, nombre, precio FROM productos WHERE activo = true ORDER BY precio LIMIT 20;

\echo ''
\echo '── Query 4: Recent orders ───────────────────────────'
EXPLAIN ANALYZE SELECT * FROM pedidos WHERE fecha_pedido > NOW() - INTERVAL '30 days';

\echo ''
\echo '── Query 5: Orders JOIN clients ─────────────────────'
EXPLAIN ANALYZE
SELECT c.nombre, COUNT(p.pedido_id)
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre
ORDER BY COUNT DESC LIMIT 10;

\echo ''
\echo '══════════════════════════════════════════════════════'
\echo 'Index sizes:'
\echo '══════════════════════════════════════════════════════'

SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) AS size
FROM pg_indexes
WHERE tablename IN ('productos','pedidos')
  AND indexname LIKE 'idx_%'
ORDER BY pg_relation_size(indexname::regclass) DESC;

\echo ''
\echo '  Table size vs total index size:'
SELECT
    pg_size_pretty(pg_table_size('productos'))        AS table_data,
    pg_size_pretty(pg_indexes_size('productos'))      AS total_indexes,
    pg_size_pretty(pg_total_relation_size('productos')) AS total_with_indexes;

\timing off
