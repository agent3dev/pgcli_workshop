# Ejercicios del Workshop
**Paso a paso con soluciones al final**

---

## 📋 Ejercicio 1: Análisis del Esquema Malo

**Objetivo**: Identificar problemas de normalización

### Paso 1.1: Explorar la tabla denormalizada

```sql
-- Ver estructura
\d pedidos_completos

-- Ver muestra de datos
SELECT * FROM pedidos_completos LIMIT 3;
```

**Preguntas**:
1. ¿Qué datos se repiten en cada fila?
2. ¿Qué pasa si un cliente cambia su email?
3. ¿Qué pasa si un pedido tiene 5 productos?

### Paso 1.2: Calcular redundancia

```sql
-- Contar clientes únicos vs filas totales
SELECT
    COUNT(DISTINCT cliente_email) as clientes_unicos,
    COUNT(*) as total_filas,
    COUNT(*) - COUNT(DISTINCT cliente_email) as filas_redundantes;

-- Ver clientes más repetidos
SELECT
    cliente_email,
    COUNT(*) as num_pedidos
FROM pedidos_completos
GROUP BY cliente_email
ORDER BY num_pedidos DESC
LIMIT 10;
```

**Preguntas**:
1. ¿Cuántas veces se repite la información de cada cliente?
2. ¿Cuánto espacio se desperdicia?

### Paso 1.3: Identificar anomalías

**Anomalía de Inserción**: Completa esta query
```sql
-- ¿Puedes insertar un cliente sin un pedido?
-- Intenta:
INSERT INTO pedidos_completos (cliente_nombre, cliente_email, ...)
VALUES ('Juan Pérez', 'juan@ejemplo.com', ...);
-- ¿Funciona? ¿Qué campos son obligatorios?
```

**Anomalía de Actualización**: Completa esta query
```sql
-- Si un cliente cambia de email, ¿cuántas filas debes actualizar?
UPDATE pedidos_completos
SET cliente_email = 'nuevo@email.com'
WHERE cliente_email = '???';
-- ¿Cuántas filas se actualizaron?
```

**Anomalía de Eliminación**:
```sql
-- Si eliminas todos los pedidos de un cliente, ¿pierdes su información?
DELETE FROM pedidos_completos WHERE cliente_email = '???';
-- ¿Qué pasó con los datos del cliente?
```

---

## 📋 Ejercicio 2: Normalización

**Objetivo**: Crear esquema en 3FN

### Paso 2.1: Diseñar tabla de clientes

```sql
-- Crear tabla clientes (completa los campos)
CREATE TABLE clientes (
    cliente_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    -- ¿Qué más campos necesitas?
    -- ...
);
```

<details>
<summary>💡 Pista</summary>

Incluye: email (único), telefono, fecha_registro

</details>

### Paso 2.2: Migrar datos de clientes

```sql
-- Extraer clientes únicos de la tabla mala
INSERT INTO clientes (nombre, email, telefono)
SELECT DISTINCT ON (cliente_email)
    cliente_nombre,
    cliente_email,
    cliente_telefono
FROM pedidos_completos
ORDER BY cliente_email;

-- Verificar
SELECT COUNT(*) FROM clientes;
```

### Paso 2.3: Crear tabla de productos

```sql
-- Diseña la tabla productos
-- Recuerda: SIN denormalización de categorías

CREATE TABLE productos (
    -- Completa aquí
);
```

<details>
<summary>💡 Pista</summary>

```sql
CREATE TABLE productos (
    producto_id SERIAL PRIMARY KEY,
    nombre VARCHAR(200) NOT NULL,
    descripcion TEXT,
    precio DECIMAL(10,2) CHECK (precio > 0),
    stock INT DEFAULT 0 CHECK (stock >= 0),
    categoria_id INT,
    activo BOOLEAN DEFAULT true
);
```

</details>

### Paso 2.4: Crear tabla de items de pedido

**¿Por qué necesitamos esta tabla?**

Porque un pedido puede tener múltiples productos, y un producto puede estar en múltiples pedidos (relación N:M).

```sql
CREATE TABLE items_pedido (
    -- Completa aquí
    -- Pista: necesitas pedido_id, producto_id, cantidad, precio_unitario
);
```

### Paso 2.5: Verificar normalización

**Checklist 3FN**:
- [ ] Cada tabla tiene clave primaria
- [ ] No hay grupos repetitivos (1FN)
- [ ] Todos los campos no clave dependen de la clave completa (2FN)
- [ ] No hay dependencias transitivas (3FN)

---

## 📋 Ejercicio 3: Diagnóstico de Performance

**Objetivo**: Usar EXPLAIN para encontrar problemas

### Paso 3.1: Medir query sin índice

```sql
\timing on

-- Query 1: Búsqueda de texto
SELECT * FROM productos
WHERE descripcion LIKE '%laptop%';

-- Anota el tiempo: __________ ms
```

### Paso 3.2: Analizar con EXPLAIN

```sql
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE descripcion LIKE '%laptop%';
```

**Preguntas**:
1. ¿Qué tipo de scan usa? (Seq Scan, Index Scan, etc.)
2. ¿Cuál es el costo estimado?
3. ¿Cuántas filas examinó vs cuántas devolvió?

### Paso 3.3: Más queries a analizar

```sql
-- Query 2: Rango de precio
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE precio BETWEEN 100 AND 500
ORDER BY precio;

-- Query 3: Fecha reciente
EXPLAIN ANALYZE
SELECT * FROM pedidos
WHERE fecha_pedido > CURRENT_DATE - INTERVAL '7 days'
ORDER BY fecha_pedido DESC;
```

Completa la tabla:

| Query | Tipo Scan | Costo | Tiempo (ms) | Filas |
|-------|-----------|-------|-------------|-------|
| Texto | ? | ? | ? | ? |
| Precio | ? | ? | ? | ? |
| Fecha | ? | ? | ? | ? |

---

## 📋 Ejercicio 4: Crear Índices

**Objetivo**: Optimizar queries con índices apropiados

### Paso 4.1: Índice B-Tree simple

```sql
-- Crear índice para búsquedas por precio
CREATE INDEX idx_productos_precio ON productos(precio);

-- Verificar que existe
\di

-- Probar query de nuevo
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE precio BETWEEN 100 AND 500;

-- ¿Usa el índice? ¿Cuánto mejoró?
```

**Antes**: _____ ms | **Después**: _____ ms | **Mejora**: _____x

### Paso 4.2: Índice GIN para texto

```sql
-- Crear índice GIN para búsqueda full-text
CREATE INDEX idx_productos_busqueda ON productos
USING GIN(to_tsvector('spanish', nombre || ' ' || descripcion));

-- IMPORTANTE: La query debe cambiar para usar el índice
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE to_tsvector('spanish', nombre || ' ' || descripcion)
      @@ to_tsquery('spanish', 'laptop');
```

**Antes**: _____ ms | **Después**: _____ ms | **Mejora**: _____x

### Paso 4.3: Índice compuesto

**Escenario**: Frecuentemente filtramos por categoría Y ordenamos por precio

```sql
-- ¿Cuál índice es mejor?

-- Opción A: Un índice en cada columna
CREATE INDEX idx_categoria ON productos(categoria_id);
CREATE INDEX idx_precio ON productos(precio);

-- Opción B: Índice compuesto
CREATE INDEX idx_categoria_precio ON productos(categoria_id, precio);

-- Prueba ambos con:
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE categoria_id = 1
ORDER BY precio
LIMIT 100;
```

**¿Cuál funciona mejor?** _____________

**¿Por qué?** _______________________

### Paso 4.4: Índice parcial

```sql
-- Solo indexar productos activos con stock
CREATE INDEX idx_productos_disponibles ON productos(precio)
WHERE activo = true AND stock > 0;

-- Esta query DEBE usar el índice
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE activo = true AND stock > 0 AND precio < 200;

-- Esta query NO usará el índice (¿por qué?)
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE precio < 200;
```

**¿Por qué la segunda query no usa el índice?**

_________________________________________________

---

## 📋 Ejercicio 5: Comparación de Tipos de Índices

**Objetivo**: Entender cuándo usar cada tipo

### Completa la tabla:

| Tipo Índice | Mejor Para | Ejemplo Query | Ventaja | Desventaja |
|-------------|------------|---------------|---------|------------|
| B-Tree | ? | ? | ? | ? |
| Hash | ? | ? | ? | ? |
| GIN | ? | ? | ? | ? |
| Partial | ? | ? | ? | ? |

---

## 📋 Ejercicio 6: Trade-offs de Índices

**Objetivo**: Comprender el costo de los índices

### Paso 6.1: Medir tamaño de índices

```sql
-- Ver tamaño de tabla
SELECT pg_size_pretty(pg_total_relation_size('productos'));

-- Ver tamaño de cada índice
SELECT
    indexname,
    pg_size_pretty(pg_relation_size(indexname::regclass)) as size
FROM pg_indexes
WHERE tablename = 'productos';
```

**Total tabla**: ______ | **Total índices**: ______ | **Ratio**: ______

### Paso 6.2: Impacto en INSERT

```sql
-- Crear función para medir tiempo de inserción
CREATE OR REPLACE FUNCTION benchmark_insert(num_rows INT) RETURNS VOID AS $$
DECLARE
    start_time TIMESTAMP;
    end_time TIMESTAMP;
BEGIN
    start_time := clock_timestamp();

    FOR i IN 1..num_rows LOOP
        INSERT INTO productos (nombre, descripcion, precio, stock, categoria_id)
        VALUES (
            'Producto Test ' || i,
            'Descripción de prueba',
            random() * 1000,
            floor(random() * 100),
            floor(random() * 8) + 1
        );
    END LOOP;

    end_time := clock_timestamp();
    RAISE NOTICE 'Insertados % filas en %', num_rows, (end_time - start_time);
END;
$$ LANGUAGE plpgsql;

-- Probar SIN índices
-- (primero elimina los índices en productos)
DROP INDEX IF EXISTS idx_productos_precio;
DROP INDEX IF EXISTS idx_productos_busqueda;
-- ...

SELECT benchmark_insert(1000);

-- Ahora CON índices
-- (crea los índices de nuevo)
-- ...

SELECT benchmark_insert(1000);
```

**Sin índices**: ______ | **Con índices**: ______ | **Overhead**: ______%

---

## 🎯 Desafíos Bonus

### Desafío 1: Índice Mal Diseñado

```sql
-- Este índice está MAL diseñado. ¿Por qué?
CREATE INDEX idx_malo ON productos(UPPER(nombre));

-- Esta query NO lo usará. ¿Por qué?
SELECT * FROM productos WHERE nombre = 'laptop';

-- ¿Cómo lo arreglarías?
```

### Desafío 2: Índice Innecesario

```sql
-- ¿Necesitas este índice?
CREATE INDEX idx_innecesario ON productos(producto_id);

-- ¿Por qué sí o por qué no?
```

### Desafío 3: Optimización Extrema

```sql
-- Esta query es SUPER lenta. Optimízala.
SELECT
    p.nombre,
    COUNT(*) as num_ventas,
    SUM(ip.cantidad) as total_unidades
FROM productos p
LEFT JOIN items_pedido ip ON p.producto_id = ip.producto_id
LEFT JOIN pedidos ped ON ip.pedido_id = ped.pedido_id
WHERE ped.fecha_pedido > CURRENT_DATE - INTERVAL '30 days'
GROUP BY p.producto_id, p.nombre
HAVING COUNT(*) > 10
ORDER BY num_ventas DESC;

-- ¿Qué índices crearías?
-- ¿Puedes usar una vista materializada?
```

---

## ✅ Checklist Final

Antes de terminar, verifica:

- [ ] Entiendo los problemas de denormalización
- [ ] Puedo diseñar esquema en 3FN
- [ ] Sé usar EXPLAIN para diagnosticar queries
- [ ] Puedo elegir el tipo de índice correcto
- [ ] Entiendo los trade-offs de índices
- [ ] Sé medir mejoras de rendimiento

---

**Revisa `SOLUTIONS.md` para ver las soluciones completas.**
