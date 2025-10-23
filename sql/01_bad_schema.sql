-- ❌ HORRIBLE DENORMALIZED SCHEMA
-- This is intentionally bad for the workshop!

-- Denormalized orders table with TONS of redundancy
CREATE TABLE pedidos_completos (
    pedido_id SERIAL PRIMARY KEY,

    -- Customer info (REPEATED for every order!)
    cliente_nombre VARCHAR(100),
    cliente_email VARCHAR(100),
    cliente_telefono VARCHAR(20),
    cliente_direccion TEXT,
    cliente_ciudad VARCHAR(50),
    cliente_codigo_postal VARCHAR(10),

    -- Product 1
    producto1_nombre VARCHAR(200),
    producto1_descripcion TEXT,
    producto1_precio DECIMAL(10,2),
    producto1_cantidad INT,

    -- Product 2 (what if they order 3+ products?!)
    producto2_nombre VARCHAR(200),
    producto2_descripcion TEXT,
    producto2_precio DECIMAL(10,2),
    producto2_cantidad INT,

    -- Product 3
    producto3_nombre VARCHAR(200),
    producto3_descripcion TEXT,
    producto3_precio DECIMAL(10,2),
    producto3_cantidad INT,

    -- Order info
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10,2),
    estado VARCHAR(20)
);

-- Also create a products table for queries (still denormalized)
CREATE TABLE productos (
    producto_id SERIAL PRIMARY KEY,
    nombre VARCHAR(200),
    descripcion TEXT,
    precio DECIMAL(10,2),
    stock INT DEFAULT 0,
    categoria_id INT,
    categoria_nombre VARCHAR(100),  -- DENORMALIZED!
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT true
);

-- And an orders table (will be used after normalization)
CREATE TABLE pedidos (
    pedido_id SERIAL PRIMARY KEY,
    cliente_id INT,  -- Will be foreign key later
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10,2),
    estado VARCHAR(20) DEFAULT 'pendiente'
);

\echo 'Bad schema created! Ready for workshop.'
