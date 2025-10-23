-- ✅ NORMALIZED SCHEMA (3NF)
-- This is the solution after normalization

-- Drop old tables if they exist (except pedidos_completos for migration)
DROP TABLE IF EXISTS items_pedido CASCADE;
DROP TABLE IF EXISTS pedidos CASCADE;
DROP TABLE IF EXISTS productos CASCADE;
DROP TABLE IF EXISTS direcciones CASCADE;
DROP TABLE IF EXISTS categorias CASCADE;
DROP TABLE IF EXISTS clientes CASCADE;

-- 1. Clientes (Customer information - no repetition!)
CREATE TABLE clientes (
    cliente_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 2. Direcciones (One customer can have multiple addresses)
CREATE TABLE direcciones (
    direccion_id SERIAL PRIMARY KEY,
    cliente_id INT NOT NULL REFERENCES clientes(cliente_id) ON DELETE CASCADE,
    calle TEXT NOT NULL,
    ciudad VARCHAR(50) NOT NULL,
    codigo_postal VARCHAR(10),
    es_principal BOOLEAN DEFAULT false,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 3. Categorias (Categories normalized out)
CREATE TABLE categorias (
    categoria_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL,
    descripcion TEXT
);

-- 4. Productos (Products without denormalized category name)
CREATE TABLE productos (
    producto_id SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) NOT NULL CHECK (precio > 0),
    stock INT DEFAULT 0 CHECK (stock >= 0),
    categoria_id INT REFERENCES categorias(categoria_id),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    activo BOOLEAN DEFAULT true
);

-- 5. Pedidos (Orders)
CREATE TABLE pedidos (
    pedido_id SERIAL PRIMARY KEY,
    cliente_id INT NOT NULL REFERENCES clientes(cliente_id),
    direccion_entrega_id INT REFERENCES direcciones(direccion_id),
    fecha_pedido TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    total DECIMAL(10,2) NOT NULL CHECK (total >= 0),
    estado VARCHAR(20) DEFAULT 'pendiente'
        CHECK (estado IN ('pendiente', 'procesando', 'enviado', 'entregado', 'cancelado'))
);

-- 6. Items de Pedido (Order items - the many-to-many relationship)
CREATE TABLE items_pedido (
    item_id SERIAL PRIMARY KEY,
    pedido_id INT NOT NULL REFERENCES pedidos(pedido_id) ON DELETE CASCADE,
    producto_id INT NOT NULL REFERENCES productos(producto_id),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);

-- Create indexes on foreign keys for better JOIN performance
CREATE INDEX idx_direcciones_cliente ON direcciones(cliente_id);
CREATE INDEX idx_productos_categoria ON productos(categoria_id);
CREATE INDEX idx_pedidos_cliente ON pedidos(cliente_id);
CREATE INDEX idx_items_pedido ON items_pedido(pedido_id);
CREATE INDEX idx_items_producto ON items_pedido(producto_id);

\echo '✅ Normalized schema created!'
\echo ''
\echo 'Tables created:'
\echo '  - clientes'
\echo '  - direcciones'
\echo '  - categorias'
\echo '  - productos'
\echo '  - pedidos'
\echo '  - items_pedido'
