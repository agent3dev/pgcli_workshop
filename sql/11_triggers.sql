-- ══════════════════════════════════════════════════════════════
-- 11_triggers.sql — TRIGGERS
-- Temas: trigger functions, BEFORE/AFTER, NEW/OLD, auditoría
-- Un trigger se dispara automáticamente cuando ocurre un evento
-- DML (INSERT, UPDATE, DELETE) sobre una tabla.
--
-- En PostgreSQL los triggers son dos partes:
--   1. Una TRIGGER FUNCTION que retorna TRIGGER
--   2. Un TRIGGER que la asocia a una tabla y evento
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'EJERCICIO 11 — TRIGGERS'
\echo '══════════════════════════════════════════'

-- ── Setup: tabla de auditoría ─────────────────────────────────

CREATE TABLE IF NOT EXISTS pedidos_log (
    log_id      SERIAL PRIMARY KEY,
    pedido_id   INT,
    estado_anterior VARCHAR(20),
    estado_nuevo    VARCHAR(20),
    total_anterior  NUMERIC(10,2),
    total_nuevo     NUMERIC(10,2),
    modificado_en   TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

\echo '✅ Tabla pedidos_log creada'

-- ── 11.1  AFTER UPDATE — auditoría de cambios de estado ───────

CREATE OR REPLACE FUNCTION fn_auditar_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado <> NEW.estado OR OLD.total <> NEW.total THEN
        INSERT INTO pedidos_log (pedido_id, estado_anterior, estado_nuevo, total_anterior, total_nuevo)
        VALUES (NEW.pedido_id, OLD.estado, NEW.estado, OLD.total, NEW.total);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auditar_pedido
AFTER UPDATE ON pedidos
FOR EACH ROW EXECUTE FUNCTION fn_auditar_pedido();

-- Probar
UPDATE pedidos SET estado = 'procesando' WHERE pedido_id = 1;
UPDATE pedidos SET estado = 'enviado'    WHERE pedido_id = 1;

SELECT * FROM pedidos_log ORDER BY modificado_en;

-- ── 11.2  BEFORE INSERT — validar stock disponible ────────────

CREATE OR REPLACE FUNCTION fn_validar_stock()
RETURNS TRIGGER AS $$
DECLARE
    v_stock INT;
BEGIN
    SELECT stock INTO v_stock FROM productos WHERE producto_id = NEW.producto_id;

    IF v_stock < NEW.cantidad THEN
        RAISE EXCEPTION
            'Stock insuficiente para producto %. Disponible: %, solicitado: %',
            NEW.producto_id, v_stock, NEW.cantidad;
    END IF;

    RETURN NEW;   -- permitir el INSERT
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_stock
BEFORE INSERT ON items_pedido
FOR EACH ROW EXECUTE FUNCTION fn_validar_stock();

-- Probar: insertar con stock suficiente (ajusta los IDs según tus datos)
-- INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
-- VALUES (1, 1, 1, 100.00);

-- Probar: debería fallar por stock insuficiente (descomentar)
-- INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
-- VALUES (1, 1, 999999, 100.00);

-- ── 11.3  AFTER INSERT — reducir stock automáticamente ────────

CREATE OR REPLACE FUNCTION fn_reducir_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE productos
    SET stock = stock - NEW.cantidad
    WHERE producto_id = NEW.producto_id;

    RAISE NOTICE 'Stock actualizado para producto %: -%',
        NEW.producto_id, NEW.cantidad;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reducir_stock
AFTER INSERT ON items_pedido
FOR EACH ROW EXECUTE FUNCTION fn_reducir_stock();

-- ── 11.4  BEFORE UPDATE — no reactivar pedidos cancelados ─────

CREATE OR REPLACE FUNCTION fn_proteger_cancelado()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado = 'cancelado' AND NEW.estado <> 'cancelado' THEN
        RAISE EXCEPTION 'No se puede reactivar un pedido cancelado (ID: %)', OLD.pedido_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_proteger_cancelado
BEFORE UPDATE ON pedidos
FOR EACH ROW EXECUTE FUNCTION fn_proteger_cancelado();

-- Probar error (descomentar)
-- UPDATE pedidos SET estado = 'pendiente' WHERE estado = 'cancelado' LIMIT 1;

-- ── 11.5  Listar triggers activos ─────────────────────────────

SELECT
    trigger_name,
    event_manipulation  AS evento,
    event_object_table  AS tabla,
    action_timing       AS momento
FROM information_schema.triggers
WHERE trigger_schema = 'public'
ORDER BY tabla, trigger_name;

-- ── 11.6  DROP un trigger ─────────────────────────────────────

DROP TRIGGER IF EXISTS trg_proteger_cancelado ON pedidos;
DROP FUNCTION IF EXISTS fn_proteger_cancelado();

\echo ''
\echo '══════════════════════════════════════════'
\echo 'DESAFÍO:'
\echo '  1. Crea un AFTER DELETE trigger en items_pedido que'
\echo '     restaure el stock del producto eliminado y actualice'
\echo '     el total del pedido correspondiente.'
\echo ''
\echo '  2. Crea un BEFORE UPDATE trigger en productos que'
\echo '     impida que el precio se reduzca más del 50% en una'
\echo '     sola operación.'
\echo '     Prueba: UPDATE productos SET precio = 1 WHERE producto_id = 1;'
\echo ''
\echo '  3. Discusión: ¿qué problemas puede causar tener la lógica'
\echo '     de negocio en triggers en lugar de en la aplicación?'
\echo '══════════════════════════════════════════'
