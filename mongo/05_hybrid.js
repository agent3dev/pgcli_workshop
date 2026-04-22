// ============================================================
// 05 — THE HYBRID SYSTEM
//
// mongosh alone can't query Postgres — the hybrid join
// lives in the application layer, which is the point.
//
// Run the full demo from a terminal:
//
//   make hybrid
//
// What it does:
//   1. Postgres query  — fetch a real order + items
//   2. Extract         — producto_ids from the items
//   3. MongoDB query   — find({ _id: { $in: producto_ids } })
//   4. Merge           — enrich each item with catalog specs
//   5. Print           — the full receipt
//
// You can also explore the catalog side here in mongosh:
// ============================================================

// ── What MongoDB holds for any given product ─────────────────

print("\n── Sample: one document per category (from seeded catalog) ──");

["Laptops", "Monitores", "Periféricos", "Componentes"].forEach(cat => {
  const doc = db.productos.findOne({ categoria: cat, activo: true });
  if (!doc) return;
  print(`\n[${cat}]  ${doc.nombre}  —  $${doc.precio}`);
  print("  specs: " + JSON.stringify(doc.specs));
});

// ── The $in pattern — how the app layer fetches multiple docs ─

print("\n── $in lookup: fetch catalog docs for a list of producto_ids ──");
print("   (this is exactly what scripts/hybrid_query.py runs)\n");

const sampleIds = db.productos.find({ activo: true }, { _id: 1 })
  .limit(3).toArray().map(d => d._id);

print("   producto_ids: " + JSON.stringify(sampleIds));

db.productos.find(
  { _id: { $in: sampleIds } },
  { nombre: 1, categoria: 1, precio: 1, _id: 1 }
).forEach(doc =>
  print(`   [${doc._id}] ${doc.nombre} (${doc.categoria})`)
);

print("\n── Run the full hybrid demo: ──");
print("   Exit mongosh (exit), then run:");
print("   make hybrid");
print("\n   It picks a random real order from Postgres and enriches");
print("   it with MongoDB catalog specs. Different result every run.");
