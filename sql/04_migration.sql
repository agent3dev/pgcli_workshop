-- ==================================================
-- DATA MIGRATION: From Bad Schema to Normalized
-- ==================================================

-- 1. Migrate categories (deduplicate from productos)
INSERT INTO categorias (nombre)
SELECT DISTINCT categoria_nombre
FROM productos
WHERE categoria_nombre IS NOT NULL
ORDER BY categoria_nombre;

-- 2. Migrate products (update categoria_id)
INSERT INTO productos (nombre, descripcion, precio, stock, categoria_id, fecha_creacion, activo)
SELECT
    p.nombre,
    p.descripcion,
    p.precio,
    p.stock,
    c.categoria_id,
    p.fecha_creacion,
    p.activo
FROM productos p
LEFT JOIN categorias c ON c.nombre = p.categoria_nombre;

-- 3. Migrate clients (deduplicate from pedidos_completos)
INSERT INTO clientes (nombre, email, telefono)
SELECT DISTINCT
    cliente_nombre,
    cliente_email,
    cliente_telefono
FROM pedidos_completos
ORDER BY cliente_email;

-- 4. Migrate addresses (one per client)
INSERT INTO direcciones (cliente_id, calle, ciudad, codigo_postal, es_principal)
SELECT
    c.cliente_id,
    pc.cliente_direccion,
    pc.cliente_ciudad,
    pc.cliente_codigo_postal,
    true
FROM pedidos_completos pc
JOIN clientes c ON c.email = pc.cliente_email
GROUP BY c.cliente_id, pc.cliente_direccion, pc.cliente_ciudad, pc.cliente_codigo_postal;

-- 5. Migrate orders
INSERT INTO pedidos (cliente_id, fecha_pedido, total, estado)
SELECT
    c.cliente_id,
    pc.fecha_pedido,
    pc.total,
    pc.estado
FROM pedidos_completos pc
JOIN clientes c ON c.email = pc.cliente_email;

-- 6. Migrate order items (handle up to 3 products per order)
-- Product 1
INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT
    ped.pedido_id,
    prod.producto_id,
    pc.producto1_cantidad,
    pc.producto1_precio
FROM pedidos_completos pc
JOIN pedidos ped ON ped.fecha_pedido = pc.fecha_pedido
    AND ped.total = pc.total  -- Assuming unique combination
JOIN productos prod ON prod.nombre = pc.producto1_nombre
WHERE pc.producto1_nombre IS NOT NULL;

-- Product 2
INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT
    ped.pedido_id,
    prod.producto_id,
    pc.producto2_cantidad,
    pc.producto2_precio
FROM pedidos_completos pc
JOIN pedidos ped ON ped.fecha_pedido = pc.fecha_pedido
    AND ped.total = pc.total
JOIN productos prod ON prod.nombre = pc.producto2_nombre
WHERE pc.producto2_nombre IS NOT NULL;

-- Product 3
INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
SELECT
    ped.pedido_id,
    prod.producto_id,
    pc.producto3_cantidad,
    pc.producto3_precio
FROM pedidos_completos pc
JOIN pedidos ped ON ped.fecha_pedido = pc.fecha_pedido
    AND ped.total = pc.total
JOIN productos prod ON prod.nombre = pc.producto3_nombre
WHERE pc.producto3_nombre IS NOT NULL;

-- ==================================================
-- VERIFICATION QUERIES
-- ==================================================

-- Check counts
SELECT 'clientes' as table_name, COUNT(*) as count FROM clientes
UNION ALL
SELECT 'direcciones', COUNT(*) FROM direcciones
UNION ALL
SELECT 'categorias', COUNT(*) FROM categorias
UNION ALL
SELECT 'productos', COUNT(*) FROM productos
UNION ALL
SELECT 'pedidos', COUNT(*) FROM pedidos
UNION ALL
SELECT 'items_pedido', COUNT(*) FROM items_pedido;

-- Verify data integrity
SELECT
    COUNT(*) as total_orders,
    SUM(total) as total_revenue
FROM pedidos;

-- Compare with original
SELECT
    COUNT(*) as original_orders,
    SUM(total) as original_revenue
FROM pedidos_completos;

\echo 'Migration complete! Verify counts match expectations.'