# PostgreSQL & MongoDB Workshop
## A hands-on guide you can follow at your own pace

This document walks you through every exercise in the workshop. Each section tells you what to run, what to look for, and why it matters. You don't need a presenter — just a terminal and the workshop environment running.

**Start here:**
```
make setup    # first time only — builds the container
make reset    # loads the starting database
make shell    # opens pgcli
```

---

## Module 1 — Normalization & Indexes

---

### Exercise 1 — The Bad Schema

**What you're looking at:** A denormalized e-commerce database. Every order line repeats all the customer and product information on the same row.

```sql
\d pedidos_completos
SELECT * FROM pedidos_completos LIMIT 3;
```

Notice what repeats across rows: the customer's name, email, and phone appear on every single order line they ever placed. Same for product names and prices.

Run this to see the scale of the problem:

```sql
SELECT
    COUNT(DISTINCT cliente_email) AS clientes_unicos,
    COUNT(*) AS total_filas,
    COUNT(*) - COUNT(DISTINCT cliente_email) AS filas_redundantes;
```

There are ~20,000 unique customers but hundreds of thousands of rows. Every customer's data is stored as many times as they have order lines.

**Why this hurts — the three anomalies:**

```sql
-- Update anomaly: changing one email means updating thousands of rows
UPDATE pedidos_completos SET cliente_email = 'nuevo@email.com'
WHERE cliente_email = 'alguno@email.com';

-- Deletion anomaly: deleting orders loses the customer record entirely
DELETE FROM pedidos_completos WHERE cliente_email = 'alguno@email.com';
```

A well-designed schema makes all three anomalies (insert, update, delete) structurally impossible — not something you have to remember to handle in code.

---

### Exercise 2 — Normalization

**The fix:** 3rd Normal Form — each fact lives in exactly one place.

```
\i sql/02_normalized_schema.sql
\dt
```

The schema is now:

```
clientes ──< pedidos ──< items_pedido >── productos >── categorias
   │
   └──< direcciones
```

A customer's email lives in `clientes`. One row. If it changes, one `UPDATE`. Products live in `productos`. Orders in `pedidos`. The relationship between an order and a product lives in `items_pedido`.

Look at what the constraints buy you:

```sql
\d productos
```

- `CHECK (precio > 0)` — the database rejects a negative price. Your app doesn't have to.
- `GENERATED ALWAYS AS` on `subtotal` — computed from `cantidad * precio_unitario`, always correct, can't be corrupted by a bad `INSERT`.

Load the data migration:

```
\i sql/04_migration.sql
SELECT COUNT(*) FROM clientes;
SELECT COUNT(*) FROM productos;
```

---

### Exercise 3 — Diagnosing Performance

**The problem:** Even a well-normalized schema is slow without indexes. The normalized schema has ~500k products.

```sql
\timing on
SELECT * FROM productos WHERE descripcion LIKE '%laptop%';
```

That was slow. Here's why:

```sql
EXPLAIN ANALYZE
SELECT * FROM productos WHERE descripcion LIKE '%laptop%';
```

Look for `Seq Scan` in the output. PostgreSQL read every single row in the table to find matches. With 500k rows that's expensive — with millions it becomes a production incident.

---

### Exercise 4 — Creating Indexes

```
\i sql/03_indexes.sql
```

**B-Tree index — for ranges and equality:**

```sql
CREATE INDEX idx_productos_precio ON productos(precio);
EXPLAIN ANALYZE SELECT * FROM productos WHERE precio BETWEEN 100 AND 500;
```

The plan changes from `Seq Scan` to `Index Scan`. The cost drops dramatically because PostgreSQL can jump directly to the relevant rows instead of reading everything.

**GIN index — for full-text search:**

```sql
CREATE INDEX idx_productos_busqueda ON productos
USING GIN(to_tsvector('spanish', nombre || ' ' || descripcion));

EXPLAIN ANALYZE
SELECT * FROM productos
WHERE to_tsvector('spanish', nombre || ' ' || descripcion)
      @@ to_tsquery('spanish', 'laptop');
```

GIN (Generalized Inverted Index) is designed for searches inside text and arrays. A B-Tree won't help here.

**Partial index — index only what you query:**

```sql
CREATE INDEX idx_productos_disponibles ON productos(precio)
WHERE activo = true AND stock > 0;
```

This index only covers active in-stock products — the rows that actually get queried on the storefront. Smaller, faster, and the optimizer uses it for the right queries.

**The trade-off to keep in mind:** indexes speed up reads but slow down every write — every `INSERT`, `UPDATE`, and `DELETE` also has to update all indexes on that table. Don't index everything. Index what you query.

---

## Module 2 — SQL Fundamentals

> Run `\i sql/test_seed.sql` if you want a small, clean dataset for experimenting.

---

### Exercise 5 — DDL

DDL (Data Definition Language) is how you define and evolve your schema. In production you never drop and recreate tables — you `ALTER` them.

```
\i sql/05_ddl.sql
```

**Adding a column without downtime:**

```sql
ALTER TABLE productos ADD COLUMN descuento NUMERIC(5,2) DEFAULT 0
    CHECK (descuento BETWEEN 0 AND 100);
\d productos
```

The column is added, the `DEFAULT` fills existing rows, and the `CHECK` constraint rejects anything outside 0–100 — all in one statement, no table lock for most cases.

**Composite UNIQUE constraint:**

```sql
UNIQUE (producto_id, cliente_id)
```

One review per customer per product, enforced at the database level. Your app doesn't have to check for duplicates before inserting.

---

### Exercise 6 — DML

DML (Data Manipulation Language) — `INSERT`, `UPDATE`, `DELETE`, `SELECT`.

```
\i sql/06_dml.sql
```

**`RETURNING` — get the generated ID without a second query:**

```sql
INSERT INTO clientes (nombre, email)
VALUES ('Demo', 'demo@test.com')
RETURNING cliente_id;
```

The generated `cliente_id` comes back immediately in the result. No need to run `SELECT lastval()` or a second `SELECT`.

**`UPDATE` with a subquery:**

```sql
UPDATE productos SET activo = false WHERE stock = 0;
```

**`DELETE` with `NOT EXISTS`:**

```sql
DELETE FROM pedidos WHERE estado = 'cancelado'
AND NOT EXISTS (SELECT 1 FROM items_pedido WHERE pedido_id = pedidos.pedido_id);
```

Only deletes cancelled orders that have no items. The `NOT EXISTS` subquery is a common and efficient pattern for conditional deletes.

---

### Exercise 7 — JOINs

JOINs are how you query across multiple tables. The relational model was designed around this.

```
\i sql/07_joins.sql
```

**`INNER JOIN` — only rows with a match on both sides:**

```sql
SELECT c.nombre, p.pedido_id, p.total, p.estado
FROM pedidos p
INNER JOIN clientes c ON c.cliente_id = p.cliente_id;
```

**`LEFT JOIN` — find what's missing:**

```sql
SELECT c.nombre, c.email
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
WHERE p.pedido_id IS NULL;
```

This finds customers who have never placed an order. The `LEFT JOIN` keeps all customers regardless of whether they have a match in `pedidos`. The `IS NULL` filter keeps only those with no match.

`RIGHT JOIN` exists but you'll rarely use it — you can always rewrite it as a `LEFT JOIN` by swapping the tables, which is easier to read.

**Multi-table join:**

```sql
SELECT c.nombre, pr.nombre AS producto, ip.cantidad, ip.subtotal
FROM items_pedido ip
INNER JOIN pedidos p ON p.pedido_id = ip.pedido_id
INNER JOIN clientes c ON c.cliente_id = p.cliente_id
INNER JOIN productos pr ON pr.producto_id = ip.producto_id;
```

**Aggregation with `JOIN`:**

```sql
SELECT c.nombre, COUNT(p.pedido_id) AS pedidos, COALESCE(SUM(p.total), 0) AS gastado
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre
ORDER BY gastado DESC;
```

`COALESCE` turns `NULL` (customers with no orders) into `0` for the sum.

---

### Exercise 8 — Views

A view is a saved `SELECT`. It behaves like a table but stores no data — it runs the underlying query every time you query it.

```
\i sql/08_views.sql
```

**Updatable view:**

```sql
SELECT * FROM v_pedidos_simples LIMIT 5;
UPDATE v_pedidos_simples SET estado = 'procesando' WHERE pedido_id = 1;
```

That works. A simple view with no `GROUP BY`, no `JOIN`, backed by a single table — PostgreSQL can figure out which row to update.

**Non-updatable view:**

```sql
-- This will fail:
UPDATE v_resumen_pedidos SET estado = 'enviado' WHERE pedido_id = 1;
```

PostgreSQL refuses. The view uses `GROUP BY` — there's no single underlying row that maps to each result row. The rule: a view is only updatable if it maps 1-to-1 to a single table.

**Aggregation view:**

```sql
SELECT * FROM v_clientes_stats ORDER BY total_gastado DESC NULLS LAST;
SELECT nombre, email FROM v_clientes_stats WHERE total_pedidos = 0;
```

Views let you encapsulate complex queries and reuse them across your application without duplicating SQL.

---

### Exercise 9 — Functions

Functions package SQL logic so you can call it by name. PostgreSQL supports two styles.

```
\i sql/09_functions.sql
```

**SQL-language functions — for simple expressions:**

```sql
SELECT nombre, total_pedidos_cliente(cliente_id), gasto_total_cliente(cliente_id)
FROM clientes;
```

**PL/pgSQL — for logic with conditionals:**

```sql
SELECT nombre, clasificar_cliente(cliente_id) AS segmento
FROM clientes;
```

The function returns `VIP`, `Regular`, or `Nuevo` based on order history. The classification logic lives in the database — every application that connects to this DB gets the same result without duplicating the logic.

**Input validation:**

```sql
SELECT precio_con_descuento(100, 20);   -- works: returns 80
SELECT precio_con_descuento(100, 150);  -- raises exception: discount > 100%
```

The function raises an error before any bad data reaches your tables.

---

### Exercise 10 — Procedures

Procedures are like functions but they perform actions rather than returning a value. You call them with `CALL`.

```
\i sql/10_procedures.sql
```

**State machine:**

```sql
CALL actualizar_estado_pedido(1, 'procesando');
CALL actualizar_estado_pedido(1, 'enviado');
CALL actualizar_estado_pedido(999, 'enviado');  -- fails: order doesn't exist
```

The procedure enforces valid state transitions. You can't skip states or modify a cancelled order. The rule lives in the database, not in whichever service happens to be calling it today.

**When to use `RETURNS TABLE` instead:**

```sql
SELECT * FROM pedidos_activos_cliente(1);
```

When you need to return rows, use a `FUNCTION` with `RETURNS TABLE` — not a procedure.

**Compound operation:**

```sql
CALL agregar_item_pedido(1, 3, 2);
SELECT stock FROM productos WHERE producto_id = 3;
```

One `CALL` validates stock availability, inserts the item, decrements stock, and recalculates the order total — all atomically.

---

### Exercise 11 — Triggers

A trigger fires automatically when something happens to a table. It's invisible enforcement — correct behavior happens whether the write comes from your app, a migration script, or a direct psql session.

```
\i sql/11_triggers.sql
```

Every trigger has two parts:
1. A function that `RETURNS TRIGGER`
2. The trigger definition that binds it to a table and event

**Audit trigger:**

```sql
UPDATE pedidos SET estado = 'procesando' WHERE pedido_id = 1;
UPDATE pedidos SET estado = 'enviado' WHERE pedido_id = 1;
SELECT * FROM pedidos_log;
```

Every state change is recorded automatically in `pedidos_log`. No developer has to remember to log it. No code path can bypass it.

**Validation trigger (`BEFORE`):**

```sql
-- Try to insert more items than available stock:
INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (1, 1, 999999, 100);
```

The trigger fires `BEFORE` the `INSERT` and blocks it. The row never gets written.

Inside a trigger function, `NEW` is the row being inserted or updated, `OLD` is the row before the change. Return `NEW` to allow the operation, return `NULL` to cancel it (in `BEFORE` triggers).

**Note on Exercise 10 vs. Exercise 11:** The procedure and the trigger both validate stock. That's not redundant — the trigger is a safety net at the database layer, the procedure is the intended path. Belt and suspenders: if something bypasses the procedure, the trigger catches it.

---

### Exercise 12 — Transactions

A transaction is an atomic unit of work. Either everything commits or nothing does. This is the foundation of data integrity in relational databases.

```
\i sql/12_transactions.sql
```

**`BEGIN` / `COMMIT`:**

```sql
BEGIN;
INSERT INTO clientes (nombre, email) VALUES ('TX Demo', 'txdemo@test.com');
INSERT INTO pedidos (cliente_id, total, estado)
VALUES ((SELECT cliente_id FROM clientes WHERE email = 'txdemo@test.com'), 0, 'pendiente');
COMMIT;
```

Both rows land together. If the second `INSERT` had failed, the first would have been rolled back automatically — no orphaned customer record with no orders.

**`ROLLBACK`:**

```sql
BEGIN;
UPDATE productos SET precio = precio * 0.01 WHERE activo = true;
SELECT ROUND(AVG(precio)::NUMERIC, 4) FROM productos;  -- prices look very wrong
ROLLBACK;
SELECT ROUND(AVG(precio)::NUMERIC, 2) FROM productos;  -- back to normal
```

Inside the transaction you can see the damage. `ROLLBACK` undoes everything — it never hit the disk permanently.

**`SAVEPOINT` — partial rollback:**

```sql
BEGIN;
INSERT INTO categorias (nombre) VALUES ('TestTX');
SAVEPOINT sp1;
-- if a second operation fails here, ROLLBACK TO SAVEPOINT sp1
-- undoes only the second operation, not the first
COMMIT;  -- the first insert is saved
```

`SAVEPOINT`s let you recover from partial failures without aborting the whole transaction. Useful in bulk imports: process 1000 rows, savepoint every 100 — if row 150 fails, roll back to the last savepoint and continue from 101.

**Isolation — open two terminals to see it:**

| Terminal A | Terminal B |
|-----------|-----------|
| `BEGIN;` | |
| `UPDATE productos SET precio = 9999 WHERE producto_id = 1;` | |
| | `SELECT precio FROM productos WHERE producto_id = 1;` — sees the old price |
| `COMMIT;` | |
| | `SELECT precio FROM productos WHERE producto_id = 1;` — now sees 9999 |

Terminal B sees the old price until A commits. This is `READ COMMITTED` — PostgreSQL's default isolation level. Each statement sees only data that was committed before it started. If your Python app crashes mid-transaction, the connection closes and PostgreSQL automatically rolls back the open transaction.

---

## Wrap Up — Module 1 & 2

| Topic | The point |
|-------|-----------|
| Normalization | One fact, one place. Eliminates update/delete/insert anomalies. |
| Indexes | Speed up reads. Cost writes and storage. Choose carefully. |
| DDL/DML | `ALTER` not recreate. `RETURNING` saves a round-trip. |
| JOINs | `INNER` for matches, `LEFT` for gaps, aggregate with `GROUP BY`. |
| Views | Encapsulate complex queries. Updatable only if 1-to-1 to a table. |
| Functions | Reusable logic, validated inputs, two styles (`sql` vs `plpgsql`). |
| Procedures | Actions without return values. Enforce business rules. |
| Triggers | Automatic enforcement. Audit, validate, react — invisibly. |
| Transactions | Atomic, all-or-nothing. `ROLLBACK` is your safety net. |

Challenges and exercises are in each SQL file. Solutions are in `SOLUTIONS.md` and `SOLUTIONS_SQL_FUNDAMENTALS.md`.

---

---

## Module 3 — MongoDB & Hybrid Systems

**Prerequisites:**
```
make reset-normalized   # clean Postgres with the real productos table
make mongo-start        # start the MongoDB container
make mongo-seed         # populate MongoDB from the Postgres catalog
make mongosh            # open the MongoDB shell
```

Verify the seed worked before starting:
```js
db.productos.countDocuments()                    // should match Postgres productos count
db.productos.findOne({ categoria: "Laptops" })   // inspect a document
```

---

### Exercise 13 — SQL Hits a Wall

The PM has just dropped this ticket:

> "Hey, can we show laptop RAM, CPU, and screen size on the product page? Also monitor resolution and panel type, and mouse DPI and whether it's wireless. Should be easy right? 😊"

Before writing a line of code, the team gets into a room. Three proposals come up. Here's why each one gets rejected.

```
\i sql/13_sql_hits_a_wall.sql
```

> After this exercise, run `make reset-normalized` to restore the clean normalized schema before continuing. (`make reset` goes back to Module 1's bad schema — that's the wrong state.)

---

#### Proposal 1 — "Just add columns"

*"It's three `ALTER TABLE`s, done by end of sprint."*

Run the first section of the SQL and look at what a laptop row looks like after Sprints 3, 7, and 11:

```sql
SELECT
    producto_id, nombre, precio,
    ram_gb, cpu, storage_gb,     -- laptop columns
    resolution, panel_type,      -- monitor columns (NULL for laptops)
    dpi, wireless                -- mouse columns (NULL for laptops)
FROM productos
WHERE categoria_id = 1
LIMIT 3;
```

Every laptop row now carries `resolution`, `panel_type`, `refresh_hz` — permanently NULL. Every monitor row carries `ram_gb`, `cpu`, `storage_gb` — permanently NULL. Nothing in the schema prevents a laptop from having a `dpi` value or a monitor from having a `battery_hours`. The database won't stop it.

The next sprint adds keyboard specs: three more columns, seven out of eight categories get NULL again. This compounds every sprint indefinitely.

**Why this is the one that actually ships:** it's the path of least resistance. Teams don't do this once — they do it eight times and wake up with a table that has 40 columns, most of which are NULL for any given row.

---

#### Proposal 2 — EAV (Entity–Attribute–Value)

*"One generic `producto_atributos` table — key/value pairs. No more nullable columns, fully extensible."*

Look at the EAV query in the SQL file:

```sql
SELECT p.nombre, p.precio,
       vram.valor  AS vram_gb,
       tdp.valor   AS tdp_watts
FROM   productos p
JOIN   producto_atributos vram ON vram.producto_id = p.producto_id AND vram.atributo = 'vram_gb'
JOIN   producto_atributos tdp  ON tdp.producto_id  = p.producto_id AND tdp.atributo  = 'tdp_watts'
WHERE  p.categoria_id = 8
  AND  vram.valor::INT >= 8;
```

Two attributes. Two self-joins. Every value is `TEXT` — `"8"` for VRAM, `"200"` for TDP. The filter `vram.valor::INT >= 8` casts TEXT to INT on every single row. The query planner's statistics on `valor` are useless because the column holds integers, booleans, and strings all mixed together.

Fetching five attributes requires five self-joins. There's nothing stopping someone from inserting `"ocho"` as the value for `vram_gb` — the schema won't catch it.

**Why this gets killed in code review:** the moment someone sees what the queries look like, it's over. The schema diagram looks clean; the queries that use it don't.

---

#### Proposal 3 — One table per category

*"Typed columns, proper foreign keys, real constraints — `specs_laptops`, `specs_monitores`, one per category. This is the correct relational approach."*

It is the most correct relational solution. It is also the most expensive to maintain.

Look at the cross-category query:

```sql
SELECT p.nombre, p.precio,
       p.ram_gb,
       si.pages_per_min, si.color_print
FROM   productos p
LEFT JOIN specs_impresoras si ON si.producto_id = p.producto_id
WHERE  p.precio < 300
ORDER  BY p.precio
LIMIT  10;
```

One `LEFT JOIN` per spec table. Every result row is still mostly NULL — the same problem as Proposal 1, now split across multiple tables. You currently have 8 categories. The PM will add a ninth. Then a tenth. Every cross-category query gets a new join every sprint.

The migration story also kills it before it lands: "We need to backfill 100k rows across 8 new tables" is a hard conversation with a PM who wanted this done by end of sprint.

---

#### Why all three fail

Three proposals, three developers, all rejected — not because the developers are wrong, but because **SQL requires every row in a table to have the same shape, and product specs don't.** That constraint is load-bearing in the relational model. You can't design around it using the same tool.

Look at the current state of the `productos` table after running the script:

```sql
\d productos
```

Three different approaches coexist in the same schema simultaneously. This is what six months of feature pressure looks like in a relational database.

```
  ➜  Enter MongoDB.
```

---

### The Document Model — Concepts

Before opening mongosh, look at this diagram: `diagrams/sql_vs_mongo.png`

The left side is the schema you just ran. The right side is the same product data in MongoDB.

| SQL | MongoDB |
|-----|---------|
| Database | Database |
| Table | Collection |
| Row | Document |
| Column | Field (present only where relevant) |
| `NULL` | Field simply absent |
| `ALTER TABLE` | `$set` on any document |
| `JOIN` | Embedded subdoc or app-layer `$in` lookup |

Three things to anchor on:

- **No fixed schema.** A laptop document and a monitor document live in the same collection with completely different shapes. That's not a bug — it's the design.
- **Fields are absent, not NULL.** A laptop document has no `resolution` field. It doesn't exist. There's no ghost column sitting there holding a NULL value.
- **`_id` = `producto_id`.** Every MongoDB document in this workshop has an `_id` that matches a row in Postgres. That shared key is what makes the hybrid system in Exercise 18 work.

---

### Exercise 14 — The Document Model

Look at the diagram first: `diagrams/hybrid_architecture.png`

Postgres owns the left side (orders, customers, transactions). MongoDB owns the right side (product catalog, specs). `producto_id` / `_id` is the shared key between them.

```js
// in mongosh
load('mongo/01_document_model.js')
```

The script inserts four products — one per category — into a demo collection. Each document has a `specs` subdocument with a completely different shape:

- Laptop: `ram_gb`, `cpu`, `storage_gb`, `screen_inch`, `os`, `battery_hours`
- Monitor: `resolution`, `panel_type`, `refresh_hz`, `ports` (an array)
- Mouse: `dpi`, `wireless`, `sensor_type`, `buttons`
- GPU: `vram_gb`, `tdp_watts`, `connector`, `outputs` (an array)

No NULLs. No columns that don't belong. Each document carries exactly what it needs and nothing else.

Adding keyboard specs next sprint means inserting keyboard documents with a `specs.switch_type` field. No `ALTER TABLE`. No migration. The existing laptop, monitor, mouse, and GPU documents are completely unaffected.

**Think about:** if a product has no specs yet — a new category just added — what does its document look like? You can just omit the `specs` field entirely. The document is still valid.

---

### Exercise 15 — CRUD

```js
load('mongo/02_crud.js')
```

**`insertOne`** — the keyboard document has fields no other category uses. The collection has no schema to enforce.

**`find` with projection** — the second argument controls which fields come back:

```js
db.productos_demo.find(
  { categoria: "Laptops" },
  { nombre: 1, precio: 1, "specs.ram_gb": 1, _id: 0 }
)
```

`1` = include, `0` = exclude. `_id: 0` suppresses the id. Dot notation (`"specs.ram_gb"`) reaches into the nested subdocument.

**`updateOne` with `$set` and `$inc`:**

```js
db.productos_demo.updateOne(
  { _id: 5 },
  {
    $set:  { precio: 139.99, "specs.backlit": true },
    $inc:  { stock: -5 }
  }
)
```

`$set` adds or updates a field without touching anything else on the document. `$inc` modifies a numeric field atomically. You're adding a `specs.backlit` field that no other document in the collection has — and that's fine.

**`deleteOne`** — removes one matching document.

**Think about:** `$set` can add a field to one document that no other document has. Is that a feature or a risk? (The honest answer: both, depending on whether your application code is disciplined about the shape it expects.)

---

### Exercise 16 — Querying

```js
load('mongo/03_querying.js')
```

**Dot notation into nested specs:**

```js
db.productos.find(
  { categoria: "Laptops", "specs.ram_gb": { $gte: 32 }, activo: true },
  { nombre: 1, precio: 1, "specs.ram_gb": 1, "specs.cpu": 1, _id: 0 }
)
```

Compare this to the EAV query from Exercise 13: the same filter (`ram >= 32`) needed two self-joins and a TEXT cast. Here it's one field in the query filter.

**Array field — membership as equality:**

```js
db.productos.find(
  { "specs.ports": "USB-C" },
  { nombre: 1, "specs.ports": 1, _id: 0 }
)
```

MongoDB checks whether `"USB-C"` is in the `ports` array. You don't need to `UNNEST` or `ANY()` — array membership is just equality.

**`$exists` — query across different document shapes:**

```js
db.productos.find(
  { "specs.wireless": true, activo: true },
  { nombre: 1, categoria: 1, precio: 1, _id: 0 }
)
```

This returns mice, keyboards, and headphones — any document that has a `specs.wireless` field set to `true`, regardless of category. Cross-category queries that were painful with nullable columns or category spec tables are just filters here.

**`$in`** works on any field including `_id` — which is exactly how the hybrid lookup in Exercise 18 works.

If you want to see the timing difference: turn on `\timing on` in pgcli and run the equivalent EAV query from Exercise 13. Then run the MongoDB query here. The gap makes the architectural point concrete.

---

### Exercise 17 — Aggregation Pipeline

```js
load('mongo/04_aggregation.js')
```

The aggregation pipeline is MongoDB's equivalent of `GROUP BY`, `HAVING`, and computed columns. Each stage transforms the stream of documents coming out of the previous stage.

| Stage | SQL equivalent |
|-------|---------------|
| `$match` | `WHERE` |
| `$group` | `GROUP BY` + aggregate functions |
| `$sort` | `ORDER BY` |
| `$project` | `SELECT` — reshape, rename, compute new fields |
| `$unwind` | Explode an array into one document per element |

**Build it up one stage at a time:**

```js
// Stage 1 only
db.productos.aggregate([
  { $match: { activo: true } }
])

// Add $group
db.productos.aggregate([
  { $match: { activo: true } },
  { $group: { _id: "$categoria", total: { $sum: 1 }, avg_price: { $avg: "$precio" } } }
])

// Add $sort
db.productos.aggregate([
  { $match: { activo: true } },
  { $group: { _id: "$categoria", total: { $sum: 1 }, avg_price: { $avg: "$precio" } } },
  { $sort: { avg_price: -1 } }
])
```

**`$project` computes new fields inline:**

```js
{ $project: {
    nombre: 1,
    precio_con_10pct: { $round: [{ $multiply: ["$precio", 0.9] }, 2] }
} }
```

No subquery, no CTE — just an expression in the projection stage.

**`$unwind` — explode an array:**

```js
db.productos.aggregate([
  { $match:   { categoria: "Monitores", "specs.ports": { $exists: true } } },
  { $unwind:  "$specs.ports" },
  { $group:   { _id: "$specs.ports", count: { $sum: 1 } } },
  { $sort:    { count: -1 } }
])
```

One monitor document with three ports becomes three documents — one per port. Then `$group` counts them. This is how you aggregate over array contents.

**`$match` after `$group` = `HAVING`:**

```js
db.productos.aggregate([
  { $group:  { _id: "$categoria", total: { $sum: 1 } } },
  { $match:  { total: { $gte: 12500 } } }
])
```

A `$match` stage after a `$group` stage filters on the aggregated result — exactly what `HAVING` does in SQL.

---

### Exercise 18 — The Hybrid System

Back to the diagram: `diagrams/hybrid_architecture.png`

```js
load('mongo/05_hybrid.js')
```

The script shows the `$in` pattern — how the application layer fetches multiple documents by a list of IDs:

```js
db.productos.find(
  { _id: { $in: [101, 204, 389] } },
  { nombre: 1, categoria: 1, precio: 1, specs: 1 }
)
```

This is the same query that `make hybrid` runs in the full demo. Exit mongosh and run it:

```
make hybrid
```

What happens:

1. **Postgres** — fetch a real order and its line items (`pedido_id`, `cliente`, `items_pedido`)
2. **Extract** — pull the `producto_ids` out of the items
3. **MongoDB** — `find({ _id: { $in: producto_ids } })` — one query, all products
4. **Merge** — enrich each item with its catalog specs
5. **Print** — a full receipt with product specs per line item

Neither system knows the other exists. Postgres has no idea MongoDB is running. MongoDB has no idea what a `pedido` is. The application layer owns the join — that's intentional. Each system does exactly what it's good at.

| Postgres | MongoDB |
|----------|---------|
| Orders, payments, inventory | Product catalog, specs |
| ACID transactions | Flexible document shape |
| Referential integrity | Schema-free per document |
| Strong consistency | Fast catalog reads |
| `producto_id` FK | `_id` = same value |

Neither system is better. They solve different problems. The skill is knowing which problem you have.

---

### Exercise 19 — Closing the Loop

```js
load('mongo/06_closing_the_loop.js')
```

Back to the PM's ticket:

> "Hey, can we show laptop RAM, CPU, and screen size on the product page? Also monitor resolution and panel type, and mouse DPI and whether it's wireless. Should be easy right? 😊"

Three `find()` calls. One per category. No JOINs. No migrations. No NULLs.

The script also handles the next sprint — keyboards need `backlit` added:

```js
db.productos.updateMany(
  { categoria: "Periféricos", "specs.switch_type": { $exists: true } },
  { $set: { "specs.backlit": true } }
)
```

One `$updateMany`. Every keyboard document gets the field. Every laptop, monitor, and mouse document: completely unaffected.

Final score: schema migrations required = 0, `ALTER TABLE` statements = 0, NULL columns added = 0.

The problem was never the developers. It was using the wrong tool for the shape of the data.

---

## Quick Reference

**pgcli:**

| Command | What it does |
|---------|-------------|
| `\dt` | List tables |
| `\d tablename` | Describe a table |
| `\di` | List indexes |
| `\timing on/off` | Show query execution time |
| `\i file.sql` | Run a SQL file |
| `F3` | Toggle multi-line mode |
| `\q` | Quit |

**mongosh:**

| Command | What it does |
|---------|-------------|
| `show dbs` | List databases |
| `use workshop` | Switch to the workshop database |
| `show collections` | List collections |
| `db.collection.find().pretty()` | Formatted output |
| `db.collection.countDocuments()` | Count documents |
| `db.collection.findOne()` | First document |
| `load('file.js')` | Run a script file |
| `exit` | Quit |
