// ============================================================
// 03 — QUERYING
// Comparison, dot notation into nested specs, projection,
// sort, limit — the mongosh equivalents of WHERE, ORDER BY.
// Runs against the real productos catalog (100k documents).
// ============================================================

// ── Equality & comparison ─────────────────────────────────────

print("\n── Products under $200 (sample from 100k catalog) ──");
db.productos.find(
  { precio: { $lt: 200 }, activo: true },
  { nombre: 1, precio: 1, categoria: 1, _id: 0 }
).sort({ precio: 1 }).limit(5).forEach(printjson);

// ── Dot notation — query into nested specs ────────────────────

print("\n── Laptops with 32+ GB RAM ──");
print("   (in EAV: 3 self-joins + TEXT cast. Here: one find)\n");
db.productos.find(
  { categoria: "Laptops", "specs.ram_gb": { $gte: 32 }, activo: true },
  { nombre: 1, precio: 1, "specs.ram_gb": 1, "specs.cpu": 1, "specs.screen_inch": 1, _id: 0 }
).sort({ precio: 1 }).limit(5).forEach(printjson);

print("\n── 4K monitors with IPS panel ──");
db.productos.find(
  { categoria: "Monitores", "specs.resolution": "3840x2160", "specs.panel_type": "IPS" },
  { nombre: 1, precio: 1, "specs.resolution": 1, "specs.refresh_hz": 1, _id: 0 }
).sort({ precio: 1 }).limit(5).forEach(printjson);

// ── Array field — query inside ports list ─────────────────────

print("\n── Monitors with USB-C port ──");
db.productos.find(
  { "specs.ports": "USB-C" },
  { nombre: 1, "specs.ports": 1, _id: 0 }
).limit(3).forEach(printjson);

// ── $in — multiple values ─────────────────────────────────────

print("\n── Count by category (Laptops vs Monitores) ──");
["Laptops", "Monitores"].forEach(cat => {
  const n = db.productos.countDocuments({ categoria: cat, activo: true });
  print(`  ${cat}: ${n.toLocaleString()} active products`);
});

// ── $exists — products that have a specific spec ──────────────

print("\n── Wireless products (across all categories) ──");
db.productos.find(
  { "specs.wireless": true, activo: true },
  { nombre: 1, categoria: 1, precio: 1, _id: 0 }
).sort({ precio: 1 }).limit(5).forEach(printjson);

print("\n── Total wireless products in catalog: " +
  db.productos.countDocuments({ "specs.wireless": true }));

print("\n✅ Querying done.");
print("   Dot notation reaches into nested specs — no JOIN needed.");
print("   $exists finds documents regardless of category shape.");
print("   All queries run against 100k real documents.");
