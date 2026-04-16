-- ══════════════════════════════════════════════════════════════
-- 09_functions.sql — FUNCIONES (Stored Functions)
-- Temas: LANGUAGE sql, LANGUAGE plpgsql, RETURN, DROP FUNCTION
-- Una función recibe parámetros y devuelve un valor.
-- Se puede usar en cualquier SELECT como si fuera una expresión.
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'EJERCICIO 9 — FUNCIONES'
\echo '══════════════════════════════════════════'

-- ── 9.1  LANGUAGE sql — conteo de pedidos por cliente ────────
-- Para consultas simples, LANGUAGE sql es suficiente (sin BEGIN)

CREATE OR REPLACE FUNCTION total_pedidos_cliente(p_cliente_id INT)
RETURNS BIGINT AS $$
    SELECT COUNT(*) FROM pedidos WHERE cliente_id = p_cliente_id;
$$ LANGUAGE sql;

-- Usar en un SELECT
SELECT nombre, total_pedidos_cliente(cliente_id) AS pedidos
FROM clientes
ORDER BY pedidos DESC;

-- ── 9.2  LANGUAGE sql — gasto total de un cliente ────────────

CREATE OR REPLACE FUNCTION gasto_total_cliente(p_cliente_id INT)
RETURNS NUMERIC AS $$
    SELECT COALESCE(SUM(total), 0)
    FROM pedidos
    WHERE cliente_id = p_cliente_id;
$$ LANGUAGE sql;

SELECT
    nombre,
    gasto_total_cliente(cliente_id) AS total_gastado
FROM clientes
ORDER BY total_gastado DESC;

-- ── 9.3  LANGUAGE sql — nombre de categoría ──────────────────

CREATE OR REPLACE FUNCTION nombre_categoria(p_categoria_id INT)
RETURNS VARCHAR AS $$
    SELECT nombre FROM categorias WHERE categoria_id = p_categoria_id;
$$ LANGUAGE sql;

SELECT nombre, precio, nombre_categoria(categoria_id) AS categoria
FROM productos
ORDER BY categoria, precio;

-- ── 9.4  LANGUAGE plpgsql — lógica condicional ───────────────
-- Clasifica al cliente según su gasto total

CREATE OR REPLACE FUNCTION clasificar_cliente(p_cliente_id INT)
RETURNS VARCHAR AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(total), 0) INTO v_total
    FROM pedidos WHERE cliente_id = p_cliente_id;

    IF v_total >= 1000 THEN
        RETURN 'VIP';
    ELSIF v_total >= 200 THEN
        RETURN 'Regular';
    ELSE
        RETURN 'Nuevo';
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT
    nombre,
    gasto_total_cliente(cliente_id)  AS total_gastado,
    clasificar_cliente(cliente_id)   AS segmento
FROM clientes
ORDER BY total_gastado DESC;

-- ── 9.5  LANGUAGE plpgsql — precio con descuento ─────────────

CREATE OR REPLACE FUNCTION precio_con_descuento(
    p_precio   NUMERIC,
    p_pct_desc NUMERIC
)
RETURNS NUMERIC AS $$
BEGIN
    IF p_pct_desc < 0 OR p_pct_desc > 100 THEN
        RAISE EXCEPTION 'Descuento debe estar entre 0 y 100';
    END IF;
    RETURN ROUND(p_precio * (1 - p_pct_desc / 100), 2);
END;
$$ LANGUAGE plpgsql;

SELECT
    nombre,
    precio                              AS precio_original,
    precio_con_descuento(precio, 15)    AS precio_con_15pct_desc
FROM productos
WHERE activo = true
ORDER BY precio DESC
LIMIT 10;

-- ── 9.6  DROP una función ─────────────────────────────────────
-- En PostgreSQL hay que incluir los tipos de parámetros

DROP FUNCTION IF EXISTS precio_con_descuento(NUMERIC, NUMERIC);

\echo ''
\echo '══════════════════════════════════════════'
\echo 'DESAFÍO:'
\echo '  1. Crea una función dias_desde_registro(p_cliente_id INT)'
\echo '     que retorne cuántos días han pasado desde que el cliente'
\echo '     se registró. Úsala para todos los clientes.'
\echo '     Hint: EXTRACT(EPOCH FROM ...) / 86400 o DATE_PART'
\echo ''
\echo '  2. Crea una función stock_suficiente(p_producto_id INT,'
\echo '     p_cantidad INT) que retorne TRUE si hay suficiente stock,'
\echo '     FALSE si no. Úsala en un SELECT sobre productos.'
\echo ''
\echo '  3. Crea una función resumen_pedido(p_pedido_id INT)'
\echo '     que retorne TEXT con: "Cliente: X | Items: N | Total: $Y"'
\echo '══════════════════════════════════════════'
