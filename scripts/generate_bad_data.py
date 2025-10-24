#!/usr/bin/env python3
"""
Generate intentionally bad denormalized data for workshop
"""

from faker import Faker
import psycopg2
import psycopg2.extras
import os
from datetime import datetime, timedelta
import random
import argparse

fake = Faker(['es_ES'])

def get_connection():
    """Get database connection"""
    return psycopg2.connect(
        dbname=os.getenv('PGDATABASE', 'workshop'),
        user=os.getenv('PGUSER', 'workshop_user'),
        password=os.getenv('PGPASSWORD', 'workshop_pass'),
        host=os.getenv('PGHOST', 'localhost')
    )

def generate_products(conn, num_products=100000):
    """Generate products with categories"""
    print(f"📦 Generating {num_products:,} products...")

    cur = conn.cursor()

    # Categories dict (no table in bad schema)
    categories = {
        1: 'Electronics',
        2: 'Clothing',
        3: 'Home',
        4: 'Sports',
        5: 'Books',
        6: 'Toys',
        7: 'Beauty',
        8: 'Automotive'
    }

    # Product names by category
    product_names = {
        1: ['Laptop', 'Smartphone', 'Tablet', 'Monitor', 'Keyboard', 'Mouse', 'Headphones'],
        2: ['T-Shirt', 'Jeans', 'Jacket', 'Shoes', 'Hat', 'Socks', 'Dress'],
        3: ['Chair', 'Table', 'Lamp', 'Bed', 'Sofa', 'Fridge', 'Microwave'],
        4: ['Ball', 'Racket', 'Bike', 'Dumbbells', 'Yoga Mat', 'Treadmill', 'Swimsuit'],
        5: ['Novel', 'Textbook', 'Comic', 'Biography', 'Cookbook', 'Dictionary', 'Magazine'],
        6: ['Action Figure', 'Puzzle', 'Board Game', 'Doll', 'Lego', 'Teddy Bear', 'Remote Car'],
        7: ['Shampoo', 'Cream', 'Perfume', 'Makeup', 'Nail Polish', 'Hair Dryer', 'Brush'],
        8: ['Oil', 'Tires', 'Car Wash', 'Battery', 'Wipers', 'Tools', 'Mats']
    }

    brands = ['Sony', 'Samsung', 'LG', 'Apple', 'Dell', 'HP', 'Nike', 'Adidas', 'Zara', 'H&M']
    adjectives = ['Premium', 'Pro', 'Ultra', 'Básico', 'Deluxe', 'Económico', 'Gaming', 'Profesional']

    # Generate all data
    data = []
    for i in range(num_products):
        cat_id = random.choice(list(categories.keys()))
        cat_name = categories[cat_id]
        base_name = random.choice(product_names[cat_id])
        brand = random.choice(brands)
        adj = random.choice(adjectives)

        nombre = f"{brand} {base_name} {adj}"
        descripcion = fake.text(max_nb_chars=200)
        precio = round(random.uniform(10, 2000), 2)
        stock = random.randint(0, 500)
        activo = random.choice([True, True, True, False])  # 75% active

        data.append((nombre, descripcion, precio, stock, cat_id, cat_name, activo))

        if (i + 1) % 10000 == 0:
            print(f"  ✓ {i + 1:,} products...")

    # Insert using execute_values
    psycopg2.extras.execute_values(
        cur,
        "INSERT INTO productos_bad (nombre, descripcion, precio, stock, categoria_id, categoria_nombre, activo) VALUES %s",
        data
    )
    conn.commit()

    cur.close()
    print(f"  ✅ {num_products:,} products created")

def generate_bad_orders(conn, num_orders=50000):
    """Generate intentionally denormalized orders"""
    print(f"📋 Generating {num_orders:,} denormalized orders...")

    cur = conn.cursor()

    # Generate some "customers" (repeated data!)
    customers = []
    for _ in range(20000):
        customers.append({
            'nombre': fake.name(),
            'email': fake.email(),
            'telefono': fake.phone_number(),
            'direccion': fake.address(),
            'ciudad': fake.city(),
            'codigo_postal': fake.postcode()
        })

    products_sample = []
    for _ in range(1000):
        products_sample.append({
            'nombre': fake.word().capitalize() + ' ' + fake.word(),
            'descripcion': fake.text(max_nb_chars=100),
            'precio': round(random.uniform(10, 500), 2)
        })

    batch_size = 1000
    for batch in range(0, num_orders, batch_size):
        values = []
        for i in range(min(batch_size, num_orders - batch)):
            # REPEAT customer data (bad!)
            customer = random.choice(customers)

            # Random products
            prod1 = random.choice(products_sample)
            prod2 = random.choice(products_sample) if random.random() > 0.3 else None
            prod3 = random.choice(products_sample) if random.random() > 0.7 else None

            fecha = fake.date_time_between(start_date='-1y')
            cantidad1 = random.randint(1, 5)
            total = prod1['precio'] * cantidad1

            order_data = [
                customer['nombre'],
                customer['email'],
                customer['telefono'],
                customer['direccion'],
                customer['ciudad'],
                customer['codigo_postal'],
                prod1['nombre'],
                prod1['descripcion'],
                prod1['precio'],
                cantidad1
            ]

            if prod2:
                cantidad2 = random.randint(1, 3)
                total += prod2['precio'] * cantidad2
                order_data.extend([
                    prod2['nombre'],
                    prod2['descripcion'],
                    prod2['precio'],
                    cantidad2
                ])
            else:
                order_data.extend([None, None, None, None])

            if prod3:
                cantidad3 = random.randint(1, 2)
                total += prod3['precio'] * cantidad3
                order_data.extend([
                    prod3['nombre'],
                    prod3['descripcion'],
                    prod3['precio'],
                    cantidad3
                ])
            else:
                order_data.extend([None, None, None, None])

            order_data.extend([fecha, total, random.choice(['pendiente', 'procesando', 'enviado', 'entregado'])])

            values.append(cur.mogrify(
                "(%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s)",
                tuple(order_data)
            ).decode('utf-8'))

        query = f"""
        INSERT INTO pedidos_completos
        (cliente_nombre, cliente_email, cliente_telefono, cliente_direccion, cliente_ciudad, cliente_codigo_postal,
         producto1_nombre, producto1_descripcion, producto1_precio, producto1_cantidad,
         producto2_nombre, producto2_descripcion, producto2_precio, producto2_cantidad,
         producto3_nombre, producto3_descripcion, producto3_precio, producto3_cantidad,
         fecha_pedido, total, estado)
        VALUES {','.join(values)}
        """
        cur.execute(query)
        conn.commit()

        if (batch + batch_size) % 10000 == 0:
            print(f"  ✓ {batch + batch_size:,} orders...")

    cur.close()
    print(f"  ✅ {num_orders:,} denormalized orders created")

def generate_simple_orders(conn, num_orders=50000):
    """Generate simple orders for the pedidos table"""
    print(f"📋 Generating {num_orders:,} simple orders...")

    cur = conn.cursor()

    batch_size = 1000
    for batch in range(0, num_orders, batch_size):
        values = []
        for i in range(min(batch_size, num_orders - batch)):
            cliente_id = random.randint(1, 5000)
            fecha = fake.date_time_between(start_date='-1y')
            total = round(random.uniform(20, 2000), 2)
            estado = random.choice(['pendiente', 'procesando', 'enviado', 'entregado', 'cancelado'])

            values.append(
                cur.mogrify("(%s, %s, %s, %s)", (cliente_id, fecha, total, estado)).decode('utf-8')
            )

        query = f"INSERT INTO pedidos_bad (cliente_id, fecha_pedido, total, estado) VALUES {','.join(values)}"
        cur.execute(query)
        conn.commit()

        if (batch + batch_size) % 10000 == 0:
            print(f"  ✓ {batch + batch_size:,} orders...")

    cur.close()
    print(f"  ✅ {num_orders:,} simple orders created")

def main():
    parser = argparse.ArgumentParser(description="Generate bad data for database workshop")
    parser.add_argument('-p', '--products', type=int, default=500000, help='Number of products to generate')
    parser.add_argument('-o', '--orders', type=int, default=200000, help='Number of orders to generate')

    args = parser.parse_args()

    print("=" * 50)
    print("DATA GENERATOR - Workshop de Bases de Datos")
    print(f"Products: {args.products:,}")
    print(f"Orders: {args.orders:,}")
    print("=" * 50)
    print()

    conn = get_connection()

    try:
        # Generate products
        generate_products(conn, num_products=args.products)
        print()

        # Generate denormalized orders
        generate_bad_orders(conn, num_orders=args.orders)
        print()

        # Generate simple orders
        generate_simple_orders(conn, num_orders=args.orders)
        print()

        print("=" * 50)
        print("✅ DATA GENERATION COMPLETE!")
        print("=" * 50)

    except Exception as e:
        print(f"\n❌ Error: {e}")
        conn.rollback()
        raise
    finally:
        conn.close()

if __name__ == "__main__":
    main()
