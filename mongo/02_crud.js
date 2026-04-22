// ============================================================
// 02 — CRUD IN MONGOSH
// insertOne, findOne, updateOne, deleteOne — the basics.
// Runs against productos_demo (4 controlled docs from script 01).
// ============================================================

// ── CREATE ────────────────────────────────────────────────────

print("\n── insertOne ──");

db.productos_demo.insertOne({
  _id:      5,
  nombre:   "Corsair Teclado RGB 900",
  precio:   129.99,
  stock:    60,
  categoria: "Periféricos",
  specs: {
    switch_type:    "Cherry MX Red",
    actuation_g:    45,
    rgb:            true,
    layout:         "TKL",
    wireless:       false
  }
});

// ── READ ──────────────────────────────────────────────────────

print("\n── findOne by _id ──");
printjson(db.productos_demo.findOne({ _id: 5 }));

print("\n── find with filter + projection ──");
db.productos_demo.find(
  { categoria: "Laptops" },
  { nombre: 1, precio: 1, "specs.ram_gb": 1, _id: 0 }
).forEach(printjson);

// ── UPDATE ────────────────────────────────────────────────────

print("\n── updateOne: raise price and add a field ──");

db.productos_demo.updateOne(
  { _id: 5 },
  {
    $set:  { precio: 139.99, "specs.backlit": true },
    $inc:  { stock: -5 }
  }
);

printjson(db.productos_demo.findOne({ _id: 5 }));

// ── DELETE ────────────────────────────────────────────────────

print("\n── deleteOne ──");
db.productos_demo.deleteOne({ _id: 5 });

print("Remaining count: " + db.productos_demo.countDocuments());

print("\n✅ CRUD done.");
print("   $set adds or updates a field — no ALTER TABLE needed.");
print("   $inc modifies a numeric field atomically.");
