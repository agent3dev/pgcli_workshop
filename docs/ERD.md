# Entity Relationship Diagram — Workshop Schema

```mermaid
erDiagram
    clientes {
        SERIAL      cliente_id      PK
        VARCHAR100  nombre          "NOT NULL"
        VARCHAR100  email           "UNIQUE NOT NULL"
        VARCHAR20   telefono
        TIMESTAMP   fecha_registro  "DEFAULT now()"
    }

    direcciones {
        SERIAL      direccion_id    PK
        INT         cliente_id      FK
        TEXT        calle           "NOT NULL"
        VARCHAR50   ciudad          "NOT NULL"
        VARCHAR10   codigo_postal
        BOOLEAN     es_principal    "DEFAULT false"
        TIMESTAMP   fecha_creacion  "DEFAULT now()"
    }

    categorias {
        SERIAL      categoria_id    PK
        VARCHAR100  nombre          "UNIQUE NOT NULL"
        TEXT        descripcion
    }

    productos {
        SERIAL      producto_id     PK
        VARCHAR200  nombre          "NOT NULL"
        TEXT        descripcion
        DECIMAL102  precio          "CHECK > 0"
        INT         stock           "CHECK >= 0, DEFAULT 0"
        INT         categoria_id    FK
        TIMESTAMP   fecha_creacion  "DEFAULT now()"
        BOOLEAN     activo          "DEFAULT true"
    }

    pedidos {
        SERIAL      pedido_id           PK
        INT         cliente_id          FK
        INT         direccion_entrega_id FK "nullable"
        TIMESTAMP   fecha_pedido        "DEFAULT now()"
        DECIMAL102  total               "CHECK >= 0"
        VARCHAR20   estado              "DEFAULT 'pendiente'"
    }

    items_pedido {
        SERIAL      item_id          PK
        INT         pedido_id        FK
        INT         producto_id      FK
        INT         cantidad         "CHECK > 0"
        DECIMAL102  precio_unitario  "CHECK >= 0"
        DECIMAL102  subtotal         "GENERATED (cantidad * precio_unitario)"
    }

    clientes      ||--o{  direcciones   : "has"
    clientes      ||--o{  pedidos       : "places"
    direcciones   ||--o{  pedidos       : "ships to"
    categorias    ||--o{  productos     : "groups"
    pedidos       ||--o{  items_pedido  : "contains"
    productos     ||--o{  items_pedido  : "included in"
```

---

## Relationships

| From | To | Type | On Delete |
|------|----|------|-----------|
| `clientes` | `direcciones` | 1 to many | CASCADE |
| `clientes` | `pedidos` | 1 to many | RESTRICT |
| `direcciones` | `pedidos` | 1 to many (nullable) | RESTRICT |
| `categorias` | `productos` | 1 to many | RESTRICT |
| `pedidos` | `items_pedido` | 1 to many | CASCADE |
| `productos` | `items_pedido` | 1 to many | RESTRICT |

## Key Constraints

| Table | Column | Constraint |
|-------|--------|------------|
| `clientes` | `email` | UNIQUE |
| `categorias` | `nombre` | UNIQUE |
| `productos` | `precio` | CHECK > 0 |
| `productos` | `stock` | CHECK >= 0 |
| `pedidos` | `total` | CHECK >= 0 |
| `pedidos` | `estado` | CHECK IN ('pendiente','procesando','enviado','entregado','cancelado') |
| `items_pedido` | `cantidad` | CHECK > 0 |
| `items_pedido` | `subtotal` | GENERATED ALWAYS AS (cantidad * precio_unitario) |
