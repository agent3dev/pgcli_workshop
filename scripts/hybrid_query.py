#!/usr/bin/env python3
"""
Hybrid query demo — Workshop Module 3, Exercise 18.

Simulates the application layer:
  1. Fetch a real order + items from Postgres
  2. Extract producto_ids
  3. Enrich with product specs from MongoDB
  4. Print the full receipt

This is the seam between the two systems.
"""

import os
import random
import psycopg2
import psycopg2.extras
from pymongo import MongoClient

# ── connections ───────────────────────────────────────────────

pg = psycopg2.connect(
    dbname=os.getenv('PGDATABASE', 'workshop'),
    user=os.getenv('PGUSER', 'workshop_user'),
    password=os.getenv('PGPASSWORD', 'workshop_pass'),
    host=os.getenv('PGHOST', 'localhost'),
    port=os.getenv('PGPORT', '5432'),
)
cur = pg.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

mongo = MongoClient(os.getenv('MONGO_HOST', 'localhost'),
                    int(os.getenv('MONGO_PORT', '27017')))
col = mongo['workshop']['productos']

# ── Step 1: pick a real order that has 2–4 items ─────────────

print("\n" + "=" * 55)
print("  HYBRID QUERY DEMO — Workshop Módulo 3")
print("=" * 55)

cur.execute("""
    SELECT p.pedido_id, c.nombre AS cliente, p.estado, p.total,
           p.fecha_pedido::date AS fecha
    FROM   pedidos p
    JOIN   clientes c ON c.cliente_id = p.cliente_id
    WHERE  p.estado IN ('enviado', 'entregado')
      AND  (SELECT COUNT(*) FROM items_pedido ip WHERE ip.pedido_id = p.pedido_id)
           BETWEEN 2 AND 4
    ORDER  BY RANDOM()
    LIMIT  1
""")
order = cur.fetchone()

print(f"\n── Step 1: fetch order from Postgres ──")
print(f"   SQL: SELECT pedido + cliente + estado WHERE items BETWEEN 2 AND 4\n")
print(f"   pedido_id : {order['pedido_id']}")
print(f"   cliente   : {order['cliente']}")
print(f"   estado    : {order['estado']}")
print(f"   fecha     : {order['fecha']}")
print(f"   total     : ${float(order['total']):,.2f}")

# ── Step 2: fetch items for that order ───────────────────────

cur.execute("""
    SELECT ip.producto_id, ip.cantidad,
           ip.precio_unitario, ip.subtotal
    FROM   items_pedido ip
    WHERE  ip.pedido_id = %s
    ORDER  BY ip.item_id
""", (order['pedido_id'],))
items = cur.fetchall()

product_ids = [row['producto_id'] for row in items]

print(f"\n── Step 2: extract producto_ids from items ──")
print(f"   {len(items)} items → producto_ids: {product_ids}")

# ── Step 3: MongoDB $in lookup ────────────────────────────────

print(f"\n── Step 3: MongoDB find({{ _id: {{ $in: {product_ids} }} }}) ──")

catalog = {}
for doc in col.find({'_id': {'$in': product_ids}}):
    catalog[doc['_id']] = doc

print(f"   {len(catalog)} catalog documents retrieved\n")

# ── Step 4: merge and print the enriched receipt ─────────────

print("─" * 55)
print(f"  ORDER #{order['pedido_id']}  —  {order['cliente']}")
print(f"  Status: {order['estado']}  |  Date: {order['fecha']}")
print("─" * 55)

for item in items:
    pid = item['producto_id']
    doc = catalog.get(pid, {})
    nombre    = doc.get('nombre', f'producto_id={pid}')
    categoria = doc.get('categoria', '—')
    specs     = doc.get('specs', {})

    print(f"\n  {nombre}")
    print(f"  Category : {categoria}")

    # Print specs selectively by category
    if categoria == 'Laptops':
        print(f"  Specs    : {specs.get('ram_gb')}GB RAM · {specs.get('cpu')} · {specs.get('screen_inch')}\"")
    elif categoria == 'Monitores':
        print(f"  Specs    : {specs.get('resolution')} · {specs.get('panel_type')} · {specs.get('refresh_hz')}Hz")
    elif categoria == 'Componentes' and 'vram_gb' in specs:
        print(f"  Specs    : {specs.get('vram_gb')}GB VRAM · {specs.get('tdp_watts')}W · {specs.get('connector')}")
    elif categoria == 'Almacenamiento':
        print(f"  Specs    : {specs.get('capacity_gb')}GB {specs.get('tipo')} · {specs.get('interface')}")
    elif specs:
        first_three = list(specs.items())[:3]
        print(f"  Specs    : {', '.join(f'{k}: {v}' for k, v in first_three)}")

    print(f"  Qty      : {item['cantidad']} × ${float(item['precio_unitario']):,.2f} = ${float(item['subtotal']):,.2f}")

print(f"\n  Order total : ${float(order['total']):,.2f}")
print("─" * 55)
print("\n  Postgres owned the transaction.")
print("  MongoDB owned the catalog.")
print("  The app layer joined them on producto_id / _id.")
print("=" * 55)

cur.close()
pg.close()
mongo.close()
