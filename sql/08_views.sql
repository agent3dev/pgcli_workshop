-- ══════════════════════════════════════════════════════════════
-- 08_views.sql — VIEWS (Vistas)
-- Temas: CREATE VIEW, consultar vista, STRING_AGG, DROP VIEW
-- Una vista es un SELECT guardado que se comporta como tabla virtual.
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'EJERCICIO 8 — VIEWS'
\echo '══════════════════════════════════════════'

-- ── 8.1  Vista simple — resumen de pedidos ────────────────────

CREATE VIEW v_resumen_pedidos AS
SELECT
    p.pedido_id,
    c.nombre            AS cliente,
    c.email,
    p.fecha_pedido,
    p.total,
    p.estado,
    COUNT(ip.item_id)   AS total_items
FROM pedidos p
INNER JOIN clientes    c  ON c.cliente_id = p.cliente_id
LEFT  JOIN items_pedido ip ON ip.pedido_id = p.pedido_id
GROUP BY p.pedido_id, c.nombre, c.email, p.fecha_pedido, p.total, p.estado;

-- Usar como tabla normal
SELECT * FROM v_resumen_pedidos ORDER BY fecha_pedido DESC LIMIT 10;

-- Filtrar sobre la vista
SELECT * FROM v_resumen_pedidos
WHERE estado = 'pendiente'
ORDER BY total DESC;

-- ── 8.2  Vista con agregación — estadísticas por cliente ──────

CREATE VIEW v_clientes_stats AS
SELECT
    c.cliente_id,
    c.nombre,
    c.email,
    COUNT(p.pedido_id)              AS total_pedidos,
    ROUND(SUM(p.total)::NUMERIC, 2) AS total_gastado,
    ROUND(AVG(p.total)::NUMERIC, 2) AS ticket_promedio,
    MAX(p.fecha_pedido)             AS ultimo_pedido
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre, c.email;

SELECT * FROM v_clientes_stats ORDER BY total_gastado DESC NULLS LAST;

-- Clientes que nunca han comprado
SELECT nombre, email FROM v_clientes_stats WHERE total_pedidos = 0;

-- ── 8.3  Vista — productos disponibles ───────────────────────

CREATE VIEW v_productos_disponibles AS
SELECT
    pr.producto_id,
    pr.nombre,
    cat.nombre          AS categoria,
    pr.precio,
    pr.stock,
    pr.descripcion
FROM productos pr
INNER JOIN categorias cat ON cat.categoria_id = pr.categoria_id
WHERE pr.activo = true AND pr.stock > 0
ORDER BY cat.nombre, pr.nombre;

SELECT * FROM v_productos_disponibles;

-- ── 8.4  Vista con STRING_AGG — productos por pedido ─────────

CREATE VIEW v_pedido_detalle AS
SELECT
    p.pedido_id,
    c.nombre                AS cliente,
    p.estado,
    p.total,
    STRING_AGG(
        pr.nombre || ' x' || ip.cantidad,
        ', '
        ORDER BY pr.nombre
    )                       AS productos
FROM pedidos p
INNER JOIN clientes     c   ON c.cliente_id   = p.cliente_id
INNER JOIN items_pedido ip  ON ip.pedido_id   = p.pedido_id
INNER JOIN productos    pr  ON pr.producto_id = ip.producto_id
GROUP BY p.pedido_id, c.nombre, p.estado, p.total;

SELECT * FROM v_pedido_detalle ORDER BY pedido_id DESC LIMIT 5;

-- ── 8.5  DROP una vista ───────────────────────────────────────

DROP VIEW IF EXISTS v_pedido_detalle;

\echo ''
\echo '══════════════════════════════════════════'
\echo 'DESAFÍO:'
\echo '  1. Crea una vista v_productos_agotados que muestre'
\echo '     productos con stock = 0, su categoría y su precio.'
\echo '  2. Crea una vista v_ingresos_por_categoria que muestre'
\echo '     para cada categoría: nombre, total de unidades vendidas'
\echo '     e ingresos totales. Ordena por ingresos DESC.'
\echo '  3. Usa v_clientes_stats para encontrar el cliente con'
\echo '     el ticket_promedio más alto.'
\echo '══════════════════════════════════════════'
