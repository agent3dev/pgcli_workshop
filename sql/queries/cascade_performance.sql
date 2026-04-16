-- ══════════════════════════════════════════════════════════════
-- cascade_performance.sql
-- ¿Cómo afecta ON DELETE CASCADE al rendimiento?
--
-- En el esquema normalizado las cadenas CASCADE son:
--   clientes → direcciones (ON DELETE CASCADE)
--   pedidos  → items_pedido (ON DELETE CASCADE)
--
-- Este script demuestra la segunda cadena: al eliminar un
-- pedido, PostgreSQL borra automáticamente todos sus items.
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'CASCADE Y RENDIMIENTO'
\echo '══════════════════════════════════════════'
\timing on

-- ── Limpieza previa (para que el script sea re-ejecutable) ────
DO $$
BEGIN
    -- Borrar items → pedidos → cliente en orden (FK NO ACTION)
    DELETE FROM items_pedido
    WHERE pedido_id IN (
        SELECT p.pedido_id FROM pedidos p
        JOIN clientes c ON c.cliente_id = p.cliente_id
        WHERE c.email IN ('cascade@test.com', 'manual@test.com')
    );
    DELETE FROM pedidos
    WHERE cliente_id IN (
        SELECT cliente_id FROM clientes
        WHERE email IN ('cascade@test.com', 'manual@test.com')
    );
    DELETE FROM clientes
    WHERE email IN ('cascade@test.com', 'manual@test.com');
END $$;

-- ── Paso 1: ver la cadena de FK definida ─────────────────────
SELECT
    tc.table_name          AS tabla_hijo,
    kcu.column_name        AS columna_fk,
    ccu.table_name         AS tabla_padre,
    rc.delete_rule         AS on_delete
FROM information_schema.table_constraints tc
JOIN information_schema.key_column_usage kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage ccu
    ON ccu.constraint_name = tc.constraint_name
JOIN information_schema.referential_constraints rc
    ON rc.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
ORDER BY tabla_padre, tabla_hijo;

-- ── Paso 2: crear pedido con muchos items ─────────────────────
\echo ''
\echo '=== Creando datos de prueba: 1 pedido con 500 items ==='

-- Insertar cliente y pedido de prueba
INSERT INTO clientes (nombre, email) VALUES ('Cliente Cascade Test', 'cascade@test.com');

INSERT INTO pedidos (cliente_id, total, estado)
SELECT cliente_id, 0, 'entregado'
FROM clientes WHERE email = 'cascade@test.com';

-- Desactivar triggers temporalmente para este benchmark
-- (los triggers de stock interferirían con los 500 inserts de prueba)
ALTER TABLE items_pedido DISABLE TRIGGER ALL;

DO $$
DECLARE
    v_pedido_id  INT;
    v_producto_id INT;
    j INT;
BEGIN
    SELECT p.pedido_id INTO v_pedido_id
    FROM pedidos p
    JOIN clientes c ON c.cliente_id = p.cliente_id
    WHERE c.email = 'cascade@test.com';

    FOR j IN 1..500 LOOP
        SELECT producto_id INTO v_producto_id
        FROM productos WHERE activo = true ORDER BY RANDOM() LIMIT 1;

        INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
        VALUES (v_pedido_id, v_producto_id, 1, 10.00);
    END LOOP;
END $$;

ALTER TABLE items_pedido ENABLE TRIGGER ALL;

SELECT COUNT(*) AS items_creados
FROM items_pedido
WHERE pedido_id = (
    SELECT p.pedido_id FROM pedidos p
    JOIN clientes c ON c.cliente_id = p.cliente_id
    WHERE c.email = 'cascade@test.com'
);

-- ── Paso 3: EXPLAIN del DELETE con CASCADE ────────────────────
\echo ''
\echo '=== EXPLAIN ANALYZE del DELETE con CASCADE ==='
\echo '    (borra el pedido → items_pedido se eliminan automáticamente)'

EXPLAIN ANALYZE
DELETE FROM pedidos
WHERE pedido_id = (
    SELECT p.pedido_id FROM pedidos p
    JOIN clientes c ON c.cliente_id = p.cliente_id
    WHERE c.email = 'cascade@test.com'
);

-- Verificar que los items también se borraron
SELECT COUNT(*) AS items_restantes_cascade
FROM items_pedido ip
WHERE NOT EXISTS (SELECT 1 FROM pedidos p WHERE p.pedido_id = ip.pedido_id);

-- ── Paso 4: comparar SIN CASCADE (borrado manual) ─────────────
\echo ''
\echo '=== Comparación: DELETE manual en orden inverso ==='

-- Recrear el pedido con 500 items
INSERT INTO pedidos (cliente_id, total, estado)
SELECT cliente_id, 0, 'entregado'
FROM clientes WHERE email = 'cascade@test.com';

ALTER TABLE items_pedido DISABLE TRIGGER ALL;

DO $$
DECLARE
    v_pedido_id  INT;
    v_producto_id INT;
    j INT;
BEGIN
    SELECT p.pedido_id INTO v_pedido_id
    FROM pedidos p
    JOIN clientes c ON c.cliente_id = p.cliente_id
    WHERE c.email = 'cascade@test.com'
    ORDER BY p.pedido_id DESC
    LIMIT 1;

    FOR j IN 1..500 LOOP
        SELECT producto_id INTO v_producto_id
        FROM productos WHERE activo = true ORDER BY RANDOM() LIMIT 1;

        INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
        VALUES (v_pedido_id, v_producto_id, 1, 10.00);
    END LOOP;
END $$;

ALTER TABLE items_pedido ENABLE TRIGGER ALL;

-- Borrar en orden manual (hijo primero, luego padre)
EXPLAIN ANALYZE
DELETE FROM items_pedido
WHERE pedido_id = (
    SELECT p.pedido_id FROM pedidos p
    JOIN clientes c ON c.cliente_id = p.cliente_id
    WHERE c.email = 'cascade@test.com'
    ORDER BY p.pedido_id DESC
    LIMIT 1
);

EXPLAIN ANALYZE
DELETE FROM pedidos
WHERE pedido_id IN (
    SELECT p.pedido_id FROM pedidos p
    JOIN clientes c ON c.cliente_id = p.cliente_id
    WHERE c.email = 'cascade@test.com'
);

-- Limpiar datos de prueba (pedidos.cliente_id es NO ACTION, borrar en orden)
DELETE FROM items_pedido
WHERE pedido_id IN (
    SELECT p.pedido_id FROM pedidos p
    JOIN clientes c ON c.cliente_id = p.cliente_id
    WHERE c.email = 'cascade@test.com'
);
DELETE FROM pedidos
WHERE cliente_id = (SELECT cliente_id FROM clientes WHERE email = 'cascade@test.com');
DELETE FROM clientes WHERE email = 'cascade@test.com';

\timing off

-- ── Paso 5: conclusiones ──────────────────────────────────────
\echo ''
\echo '══════════════════════════════════════════'
\echo 'OBSERVACIONES:'
\echo ''
\echo '1. CASCADE es conveniente pero hace trabajo "invisible".'
\echo '   Un solo DELETE en pedidos elimina todos sus items'
\echo '   sin que el código de aplicación lo vea.'
\echo ''
\echo '2. El costo del CASCADE depende de:'
\echo '   - Cuántas tablas hijas existen en la cadena'
\echo '   - Si las FK tienen índices (idx_items_pedido_pedido)'
\echo '   - El volumen de filas afectadas'
\echo ''
\echo '3. SIN índices en la FK, cada nivel de CASCADE hace un'
\echo '   Sequential Scan en la tabla hija — muy lento a escala.'
\echo '   CON índices (como los que tenemos) usa Index Scan.'
\echo ''
\echo '4. Alternativa a CASCADE: SET NULL o RESTRICT.'
\echo '   RESTRICT es más seguro en producción — fuerza al código'
\echo '   de aplicación a limpiar explícitamente.'
\echo '══════════════════════════════════════════'

-- ── Bonus: demostrar el impacto de NO tener índice en FK ──────
\echo ''
\echo '=== Comparación: con y sin índice en FK ==='

-- Con índice (ya existe idx_items_pedido_pedido o similar)
EXPLAIN ANALYZE
SELECT COUNT(*) FROM items_pedido WHERE pedido_id = 1;

-- Sin índice
CREATE TABLE items_sin_idx AS SELECT * FROM items_pedido;

EXPLAIN ANALYZE
SELECT COUNT(*) FROM items_sin_idx WHERE pedido_id = 1;

-- Limpiar
DROP TABLE IF EXISTS items_sin_idx;

\echo ''
\echo 'Conclusión: los índices en FK son CRÍTICOS cuando se usa CASCADE.'
\echo 'El esquema normalizado ya los incluye (idx_pedidos_cliente, etc.)'
