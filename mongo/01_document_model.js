// ============================================================
// 01 — THE DOCUMENT MODEL
// The answer to sql/13_sql_hits_a_wall.sql
//
// Same domain, same producto_id — different shape per category.
// No NULLs. No extra tables. No JOINs.
// ============================================================

// Use a separate demo collection — keeps the seeded 100k catalog intact
db.productos_demo.drop();

// ── Insert one document per category ─────────────────────────

db.productos_demo.insertMany([

  // Laptop — has RAM, CPU, storage, screen
  {
    _id: 1,
    nombre: "Dell Laptop Pro 900",
    precio: 899.99,
    stock: 45,
    categoria: "Laptops",
    specs: {
      ram_gb:        16,
      cpu:           "Intel Core i7-1355U",
      storage_gb:    512,
      screen_inch:   15.6,
      os:            "Windows 11",
      battery_hours: 10
    }
  },

  // Monitor — completely different shape, same collection
  {
    _id: 2,
    nombre: "LG Monitor Ultra 900",
    precio: 449.99,
    stock: 23,
    categoria: "Monitores",
    specs: {
      resolution:  "3840x2160",
      panel_type:  "IPS",
      refresh_hz:  144,
      ports:       ["HDMI 2.1", "DisplayPort 1.4", "USB-C"]
    }
  },

  // Mouse — yet another shape
  {
    _id: 3,
    nombre: "Logitech Mouse Elite 900",
    precio: 79.99,
    stock: 130,
    categoria: "Periféricos",
    specs: {
      dpi:         25600,
      wireless:    true,
      sensor_type: "HERO 25K",
      buttons:     7
    }
  },

  // GPU — its own shape
  {
    _id: 4,
    nombre: "ASUS GPU Turbo 900",
    precio: 1199.99,
    stock: 12,
    categoria: "Componentes",
    specs: {
      vram_gb:   12,
      tdp_watts: 200,
      connector: "PCIe 4.0 x16",
      outputs:   ["HDMI 2.1", "DisplayPort 1.4a", "DisplayPort 1.4a"]
    }
  }

]);

// ── Verify ────────────────────────────────────────────────────

print("\n── All documents (note different specs per category) ──");
db.productos_demo.find().forEach(doc => {
  print(`\n[${doc.categoria}] ${doc.nombre} — $${doc.precio}`);
  print("  specs: " + JSON.stringify(doc.specs, null, 2).replace(/\n/g, "\n  "));
});

print("\n✅ One collection. Four shapes. Zero NULLs.");
print("   No schema migration needed to add keyboard switch types next sprint.");
