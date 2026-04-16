-- ══════════════════════════════════════════════════════════════
-- 07_joins.sql — JOINs
-- Temas: INNER, LEFT, multi-tabla, agregaciones
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'EJERCICIO 7 — JOINs'
\echo '══════════════════════════════════════════'

-- ── 7.1  INNER JOIN — pedidos con datos del cliente ──────────
-- Solo devuelve pedidos que tienen cliente registrado

SELECT
    p.pedido_id,
    c.nombre        AS cliente,
    c.email,
    p.fecha_pedido,
    p.total,
    p.estado
FROM pedidos p
INNER JOIN clientes c ON c.cliente_id = p.cliente_id
ORDER BY p.fecha_pedido DESC
LIMIT 10;

-- ── 7.2  LEFT JOIN — clientes que NUNCA han pedido ───────────
-- LEFT JOIN mantiene todos los clientes; NULL en pedido = sin pedido

SELECT
    c.cliente_id,
    c.nombre,
    c.email,
    c.fecha_registro
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
WHERE p.pedido_id IS NULL
ORDER BY c.fecha_registro DESC;

-- ── 7.3  JOIN tres tablas — detalle de items ─────────────────

SELECT
    p.pedido_id,
    c.nombre            AS cliente,
    pr.nombre           AS producto,
    ip.cantidad,
    ip.precio_unitario,
    ip.subtotal
FROM items_pedido ip
INNER JOIN pedidos   p  ON p.pedido_id  = ip.pedido_id
INNER JOIN clientes  c  ON c.cliente_id = p.cliente_id
INNER JOIN productos pr ON pr.producto_id = ip.producto_id
ORDER BY p.pedido_id, pr.nombre;

-- ── 7.4  JOIN cuatro tablas — con categoría ──────────────────

SELECT
    p.pedido_id,
    c.nombre            AS cliente,
    cat.nombre          AS categoria,
    pr.nombre           AS producto,
    ip.cantidad,
    ip.subtotal
FROM items_pedido ip
INNER JOIN pedidos    p   ON p.pedido_id    = ip.pedido_id
INNER JOIN clientes   c   ON c.cliente_id   = p.cliente_id
INNER JOIN productos  pr  ON pr.producto_id = ip.producto_id
INNER JOIN categorias cat ON cat.categoria_id = pr.categoria_id
ORDER BY cat.nombre, pr.nombre;

-- ── 7.5  JOIN + agregación — total gastado por cliente ───────

SELECT
    c.cliente_id,
    c.nombre,
    COUNT(p.pedido_id)              AS total_pedidos,
    ROUND(SUM(p.total)::NUMERIC, 2) AS total_gastado,
    ROUND(AVG(p.total)::NUMERIC, 2) AS ticket_promedio
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre
ORDER BY total_gastado DESC NULLS LAST;

-- ── 7.6  JOIN + agregación — productos más vendidos ──────────

SELECT
    pr.producto_id,
    pr.nombre,
    cat.nombre              AS categoria,
    SUM(ip.cantidad)        AS unidades_vendidas,
    ROUND(SUM(ip.subtotal)::NUMERIC, 2) AS ingresos_totales
FROM items_pedido ip
INNER JOIN productos  pr  ON pr.producto_id   = ip.producto_id
INNER JOIN categorias cat ON cat.categoria_id = pr.categoria_id
GROUP BY pr.producto_id, pr.nombre, cat.nombre
ORDER BY unidades_vendidas DESC
LIMIT 10;

-- ── 7.7  LEFT JOIN — productos que jamás se han vendido ──────

SELECT
    pr.producto_id,
    pr.nombre,
    pr.stock,
    pr.activo
FROM productos pr
LEFT JOIN items_pedido ip ON ip.producto_id = pr.producto_id
WHERE ip.item_id IS NULL
ORDER BY pr.nombre;

-- ── 7.8  JOIN + GROUP BY — ventas por categoría ──────────────

SELECT
    cat.nombre              AS categoria,
    COUNT(DISTINCT p.pedido_id)  AS pedidos_con_esta_categoria,
    SUM(ip.cantidad)             AS unidades_vendidas,
    ROUND(SUM(ip.subtotal)::NUMERIC, 2) AS ingresos
FROM categorias cat
LEFT JOIN productos  pr  ON pr.categoria_id = cat.categoria_id
LEFT JOIN items_pedido ip ON ip.producto_id = pr.producto_id
LEFT JOIN pedidos    p   ON p.pedido_id     = ip.pedido_id
GROUP BY cat.categoria_id, cat.nombre
ORDER BY ingresos DESC NULLS LAST;

\echo ''
\echo '══════════════════════════════════════════'
\echo 'DESAFÍO:'
\echo '  1. Lista todas las direcciones de clientes que tienen'
\echo '     al menos un pedido en estado "enviado".'
\echo '  2. Encuentra los 3 clientes con más pedidos.'
\echo '  3. Muestra qué categorías tienen productos con stock = 0.'
\echo '     (LEFT JOIN + HAVING o WHERE)'
\echo '══════════════════════════════════════════'
