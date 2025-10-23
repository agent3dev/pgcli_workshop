# Soluciones del Workshop

Respuestas completas a todos los ejercicios.

---

## ✅ Ejercicio 1: Análisis del Esquema Malo

### Respuestas a Preguntas 1.1

**1. ¿Qué datos se repiten en cada fila?**
- Nombre del cliente
- Email del cliente
- Teléfono del cliente
- Dirección completa del cliente
- Información de categoría (en tabla productos)

**2. ¿Qué pasa si un cliente cambia su email?**
- Debes actualizar TODAS las filas de pedidos de ese cliente
- Riesgo de inconsistencia si no actualizas todas
- Operación muy costosa

**3. ¿Qué pasa si un pedido tiene 5 productos?**
- ¡No se puede! El esquema solo soporta 3 productos máximo
- Necesitarías agregar producto4_nombre, producto4_precio, etc.
- Esquema inflexible

### Solución 1.2: Redundancia

```sql
-- Resultado típico:
-- clientes_unicos: ~5,000
-- total_filas: 50,000
-- filas_redundantes: 45,000

-- Es decir, 90% de redundancia!
```

### Solución 1.3: Anomalías

**Anomalía de Inserción**:
```sql
-- NO puedes insertar un cliente sin pedido
-- porque producto1_nombre, producto1_precio son requeridos
```

**Anomalía de Actualización**:
```sql
UPDATE pedidos_completos
SET cliente_email = 'nuevo@email.com'
WHERE cliente_email = 'viejo@email.com';
-- Actualiza múltiples filas (tantas como pedidos tenga)
```

**Anomalía de Eliminación**:
```sql
-- Si eliminas todos los pedidos, pierdes los datos del cliente
-- No hay registro independiente del cliente
```

---

## ✅ Ejercicio 2: Normalización

### Solución 2.1: Tabla clientes

```sql
CREATE TABLE clientes (
    cliente_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    telefono VARCHAR(20),
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Solución 2.2: Migración verificada

```sql
-- Resultado esperado: ~5,000 clientes únicos
-- vs 50,000 filas en pedidos_completos
```

### Solución 2.3: Tabla productos

```sql
CREATE TABLE categorias (
    categoria_id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) UNIQUE NOT NULL
);

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
```

### Solución 2.4: Items de pedido

```sql
CREATE TABLE items_pedido (
    item_id SERIAL PRIMARY KEY,
    pedido_id INT NOT NULL REFERENCES pedidos(pedido_id) ON DELETE CASCADE,
    producto_id INT NOT NULL REFERENCES productos(producto_id),
    cantidad INT NOT NULL CHECK (cantidad > 0),
    precio_unitario DECIMAL(10,2) NOT NULL CHECK (precio_unitario >= 0),
    subtotal DECIMAL(10,2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED
);
```

### Solución 2.5: Checklist 3FN

- [x] Cada tabla tiene clave primaria
- [x] No hay grupos repetitivos (productos ahora en tabla separada)
- [x] Dependencia de clave completa (precio_unitario depende de item, no solo pedido)
- [x] Sin dependencias transitivas (categoria_nombre eliminado de productos)

---

## ✅ Ejercicio 3: Diagnóstico de Performance

### Solución 3.1 y 3.2: Análisis EXPLAIN

```sql
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE descripcion LIKE '%laptop%';

-- Resultado típico SIN índice:
-- Seq Scan on productos (cost=0.00..2500.00 rows=100 width=200)
--   (actual time=0.123..45.678 rows=850 loops=1)
-- Planning Time: 0.123 ms
-- Execution Time: 45.901 ms
```

**Respuestas**:
1. **Tipo de scan**: Seq Scan (secuencial, lee toda la tabla)
2. **Costo**: ~2500 unidades
3. **Filas**: Examinó 100,000, devolvió ~850

### Solución 3.3: Tabla completa

| Query | Tipo Scan | Costo | Tiempo (ms) | Filas |
|-------|-----------|-------|-------------|-------|
| Texto | Seq Scan | 2500 | 45 | 850/100000 |
| Precio | Seq Scan | 2200 | 38 | 5000/100000 |
| Fecha | Seq Scan | 1800 | 32 | 2000/50000 |

---

## ✅ Ejercicio 4: Crear Índices

### Solución 4.1: Índice B-Tree

```sql
CREATE INDEX idx_productos_precio ON productos(precio);

-- Resultado CON índice:
-- Index Scan using idx_productos_precio (cost=0.42..125.50)
--   (actual time=0.015..2.123 rows=5000 loops=1)
-- Execution Time: 2.245 ms
```

**Mejora**: 38ms → 2.2ms = **17x más rápido**

### Solución 4.2: Índice GIN

```sql
CREATE INDEX idx_productos_busqueda ON productos
USING GIN(to_tsvector('spanish', nombre || ' ' || descripcion));

-- Query optimizada:
EXPLAIN ANALYZE
SELECT * FROM productos
WHERE to_tsvector('spanish', nombre || ' ' || descripcion)
      @@ to_tsquery('spanish', 'laptop');

-- Resultado:
-- Bitmap Heap Scan (cost=12.50..215.75)
--   Recheck Cond: ...
--   -> Bitmap Index Scan on idx_productos_busqueda (cost=0.00..12.28)
-- Execution Time: 0.892 ms
```

**Mejora**: 45ms → 0.9ms = **50x más rápido**

### Solución 4.3: Índice compuesto

**Respuesta**: **Opción B (índice compuesto) es mejor**

**¿Por qué?**
- PostgreSQL puede usar el índice compuesto para filtrar Y ordenar
- Con índices separados, debe filtrar con uno y luego ordenar en memoria
- El índice compuesto (categoria_id, precio) está ordenado por precio dentro de cada categoría

```sql
-- Con índice compuesto:
-- Index Scan using idx_categoria_precio (cost=0.42..45.50)
--   Index Cond: (categoria_id = 1)

-- vs índices separados:
-- Index Scan using idx_categoria (cost=0.42..125.50)
--   Filter: (categoria_id = 1)
-- Sort (cost=80.00..85.00)
```

### Solución 4.4: Índice parcial

**¿Por qué la segunda query no usa el índice?**

Porque el índice parcial solo incluye filas donde `activo = true AND stock > 0`.

La segunda query no tiene esas condiciones en el WHERE, por lo que PostgreSQL no puede usar el índice parcial.

---

## ✅ Ejercicio 5: Comparación de Tipos de Índices

| Tipo Índice | Mejor Para | Ejemplo Query | Ventaja | Desventaja |
|-------------|------------|---------------|---------|------------|
| B-Tree | Rangos, ordenamiento, igualdad | `precio BETWEEN 100 AND 500` | Versátil, soporta <, >, =, ORDER BY | Más grande que Hash |
| Hash | Solo igualdad exacta | `id = 123` | Muy rápido para = | No soporta rangos ni ORDER BY |
| GIN | Texto completo, arrays, JSONB | `text @@ 'palabra'` | Búsquedas complejas rápidas | Lento en INSERT/UPDATE, grande |
| Partial | Subset de datos frecuente | `WHERE activo = true` | Pequeño, rápido para subset | Solo funciona con condiciones específicas |

---

## ✅ Ejercicio 6: Trade-offs de Índices

### Solución 6.1: Tamaños típicos

```
Total tabla:    ~450 MB
Total índices:  ~180 MB
Ratio:          40% del tamaño de la tabla
```

### Solución 6.2: Impacto en INSERT

```
Sin índices:    1000 filas en 0.123 segundos
Con 5 índices:  1000 filas en 0.487 segundos
Overhead:       ~300% más lento
```

**Lección**: Más índices = INSERT más lento. Solo crea índices que realmente uses.

---

## 🎯 Desafíos Bonus - Soluciones

### Desafío 1: Índice Mal Diseñado

**Problema**:
```sql
CREATE INDEX idx_malo ON productos(UPPER(nombre));

-- Esta query NO lo usará:
SELECT * FROM productos WHERE nombre = 'laptop';
```

**¿Por qué?**
- El índice está en `UPPER(nombre)`, pero la query busca `nombre` sin UPPER()
- PostgreSQL no puede usar el índice porque las expresiones no coinciden

**Solución**:
```sql
-- Opción 1: Índice funcional + query que lo use
CREATE INDEX idx_nombre_upper ON productos(UPPER(nombre));
SELECT * FROM productos WHERE UPPER(nombre) = UPPER('laptop');

-- Opción 2: Índice con pg_trgm para case-insensitive
CREATE INDEX idx_nombre_trgm ON productos USING GIN(nombre gin_trgm_ops);
SELECT * FROM productos WHERE nombre ILIKE '%laptop%';

-- Opción 3: Usar full-text search
CREATE INDEX idx_nombre_fts ON productos
USING GIN(to_tsvector('spanish', nombre));
SELECT * FROM productos
WHERE to_tsvector('spanish', nombre) @@ to_tsquery('spanish', 'laptop');
```

### Desafío 2: Índice Innecesario

```sql
CREATE INDEX idx_innecesario ON productos(producto_id);
```

**Respuesta**: ¡NO lo necesitas!

**¿Por qué?**
- `producto_id` ya es PRIMARY KEY
- Las claves primarias automáticamente tienen un índice B-Tree
- Crear otro índice duplica trabajo y espacio

Verifica:
```sql
\d productos
-- Verás: "productos_pkey" PRIMARY KEY, btree (producto_id)
```

### Desafío 3: Optimización Extrema

**Índices necesarios**:

```sql
-- 1. Índice en fecha de pedido (filtro WHERE)
CREATE INDEX idx_pedidos_fecha ON pedidos(fecha_pedido DESC);

-- 2. Índice en foreign keys (para JOINs)
CREATE INDEX idx_items_pedido ON items_pedido(pedido_id);
CREATE INDEX idx_items_producto ON items_pedido(producto_id);

-- 3. Índice compuesto para GROUP BY
CREATE INDEX idx_productos_ventas ON productos(producto_id, nombre);

-- 4. OPCIONAL: Vista materializada si la query se ejecuta frecuentemente
CREATE MATERIALIZED VIEW ventas_ultimos_30_dias AS
SELECT
    p.nombre,
    COUNT(*) as num_ventas,
    SUM(ip.cantidad) as total_unidades
FROM productos p
LEFT JOIN items_pedido ip ON p.producto_id = ip.producto_id
LEFT JOIN pedidos ped ON ip.pedido_id = ped.pedido_id
WHERE ped.fecha_pedido > CURRENT_DATE - INTERVAL '30 days'
GROUP BY p.producto_id, p.nombre
HAVING COUNT(*) > 10;

-- Refrescar la vista diariamente
REFRESH MATERIALIZED VIEW ventas_ultimos_30_dias;

-- Query súper rápida:
SELECT * FROM ventas_ultimos_30_dias ORDER BY num_ventas DESC;
```

**Mejora esperada**:
- Sin índices: ~2000-5000ms
- Con índices: ~50-150ms (**40x más rápido**)
- Con vista materializada: ~5-10ms (**400x más rápido**)

---

## 📊 Resumen de Mejoras

### Performance Típica

| Optimización | Mejora |
|-------------|--------|
| B-Tree en precio | 15-20x |
| GIN en texto | 50-100x |
| Índice compuesto | 10-30x |
| Índice parcial | 5-15x |
| Vista materializada | 100-500x |

### Tamaño y Overhead

| Métrica | Valor Típico |
|---------|--------------|
| Tamaño índices vs tabla | 30-50% |
| Overhead en INSERT | 200-400% |
| Overhead en UPDATE | 100-300% |
| Overhead en SELECT | -90% a -99% (¡mejora!) |

---

## 🎓 Conceptos Clave Aprendidos

1. **Normalización elimina redundancia** pero requiere JOINs
2. **Índices aceleran SELECTs** pero ralentizan INSERT/UPDATE
3. **EXPLAIN es tu mejor amigo** para diagnóstico
4. **GIN es poderoso para texto** pero costoso en espacio
5. **Índices parciales son eficientes** para subsets frecuentes
6. **No todos los índices se usan** - verifica con pg_stat_user_indexes
7. **Trade-off siempre**: Espacio vs Velocidad vs Mantenimiento

---

## ✅ Checklist Final - Verificación

- [x] Entiendo los 3 tipos de anomalías
- [x] Sé normalizar hasta 3FN
- [x] Puedo leer EXPLAIN y entender Seq Scan vs Index Scan
- [x] Conozco 4+ tipos de índices y cuándo usarlos
- [x] Entiendo que más índices = SELECT rápido pero INSERT lento
- [x] Sé medir mejoras de rendimiento con \timing
- [x] Puedo decidir qué índices crear basándome en queries reales

---

**¡Felicitaciones! Has completado el workshop.** 🎉

Ahora sabes:
- Diseñar bases de datos normalizadas
- Diagnosticar problemas de rendimiento
- Optimizar queries con índices apropiados
- Medir y validar mejoras

**Siguiente paso**: Aplica esto en tus proyectos reales. 🚀
