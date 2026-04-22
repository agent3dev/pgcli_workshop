// ============================================================
// 06 — CLOSING THE LOOP
//
// The PM's ticket from the start of the session:
//
//   "Hey, can we show laptop RAM, CPU, and screen size on the
//    product page? Also monitor resolution and panel type,
//    and mouse DPI and whether it's wireless. Should be easy
//    right? 😊"
//
// Let's answer it.
// ============================================================

// ── Laptop product page ───────────────────────────────────────

print("\n── Laptop product page data ──");
print("   (RAM, CPU, screen size — from the ticket)\n");

db.productos.find(
  { categoria: "Laptops", activo: true },
  { nombre: 1, precio: 1,
    "specs.ram_gb": 1, "specs.cpu": 1, "specs.screen_inch": 1,
    _id: 0 }
).sort({ precio: 1 }).limit(5).forEach(printjson);

// ── Monitor product page ──────────────────────────────────────

print("\n── Monitor product page data ──");
print("   (resolution, panel type — from the ticket)\n");

db.productos.find(
  { categoria: "Monitores", activo: true },
  { nombre: 1, precio: 1,
    "specs.resolution": 1, "specs.panel_type": 1, "specs.refresh_hz": 1,
    _id: 0 }
).sort({ precio: 1 }).limit(5).forEach(printjson);

// ── Mouse product page ────────────────────────────────────────

print("\n── Mouse product page data ──");
print("   (DPI, wireless — from the ticket)\n");

db.productos.find(
  { categoria: "Periféricos", "specs.dpi": { $exists: true }, activo: true },
  { nombre: 1, precio: 1,
    "specs.dpi": 1, "specs.wireless": 1,
    _id: 0 }
).sort({ precio: 1 }).limit(5).forEach(printjson);

// ── Sprint stats — how many products have each spec ───────────

print("\n── Coverage across the catalog ──\n");

const laptopCount   = db.productos.countDocuments({ categoria: "Laptops" });
const monitorCount  = db.productos.countDocuments({ categoria: "Monitores" });
const mouseCount    = db.productos.countDocuments({ categoria: "Periféricos", "specs.dpi": { $exists: true } });

print(`  Laptops with RAM/CPU/screen : ${laptopCount.toLocaleString()} products`);
print(`  Monitors with resolution    : ${monitorCount.toLocaleString()} products`);
print(`  Mice with DPI/wireless      : ${mouseCount.toLocaleString()} products`);
print(`  Total: ${(laptopCount + monitorCount + mouseCount).toLocaleString()} products covered`);
print(`  Schema migrations required  : 0`);
print(`  ALTER TABLE statements      : 0`);
print(`  NULL columns added          : 0`);

// ── Next sprint — keyboard specs ─────────────────────────────

print("\n── Next sprint: add keyboard specs ──");
print("   The PM's next message: keyboard switch type, actuation force, RGB\n");

// In SQL: ALTER TABLE productos ADD COLUMN switch_type VARCHAR(50);
//         ALTER TABLE productos ADD COLUMN actuation_g INT;
//         ALTER TABLE productos ADD COLUMN rgb BOOLEAN;
//         ... and 97% of rows get NULL

// In MongoDB: just insert keyboards with the fields they need
db.productos.updateMany(
  { categoria: "Periféricos", "specs.switch_type": { $exists: true } },
  { $set: { "specs.backlit": true } }
);

const keyboardCount = db.productos.countDocuments({
  categoria: "Periféricos", "specs.switch_type": { $exists: true }
});

print(`  Keyboards with switch specs already in catalog: ${keyboardCount.toLocaleString()}`);
print("  Adding 'backlit' field to all of them:\n");

db.productos.find(
  { categoria: "Periféricos", "specs.switch_type": { $exists: true } },
  { nombre: 1, "specs.switch_type": 1, "specs.rgb": 1, "specs.backlit": 1, _id: 0 }
).limit(3).forEach(printjson);

print("\n────────────────────────────────────────────────────────");
print("  Ticket delivered.");
print("");
print("  The PM asked for three things.");
print("  Three queries. No JOINs. No migrations. No NULLs.");
print("");
print("  Next sprint's keyboard specs: one $updateMany.");
print("  Existing laptop, monitor, and mouse documents:");
print("  completely unaffected.");
print("────────────────────────────────────────────────────────");
