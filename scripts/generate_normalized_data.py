#!/usr/bin/env python3
"""
Generate realistic normalized data for Module 2 workshop demos.
Targets: ~100k products, ~50k orders, ~5k clients, ~150k order items.
"""

import psycopg2
import psycopg2.extras
import os
import random
from datetime import datetime, timedelta

# ── connection ────────────────────────────────────────────────────────────────

def get_connection():
    return psycopg2.connect(
        dbname=os.getenv('PGDATABASE', 'workshop'),
        user=os.getenv('PGUSER', 'workshop_user'),
        password=os.getenv('PGPASSWORD', 'workshop_pass'),
        host=os.getenv('PGHOST', 'localhost')
    )

# ── data pools ────────────────────────────────────────────────────────────────

CATEGORIES = [
    ('Laptops',         'Computadoras portátiles y ultrabooks'),
    ('Periféricos',     'Teclados, ratones y accesorios de escritorio'),
    ('Monitores',       'Pantallas, displays y proyectores'),
    ('Almacenamiento',  'SSDs, HDDs, memorias USB y tarjetas SD'),
    ('Redes',           'Routers, switches, cables y access points'),
    ('Audio',           'Auriculares, bocinas y micrófonos'),
    ('Impresión',       'Impresoras, scanners y consumibles'),
    ('Componentes',     'CPUs, GPUs, memorias RAM y placas base'),
]

BRANDS   = ['Dell','HP','Lenovo','Asus','Acer','Apple','Samsung','LG',
            'Sony','Logitech','Corsair','Kingston','Seagate','WD','TP-Link',
            'Netgear','Bose','JBL','Canon','Epson']

ADJECTIVES = ['Pro','Ultra','Max','Plus','Elite','Gaming','Business',
              'Essential','Slim','Portable','Wireless','RGB','Turbo','Lite']

PRODUCT_BASES = {
    1: ['Laptop','Notebook','Ultrabook','Chromebook'],
    2: ['Teclado','Mouse','Mousepad','Webcam','Hub USB','Auriculares con cable'],
    3: ['Monitor','Pantalla','Display','Pantalla Curva'],
    4: ['SSD','HDD','USB','Memoria SD','NAS','SSD Portable'],
    5: ['Router','Switch','Access Point','Cable Ethernet','Firewall','Repetidor WiFi'],
    6: ['Auriculares','Bocina','Micrófono','Soundbar','Amplificador'],
    7: ['Impresora','Scanner','Multifuncional','Tóner','Cartucho'],
    8: ['CPU','GPU','RAM','Placa Base','Fuente de Poder','Cooler','Tarjeta de Red'],
}

FIRST_NAMES = ['María','Juan','Ana','Carlos','Laura','Pedro','Sofía','Diego',
               'Valentina','Andrés','Luis','Rosa','Miguel','Claudia','Jorge',
               'Patricia','Fernando','Isabel','Roberto','Carmen','Alejandro',
               'Gabriela','Héctor','Daniela','Ricardo','Marcela','Eduardo','Beatriz']

LAST_NAMES  = ['González','Martínez','Rodríguez','López','Sánchez','Pérez',
               'García','Hernández','Torres','Ramírez','Flores','Cruz','Morales',
               'Reyes','Jiménez','Ortiz','Vargas','Castillo','Romero','Gutiérrez']

CITIES = ['CDMX','Guadalajara','Monterrey','Puebla','Tijuana','Cancún',
          'León','Mérida','Querétaro','San Luis Potosí','Chihuahua','Aguascalientes']

STREETS = ['Av. Insurgentes','Paseo de la Reforma','Av. Juárez','Calle Morelos',
           'Blvd. Kukulcán','Av. Chapultepec','Calle 5 de Mayo','Av. Universidad',
           'Blvd. Agua Caliente','Av. Constitución','Calle Hidalgo','Av. Madero']

ESTADOS_PEDIDO = ['pendiente','procesando','enviado','entregado','cancelado']
ESTADO_WEIGHTS  = [0.15, 0.10, 0.15, 0.50, 0.10]

# ── helpers ───────────────────────────────────────────────────────────────────

def random_date(days_back=730):
    return datetime.now() - timedelta(days=random.randint(0, days_back))

def chunk(lst, size):
    for i in range(0, len(lst), size):
        yield lst[i:i+size]

# ── generators ────────────────────────────────────────────────────────────────

def seed_categories(cur):
    print("  📂 Categories...")
    psycopg2.extras.execute_values(
        cur,
        "INSERT INTO categorias (nombre, descripcion) VALUES %s ON CONFLICT (nombre) DO NOTHING",
        CATEGORIES
    )
    cur.execute("SELECT categoria_id FROM categorias ORDER BY categoria_id")
    return [r[0] for r in cur.fetchall()]


def seed_products(cur, category_ids, n=100_000):
    print(f"  📦 Products ({n:,})...")
    rows = []
    cat_map = {i+1: category_ids[i] for i in range(len(category_ids))}

    for i in range(n):
        cat_key = random.randint(1, len(PRODUCT_BASES))
        cat_id  = cat_map.get(cat_key, category_ids[0])
        base    = random.choice(PRODUCT_BASES[cat_key])
        brand   = random.choice(BRANDS)
        adj     = random.choice(ADJECTIVES)
        nombre  = f"{brand} {base} {adj} {random.randint(1,9)}00"
        desc    = f"{brand} {base} — {adj}. Modelo {2020 + random.randint(0,4)}."
        precio  = round(random.uniform(9.99, 2499.99), 2)
        stock   = random.randint(0, 500)
        activo  = random.random() > 0.08   # 92% active
        rows.append((nombre, desc, precio, stock, cat_id, activo))

        if (i + 1) % 20000 == 0:
            print(f"    ✓ {i+1:,}")

    for batch in chunk(rows, 5000):
        psycopg2.extras.execute_values(
            cur,
            "INSERT INTO productos (nombre, descripcion, precio, stock, categoria_id, activo) VALUES %s",
            batch
        )

    cur.execute("SELECT producto_id, precio FROM productos ORDER BY producto_id")
    return cur.fetchall()   # list of (producto_id, precio)


def seed_clients(cur, n=5_000):
    print(f"  👤 Clients ({n:,})...")
    rows = []
    for i in range(n):
        nombre = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
        email  = f"user{i+1}@workshop.com"
        phone  = f"+52-55-{random.randint(1000,9999)}-{random.randint(1000,9999)}"
        rows.append((nombre, email, phone))

    psycopg2.extras.execute_values(
        cur,
        "INSERT INTO clientes (nombre, email, telefono) VALUES %s ON CONFLICT (email) DO NOTHING",
        rows
    )
    cur.execute("SELECT cliente_id FROM clientes ORDER BY cliente_id")
    return [r[0] for r in cur.fetchall()]


def seed_addresses(cur, client_ids):
    print(f"  🏠 Addresses ({len(client_ids):,})...")
    rows = []
    for cid in client_ids:
        city = random.choice(CITIES)
        rows.append((
            cid,
            f"{random.choice(STREETS)} {random.randint(1,999)}",
            city,
            f"{random.randint(10000,99999)}",
            True
        ))

    psycopg2.extras.execute_values(
        cur,
        "INSERT INTO direcciones (cliente_id, calle, ciudad, codigo_postal, es_principal) VALUES %s",
        rows
    )
    cur.execute("SELECT cliente_id, direccion_id FROM direcciones WHERE es_principal = true")
    return {r[0]: r[1] for r in cur.fetchall()}   # {cliente_id: direccion_id}


def seed_orders_and_items(cur, client_ids, addr_map, products, n_orders=50_000):
    print(f"  🛒 Orders + items ({n_orders:,} orders)...")

    # Build orders
    order_rows = []
    for _ in range(n_orders):
        cid    = random.choice(client_ids)
        did    = addr_map.get(cid)
        fecha  = random_date(730)
        estado = random.choices(ESTADOS_PEDIDO, weights=ESTADO_WEIGHTS)[0]
        order_rows.append((cid, did, fecha, 0, estado))

    psycopg2.extras.execute_values(
        cur,
        "INSERT INTO pedidos (cliente_id, direccion_entrega_id, fecha_pedido, total, estado) VALUES %s",
        order_rows
    )
    cur.execute("SELECT pedido_id FROM pedidos ORDER BY pedido_id")
    order_ids = [r[0] for r in cur.fetchall()]

    # Build items
    print(f"  📋 Generating items...")
    item_rows   = []
    total_map   = {oid: 0.0 for oid in order_ids}

    for oid in order_ids:
        n_items = random.choices([1,2,3,4,5], weights=[30,35,20,10,5])[0]
        chosen  = random.sample(products, min(n_items, len(products)))
        for (pid, base_price) in chosen:
            qty      = random.randint(1, 5)
            price    = round(float(base_price) * random.uniform(0.9, 1.1), 2)
            price    = max(price, 0.01)
            total_map[oid] += qty * price
            item_rows.append((oid, pid, qty, price))

    for batch in chunk(item_rows, 5000):
        psycopg2.extras.execute_values(
            cur,
            "INSERT INTO items_pedido (pedido_id, producto_id, cantidad, precio_unitario) VALUES %s",
            batch
        )
        print(f"    ✓ items batch inserted")

    # Update totals
    print("  💰 Updating order totals...")
    cur.execute("""
        UPDATE pedidos p
        SET total = sub.t
        FROM (
            SELECT pedido_id, SUM(subtotal) AS t
            FROM items_pedido
            GROUP BY pedido_id
        ) sub
        WHERE p.pedido_id = sub.pedido_id
    """)

    print(f"    ✓ {len(item_rows):,} items total")


# ── main ──────────────────────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print("  NORMALIZED DATA GENERATOR — Workshop Módulo 2")
    print("  100k products · 5k clients · 50k orders")
    print("=" * 55)

    conn = get_connection()
    cur  = conn.cursor()

    try:
        # Check if data already exists
        cur.execute("SELECT COUNT(*) FROM productos")
        existing = cur.fetchone()[0]
        if existing > 100:
            print(f"\n⚠️  productos already has {existing:,} rows — clearing normalized tables first...")
            cur.execute("TRUNCATE items_pedido, pedidos, productos, direcciones, clientes, categorias RESTART IDENTITY CASCADE")
            conn.commit()

        category_ids = seed_categories(cur); conn.commit()
        products     = seed_products(cur, category_ids, n=100_000); conn.commit()
        client_ids   = seed_clients(cur, n=5_000); conn.commit()
        addr_map     = seed_addresses(cur, client_ids); conn.commit()
        seed_orders_and_items(cur, client_ids, addr_map, products, n_orders=50_000); conn.commit()

        # Summary
        cur.execute("""
            SELECT 'categorias' AS t, COUNT(*) FROM categorias
            UNION ALL SELECT 'clientes',    COUNT(*) FROM clientes
            UNION ALL SELECT 'productos',   COUNT(*) FROM productos
            UNION ALL SELECT 'pedidos',     COUNT(*) FROM pedidos
            UNION ALL SELECT 'items_pedido',COUNT(*) FROM items_pedido
        """)
        print("\n  Final row counts:")
        for table, count in cur.fetchall():
            print(f"    {table:<15} {count:>10,}")

        print("\n✅ Done! Run sql/03_indexes.sql to see the performance impact.")
        print("=" * 55)

    except Exception as e:
        conn.rollback()
        print(f"\n❌ Error: {e}")
        raise
    finally:
        cur.close()
        conn.close()


if __name__ == "__main__":
    main()
