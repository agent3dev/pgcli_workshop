-- Test seed data for running exercise files locally
-- Enough data to make JOINs, aggregations and triggers meaningful

-- Extensions
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS btree_gin;

-- Categorias
INSERT INTO categorias (nombre, descripcion) VALUES
('Laptops',        'Computadoras portátiles'),
('Periféricos',    'Teclados, ratones y accesorios'),
('Monitores',      'Pantallas y displays'),
('Almacenamiento', 'SSDs, HDDs y memorias USB'),
('Redes',          'Routers, switches y cables');

-- Productos
INSERT INTO productos (nombre, descripcion, precio, stock, categoria_id, activo) VALUES
('Laptop Pro 15',       'Intel i7, 16GB RAM, 512GB SSD',    1299.99, 45, 1, true),
('Laptop Air 13',       'AMD Ryzen 5, 8GB RAM, 256GB SSD',   799.99, 60, 1, true),
('Laptop Gaming X',     'Intel i9, 32GB RAM, RTX 4070',     2199.99, 20, 1, true),
('Teclado Mecánico RGB','Switches Blue, retroiluminación',     89.99,150, 2, true),
('Mouse Inalámbrico',   '12000 DPI, 3 años batería',          49.99,200, 2, true),
('Mousepad XL',         'Base de tela 90x40cm',               19.99,300, 2, true),
('Monitor 4K 27"',      'IPS, 144Hz, HDR400',                449.99, 30, 3, true),
('Monitor Curvo 32"',   'VA, 165Hz, 1ms',                    329.99, 25, 3, true),
('SSD NVMe 1TB',        'PCIe 4.0, 7000MB/s lectura',        119.99,100, 4, true),
('SSD Portable 2TB',    'USB-C, 1050MB/s',                    89.99, 80, 4, true),
('USB 128GB',           'USB 3.2, lectura 400MB/s',           12.99,500, 4, true),
('Router WiFi 6',       'AX6000, cobertura 300m²',           199.99, 40, 5, true),
('Switch 8 puertos',    'Gigabit no administrable',            35.99, 60, 5, true),
('Laptop Básica',       'Celeron, 4GB, 64GB eMMC',           299.99,  0, 1, false),
('Webcam HD',           '1080p, micrófono integrado',         39.99,  0, 2, false);

-- Clientes
INSERT INTO clientes (nombre, email, telefono) VALUES
('María González',  'maria.gonzalez@email.com',  '+52-55-1234-5678'),
('Juan Martínez',   'juan.martinez@email.com',   '+52-55-2345-6789'),
('Ana Rodríguez',   'ana.rodriguez@email.com',   '+52-55-3456-7890'),
('Carlos López',    'carlos.lopez@email.com',    '+52-55-4567-8901'),
('Laura Sánchez',   'laura.sanchez@email.com',   '+52-55-5678-9012'),
('Pedro Ramírez',   'pedro.ramirez@email.com',   '+52-55-6789-0123'),
('Sofía Torres',    'sofia.torres@email.com',    '+52-55-7890-1234'),
('Diego Flores',    'diego.flores@email.com',    '+52-55-8901-2345'),
('Valentina Cruz',  'valentina.cruz@email.com',  '+52-55-9012-3456'),
('Andrés Morales',  'andres.morales@email.com',  '+52-55-0123-4567');

-- Direcciones
INSERT INTO direcciones (cliente_id, calle, ciudad, codigo_postal, es_principal) VALUES
(1, 'Av. Insurgentes 100',   'CDMX',          '06600', true),
(1, 'Calle Reforma 25',      'CDMX',          '06700', false),
(2, 'Blvd. Kukulcán 200',    'Cancún',        '77500', true),
(3, 'Av. Chapultepec 300',   'Guadalajara',   '44600', true),
(4, 'Calle Morelos 50',      'Monterrey',     '64000', true),
(5, 'Paseo de la Reforma 1', 'CDMX',          '06600', true),
(6, 'Av. Universidad 500',   'CDMX',          '04510', true),
(7, 'Blvd. Agua Caliente 10','Tijuana',       '22420', true),
(8, 'Calle 5 de Mayo 75',    'Puebla',        '72000', true),
(9, 'Av. Constitución 250',  'Monterrey',     '64010', true);
-- Cliente 10 (Andrés) no tiene dirección — para demostrar LEFT JOIN

-- Pedidos
INSERT INTO pedidos (cliente_id, direccion_entrega_id, total, estado) VALUES
(1, 1, 0, 'entregado'),   -- pedido 1: María
(1, 1, 0, 'enviado'),     -- pedido 2: María
(2, 3, 0, 'entregado'),   -- pedido 3: Juan
(3, 4, 0, 'procesando'),  -- pedido 4: Ana
(4, 5, 0, 'pendiente'),   -- pedido 5: Carlos
(5, 6, 0, 'entregado'),   -- pedido 6: Laura
(5, 6, 0, 'cancelado'),   -- pedido 7: Laura (cancelado)
(6, 7, 0, 'enviado'),     -- pedido 8: Pedro
(7, 8, 0, 'entregado'),   -- pedido 9: Sofía
(1, 2, 0, 'pendiente');   -- pedido 10: María (segunda dirección)
-- Clientes 8 (Diego), 9 (Valentina) y 10 (Andrés) sin pedidos

-- Items de pedido (subtotal es GENERATED — no incluir)
INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES
-- Pedido 1: María — laptop + teclado + mouse
(1, 1,  1, 1299.99),
(1, 4,  1,   89.99),
(1, 5,  1,   49.99),
-- Pedido 2: María — monitor + SSD
(2, 7,  1,  449.99),
(2, 9,  2,  119.99),
-- Pedido 3: Juan — laptop gaming
(3, 3,  1, 2199.99),
(3, 4,  1,   89.99),
-- Pedido 4: Ana — monitor + mousepad + SSD portable
(4, 8,  1,  329.99),
(4, 6,  2,   19.99),
(4, 10, 1,   89.99),
-- Pedido 5: Carlos — router + switch
(5, 12, 1,  199.99),
(5, 13, 2,   35.99),
-- Pedido 6: Laura — laptop + mouse
(6, 2,  1,  799.99),
(6, 5,  1,   49.99),
-- Pedido 7: cancelado — no items
-- Pedido 8: Pedro — SSD + USB
(8, 9,  1,  119.99),
(8, 11, 3,   12.99),
-- Pedido 9: Sofía — teclado + mouse + mousepad
(9, 4,  1,   89.99),
(9, 5,  1,   49.99),
(9, 6,  1,   19.99),
-- Pedido 10: María — SSD NVMe
(10,9,  1,  119.99);

-- Recalcular totales de pedidos
UPDATE pedidos p
SET total = (
    SELECT COALESCE(SUM(subtotal), 0)
    FROM items_pedido ip
    WHERE ip.pedido_id = p.pedido_id
);
