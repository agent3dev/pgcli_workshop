#!/usr/bin/env python3
"""
Seed MongoDB product catalog from the normalized Postgres schema.
Reads productos + categorias from Postgres, generates category-specific
spec documents, inserts into MongoDB with _id = producto_id.

This is the bridge between the two systems — producto_id is the shared key.
"""

import os
import random
import psycopg2
import psycopg2.extras
from pymongo import MongoClient, ASCENDING
from pymongo.errors import BulkWriteError

# ── connections ───────────────────────────────────────────────

def pg_connect():
    return psycopg2.connect(
        dbname=os.getenv('PGDATABASE', 'workshop'),
        user=os.getenv('PGUSER', 'workshop_user'),
        password=os.getenv('PGPASSWORD', 'workshop_pass'),
        host=os.getenv('PGHOST', 'localhost'),
        port=os.getenv('PGPORT', '5432'),
    )

def mongo_connect():
    host = os.getenv('MONGO_HOST', 'localhost')
    port = int(os.getenv('MONGO_PORT', '27017'))
    return MongoClient(host, port)

# ── spec generators — one per category ───────────────────────

def specs_laptop(nombre):
    return {
        'ram_gb':        random.choice([8, 16, 32, 64]),
        'cpu':           random.choice([
            'Intel Core i5-1335U', 'Intel Core i7-1355U',
            'AMD Ryzen 5 7530U',   'AMD Ryzen 7 7730U',
            'Apple M2',            'Apple M3 Pro',
        ]),
        'storage_gb':    random.choice([256, 512, 1024, 2048]),
        'screen_inch':   random.choice([13.3, 14.0, 15.6, 16.0, 17.3]),
        'os':            random.choice(['Windows 11', 'macOS', 'ChromeOS', 'Ubuntu']),
        'battery_hours': random.randint(6, 18),
        'weight_kg':     round(random.uniform(1.1, 2.8), 1),
    }

def specs_monitor(nombre):
    return {
        'resolution':  random.choice(['1920x1080', '2560x1440', '3840x2160', '2560x1080']),
        'panel_type':  random.choice(['IPS', 'VA', 'TN', 'OLED']),
        'refresh_hz':  random.choice([60, 75, 144, 165, 240]),
        'size_inch':   random.choice([24, 27, 32, 34, 49]),
        'ports':       random.sample(['HDMI 2.0', 'HDMI 2.1', 'DisplayPort 1.4',
                                      'USB-C', 'VGA', 'USB-A hub'], k=random.randint(2, 4)),
        'hdr':         random.choice([True, False]),
    }

def specs_mouse(nombre):
    return {
        'dpi':         random.choice([400, 800, 1600, 3200, 12000, 25600]),
        'wireless':    random.choice([True, False]),
        'sensor_type': random.choice(['Optical', 'Laser', 'HERO 25K', 'Focus Pro']),
        'buttons':     random.choice([3, 5, 6, 7, 11]),
        'rgb':         random.choice([True, False]),
    }

def specs_teclado(nombre):
    return {
        'switch_type':   random.choice(['Cherry MX Red', 'Cherry MX Blue',
                                        'Cherry MX Brown', 'Gateron Yellow',
                                        'Membrane', 'Scissor']),
        'actuation_g':   random.choice([35, 45, 55, 60]),
        'layout':        random.choice(['Full', 'TKL', '75%', '65%', '60%']),
        'wireless':      random.choice([True, False]),
        'rgb':           random.choice([True, False]),
    }

def specs_webcam(nombre):
    return {
        'resolution':  random.choice(['720p', '1080p', '4K']),
        'fps':         random.choice([30, 60]),
        'autofocus':   random.choice([True, False]),
        'mic':         random.choice([True, False]),
    }

def specs_periférico(nombre):
    nombre_lower = nombre.lower()
    if any(k in nombre_lower for k in ['mouse', 'ratón']):
        return specs_mouse(nombre)
    elif any(k in nombre_lower for k in ['teclado', 'keyboard']):
        return specs_teclado(nombre)
    elif 'webcam' in nombre_lower:
        return specs_webcam(nombre)
    else:
        return {'tipo': 'accesorio', 'wireless': random.choice([True, False])}

def specs_almacenamiento(nombre):
    nombre_lower = nombre.lower()
    if 'ssd' in nombre_lower:
        return {
            'tipo':          'SSD',
            'capacity_gb':   random.choice([256, 512, 1024, 2048, 4096]),
            'interface':     random.choice(['SATA III', 'NVMe PCIe 3.0', 'NVMe PCIe 4.0']),
            'read_mbps':     random.randint(500, 7400),
            'write_mbps':    random.randint(400, 6900),
        }
    elif 'hdd' in nombre_lower:
        return {
            'tipo':          'HDD',
            'capacity_gb':   random.choice([500, 1000, 2000, 4000, 8000]),
            'rpm':           random.choice([5400, 7200]),
            'interface':     'SATA III',
        }
    else:
        return {
            'tipo':        'Flash',
            'capacity_gb': random.choice([32, 64, 128, 256, 512]),
            'interface':   random.choice(['USB 3.0', 'USB-C', 'SD UHS-II']),
        }

def specs_redes(nombre):
    nombre_lower = nombre.lower()
    if 'router' in nombre_lower or 'access' in nombre_lower or 'repetidor' in nombre_lower:
        return {
            'wifi_standard': random.choice(['WiFi 5 (ac)', 'WiFi 6 (ax)', 'WiFi 6E']),
            'max_mbps':      random.choice([300, 600, 1200, 3000, 6000]),
            'ports':         random.randint(2, 8),
            'bands':         random.choice(['Single', 'Dual', 'Tri']),
        }
    elif 'switch' in nombre_lower:
        return {
            'ports':     random.choice([5, 8, 16, 24, 48]),
            'speed':     random.choice(['100Mbps', '1Gbps', '10Gbps']),
            'managed':   random.choice([True, False]),
            'poe':       random.choice([True, False]),
        }
    else:
        return {
            'speed':   random.choice(['100Mbps', '1Gbps', '10Gbps']),
            'length_m': random.choice([1, 2, 3, 5, 10, 20]),
        }

def specs_audio(nombre):
    nombre_lower = nombre.lower()
    if any(k in nombre_lower for k in ['auricular', 'headphone']):
        return {
            'tipo':       'Auriculares',
            'wireless':   random.choice([True, False]),
            'noise_cancel': random.choice([True, False]),
            'freq_hz':    f'{random.randint(10, 20)}-{random.randint(18000, 40000)}',
            'mic':        random.choice([True, False]),
        }
    elif any(k in nombre_lower for k in ['bocina', 'soundbar', 'speaker']):
        return {
            'tipo':      'Bocina',
            'watts':     random.choice([10, 20, 40, 80, 200, 400]),
            'bluetooth': random.choice([True, False]),
            'channels':  random.choice(['2.0', '2.1', '5.1', '7.1']),
        }
    else:
        return {
            'tipo':        'Micrófono',
            'pattern':     random.choice(['Cardioide', 'Omnidireccional', 'Bidireccional']),
            'connection':  random.choice(['USB', 'XLR']),
            'sample_hz':   random.choice([44100, 48000, 96000]),
        }

def specs_impresion(nombre):
    nombre_lower = nombre.lower()
    if any(k in nombre_lower for k in ['tóner', 'toner', 'cartucho']):
        return {
            'tipo':       'Consumible',
            'color':      random.choice(['Negro', 'Cian', 'Magenta', 'Amarillo', 'Color']),
            'pages':      random.randint(500, 10000),
        }
    return {
        'tipo':          random.choice(['Inkjet', 'Laser']),
        'pages_per_min': random.randint(5, 60),
        'color_print':   random.choice([True, False]),
        'duplex':        random.choice([True, False]),
        'wifi':          random.choice([True, False]),
        'scan':          'scanner' in nombre_lower or 'multifuncional' in nombre_lower,
    }

def specs_componente(nombre):
    nombre_lower = nombre.lower()
    if 'gpu' in nombre_lower:
        return {
            'tipo':      'GPU',
            'vram_gb':   random.choice([4, 6, 8, 12, 16, 24]),
            'tdp_watts': random.choice([75, 115, 150, 200, 250, 350]),
            'connector': random.choice(['PCIe 3.0 x16', 'PCIe 4.0 x16']),
            'outputs':   random.sample(['HDMI 2.1', 'DisplayPort 1.4a', 'VGA'], k=random.randint(2, 3)),
        }
    elif 'cpu' in nombre_lower:
        return {
            'tipo':       'CPU',
            'cores':      random.choice([4, 6, 8, 12, 16, 24, 32]),
            'threads':    None,  # will be set below
            'base_ghz':   round(random.uniform(2.4, 4.0), 1),
            'boost_ghz':  round(random.uniform(4.0, 6.0), 1),
            'socket':     random.choice(['LGA1700', 'AM5', 'AM4']),
            'tdp_watts':  random.choice([35, 65, 95, 105, 125]),
        }
    elif 'ram' in nombre_lower:
        return {
            'tipo':       'RAM',
            'capacity_gb': random.choice([8, 16, 32, 64]),
            'speed_mhz':  random.choice([3200, 3600, 4800, 5600, 6000]),
            'type':       random.choice(['DDR4', 'DDR5']),
            'modules':    random.choice([1, 2]),
        }
    elif 'placa' in nombre_lower:
        return {
            'tipo':    'Motherboard',
            'socket':  random.choice(['LGA1700', 'AM5', 'AM4']),
            'chipset': random.choice(['Z790', 'B760', 'X670E', 'B650']),
            'form':    random.choice(['ATX', 'mATX', 'ITX']),
            'ram_slots': random.choice([2, 4]),
        }
    else:
        return {'tipo': 'Componente'}

SPEC_GENERATORS = {
    'Laptops':       specs_laptop,
    'Periféricos':   specs_periférico,
    'Monitores':     specs_monitor,
    'Almacenamiento': specs_almacenamiento,
    'Redes':         specs_redes,
    'Audio':         specs_audio,
    'Impresión':     specs_impresion,
    'Componentes':   specs_componente,
}

# ── main ──────────────────────────────────────────────────────

def main():
    print("=" * 55)
    print("  MONGO SEED — Workshop Módulo 3")
    print("  Reading from Postgres → Writing to MongoDB")
    print("=" * 55)

    pg = pg_connect()
    cur = pg.cursor(cursor_factory=psycopg2.extras.RealDictCursor)

    mongo = mongo_connect()
    db = mongo['workshop']
    col = db['productos']

    # Clear existing
    col.drop()
    print("\n  🗑  Dropped existing collection")

    # Load categories map
    cur.execute("SELECT categoria_id, nombre FROM categorias")
    categorias = {r['categoria_id']: r['nombre'] for r in cur.fetchall()}
    print(f"  📂  {len(categorias)} categories loaded from Postgres")

    # Stream products in batches
    cur.execute("""
        SELECT producto_id, nombre, descripcion, precio, stock, categoria_id, activo
        FROM   productos
        ORDER  BY producto_id
    """)

    batch = []
    total = 0
    BATCH_SIZE = 2000

    for row in cur:
        cat_nombre = categorias.get(row['categoria_id'], 'Otros')
        gen = SPEC_GENERATORS.get(cat_nombre)
        specs = gen(row['nombre']) if gen else {}

        # CPU threads derived from cores
        if cat_nombre == 'Componentes' and 'cores' in specs:
            specs['threads'] = specs['cores'] * 2

        doc = {
            '_id':       row['producto_id'],   # shared key with Postgres
            'nombre':    row['nombre'],
            'descripcion': row['descripcion'],
            'precio':    float(row['precio']),
            'stock':     row['stock'],
            'activo':    row['activo'],
            'categoria': cat_nombre,
            'specs':     specs,
        }
        batch.append(doc)

        if len(batch) >= BATCH_SIZE:
            col.insert_many(batch, ordered=False)
            total += len(batch)
            print(f"    ✓ {total:,} documents inserted")
            batch = []

    if batch:
        col.insert_many(batch, ordered=False)
        total += len(batch)

    # Indexes
    print("\n  📇  Creating indexes...")
    col.create_index('categoria')
    col.create_index('precio')
    col.create_index([('categoria', ASCENDING), ('precio', ASCENDING)])
    col.create_index('activo')

    # Summary
    print(f"\n  Final count: {col.count_documents({}):,} documents")
    print("\n  By category:")
    for cat in sorted(categorias.values()):
        n = col.count_documents({'categoria': cat})
        print(f"    {cat:<20} {n:>8,}")

    print("\n✅ MongoDB seeded. Run mongo/01_document_model.js to start the demo.")
    print("=" * 55)

    cur.close()
    pg.close()
    mongo.close()


if __name__ == '__main__':
    main()
