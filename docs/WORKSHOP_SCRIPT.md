# Workshop Speaker Script
## PostgreSQL with pgcli — Full Workshop

> **Commands to run before starting:**
> ```
> make shell        # open pgcli for you
> make reset        # if you need a fresh DB
> ```

---

## INTRO (~3 min)

"Today we're going to work hands-on with PostgreSQL using pgcli — a smarter SQL shell with autocomplete, syntax highlighting, and multi-line editing.

We'll go through two modules:
- **Module 1** — Why bad schemas hurt you, how to fix them with normalization, and how indexes make queries fast.
- **Module 2** — The SQL toolkit: DDL, DML, JOINs, views, functions, procedures, triggers, and transactions.

We have a real e-commerce database with products, customers, orders and order items. Everything we do today applies directly to production databases."

---

## MODULE 1 — Normalization & Indexes

---

### Exercise 1 — The Bad Schema (~10 min)

"Let's start by looking at what a bad schema looks like — and why it causes real problems."

```
make reset
make shell
\d pedidos_completos
SELECT * FROM pedidos_completos LIMIT 3;
```

**Ask the class:**
> "What do you notice? What repeats on every row?"

Point out:
- Customer name, email, phone are duplicated on every order line
- Product info is duplicated too
- This is called a **denormalized** schema

```sql
SELECT
    COUNT(DISTINCT cliente_email) AS clientes_unicos,
    COUNT(*) AS total_filas,
    COUNT(*) - COUNT(DISTINCT cliente_email) AS filas_redundantes;
```

**Say:** "We have ~20,000 customers but hundreds of thousands of rows. Every customer's data is stored as many times as they have order lines."

**Anomalies — show each one:**

```sql
-- Update anomaly: change one email = update thousands of rows
UPDATE pedidos_completos SET cliente_email = 'nuevo@email.com'
WHERE cliente_email = 'alguno@email.com';

-- Deletion anomaly: delete orders = lose the customer forever
DELETE FROM pedidos_completos WHERE cliente_email = 'alguno@email.com';
```

**Key point:** "Three types of anomalies: insert, update, delete. A good schema makes all three impossible."

---

### Exercise 2 — Normalization (~10 min)

"The fix is 3rd Normal Form — each piece of information lives in exactly one place."

```
\i sql/02_normalized_schema.sql
\dt
```

**Draw or describe the schema on the board:**
```
clientes ──< pedidos ──< items_pedido >── productos >── categorias
   │
   └──< direcciones
```

**Say:** "Now customers live in `clientes`. Products in `productos`. Orders link them together. If a customer changes their email — one row, one update."

**Walk through the constraints:**
```sql
\d productos
```
- `CHECK (precio > 0)` — the DB enforces business rules
- `GENERATED ALWAYS AS` on `subtotal` — computed automatically, can't be corrupted

**Load the migration:**
```
\i sql/04_migration.sql
SELECT COUNT(*) FROM clientes;
SELECT COUNT(*) FROM productos;
```

---

### Exercise 3 — Diagnosing Performance (~8 min)

"Now let's see why indexes matter. The normalized schema has ~500k products."

```sql
\timing on
SELECT * FROM productos WHERE descripcion LIKE '%laptop%';
```

**Ask:** "How long did that take? Let's look at why."

```sql
EXPLAIN ANALYZE
SELECT * FROM productos WHERE descripcion LIKE '%laptop%';
```

**Point out in the output:**
- `Seq Scan` — PostgreSQL read every single row
- `rows=500000` — examined all of them
- Cost is high

**Say:** "This is a full table scan. In production with millions of rows, this kills your database."

---

### Exercise 4 — Creating Indexes (~10 min)

```
\i sql/03_indexes.sql
```

**B-Tree index — for ranges and equality:**
```sql
CREATE INDEX idx_productos_precio ON productos(precio);
EXPLAIN ANALYZE SELECT * FROM productos WHERE precio BETWEEN 100 AND 500;
```
Show the difference: `Seq Scan` vs `Index Scan`. The cost drops dramatically.

**GIN index — for full-text search:**
```sql
CREATE INDEX idx_productos_busqueda ON productos
USING GIN(to_tsvector('spanish', nombre || ' ' || descripcion));

EXPLAIN ANALYZE
SELECT * FROM productos
WHERE to_tsvector('spanish', nombre || ' ' || descripcion)
      @@ to_tsquery('spanish', 'laptop');
```

**Key points on trade-offs:**
> "Indexes speed up reads but slow down writes. Every INSERT, UPDATE, DELETE also updates all indexes on that table. Don't index everything — index what you query."

**Partial index:**
```sql
CREATE INDEX idx_productos_disponibles ON productos(precio)
WHERE activo = true AND stock > 0;
```
> "Only indexes the rows you actually query. Smaller, faster, smarter."

---

## MODULE 2 — SQL Fundamentals

> Run `\i sql/test_seed.sql` if you want a small clean dataset for demos.

---

### Exercise 5 — DDL (~7 min)

"DDL — Data Definition Language — is how you define and evolve your schema."

```
\i sql/05_ddl.sql
```

**Live demo — ALTER TABLE:**
```sql
ALTER TABLE productos ADD COLUMN descuento NUMERIC(5,2) DEFAULT 0
    CHECK (descuento BETWEEN 0 AND 100);
\d productos
```

**Key point:** "In production you never recreate tables — you ALTER them. PostgreSQL lets you add columns, change types, add/drop constraints — all without downtime in most cases."

**Show the `resenas` table creation from the script.**
Point out the composite UNIQUE constraint:
```sql
UNIQUE (producto_id, cliente_id)
```
> "One review per customer per product — enforced at the DB level, not just in your app."

---

### Exercise 6 — DML (~7 min)

"DML — Data Manipulation Language — INSERT, UPDATE, DELETE, and SELECT."

```
\i sql/06_dml.sql
```

**RETURNING clause — very useful:**
```sql
INSERT INTO clientes (nombre, email)
VALUES ('Demo', 'demo@test.com')
RETURNING cliente_id;
```
> "You get the generated ID back immediately. No need for a second SELECT."

**UPDATE with subquery:**
```sql
UPDATE productos SET activo = false WHERE stock = 0;
```

**DELETE with NOT EXISTS:**
```sql
DELETE FROM pedidos WHERE estado = 'cancelado'
AND NOT EXISTS (SELECT 1 FROM items_pedido WHERE pedido_id = pedidos.pedido_id);
```
> "Only deletes empty cancelled orders. The NOT EXISTS subquery is a common and efficient pattern."

---

### Exercise 7 — JOINs (~10 min)

"JOINs are how you query across multiple tables. This is where relational databases shine."

```
\i sql/07_joins.sql
```

**INNER JOIN — matching rows only:**
```sql
SELECT c.nombre, p.pedido_id, p.total, p.estado
FROM pedidos p
INNER JOIN clientes c ON c.cliente_id = p.cliente_id;
```

**LEFT JOIN — find what's missing:**
```sql
SELECT c.nombre, c.email
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
WHERE p.pedido_id IS NULL;
```
> "Customers who have never ordered. The LEFT JOIN keeps all customers; the IS NULL filter keeps only those with no match."

**Ask the class:**
> "When would you use a RIGHT JOIN? (Almost never — you can always rewrite as a LEFT JOIN by swapping the tables.)"

**Multi-table join:**
```sql
SELECT c.nombre, pr.nombre AS producto, ip.cantidad, ip.subtotal
FROM items_pedido ip
INNER JOIN pedidos p ON p.pedido_id = ip.pedido_id
INNER JOIN clientes c ON c.cliente_id = p.cliente_id
INNER JOIN productos pr ON pr.producto_id = ip.producto_id;
```

**Aggregation with JOIN:**
```sql
SELECT c.nombre, COUNT(p.pedido_id) AS pedidos, COALESCE(SUM(p.total), 0) AS gastado
FROM clientes c
LEFT JOIN pedidos p ON p.cliente_id = c.cliente_id
GROUP BY c.cliente_id, c.nombre
ORDER BY gastado DESC;
```

---

### Exercise 8 — Views (~8 min)

"A view is a saved SELECT. It behaves like a table but stores no data — it runs the query every time."

```
\i sql/08_views.sql
```

**Show the updatable view:**
```sql
SELECT * FROM v_pedidos_simples LIMIT 5;
UPDATE v_pedidos_simples SET estado = 'procesando' WHERE pedido_id = 1;
```
> "Works! A simple view — no GROUP BY, no JOINs, one table — PostgreSQL can update through it."

**Show the non-updatable view:**
```sql
-- This will fail:
UPDATE v_resumen_pedidos SET estado = 'enviado' WHERE pedido_id = 1;
```
> "PostgreSQL refuses. The view uses GROUP BY — there's no single row to update. This is the rule: a view is updatable only if it maps 1-to-1 to a single table."

**Aggregation view:**
```sql
SELECT * FROM v_clientes_stats ORDER BY total_gastado DESC NULLS LAST;
SELECT nombre, email FROM v_clientes_stats WHERE total_pedidos = 0;
```
> "Views let you encapsulate complex queries and reuse them everywhere."

---

### Exercise 9 — Functions (~8 min)

"Functions let you package SQL logic and call it by name. Two styles in PostgreSQL."

```
\i sql/09_functions.sql
```

**SQL language — simple:**
```sql
SELECT nombre, total_pedidos_cliente(cliente_id), gasto_total_cliente(cliente_id)
FROM clientes;
```

**PL/pgSQL — with logic:**
```sql
SELECT nombre, clasificar_cliente(cliente_id) AS segmento
FROM clientes;
```
> "VIP, Regular, or Nuevo — computed on the fly. The classification logic lives in the DB, not scattered across your app."

**Functions with validation:**
```sql
SELECT precio_con_descuento(100, 20);   -- works
SELECT precio_con_descuento(100, 150);  -- raises exception
```

**Key point:**
> "Functions are reusable, testable, and version-controlled. Put your business logic here and every app that touches this DB benefits."

---

### Exercise 10 — Procedures (~7 min)

"Procedures are like functions but they don't return a value — they perform actions. You call them with CALL."

```
\i sql/10_procedures.sql
```

**State machine demo:**
```sql
CALL actualizar_estado_pedido(1, 'procesando');
CALL actualizar_estado_pedido(1, 'enviado');
CALL actualizar_estado_pedido(999, 'enviado');  -- fails: pedido doesn't exist
```
> "The procedure enforces the business rule. You can't skip states or modify cancelled orders."

**RETURNS TABLE:**
```sql
SELECT * FROM pedidos_activos_cliente(1);
```
> "When you need to return rows, use a FUNCTION with RETURNS TABLE — not a procedure."

**Complex procedure:**
```sql
CALL agregar_item_pedido(1, 3, 2);
SELECT stock FROM productos WHERE producto_id = 3;
```
> "One CALL — validates stock, inserts the item, reduces stock, recalculates the order total. All in one atomic operation."

---

### Exercise 11 — Triggers (~8 min)

"A trigger fires automatically when something happens to a table. Invisible, automatic enforcement."

```
\i sql/11_triggers.sql
```

**Two parts — always:**
1. A function that `RETURNS TRIGGER`
2. The trigger that binds it to a table + event

**Audit trigger:**
```sql
UPDATE pedidos SET estado = 'procesando' WHERE pedido_id = 1;
UPDATE pedidos SET estado = 'enviado' WHERE pedido_id = 1;
SELECT * FROM pedidos_log;
```
> "Every state change is recorded automatically. No developer has to remember to log it."

**Validation trigger (BEFORE):**
```sql
-- Try to insert more items than stock allows:
INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario)
VALUES (1, 1, 999999, 100);
```
> "The trigger fires BEFORE the INSERT and blocks it. The row never gets written."

**Show NEW and OLD:**
- `NEW` — the row being inserted/updated
- `OLD` — the row before the update/delete
- Return `NEW` to allow; return `NULL` to cancel (in BEFORE triggers)

**Discussion question to throw at the class:**
> "Exercise 10's procedure and Exercise 11's trigger both validate stock. Is that redundant? — Actually no. The trigger is a safety net at the DB layer. The procedure is the intended path. Belt and suspenders."

---

### Exercise 12 — Transactions (~10 min)

"A transaction is an atomic unit of work. Either everything commits or nothing does. This is the foundation of data integrity."

```
\i sql/12_transactions.sql
```

**BEGIN / COMMIT:**
```sql
BEGIN;
INSERT INTO clientes (nombre, email) VALUES ('TX Demo', 'txdemo@test.com');
INSERT INTO pedidos (cliente_id, total, estado)
VALUES ((SELECT cliente_id FROM clientes WHERE email = 'txdemo@test.com'), 0, 'pendiente');
COMMIT;
```
> "Both rows land together. If the second INSERT had failed, the first would have been rolled back too."

**ROLLBACK:**
```sql
BEGIN;
UPDATE productos SET precio = precio * 0.01 WHERE activo = true;
SELECT ROUND(AVG(precio)::NUMERIC, 4) FROM productos;  -- prices look very low
ROLLBACK;
SELECT ROUND(AVG(precio)::NUMERIC, 2) FROM productos;  -- back to normal
```
> "Inside the transaction, we see the damage. ROLLBACK — gone. Never hit the disk permanently."

**SAVEPOINT — partial rollback:**
```sql
BEGIN;
INSERT INTO categorias (nombre) VALUES ('TestTX');
SAVEPOINT sp1;
-- second insert fails (UNIQUE violation) -- caught in DO block
-- ROLLBACK TO SAVEPOINT sp1 -- undoes only the second insert
COMMIT;  -- first insert is saved
```
> "SAVEPOINTs let you recover from partial failures without aborting the whole transaction. Used in bulk imports and batch processing."

**Two-session demo (open a second terminal):**

| Terminal A | Terminal B |
|-----------|-----------|
| `BEGIN;` | |
| `UPDATE productos SET precio = 9999 WHERE producto_id = 1;` | |
| | `SELECT precio FROM productos WHERE producto_id = 1;` |
| `COMMIT;` | |
| | `SELECT precio FROM productos WHERE producto_id = 1;` |

> "Terminal B sees the OLD price until A commits. This is READ COMMITTED — PostgreSQL's default isolation level. Each statement sees only data that was committed before it started."

**Discussion questions:**
1. > "What happens if your Python app crashes in the middle of a BEGIN block? — The connection closes, PostgreSQL automatically rolls back the open transaction."
2. > "When would you use SAVEPOINT in a real app? — Batch inserts: process 1000 rows, savepoint every 100. If row 150 fails, roll back to the last savepoint and continue from 101."

---

## WRAP UP (~3 min)

"Let's recap what we covered today:

| Topic | The point |
|-------|-----------|
| Normalization | One fact, one place. Eliminates update/delete/insert anomalies. |
| Indexes | Speed up reads. Cost writes and storage. Choose carefully. |
| DDL/DML | ALTER not recreate. RETURNING saves a round-trip. |
| JOINs | INNER for matches, LEFT for gaps, aggregate with GROUP BY. |
| Views | Encapsulate complex queries. Updatable only if 1-to-1 to a table. |
| Functions | Reusable logic, validated inputs, two styles (sql vs plpgsql). |
| Procedures | Actions without return values. Enforce business rules. |
| Triggers | Automatic enforcement. Audit, validate, react — invisibly. |
| Transactions | Atomic, all-or-nothing. ROLLBACK is your safety net. |

The challenges in each exercise file are there for practice. Solutions are in `SOLUTIONS.md` and `SOLUTIONS_SQL_FUNDAMENTALS.md`.

Any questions?"

---

---

## MODULE 3 — MongoDB & Hybrid Systems

> **Prerequisites:** MongoDB running, `mongosh` available. Postgres DB from Module 2 still loaded.

---

### Exercise 13 — SQL Hits a Wall (~12 min)

**Goal:** Show why the relational model is the wrong tool for variable-shape data, using the `productos` table participants already know.

**Key framing:** These are not experiments that get rolled back. Each attempt is a real sprint ticket, made by a real developer, that stuck. The SQL file simulates 6 months of production schema evolution. Nobody rolled anything back — nobody ever does.

**Setup:** Show each diagram before running the corresponding section of the SQL. The diagram is the thesis; the SQL is the proof.

```
\i sql/13_sql_hits_a_wall.sql
```

> After the demo, run `make reset-normalized` to restore the clean normalized schema before the MongoDB section. (`make reset` goes back to the bad schema from Module 1 — wrong state.)

---

#### Attempt 1 — Nullable column explosion (Sprints 3, 7, 11)

**Diagram:** `diagrams/attempt1_nullable_columns.png`

Key points:
- Three separate sprint tickets, three separate developers, one growing table. Each addition seemed reasonable in isolation.
- For any given product row, most columns are NULL — the diagram shows this side by side for a laptop vs. a monitor row.
- No enforcement possible: nothing stops a laptop row from having `resolution`, or a monitor from having `ram_gb`.
- **Normalization callback:** 1NF violation. In Module 1 they saw repeated data across rows; this is the other flavor — columns with no consistent meaning across rows. A column irrelevant to 7 of 8 categories isn't a column for that table. Same root cause, different symptom.

**Discussion question:** What happens when the next sprint adds keyboard specs?

---

#### Attempt 2 — EAV (Entity–Attribute–Value) (Sprint 14)

**Diagram:** `diagrams/attempt2_eav.png`

Key points:
- A different developer hit the same wall and tried a different escape. The table structure looks clean — the query cost is the problem.
- Every attribute is TEXT — `"8"` for VRAM, `"200"` for TDP. No types, no constraints, no validation at the DB level.
- One JOIN per attribute you want to retrieve. The diagram shows 2 GPU attributes requiring 2 self-joins on a 500k-row table.
- Filtering by VRAM requires `valor::INT >= 8` — a TEXT cast on every row. The planner's statistics on `valor` are useless because integers, booleans, and strings are mixed in one column.
- **Performance:** ~500k rows (100k products × ~5 attrs). 2-attr query = 2 self-joins + TEXT cast. Estimated 8–15x slower than flat columns for filtered queries.

**Discussion question:** What happens if someone inserts `"ocho"` as the value for `vram_gb`?

---

#### Attempt 3 — One table per category (Sprint 18)

**Diagram:** `diagrams/attempt3_category_tables.png`

Key points:
- A third developer, a third approach. Typed columns, real constraints — the most "correct" relational solution.
- The schema now has THREE coexisting patterns in production: nullable columns, an EAV table, and a category spec table.
- Cross-category queries require a LEFT JOIN per spec table. Every result row is still mostly NULL — same problem as Attempt 1, now split across tables.
- The orange `specs_teclados` node is next sprint: another table, another migration, another LEFT JOIN in every cross-category query.
- **Performance:** ~12.5k rows per spec table, PK indexes — fast individually. Cross-category: 3–6x slower at 8 categories, degrades further. Opposite failure mode to EAV: category tables are worse for cross-category reads; EAV is worse for filtered queries.

**Closing point:** Three approaches, three developers, all in the same production schema simultaneously. The problem is not the developers — SQL requires every row in a table to have the same shape, and product specs don't.

```
  ➜  Enter MongoDB.
```

---

### Refresher — The Document Model (~5 min)

**Diagram:** `diagrams/sql_vs_mongo.png`

Show this before touching mongosh. The left side is the schema participants just ran. The right side is the same product in MongoDB. Let the diagram do the work.

Concept mapping to anchor:

| SQL | MongoDB |
|-----|---------|
| Database | Database |
| Table | Collection |
| Row | Document |
| Column | Field (exists only where relevant) |
| `NULL` | Field simply absent |
| `ALTER TABLE` | `$set` on any document |
| `JOIN` | Embedded subdoc or app-layer `$in` lookup |

Three things to emphasize:
- **No fixed schema.** The laptop document and the monitor document live in the same collection with different shapes. That's not a bug — it's the design.
- **Fields are absent, not NULL.** The laptop document has no `resolution` field. It doesn't exist. There's no ghost column sitting there holding a NULL.
- **`_id` = `producto_id`.** That's the seam between the two systems. Every MongoDB document in this workshop has an `_id` that matches a row in Postgres.

---

### Setup — MongoDB environment

```
make reset-normalized   # clean Postgres with real productos table
make mongo-start        # start MongoDB container
make mongo-seed         # read Postgres catalog → insert into MongoDB
make mongosh            # open the shell
```

Verify the seed worked:
```js
db.productos.countDocuments()          // should match Postgres productos count
db.productos.findOne({ categoria: "Laptops" })
```

---

### Exercise 14 — The Document Model (~8 min)

**Diagram:** `diagrams/hybrid_architecture.png`

Show the diagram before running anything. Establish the two-system picture: Postgres owns the left side, MongoDB owns the right, `producto_id` / `_id` is the shared key.

```
// in mongosh
load('mongo/01_document_model.js')
```

Key points:
- Drop the demo collection first, then insert 4 products — one per category. Each document has a `specs` subdocument with a different shape.
- Point at a laptop doc and a monitor doc side by side. No NULLs. No columns that don't belong. Each document carries exactly what it needs.
- `_id` equals `producto_id` from Postgres. That's the contract between the two systems.
- Adding keyboard specs next sprint = insert documents with a `specs.switch_type` field. No `ALTER TABLE`. No migration. Existing documents are unaffected.

**Discussion question:** If a product has no specs yet, what does its document look like? (Just omit the `specs` field — the document is still valid.)

---

### Exercise 15 — CRUD (~8 min)

```
load('mongo/02_crud.js')
```

Key points:
- `insertOne` — point out the document has a `specs` subdocument with fields no other category uses. No schema to conform to.
- `find` with projection — second argument controls which fields come back. `1` = include, `0` = exclude. `_id: 0` suppresses the id.
- `updateOne` with `$set` and `$inc` — `$set` adds or updates a field without touching anything else. Compare to SQL: `UPDATE productos SET precio = 139.99` would require knowing all other columns. `$inc` modifies a numeric field atomically.
- `deleteOne` — removes one matching document.

**Discussion question:** `$set` can add a field to one document that no other document has. Is that a feature or a risk?

---

### Exercise 16 — Querying (~10 min)

```
load('mongo/03_querying.js')
```

Key points:
- **Dot notation** — `"specs.ram_gb": { $gte: 16 }` reaches into the nested subdocument. No JOIN. Point back to the EAV query that needed 3 self-joins and a TEXT cast to do the same thing.
- **Array field** — `"specs.ports": "USB-C"` matches any document where the `ports` array contains `"USB-C"`. MongoDB treats array membership as equality.
- **`$exists`** — finds documents that have a field, regardless of value. Useful for cross-category queries where not all documents have the same fields.
- **`$in`** — equivalent of SQL `IN (...)`. Works on any field including `_id` — which is how the hybrid lookup in Exercise 18 works.

Pause here and show the timing difference vs. the EAV query from Exercise 13. Run the EAV query in pgcli (`\timing on`) then run the equivalent MongoDB query in mongosh. The gap makes the point.

---

### Exercise 17 — Aggregation Pipeline (~10 min)

```
load('mongo/04_aggregation.js')
```

Build the pipeline one stage at a time — run it after each addition so participants see the transformation:

| Stage | SQL equivalent |
|-------|---------------|
| `$match` | `WHERE` |
| `$group` | `GROUP BY` + aggregate functions |
| `$sort` | `ORDER BY` |
| `$project` | `SELECT` — reshape, rename, compute fields |
| `$unwind` | Explode an array field into one doc per element |

Key points:
- Each stage receives the output of the previous stage — it's a pipeline, not a query.
- `$project` can compute new fields: `{ $multiply: ["$precio", 0.9] }` — no subquery needed.
- `$unwind` on `specs.ports` turns one monitor document with 3 ports into 3 documents, one per port. Useful for counting or filtering on array contents.

**Discussion question:** What's the equivalent of a SQL `HAVING` clause in MongoDB? (`$match` after a `$group` stage.)

---

### Exercise 18 — The Hybrid System (~10 min)

**Diagram:** `diagrams/hybrid_architecture.png` — back to this one.

```
load('mongo/05_hybrid.js')
```

Walk through the 3-step flow shown in the diagram:

1. **SQL** — fetch `items_pedido` for an order. Get `producto_ids`.
2. **MongoDB** — `find({ _id: { $in: producto_ids } })`. One query, any number of products.
3. **Merge** — application layer joins the two result sets by `producto_id` / `_id`.

Key points:
- Neither system knows about the other. Postgres has no idea MongoDB exists. MongoDB has no idea about `pedidos`.
- The application layer owns the join. That's intentional — it keeps each system focused on what it does best.
- Postgres guaranteed the transaction: stock was decremented atomically, the order total is correct, the customer record is normalized.
- MongoDB provided the catalog: each product had its own spec shape, no NULLs, no migrations.
- The only contract: `producto_id` is the same value in both systems. That's the seam.

**Closing point for the module:**

| Postgres | MongoDB |
|----------|---------|
| Orders, payments, inventory | Product catalog, specs |
| ACID transactions | Flexible document shape |
| Referential integrity | Schema-free per document |
| Strong consistency | Fast catalog reads |
| `producto_id` FK | `_id` = same value |

Neither system is "better." They solve different problems. The skill is knowing which problem you have.

---

### Exercise 19 — Closing the Loop (~5 min)

```
load('mongo/06_closing_the_loop.js')
```

Callback to the PM ticket from the top of the module:

> "Hey, can we show laptop RAM, CPU, and screen size on the product page? Also monitor resolution and panel type, and mouse DPI and whether it's wireless. Should be easy right? 😊"

Key points:
- Three `find()` calls — one per category. No JOINs, no migrations, no NULLs.
- The script also shows the **next sprint** (keyboard specs): `$updateMany` adds `specs.backlit` to every keyboard document. Laptop, monitor, and mouse documents are completely unaffected.
- Score at the end: schema migrations required = 0, `ALTER TABLE` statements = 0, NULL columns added = 0.

**Final message to leave participants with:**

> The PM's ticket took three queries.  
> The next sprint took one `$updateMany`.  
> The problem was never the developers — it was using the wrong tool for the shape of the data.

---

> **Useful mongosh reminders to share with students:**
> - `show dbs` — list databases
> - `use workshop` — switch database
> - `show collections` — list collections
> - `db.collection.find().pretty()` — formatted output
> - `db.collection.countDocuments()` — count
> - `db.collection.findOne()` — first document
> - `load('file.js')` — run a script file
> - `exit` — quit

---

> **Useful pgcli reminders to share with students:**
> - `\dt` — list tables
> - `\d tablename` — describe a table
> - `\di` — list indexes
> - `\timing on/off` — show query time
> - `\i file.sql` — run a SQL file
> - `F3` — toggle multi-line mode
> - `\q` — quit
