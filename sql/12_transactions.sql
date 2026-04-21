-- ══════════════════════════════════════════════════════════════
-- 12_transactions.sql — TRANSACCIONES
-- Temas: BEGIN, COMMIT, ROLLBACK, SAVEPOINT, niveles de aislamiento
-- Una transacción agrupa varias operaciones en una unidad atómica:
-- o todas se aplican (COMMIT) o ninguna (ROLLBACK).
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'EJERCICIO 12 — TRANSACCIONES'
\echo '══════════════════════════════════════════'

-- ── 12.1  BEGIN / COMMIT — transacción exitosa ────────────────
-- Todo lo que está entre BEGIN y COMMIT se aplica junto.

-- Limpiar datos de corridas anteriores para que el ejemplo sea idempotente
DELETE FROM pedidos  WHERE cliente_id = (SELECT cliente_id FROM clientes WHERE email = 'tx@ejemplo.com');
DELETE FROM clientes WHERE email = 'tx@ejemplo.com';

BEGIN;

INSERT INTO clientes (nombre, email, telefono)
VALUES ('Cliente Transacción', 'tx@ejemplo.com', '+52-555-0000');

INSERT INTO pedidos (cliente_id, total, estado)
VALUES (
    (SELECT cliente_id FROM clientes WHERE email = 'tx@ejemplo.com'),
    0,
    'pendiente'
);

COMMIT;

-- Verificar que ambas filas existen
SELECT c.nombre, p.pedido_id, p.estado
FROM clientes c
INNER JOIN pedidos p ON p.cliente_id = c.cliente_id
WHERE c.email = 'tx@ejemplo.com';

-- ── 12.2  BEGIN / ROLLBACK — deshacer todo ───────────────────
-- Si algo falla (o decides abortar), ROLLBACK deja la BD intacta.

BEGIN;

UPDATE productos SET precio = precio * 0.01 WHERE activo = true;

-- Verificar el "daño" dentro de la transacción
SELECT COUNT(*), ROUND(AVG(precio)::NUMERIC, 4) AS avg_precio FROM productos WHERE activo = true;

-- ¡Arrepentimiento! Deshacemos TODO
ROLLBACK;

-- Verificar que los precios no cambiaron
SELECT COUNT(*), ROUND(AVG(precio)::NUMERIC, 2) AS precio_promedio
FROM productos WHERE activo = true;

-- ── 12.3  SAVEPOINT — puntos de control parciales ────────────
-- Puedes hacer ROLLBACK solo hasta un punto intermedio.
-- Nota: en psql/pgcli un error SQL aborta la transacción completa,
-- por eso usamos DO $$ para capturar la excepción y recuperar el control.

BEGIN;

-- Primera operación: nueva categoría
INSERT INTO categorias (nombre, descripcion)
VALUES ('Temporal', 'Categoría de prueba');

SAVEPOINT sp_categoria;

-- Segunda operación dentro de bloque anónimo — capturamos el error
-- para poder hacer ROLLBACK TO SAVEPOINT sin que psql aborte la TX.
DO $$
BEGIN
    INSERT INTO categorias (nombre, descripcion)
    VALUES ('Temporal', 'Duplicado — violará el UNIQUE');
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Duplicado capturado — hacemos ROLLBACK TO SAVEPOINT';
END;
$$;

ROLLBACK TO SAVEPOINT sp_categoria;

-- La categoría 'Temporal' aún existe (insertada antes del savepoint)
SELECT * FROM categorias WHERE nombre = 'Temporal';

COMMIT;   -- guarda la primera inserción; la segunda fue deshecha

-- Limpiar
DELETE FROM categorias WHERE nombre = 'Temporal';

-- ── 12.4  Error automático dentro de una transacción ─────────
-- En PostgreSQL, un error dentro de BEGIN/COMMIT aborta la transacción.
-- No puedes continuar ejecutando comandos hasta hacer ROLLBACK.

BEGIN;

SELECT 1 / 0;   -- ERROR: division by zero → transacción abortada

-- Cualquier comando ahora devuelve:
-- ERROR: current transaction is aborted, commands ignored until end of transaction block
SELECT * FROM clientes LIMIT 1;

ROLLBACK;   -- necesario para limpiar el estado

-- ── 12.5  Transacción real: transferir stock entre productos ──
-- Escenario: mover 10 unidades del producto 1 al producto 2.
-- Ambas actualizaciones deben ocurrir juntas o ninguna.

BEGIN;

DO $$
DECLARE
    v_stock_origen INT;
BEGIN
    SELECT stock INTO v_stock_origen FROM productos WHERE producto_id = 1;

    IF v_stock_origen < 10 THEN
        RAISE EXCEPTION 'Stock insuficiente en producto 1: %', v_stock_origen;
    END IF;

    UPDATE productos SET stock = stock - 10 WHERE producto_id = 1;
    UPDATE productos SET stock = stock + 10 WHERE producto_id = 2;

    RAISE NOTICE 'Transferencia completada.';
END;
$$;

COMMIT;

-- ── 12.6  Nivel de aislamiento ────────────────────────────────
-- Por defecto PostgreSQL usa READ COMMITTED.
-- Para evitar lecturas no repetibles usa REPEATABLE READ.

BEGIN TRANSACTION ISOLATION LEVEL REPEATABLE READ;

-- En esta transacción verás un snapshot consistente aunque
-- otra sesión haga cambios simultáneos.
SELECT COUNT(*) AS total_productos FROM productos;

-- (Pausa aquí y modifica productos en otra sesión de pgcli)
-- Ejecuta de nuevo: el conteo NO cambia hasta que hagas COMMIT.
SELECT COUNT(*) AS total_productos FROM productos;

COMMIT;

\echo ''
\echo '══════════════════════════════════════════'
\echo 'DESAFÍO:'
\echo '  1. Escribe una transacción que cree un cliente, su dirección'
\echo '     y su primer pedido. Si cualquier INSERT falla, nada se guarda.'
\echo ''
\echo '  2. Usa SAVEPOINT para insertar 3 ítems en un pedido.'
\echo '     Si el 3er ítem falla por stock, haz ROLLBACK al savepoint'
\echo '     y confirma solo los primeros 2.'
\echo ''
\echo '  3. Abre DOS terminales con "make shell" y:'
\echo '     - Terminal A: BEGIN; UPDATE productos SET precio = 9999 WHERE producto_id = 1;'
\echo '     - Terminal B: SELECT precio FROM productos WHERE producto_id = 1;'
\echo '     ¿Qué ve B antes y después de que A haga COMMIT?'
\echo '══════════════════════════════════════════'
