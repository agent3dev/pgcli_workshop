-- ══════════════════════════════════════════════════════════════
-- 10_procedures.sql — PROCEDIMIENTOS ALMACENADOS
-- Temas: CREATE PROCEDURE, CALL, RAISE NOTICE, validaciones, loops
-- Un procedimiento ejecuta lógica pero NO devuelve valor.
-- Para mostrar output se usa RAISE NOTICE.
-- Para devolver datos usa FUNCTION con RETURNS TABLE.
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'EJERCICIO 10 — PROCEDIMIENTOS'
\echo '══════════════════════════════════════════'

-- ── 10.1  Procedimiento simple — actualizar estado de pedido ──

CREATE OR REPLACE PROCEDURE actualizar_estado_pedido(
    p_pedido_id  INT,
    p_nuevo_estado VARCHAR
)
LANGUAGE plpgsql AS $$
DECLARE
    v_estado_actual VARCHAR;
    v_cliente       VARCHAR;
BEGIN
    -- Verificar que el pedido exista
    SELECT p.estado, c.nombre
    INTO v_estado_actual, v_cliente
    FROM pedidos p
    INNER JOIN clientes c ON c.cliente_id = p.cliente_id
    WHERE p.pedido_id = p_pedido_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido % no encontrado', p_pedido_id;
    END IF;

    -- Verificar transición válida
    IF v_estado_actual = 'cancelado' THEN
        RAISE EXCEPTION 'No se puede modificar un pedido cancelado';
    END IF;

    UPDATE pedidos SET estado = p_nuevo_estado WHERE pedido_id = p_pedido_id;

    RAISE NOTICE 'Pedido % (cliente: %) actualizado: % → %',
        p_pedido_id, v_cliente, v_estado_actual, p_nuevo_estado;
END;
$$;

-- Probar
CALL actualizar_estado_pedido(1, 'procesando');
SELECT pedido_id, estado FROM pedidos WHERE pedido_id = 1;

-- Probar error (descomentar para ver la excepción)
-- CALL actualizar_estado_pedido(999, 'enviado');

-- ── 10.2  Función con RETURNS TABLE — pedidos activos ─────────
-- Cuando necesitas devolver datos, usa FUNCTION no PROCEDURE

CREATE OR REPLACE FUNCTION pedidos_activos_cliente(p_cliente_id INT)
RETURNS TABLE(
    pedido_id    INT,
    fecha        TIMESTAMP,
    total        NUMERIC,
    estado       VARCHAR,
    total_items  BIGINT
) AS $$
    SELECT
        p.pedido_id,
        p.fecha_pedido,
        p.total,
        p.estado,
        COUNT(ip.item_id)
    FROM pedidos p
    LEFT JOIN items_pedido ip ON ip.pedido_id = p.pedido_id
    WHERE p.cliente_id = p_cliente_id
      AND p.estado NOT IN ('cancelado', 'entregado')
    GROUP BY p.pedido_id, p.fecha_pedido, p.total, p.estado
    ORDER BY p.fecha_pedido DESC;
$$ LANGUAGE sql;

SELECT * FROM pedidos_activos_cliente(1);

-- ── 10.3  Procedimiento con validación — agregar item ─────────

CREATE OR REPLACE PROCEDURE agregar_item_pedido(
    p_pedido_id   INT,
    p_producto_id INT,
    p_cantidad    INT
)
LANGUAGE plpgsql AS $$
DECLARE
    v_stock_actual  INT;
    v_precio        NUMERIC;
    v_estado_pedido VARCHAR;
    v_nuevo_total   NUMERIC;
BEGIN
    -- Validar pedido existe y está abierto
    SELECT estado INTO v_estado_pedido FROM pedidos WHERE pedido_id = p_pedido_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Pedido % no encontrado', p_pedido_id;
    END IF;
    IF v_estado_pedido NOT IN ('pendiente', 'procesando') THEN
        RAISE EXCEPTION 'No se pueden agregar items a un pedido en estado %', v_estado_pedido;
    END IF;

    -- Validar producto existe y tiene stock
    SELECT precio, stock INTO v_precio, v_stock_actual
    FROM productos WHERE producto_id = p_producto_id AND activo = true;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Producto % no encontrado o inactivo', p_producto_id;
    END IF;
    IF v_stock_actual < p_cantidad THEN
        RAISE EXCEPTION 'Stock insuficiente. Disponible: %, solicitado: %',
            v_stock_actual, p_cantidad;
    END IF;

    -- Insertar item
    INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
    VALUES (p_pedido_id, p_producto_id, p_cantidad, v_precio);

    -- Reducir stock
    UPDATE productos SET stock = stock - p_cantidad WHERE producto_id = p_producto_id;

    -- Recalcular total del pedido
    SELECT SUM(subtotal) INTO v_nuevo_total FROM items_pedido WHERE pedido_id = p_pedido_id;
    UPDATE pedidos SET total = v_nuevo_total WHERE pedido_id = p_pedido_id;

    RAISE NOTICE 'Item agregado al pedido %. Nuevo total: $%', p_pedido_id, v_nuevo_total;
END;
$$;

CALL agregar_item_pedido(1, 1, 2);

-- ── 10.4  Procedimiento con loop — archivar pedidos viejos ────

CREATE OR REPLACE PROCEDURE archivar_pedidos_entregados(p_dias_atras INT)
LANGUAGE plpgsql AS $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT pedido_id, total
        FROM pedidos
        WHERE estado = 'entregado'
          AND fecha_pedido < CURRENT_DATE - (p_dias_atras || ' days')::INTERVAL
    LOOP
        -- En un sistema real aquí moverías a una tabla histórica
        RAISE NOTICE 'Archivando pedido % ($%)', r.pedido_id, r.total;
    END LOOP;

    RAISE NOTICE 'Proceso completado.';
END;
$$;

CALL archivar_pedidos_entregados(90);

-- ── 10.5  DROP un procedimiento ───────────────────────────────

DROP PROCEDURE IF EXISTS archivar_pedidos_entregados(INT);

\echo ''
\echo '══════════════════════════════════════════'
\echo 'DESAFÍO:'
\echo '  1. Crea un procedimiento cancelar_pedido(p_pedido_id INT)'
\echo '     que: verifique que el pedido no esté ya entregado,'
\echo '     restaure el stock de todos sus items, y cambie'
\echo '     el estado a "cancelado".'
\echo ''
\echo '  2. Crea una FUNCTION (no procedure) reporte_cliente('
\echo '     p_cliente_id INT) que retorne RETURNS TABLE con:'
\echo '     pedido_id, fecha, estado, total, lista de productos.'
\echo '══════════════════════════════════════════'
