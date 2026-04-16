-- ══════════════════════════════════════════════════════════════
-- 06_dml.sql — DML (Data Manipulation Language)
-- Temas: INSERT, UPDATE, DELETE, subqueries, RETURNING
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'EJERCICIO 6 — DML'
\echo '══════════════════════════════════════════'

-- ── 6.1  INSERT fila única ────────────────────────────────────

INSERT INTO clientes (nombre, email, telefono)
VALUES ('Ana Torres', 'ana.torres@email.com', '+52-555-0101');

SELECT * FROM clientes WHERE email = 'ana.torres@email.com';

-- ── 6.2  INSERT múltiples filas ───────────────────────────────

INSERT INTO categorias (nombre, descripcion) VALUES
    ('Componentes',  'CPU, RAM, tarjetas gráficas'),
    ('Impresoras',   'Impresoras de tinta y láser'),
    ('Accesorios',   'Cables, fundas y soportes');

INSERT INTO productos (nombre, descripcion, precio, stock, categoria_id)
SELECT
    'Tarjeta Gráfica RTX',
    'NVIDIA RTX 4060, 8GB GDDR6',
    399.99,
    25,
    categoria_id
FROM categorias WHERE nombre = 'Componentes';

-- ── 6.3  INSERT … RETURNING ──────────────────────────────────
-- Obtener el ID generado inmediatamente

INSERT INTO clientes (nombre, email)
VALUES ('Carlos Ruiz', 'carlos.ruiz@email.com')
RETURNING cliente_id, nombre;

-- ── 6.4  UPDATE columna única ─────────────────────────────────

UPDATE productos
SET precio = 379.99
WHERE nombre = 'Tarjeta Gráfica RTX';

SELECT nombre, precio FROM productos WHERE nombre = 'Tarjeta Gráfica RTX';

-- ── 6.5  UPDATE múltiples columnas ───────────────────────────

UPDATE productos
SET stock  = stock - 5,
    activo = true
WHERE nombre = 'Tarjeta Gráfica RTX';

-- ── 6.6  UPDATE con subquery ──────────────────────────────────
-- Desactivar productos sin stock

UPDATE productos
SET activo = false
WHERE stock = 0;

-- ¿Cuántos quedaron inactivos?
SELECT COUNT(*) AS productos_inactivos FROM productos WHERE activo = false;

-- ── 6.7  DELETE fila específica ───────────────────────────────

-- Insertar fila de prueba
INSERT INTO categorias (nombre, descripcion)
VALUES ('PRUEBA', 'Categoría de prueba — eliminar');

SELECT * FROM categorias WHERE nombre = 'PRUEBA';

DELETE FROM categorias WHERE nombre = 'PRUEBA';

SELECT * FROM categorias WHERE nombre = 'PRUEBA';  -- debe estar vacío

-- ── 6.8  DELETE con condición ─────────────────────────────────
-- Eliminar pedidos cancelados (sin items asociados en este ejemplo)

DELETE FROM pedidos
WHERE estado = 'cancelado'
  AND NOT EXISTS (
      SELECT 1 FROM items_pedido ip WHERE ip.pedido_id = pedidos.pedido_id
  );

-- ── 6.9  Subquery en WHERE ────────────────────────────────────
-- Productos más caros que el promedio

SELECT nombre, precio
FROM productos
WHERE precio > (SELECT AVG(precio) FROM productos)
ORDER BY precio DESC;

\echo ''
\echo '══════════════════════════════════════════'
\echo 'DESAFÍO:'
\echo '  1. Inserta un nuevo cliente con dirección principal.'
\echo '     (Requiere INSERT en clientes y luego en direcciones).'
\echo '  2. Crea un pedido para ese cliente y agrégale 2 items.'
\echo '     Recuerda: subtotal es GENERATED, no lo insertes.'
\echo '  3. Actualiza el estado del pedido a "enviado".'
\echo '  4. Elimina el cliente que creaste.'
\echo '     ¿Qué pasa con sus pedidos? (ON DELETE CASCADE)'
\echo '══════════════════════════════════════════'
