# Ejercicios — SQL Fundamentals
## Módulo 2: DDL, DML, JOINs, Vistas, Funciones, Procedimientos y Triggers

> **Prerequisito:** Completar el Módulo 1 (Normalización e Índices).  
> El esquema normalizado (`02_normalized_schema.sql`) debe estar cargado.  
> Ejecutar los scripts en orden: `05_ddl.sql` → `11_triggers.sql`

---

## Ejercicio 5 — DDL (Data Definition Language)

> Archivo: `sql/05_ddl.sql`

El DDL define la **estructura** de la base de datos.

### 5.1 Inspeccionar el esquema
Corre `\d productos` y responde:
- ¿Qué columnas tiene la tabla `productos`?
- ¿Cuáles tienen constraints CHECK?
- ¿Cuál es la columna que se calcula automáticamente en `items_pedido`?

### 5.2 Modificar tablas
1. Agrega una columna `descuento NUMERIC(5,2) DEFAULT 0` a `productos` con un CHECK que valide que esté entre 0 y 100.
2. Agrega una columna `notas TEXT` a `pedidos`.
3. Modifica `clientes.telefono` para que acepte hasta 30 caracteres.

### 5.3 Constraints
1. Agrega un constraint UNIQUE al nombre del producto.
2. Intenta insertar dos productos con el mismo nombre. ¿Qué ocurre?
3. Elimina el constraint.

### 5.4 Nueva tabla
Crea una tabla `resenas` con:
- `resena_id SERIAL PRIMARY KEY`
- `producto_id` FK a productos
- `cliente_id` FK a clientes
- `puntuacion INT` — solo valores del 1 al 5
- `comentario TEXT`
- `fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP`
- Constraint UNIQUE que impida que un cliente reseñe el mismo producto dos veces

**Desafío:** Crea una tabla `cupones` con `codigo UNIQUE`, `descuento_pct`, y `activo BOOLEAN`. Agrega una FK nullable `cupon_id` a `pedidos`.

---

## Ejercicio 6 — DML (Data Manipulation Language)

> Archivo: `sql/06_dml.sql`

### 6.1 INSERT
1. Inserta un nuevo cliente con nombre, email y teléfono.
2. Inserta 3 productos en una categoría existente con un solo INSERT de múltiples filas.
3. Usa `INSERT … RETURNING` para obtener el `cliente_id` generado.

### 6.2 UPDATE
1. Actualiza el precio de un producto.
2. Actualiza stock y activo en la misma sentencia.
3. Desactiva con un UPDATE todos los productos cuyo stock sea 0.

### 6.3 DELETE
1. Inserta una categoría de prueba y luego elimínala.
2. ¿Qué pasa si intentas eliminar una categoría que tiene productos asociados? Pruébalo.
3. Elimina los pedidos cancelados que no tengan items usando un subquery con `NOT EXISTS`.

### 6.4 Subqueries
Escribe una query que muestre los productos cuyo precio es mayor que el promedio. Ordena por precio descendente.

**Desafío:**
1. Inserta un cliente con dirección principal (requiere dos INSERTs — ¿en qué orden?).
2. Crea un pedido para ese cliente y agrégale dos items. Recuerda: `subtotal` es GENERATED, no lo insertes.

---

## Ejercicio 7 — JOINs

> Archivo: `sql/07_joins.sql`

```
clientes ──< pedidos ──< items_pedido >── productos >── categorias
   │
   └──< direcciones
```

### 7.1 INNER JOIN
Escribe una query que muestre: `pedido_id`, nombre del cliente, email, fecha, total y estado.  
¿Por qué INNER JOIN y no LEFT JOIN aquí?

### 7.2 LEFT JOIN
Encuentra todos los clientes que **nunca han realizado un pedido**.  
¿Cómo usas `IS NULL` para filtrar los no-coincidentes?

### 7.3 Multi-tabla
Lista el detalle completo de items: pedido, cliente, producto, cantidad, precio unitario y subtotal.  
Requiere JOIN sobre 4 tablas: `items_pedido → pedidos → clientes` y `items_pedido → productos`.

### 7.4 Agregación con JOIN
1. Total gastado por cada cliente (incluye clientes sin pedidos con 0).
2. Los 5 productos más vendidos (por unidades).
3. Ingresos por categoría.

### 7.5 Completar la tabla

| Query | Tipo de JOIN | ¿Por qué? |
|-------|-------------|-----------|
| Clientes sin pedidos | | |
| Detalle de un pedido | | |
| Productos nunca vendidos | | |
| Total por cliente | | |

**Desafío:**
1. Clientes con al menos un pedido en estado `enviado` — muestra también su dirección de entrega.
2. Categorías con todos sus productos agotados (stock = 0).

---

## Ejercicio 8 — Vistas

> Archivo: `sql/08_views.sql`

Una vista es un **SELECT guardado** que se comporta como tabla virtual.  
No almacena datos — ejecuta la query cada vez que haces SELECT sobre ella.

### 8.1 Crear y usar una vista
1. Crea `v_resumen_pedidos` con: pedido_id, nombre del cliente, email, fecha, total, estado y cantidad de items.
2. Consulta la vista para ver solo pedidos pendientes.
3. ¿Puedes hacer un `UPDATE` a través de una vista simple? Prueba actualizar el estado.

### 8.2 Vista con agregación
Crea `v_clientes_stats` que muestre para cada cliente: total de pedidos, total gastado, ticket promedio y fecha del último pedido.  
Úsala para encontrar clientes con `total_pedidos = 0`.

### 8.3 STRING_AGG
Crea una vista `v_pedido_detalle` que muestre para cada pedido una columna `productos` con todos los productos concatenados: `"Laptop x2, Mouse x1"`.

**Desafío:**
1. `v_productos_agotados` — productos con stock = 0, su categoría y precio.
2. `v_ingresos_por_categoria` — nombre de categoría, unidades vendidas e ingresos totales, ordenado por ingresos DESC.

---

## Ejercicio 9 — Funciones

> Archivo: `sql/09_functions.sql`

PostgreSQL tiene dos estilos:
- `LANGUAGE sql` — cuerpo es una expresión SQL, sin BEGIN
- `LANGUAGE plpgsql` — lenguaje procedural completo, necesario para IF/LOOP/DECLARE

### 9.1 LANGUAGE sql
1. Crea `total_pedidos_cliente(p_cliente_id INT) RETURNS BIGINT`.
2. Crea `gasto_total_cliente(p_cliente_id INT) RETURNS NUMERIC`.
3. Úsalas en un SELECT que muestre todos los clientes con sus métricas.

### 9.2 LANGUAGE plpgsql — lógica condicional
Crea `clasificar_cliente(p_cliente_id INT) RETURNS VARCHAR` que devuelva:
- `'VIP'` si gastó ≥ $1,000
- `'Regular'` si gastó ≥ $200
- `'Nuevo'` si gastó menos

### 9.3 Validaciones en funciones
Crea `precio_con_descuento(p_precio NUMERIC, p_pct NUMERIC) RETURNS NUMERIC` que:
- Calcule el precio con descuento
- Lance una excepción si `p_pct` está fuera del rango 0–100

**Desafío:**
1. `dias_desde_registro(p_cliente_id INT)` — días desde que se registró el cliente.
2. `stock_suficiente(p_producto_id INT, p_cantidad INT)` — retorna BOOLEAN.
3. `resumen_pedido(p_pedido_id INT)` — retorna TEXT con `"Cliente: X | Items: N | Total: $Y"`.

---

## Ejercicio 10 — Procedimientos

> Archivo: `sql/10_procedures.sql`

Un procedimiento ejecuta acciones pero **no devuelve valor**.  
Se llama con `CALL`. Usa `RAISE NOTICE` para imprimir mensajes.  
Para devolver datos usa `FUNCTION` con `RETURNS TABLE`.

### 10.1 Procedimiento con validación
Crea `actualizar_estado_pedido(p_pedido_id INT, p_nuevo_estado VARCHAR)` que:
1. Verifique que el pedido existe — lanza excepción si no
2. Impida modificar pedidos ya cancelados
3. Actualice el estado y muestre un `RAISE NOTICE` con el cambio

Prueba con un pedido existente y con uno inexistente.

### 10.2 RETURNS TABLE
Crea una FUNCTION `pedidos_activos_cliente(p_cliente_id INT)` que devuelva una tabla con los pedidos que no están cancelados ni entregados.

### 10.3 Procedimiento complejo
Crea `agregar_item_pedido(p_pedido_id INT, p_producto_id INT, p_cantidad INT)` que:
1. Valide que el pedido está en estado `pendiente` o `procesando`
2. Valide que hay suficiente stock
3. Inserte el item en `items_pedido`
4. Reduzca el stock del producto
5. Recalcule y actualice el total del pedido

**Desafío:**  
Crea `cancelar_pedido(p_pedido_id INT)` que:
- Impida cancelar un pedido ya `entregado`
- Restaure el stock de todos sus items (loop sobre `items_pedido`)
- Cambie el estado a `cancelado`

---

## Ejercicio 11 — Triggers

> Archivo: `sql/11_triggers.sql`

Un trigger **se dispara automáticamente** ante un evento DML.

En PostgreSQL son **dos partes**:
1. Una función `RETURNS TRIGGER`
2. El trigger que la asocia a tabla + evento

Dentro de la función:
- `NEW` — fila nueva (INSERT/UPDATE)
- `OLD` — fila anterior (UPDATE/DELETE)
- Retornar `NEW` en triggers BEFORE permite la operación; retornar `NULL` la cancela

### 11.1 Auditoría AFTER UPDATE
Crea un trigger `trg_auditar_pedido` que, al cambiar el estado o total de un pedido, registre en `pedidos_log`: pedido_id, estado anterior, estado nuevo, total anterior, total nuevo.  
Cambia el estado de un pedido dos veces y verifica `SELECT * FROM pedidos_log`.

### 11.2 Validación BEFORE INSERT
Crea un trigger `trg_validar_stock` en `items_pedido` que **antes** de insertar verifique que hay suficiente stock. Si no hay, debe lanzar una excepción.  
Prueba intentar insertar 999,999 unidades de un producto.

### 11.3 Stock automático AFTER INSERT
Crea un trigger `trg_reducir_stock` en `items_pedido` que **después** de insertar un item, reduzca automáticamente el stock del producto correspondiente.

### 11.4 Listar triggers
Usa `information_schema.triggers` para listar todos los triggers del schema public.

### 11.5 Preguntas de discusión
1. El trigger `trg_validar_stock` (BEFORE) y el procedimiento `agregar_item_pedido` ambos validan el stock. ¿Es esto redundante? ¿Cuál es la diferencia en términos de capas de seguridad?
2. ¿Qué problemas puede causar tener lógica de negocio en triggers en lugar de en la aplicación?
3. ¿Qué pasa si un trigger falla a mitad de una transacción?

**Desafío:**
1. `AFTER DELETE` en `items_pedido`: restaura el stock y actualiza el total del pedido.
2. `BEFORE UPDATE` en `productos`: impide que el precio baje más del 50% en una sola operación.
