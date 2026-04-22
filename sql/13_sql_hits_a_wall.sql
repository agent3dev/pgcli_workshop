-- ============================================================
-- 🧱 SQL HITS A WALL — Why the relational model fights you here
-- MongoDB Workshop — Opening Act
--
-- This is not a prototype. This is a production schema after
-- six months of feature requests — each sprint adding something
-- that seemed reasonable at the time.
--
-- Sprint 3:  "show laptop specs on the product page"
-- Sprint 7:  "add monitor resolution and panel type"
-- Sprint 11: "filter mice by DPI and wireless"
-- Sprint 14: "someone tried EAV for GPU specs"
-- Sprint 18: "new hire created per-category tables"
--
-- Nobody rolled anything back. Nobody ever does.
-- ============================================================

-- ── Sprint 3 — Laptop specs ───────────────────────────────────
-- Ticket: PROD-241 — Show RAM, CPU, storage on product page

ALTER TABLE productos ADD COLUMN IF NOT EXISTS ram_gb         INT;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS cpu            VARCHAR(100);
ALTER TABLE productos ADD COLUMN IF NOT EXISTS storage_gb     INT;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS screen_inch    DECIMAL(4,1);
ALTER TABLE productos ADD COLUMN IF NOT EXISTS os             VARCHAR(50);
ALTER TABLE productos ADD COLUMN IF NOT EXISTS battery_hours  INT;

-- ── Sprint 7 — Monitor specs ──────────────────────────────────
-- Ticket: PROD-389 — Show resolution and panel type for monitors

ALTER TABLE productos ADD COLUMN IF NOT EXISTS resolution     VARCHAR(20);
ALTER TABLE productos ADD COLUMN IF NOT EXISTS panel_type     VARCHAR(30);
ALTER TABLE productos ADD COLUMN IF NOT EXISTS refresh_hz     INT;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS ports          TEXT;

-- ── Sprint 11 — Mouse specs ───────────────────────────────────
-- Ticket: PROD-512 — Filter peripherals by DPI and wireless

ALTER TABLE productos ADD COLUMN IF NOT EXISTS dpi            INT;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS wireless       BOOLEAN;
ALTER TABLE productos ADD COLUMN IF NOT EXISTS sensor_type    VARCHAR(50);
ALTER TABLE productos ADD COLUMN IF NOT EXISTS buttons        INT;

\echo ''
\echo '── After Sprint 11: what does a laptop row look like? ──'

SELECT
    producto_id, nombre, precio,
    ram_gb, cpu, storage_gb,          -- Sprint 3 columns (filled for laptops)
    resolution, panel_type,           -- Sprint 7 columns (NULL for laptops)
    dpi, wireless                     -- Sprint 11 columns (NULL for laptops)
FROM productos
WHERE categoria_id = 1
LIMIT 3;

\echo ''
\echo '🔴 1NF violation — columns have no consistent meaning across rows.'
\echo '   Laptops carry NULL monitor and mouse columns. Always.'
\echo ''

-- ── Sprint 14 — GPU specs via EAV ────────────────────────────
-- Ticket: PROD-634 — GPU attributes vary too much, try EAV
-- (A different developer, different approach, same codebase.)

CREATE TABLE IF NOT EXISTS producto_atributos (
    producto_id  INT  NOT NULL REFERENCES productos(producto_id) ON DELETE CASCADE,
    atributo     TEXT NOT NULL,
    valor        TEXT NOT NULL,         -- everything is TEXT
    PRIMARY KEY (producto_id, atributo)
);

INSERT INTO producto_atributos (producto_id, atributo, valor)
SELECT producto_id, 'vram_gb',   '8'
FROM   productos WHERE categoria_id = 8   -- Componentes
ON CONFLICT DO NOTHING;

INSERT INTO producto_atributos (producto_id, atributo, valor)
SELECT producto_id, 'tdp_watts', '200'
FROM   productos WHERE categoria_id = 8
ON CONFLICT DO NOTHING;

\echo ''
\echo '── Sprint 14: top 5 GPUs with 8+ GB VRAM ──'

SELECT p.nombre, p.precio,
       vram.valor  AS vram_gb,
       tdp.valor   AS tdp_watts
FROM   productos p
JOIN   producto_atributos vram ON vram.producto_id = p.producto_id AND vram.atributo = 'vram_gb'
JOIN   producto_atributos tdp  ON tdp.producto_id  = p.producto_id AND tdp.atributo  = 'tdp_watts'
WHERE  p.categoria_id = 8
  AND  vram.valor::INT >= 8       -- cast TEXT to INT on every row
ORDER  BY p.precio DESC
LIMIT  5;

\echo ''
\echo '🔴 2 JOINs for 2 columns. valor is TEXT — no types, no constraints.'
\echo '   The planner cannot use statistics on a mixed-type TEXT column.'
\echo ''

-- ── Sprint 18 — Printer specs via category tables ─────────────
-- Ticket: PROD-801 — "Let's do it properly this time"
-- (Yet another developer, yet another approach.)

CREATE TABLE IF NOT EXISTS specs_impresoras (
    producto_id    INT PRIMARY KEY REFERENCES productos(producto_id),
    pages_per_min  INT,
    color_print    BOOLEAN,
    cartridge_type VARCHAR(50)
);

\echo ''
\echo '── Sprint 18: all products under $300 (laptops + printers) ──'

SELECT p.nombre, p.precio,
       p.ram_gb,                            -- Sprint 3 column (NULL for printers)
       si.pages_per_min, si.color_print     -- Sprint 18 table (NULL for laptops)
FROM   productos p
LEFT JOIN specs_impresoras si ON si.producto_id = p.producto_id
WHERE  p.precio < 300
ORDER  BY p.precio
LIMIT  10;

\echo ''
\echo '🔴 Three different approaches coexist in the same codebase:'
\echo '   - Nullable columns on productos (Sprints 3, 7, 11)'
\echo '   - EAV table producto_atributos (Sprint 14)'
\echo '   - Category spec table specs_impresoras (Sprint 18)'
\echo ''
\echo '── Current state of productos ──'

\d productos

\echo ''
\echo '────────────────────────────────────────────────────────'
\echo '  This is not a prototype. This is what the schema'
\echo '  looks like after 6 months. No one rolled anything back.'
\echo ''
\echo '  The problem is not the developers.'
\echo '  The problem is that SQL assumes every row has the'
\echo '  same shape — and product specs do not.'
\echo ''
\echo '  ➜  Enter MongoDB.'
\echo '────────────────────────────────────────────────────────'
\echo ''
\echo '  (Run `make reset-normalized` to restore the clean'
\echo '   normalized schema before the MongoDB demo.)'
