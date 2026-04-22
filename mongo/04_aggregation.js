// ============================================================
// 04 — AGGREGATION PIPELINE
// The MongoDB equivalent of GROUP BY, HAVING, JOIN.
// Each stage transforms the stream of documents.
// Runs against the real productos catalog (100k documents).
// ============================================================

// ── Stage by stage — build it up ─────────────────────────────

print("\n── Stage 1 only: $match (like WHERE) ──");
print("   Active products under $500 — count:\n");
print("   " + db.productos.countDocuments({ activo: true, precio: { $lt: 500 } }).toLocaleString() + " products");

print("\n── + Stage 2: $group (like GROUP BY) — price stats per category ──");
db.productos.aggregate([
  { $match: { activo: true } },
  {
    $group: {
      _id:             "$categoria",
      total_productos: { $sum: 1 },
      precio_promedio: { $avg: "$precio" },
      precio_min:      { $min: "$precio" },
      precio_max:      { $max: "$precio" }
    }
  },
  {
    $project: {
      total_productos: 1,
      precio_promedio: { $round: ["$precio_promedio", 2] },
      precio_min:      { $round: ["$precio_min", 2] },
      precio_max:      { $round: ["$precio_max", 2] }
    }
  },
  { $sort: { precio_promedio: -1 } }
]).forEach(printjson);

// ── $project — reshape documents ─────────────────────────────

print("\n── $project: cheapest laptop with 10% discount applied ──");
db.productos.aggregate([
  { $match:  { categoria: "Laptops", activo: true } },
  {
    $project: {
      nombre:           1,
      precio:           1,
      precio_con_10pct: { $round: [{ $multiply: ["$precio", 0.9] }, 2] },
      "specs.ram_gb":   1,
      _id:              0
    }
  },
  { $sort:  { precio: 1 } },
  { $limit: 3 }
]).forEach(printjson);

// ── $unwind — explode an array field ─────────────────────────

print("\n── $unwind: count monitors per port type ──");
db.productos.aggregate([
  { $match:   { categoria: "Monitores", "specs.ports": { $exists: true } } },
  { $unwind:  "$specs.ports" },
  { $group:   { _id: "$specs.ports", count: { $sum: 1 } } },
  { $sort:    { count: -1 } }
]).forEach(printjson);

// ── $match after $group — equivalent of HAVING ───────────────

print("\n── $match after $group (like HAVING): categories with 12k+ products ──");
db.productos.aggregate([
  { $group:  { _id: "$categoria", total: { $sum: 1 } } },
  { $match:  { total: { $gte: 12500 } } },
  { $sort:   { total: -1 } }
]).forEach(printjson);

print("\n✅ Aggregation done.");
print("   Each stage is a transformation: match → group → sort → project.");
print("   $unwind turns an array field into individual documents.");
print("   $match after $group = HAVING in SQL.");
