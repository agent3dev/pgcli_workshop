-- ✅ INDEX OPTIMIZATION SOLUTIONS
-- Create indexes to speed up common queries

-- ==================================================
-- B-TREE INDEXES
-- ==================================================

-- Price range queries (most common)
CREATE INDEX idx_productos_precio ON productos(precio);

-- Date-based queries (recent orders)
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_pedido DESC);

-- Composite index for category + price filtering
CREATE INDEX idx_productos_categoria_precio ON productos(categoria_id, precio);

-- Stock lookups
CREATE INDEX idx_productos_stock ON productos(stock);

-- ==================================================
-- GIN INDEXES (Full-Text Search)
-- ==================================================

-- Full-text search on product name and description
CREATE INDEX idx_productos_busqueda ON productos
USING GIN(to_tsvector('spanish', nombre || ' ' || descripcion));

-- Alternative: Using pg_trgm for LIKE queries
CREATE INDEX idx_productos_nombre_trgm ON productos
USING GIN(nombre gin_trgm_ops);

CREATE INDEX idx_productos_descripcion_trgm ON productos
USING GIN(descripcion gin_trgm_ops);

-- ==================================================
-- PARTIAL INDEXES
-- ==================================================

-- Only index active products with stock
CREATE INDEX idx_productos_activos_stock ON productos(precio)
WHERE activo = true AND stock > 0;

-- Only index pending orders
CREATE INDEX idx_pedidos_pendientes ON pedidos(cliente_id, fecha_pedido)
WHERE estado = 'pendiente';

-- ==================================================
-- UNIQUE INDEXES
-- ==================================================

-- Ensure email uniqueness (if not already in schema)
CREATE UNIQUE INDEX idx_clientes_email_unique ON clientes(LOWER(email));

-- ==================================================
-- VERIFICATION
-- ==================================================

\echo ''
\echo '✅ All indexes created!'
\echo ''
\echo 'Verify with:'
\echo '  \\di                  -- List all indexes'
\echo '  \\d productos         -- See table indexes'
\echo ''
\echo 'Test performance with:'
\echo '  make benchmark'
