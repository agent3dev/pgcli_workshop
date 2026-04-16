-- ══════════════════════════════════════════════════════════════
-- 05_ddl.sql — DDL (Data Definition Language)
-- Temas: ALTER TABLE, ADD/DROP COLUMN, constraints, CREATE TABLE
-- ══════════════════════════════════════════════════════════════

\echo '══════════════════════════════════════════'
\echo 'EJERCICIO 5 — DDL'
\echo '══════════════════════════════════════════'

-- ── 5.1  Inspeccionar la estructura de una tabla ──────────────

\d clientes
\d productos
\d pedidos

-- ── 5.2  Agregar una columna ──────────────────────────────────
-- Los productos ahora pueden tener un porcentaje de descuento

ALTER TABLE productos
    ADD COLUMN descuento NUMERIC(5,2) DEFAULT 0 CHECK (descuento >= 0 AND descuento <= 100);

\echo '✅ Columna descuento agregada a productos'

SELECT nombre, precio, descuento FROM productos LIMIT 5;

-- ── 5.3  Agregar columna a otra tabla ─────────────────────────

ALTER TABLE pedidos
    ADD COLUMN notas TEXT;

-- ── 5.4  Modificar el tipo de una columna ─────────────────────

ALTER TABLE clientes
    ALTER COLUMN telefono TYPE VARCHAR(30);

-- ── 5.5  Agregar un constraint UNIQUE ─────────────────────────
-- Asegurar que no haya dos productos con el mismo nombre

ALTER TABLE productos
    ADD CONSTRAINT uq_producto_nombre UNIQUE (nombre);

-- ── 5.6  Crear una tabla nueva ────────────────────────────────
-- Tabla para reseñas de productos

CREATE TABLE resenas (
    resena_id    SERIAL PRIMARY KEY,
    producto_id  INT NOT NULL REFERENCES productos(producto_id) ON DELETE CASCADE,
    cliente_id   INT NOT NULL REFERENCES clientes(cliente_id)  ON DELETE CASCADE,
    puntuacion   INT NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
    comentario   TEXT,
    fecha        TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (producto_id, cliente_id)   -- un cliente solo puede reseñar un producto una vez
);

\echo '✅ Tabla resenas creada'

-- ── 5.7  Eliminar una columna ─────────────────────────────────

ALTER TABLE productos DROP COLUMN descuento;

-- ── 5.8  Eliminar un constraint ───────────────────────────────

ALTER TABLE productos DROP CONSTRAINT uq_producto_nombre;

-- ── 5.9  Eliminar una tabla ───────────────────────────────────

DROP TABLE IF EXISTS resenas;

\echo ''
\echo '══════════════════════════════════════════'
\echo 'DESAFÍO:'
\echo '  1. Agrega columna imagen_url VARCHAR(500) a productos.'
\echo '  2. Agrega FK nullable launch_site_id a pedidos'
\echo '     referenciando una tabla que tú crees: cupones(cupon_id).'
\echo '  3. Crea la tabla cupones con: cupon_id, codigo UNIQUE,'
\echo '     descuento_pct NUMERIC(5,2), activo BOOLEAN.'
\echo '══════════════════════════════════════════'
