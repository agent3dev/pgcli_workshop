# Soluciones — SQL Fundamentals

---

## Ejercicio 5 — DDL

```sql
-- 5.2 Agregar columnas
ALTER TABLE productos ADD COLUMN descuento NUMERIC(5,2) DEFAULT 0
    CHECK (descuento >= 0 AND descuento <= 100);
ALTER TABLE pedidos ADD COLUMN notas TEXT;
ALTER TABLE clientes ALTER COLUMN telefono TYPE VARCHAR(30);

-- 5.3 Constraint UNIQUE
ALTER TABLE productos ADD CONSTRAINT uq_producto_nombre UNIQUE (nombre);
-- El segundo INSERT con el mismo nombre devuelve:
-- ERROR: duplicate key value violates unique constraint "uq_producto_nombre"
ALTER TABLE productos DROP CONSTRAINT uq_producto_nombre;

-- 5.4 Tabla resenas
CREATE TABLE resenas (
    resena_id   SERIAL PRIMARY KEY,
    producto_id INT NOT NULL REFERENCES productos(producto_id) ON DELETE CASCADE,
    cliente_id  INT NOT NULL REFERENCES clientes(cliente_id)  ON DELETE CASCADE,
    puntuacion  INT NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
    comentario  TEXT,
    fecha       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (producto_id, cliente_id)
);

-- Desafío: cupones
CREATE TABLE cupones (
    cupon_id     SERIAL PRIMARY KEY,
    codigo       VARCHAR(50) UNIQUE NOT NULL,
    descuento_pct NUMERIC(5,2) CHECK (descuento_pct > 0 AND descuento_pct <= 100),
    activo       BOOLEAN DEFAULT true
);
ALTER TABLE pedidos ADD COLUMN cupon_id INT REFERENCES cupones(cupon_id);
```

---

## Ejercicio 6 — DML

```sql
-- 6.1 INSERT con RETURNING
INSERT INTO clientes (nombre, email, telefono)
VALUES ('Ana Torres', 'ana@email.com', '+52-555-0101')
RETURNING cliente_id, nombre;

-- INSERT múltiples productos
INSERT INTO productos (nombre, descripcion, precio, stock, categoria_id) VALUES
    ('Teclado RGB',   'Mecánico switches Blue', 89.99, 100, 1),
    ('Mouse Gamer',   '12000 DPI inalámbrico',  59.99,  80, 1),
    ('Mousepad XL',   'Base de tela 90x40cm',   19.99, 200, 1);

-- 6.2 UPDATE múltiple
UPDATE productos
SET stock  = stock - 10,
    activo = true
WHERE nombre = 'Teclado RGB';

UPDATE productos SET activo = false WHERE stock = 0;

-- 6.3 DELETE con NOT EXISTS
DELETE FROM pedidos
WHERE estado = 'cancelado'
  AND NOT EXISTS (
      SELECT 1 FROM items_pedido ip WHERE ip.pedido_id = pedidos.pedido_id
  );

-- 6.4 Subquery: productos sobre el promedio
SELECT nombre, precio
FROM productos
WHERE precio > (SELECT AVG(precio) FROM productos)
ORDER BY precio DESC;

-- Desafío: insertar cliente con dirección (orden correcto: cliente primero)
INSERT INTO clientes (nombre, email) VALUES ('Test User', 'test@test.com')
RETURNING cliente_id;
-- Usar el cliente_id retornado:
INSERT INTO direcciones (cliente_id, calle, ciudad, es_principal)
VALUES (<<cliente_id>>, 'Av. Reforma 100', 'CDMX', true);
```

---

## Ejercicio 7 — JOINs

```sql
-- 7.1 INNER JOIN pedidos + clientes
SELECT p.pedido_id, c.nombre, c.email, p.fecha_pedido, p.total, p.estado
FROM pedidos p
INNER JOIN clientes c ON c.cliente_id = p.cliente_id
ORDER BY p.fecha_pedido DESC;

-- 7.2 Clientes sin pedidos
SELECT c.cliente_id, c.nombre, c.email
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
WHERE p.pedido_id IS NULL;

-- 7.3 Detalle de items
SELECT p.pedido_id, c.nombre AS cliente, pr.nombre AS producto,
       ip.cantidad, ip.precio_unitario, ip.subtotal
FROM items_pedido ip
INNER JOIN pedidos   p  ON p.pedido_id    = ip.pedido_id
INNER JOIN clientes  c  ON c.cliente_id   = p.cliente_id
INNER JOIN productos pr ON pr.producto_id = ip.producto_id;

-- 7.4 Total gastado por cliente
SELECT c.nombre, COUNT(p.pedido_id) AS pedidos,
       ROUND(SUM(p.total)::NUMERIC, 2) AS total_gastado
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre
ORDER BY total_gastado DESC NULLS LAST;

-- Productos más vendidos
SELECT pr.nombre, SUM(ip.cantidad) AS unidades
FROM items_pedido ip
INNER JOIN productos pr ON pr.producto_id = ip.producto_id
GROUP BY pr.producto_id, pr.nombre
ORDER BY unidades DESC LIMIT 5;

-- Tabla completada:
-- Clientes sin pedidos       → LEFT JOIN + IS NULL
-- Detalle de un pedido       → INNER JOIN (3–4 tablas)
-- Productos nunca vendidos   → LEFT JOIN items_pedido + IS NULL
-- Total por cliente          → LEFT JOIN + GROUP BY + SUM

-- Desafío: clientes con pedido enviado + dirección
SELECT DISTINCT c.nombre, d.calle, d.ciudad, p.estado
FROM pedidos p
INNER JOIN clientes    c ON c.cliente_id   = p.cliente_id
INNER JOIN direcciones d ON d.direccion_id = p.direccion_entrega_id
WHERE p.estado = 'enviado';
```

---

## Ejercicio 8 — Vistas

```sql
-- 8.1 v_resumen_pedidos
CREATE VIEW v_resumen_pedidos AS
SELECT p.pedido_id, c.nombre AS cliente, c.email,
       p.fecha_pedido, p.total, p.estado, COUNT(ip.item_id) AS total_items
FROM pedidos p
INNER JOIN clientes     c  ON c.cliente_id = p.cliente_id
LEFT  JOIN items_pedido ip ON ip.pedido_id = p.pedido_id
GROUP BY p.pedido_id, c.nombre, c.email, p.fecha_pedido, p.total, p.estado;

SELECT * FROM v_resumen_pedidos WHERE estado = 'pendiente';

-- 8.2 v_clientes_stats
CREATE VIEW v_clientes_stats AS
SELECT c.cliente_id, c.nombre, c.email,
       COUNT(p.pedido_id)              AS total_pedidos,
       ROUND(SUM(p.total)::NUMERIC, 2) AS total_gastado,
       ROUND(AVG(p.total)::NUMERIC, 2) AS ticket_promedio,
       MAX(p.fecha_pedido)             AS ultimo_pedido
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre, c.email;

SELECT nombre FROM v_clientes_stats WHERE total_pedidos = 0;

-- 8.3 v_pedido_detalle con STRING_AGG
CREATE VIEW v_pedido_detalle AS
SELECT p.pedido_id, c.nombre AS cliente, p.estado, p.total,
       STRING_AGG(pr.nombre || ' x' || ip.cantidad, ', ' ORDER BY pr.nombre) AS productos
FROM pedidos p
INNER JOIN clientes     c   ON c.cliente_id   = p.cliente_id
INNER JOIN items_pedido ip  ON ip.pedido_id   = p.pedido_id
INNER JOIN productos    pr  ON pr.producto_id = ip.producto_id
GROUP BY p.pedido_id, c.nombre, p.estado, p.total;

-- Desafíos
CREATE VIEW v_productos_agotados AS
SELECT pr.nombre, cat.nombre AS categoria, pr.precio
FROM productos pr
INNER JOIN categorias cat ON cat.categoria_id = pr.categoria_id
WHERE pr.stock = 0;

CREATE VIEW v_ingresos_por_categoria AS
SELECT cat.nombre AS categoria,
       SUM(ip.cantidad) AS unidades_vendidas,
       ROUND(SUM(ip.subtotal)::NUMERIC, 2) AS ingresos
FROM categorias cat
LEFT JOIN productos   pr ON pr.categoria_id = cat.categoria_id
LEFT JOIN items_pedido ip ON ip.producto_id = pr.producto_id
GROUP BY cat.categoria_id, cat.nombre
ORDER BY ingresos DESC NULLS LAST;
```

---

## Ejercicio 9 — Funciones

```sql
-- 9.1 LANGUAGE sql
CREATE OR REPLACE FUNCTION total_pedidos_cliente(p_cliente_id INT)
RETURNS BIGINT AS $$
    SELECT COUNT(*) FROM pedidos WHERE cliente_id = p_cliente_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION gasto_total_cliente(p_cliente_id INT)
RETURNS NUMERIC AS $$
    SELECT COALESCE(SUM(total), 0) FROM pedidos WHERE cliente_id = p_cliente_id;
$$ LANGUAGE sql;

SELECT nombre, total_pedidos_cliente(cliente_id) AS pedidos,
       gasto_total_cliente(cliente_id) AS gastado
FROM clientes ORDER BY gastado DESC;

-- 9.2 Clasificar cliente
CREATE OR REPLACE FUNCTION clasificar_cliente(p_cliente_id INT)
RETURNS VARCHAR AS $$
DECLARE v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(total), 0) INTO v_total
    FROM pedidos WHERE cliente_id = p_cliente_id;
    IF v_total >= 1000 THEN RETURN 'VIP';
    ELSIF v_total >= 200 THEN RETURN 'Regular';
    ELSE RETURN 'Nuevo';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- 9.3 Precio con descuento + validación
CREATE OR REPLACE FUNCTION precio_con_descuento(p_precio NUMERIC, p_pct NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    IF p_pct < 0 OR p_pct > 100 THEN
        RAISE EXCEPTION 'Descuento debe estar entre 0 y 100, recibido: %', p_pct;
    END IF;
    RETURN ROUND(p_precio * (1 - p_pct / 100), 2);
END;
$$ LANGUAGE plpgsql;

-- Desafíos
CREATE OR REPLACE FUNCTION dias_desde_registro(p_cliente_id INT)
RETURNS INT AS $$
    SELECT EXTRACT(DAY FROM NOW() - fecha_registro)::INT
    FROM clientes WHERE cliente_id = p_cliente_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION stock_suficiente(p_producto_id INT, p_cantidad INT)
RETURNS BOOLEAN AS $$
    SELECT stock >= p_cantidad FROM productos WHERE producto_id = p_producto_id;
$$ LANGUAGE sql;

CREATE OR REPLACE FUNCTION resumen_pedido(p_pedido_id INT)
RETURNS TEXT AS $$
DECLARE
    v_cliente VARCHAR; v_items BIGINT; v_total NUMERIC;
BEGIN
    SELECT c.nombre, COUNT(ip.item_id), p.total
    INTO v_cliente, v_items, v_total
    FROM pedidos p
    INNER JOIN clientes     c  ON c.cliente_id = p.cliente_id
    LEFT  JOIN items_pedido ip ON ip.pedido_id = p.pedido_id
    WHERE p.pedido_id = p_pedido_id
    GROUP BY c.nombre, p.total;
    RETURN 'Cliente: ' || v_cliente || ' | Items: ' || v_items || ' | Total: $' || v_total;
END;
$$ LANGUAGE plpgsql;
```

---

## Ejercicio 10 — Procedimientos

```sql
-- 10.1 actualizar_estado_pedido (ver 10_procedures.sql)

-- 10.2 RETURNS TABLE
CREATE OR REPLACE FUNCTION pedidos_activos_cliente(p_cliente_id INT)
RETURNS TABLE(pedido_id INT, fecha TIMESTAMP, total NUMERIC, estado VARCHAR, items BIGINT) AS $$
    SELECT p.pedido_id, p.fecha_pedido, p.total, p.estado, COUNT(ip.item_id)
    FROM pedidos p
    LEFT JOIN items_pedido ip ON ip.pedido_id = p.pedido_id
    WHERE p.cliente_id = p_cliente_id
      AND p.estado NOT IN ('cancelado', 'entregado')
    GROUP BY p.pedido_id, p.fecha_pedido, p.total, p.estado
    ORDER BY p.fecha_pedido DESC;
$$ LANGUAGE sql;

-- Desafío: cancelar_pedido
CREATE OR REPLACE PROCEDURE cancelar_pedido(p_pedido_id INT)
LANGUAGE plpgsql AS $$
DECLARE r RECORD;
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pedidos WHERE pedido_id = p_pedido_id) THEN
        RAISE EXCEPTION 'Pedido % no encontrado', p_pedido_id;
    END IF;
    IF EXISTS (SELECT 1 FROM pedidos WHERE pedido_id = p_pedido_id AND estado = 'entregado') THEN
        RAISE EXCEPTION 'No se puede cancelar un pedido ya entregado';
    END IF;
    -- Restaurar stock
    FOR r IN SELECT producto_id, cantidad FROM items_pedido WHERE pedido_id = p_pedido_id LOOP
        UPDATE productos SET stock = stock + r.cantidad WHERE producto_id = r.producto_id;
        RAISE NOTICE 'Stock restaurado: producto % + %', r.producto_id, r.cantidad;
    END LOOP;
    UPDATE pedidos SET estado = 'cancelado' WHERE pedido_id = p_pedido_id;
    RAISE NOTICE 'Pedido % cancelado.', p_pedido_id;
END;
$$;
```

---

## Ejercicio 11 — Triggers

```sql
-- Ver 11_triggers.sql para implementación completa.

-- Desafío 1: AFTER DELETE en items_pedido
CREATE OR REPLACE FUNCTION fn_restaurar_stock()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE productos SET stock = stock + OLD.cantidad WHERE producto_id = OLD.producto_id;
    UPDATE pedidos SET total = (
        SELECT COALESCE(SUM(subtotal), 0) FROM items_pedido WHERE pedido_id = OLD.pedido_id
    ) WHERE pedido_id = OLD.pedido_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_restaurar_stock
AFTER DELETE ON items_pedido
FOR EACH ROW EXECUTE FUNCTION fn_restaurar_stock();

-- Desafío 2: BEFORE UPDATE — precio no puede bajar más del 50%
CREATE OR REPLACE FUNCTION fn_validar_precio()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.precio < OLD.precio * 0.5 THEN
        RAISE EXCEPTION
            'No se puede reducir el precio más del 50%%. Actual: %, Nuevo: %',
            OLD.precio, NEW.precio;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_precio
BEFORE UPDATE ON productos
FOR EACH ROW EXECUTE FUNCTION fn_validar_precio();

-- Prueba:
-- UPDATE productos SET precio = 1 WHERE producto_id = 1;  -- debe fallar
-- UPDATE productos SET precio = precio * 0.6 WHERE producto_id = 1;  -- debe pasar
```

---

## Ejercicio 12 — Transacciones

```sql
-- 12.1 BEGIN / COMMIT
BEGIN;
INSERT INTO clientes (nombre, email) VALUES ('TX Test', 'tx@test.com') RETURNING cliente_id;
-- Usar el cliente_id devuelto:
INSERT INTO pedidos (cliente_id, total, estado) VALUES (<<cliente_id>>, 0, 'pendiente');
COMMIT;

-- 12.2 ROLLBACK
BEGIN;
UPDATE productos SET precio = precio * 0.01 WHERE activo = true;
SELECT ROUND(AVG(precio)::NUMERIC, 4) FROM productos;  -- precio muy bajo dentro de la transacción
ROLLBACK;
SELECT ROUND(AVG(precio)::NUMERIC, 2) FROM productos;  -- precios originales

-- 12.3 SAVEPOINT
-- Nota: en psql/pgcli un error SQL aborta la transacción, por eso
-- usamos DO $$ para capturar la excepción y ejecutar ROLLBACK TO SAVEPOINT.
BEGIN;
INSERT INTO categorias (nombre) VALUES ('TestTX');
SAVEPOINT sp1;
DO $$
BEGIN
    INSERT INTO categorias (nombre) VALUES ('TestTX');  -- falla por UNIQUE
EXCEPTION
    WHEN unique_violation THEN
        RAISE NOTICE 'Duplicado capturado, hacemos ROLLBACK TO SAVEPOINT';
END;
$$;
ROLLBACK TO SAVEPOINT sp1;                          -- vuelve al punto seguro
-- 'TestTX' aún existe desde antes del savepoint
SELECT * FROM categorias WHERE nombre = 'TestTX';
COMMIT;
DELETE FROM categorias WHERE nombre = 'TestTX';
-- Resultado: una sola fila 'TestTX' fue guardada y luego limpiada

-- 12.4 Error dentro de transacción
BEGIN;
SELECT 1/0;        -- ERROR: division by zero — transacción abortada
SELECT 1;          -- ERROR: current transaction is aborted
ROLLBACK;          -- único comando válido ahora

-- 12.5 Respuesta: READ COMMITTED
-- Terminal B ve el precio ORIGINAL antes del COMMIT de A.
-- PostgreSQL usa READ COMMITTED por defecto: cada statement ve solo
-- datos confirmados al momento en que ese statement comenzó.

-- 12.6 Respuestas de discusión
-- 1. Un error de aplicación no revierte la BD por sí solo; si estás
--    en el medio de una transacción sin BEGIN explícito, cada statement
--    es su propia transacción (autocommit). Con BEGIN explícito, el error
--    aborta el bloque y requiere ROLLBACK.
-- 2. CALL dentro de una sesión sin BEGIN explícito corre en autocommit;
--    dentro de un BEGIN el procedimiento hereda la transacción del llamador.
-- 3. SAVEPOINT es útil en loops o importaciones masivas donde quieres
--    continuar después de un error en una fila sin abortar todo el lote.

-- Desafío 1: cliente + dirección + pedido + ítems atómicos
BEGIN;

INSERT INTO clientes (nombre, email)
VALUES ('Demo TX', 'demo.tx@email.com');

INSERT INTO direcciones (cliente_id, calle, ciudad, es_principal)
VALUES (
    (SELECT cliente_id FROM clientes WHERE email = 'demo.tx@email.com'),
    'Av. Principal 1', 'CDMX', true
);

INSERT INTO pedidos (cliente_id, total, estado)
VALUES (
    (SELECT cliente_id FROM clientes WHERE email = 'demo.tx@email.com'),
    0, 'pendiente'
);

INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (
    (SELECT pedido_id FROM pedidos
     WHERE cliente_id = (SELECT cliente_id FROM clientes WHERE email = 'demo.tx@email.com')
     ORDER BY fecha_pedido DESC LIMIT 1),
    1, 2,
    (SELECT precio FROM productos WHERE producto_id = 1)
);

COMMIT;

-- Desafío 2: 3 ítems con SAVEPOINT, rollback del 3ro si falla
BEGIN;

INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (1, 1, 1, (SELECT precio FROM productos WHERE producto_id = 1));
SAVEPOINT sp_item1;

INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (1, 2, 1, (SELECT precio FROM productos WHERE producto_id = 2));
SAVEPOINT sp_item2;

-- Intento con stock excesivo (puede fallar si el trigger de stock está activo)
-- INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
-- VALUES (1, 3, 999999, 100);
-- ROLLBACK TO SAVEPOINT sp_item2;  -- solo deshace el 3er ítem

COMMIT;  -- guarda ítems 1 y 2
```
