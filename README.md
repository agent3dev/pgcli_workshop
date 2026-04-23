# Workshop de Bases de Datos
**PostgreSQL, SQL Fundamentals y MongoDB — Sistemas Híbridos**

Workshop práctico hands-on con PostgreSQL, MongoDB, Docker y pgcli.

---

## Objetivos

Al finalizar este workshop sabrás:

**Módulo 1 — Normalización e Índices**

1. Identificar problemas en esquemas denormalizados
2. Normalizar una base de datos hasta 3FN
3. Usar EXPLAIN para diagnosticar consultas lentas
4. Implementar índices apropiados (B-Tree, GIN, parciales)
5. Medir mejoras de rendimiento (antes/después)

**Módulo 2 — SQL Fundamentals**

6. DDL y DML: ALTER, INSERT RETURNING, DELETE con NOT EXISTS
7. JOINs: INNER, LEFT, multi-tabla, agregación
8. Vistas actualizables vs no-actualizables
9. Funciones SQL y PL/pgSQL
10. Procedures y state machines
11. Triggers de auditoría y validación
12. Transacciones, ROLLBACK, SAVEPOINTs y niveles de aislamiento

**Módulo 3 — MongoDB y Sistemas Híbridos**

13. Por qué el modelo relacional falla con datos de forma variable
14. El modelo de documentos: colecciones, campos, subdocumentos
15. CRUD en MongoDB: insertOne, find, updateOne, deleteOne
16. Querying: dot notation, arrays, `$exists`, `$in`
17. Aggregation pipeline: `$match`, `$group`, `$sort`, `$project`, `$unwind`
18. Sistema híbrido: PostgreSQL (transacciones) + MongoDB (catálogo)
19. Closing the loop: por qué la herramienta importa

---

## Setup Rápido

### Prerrequisitos

- Docker instalado (`sudo apt install docker.io`)
- Terminal/consola
- **¡Eso es todo!**

### Módulos 1 y 2 — Solo PostgreSQL

```bash
# Primera vez
sudo make setup
sudo make reset          # esquema malo (Módulo 1)
# o bien:
sudo make reset-normalized  # esquema normalizado (Módulo 2)

# Abrir shell SQL
sudo make shell
```

### Módulo 3 — Agregar MongoDB

Después de tener PostgreSQL con el esquema normalizado:

```bash
sudo make mongo-start    # levantar MongoDB
sudo make mongo-seed     # poblar MongoDB desde el catálogo de Postgres
sudo make mongosh        # abrir shell de MongoDB
```

Verificar que quedó bien:
```js
db.productos.countDocuments()                  // debe dar 100,000
db.productos.findOne({ categoria: "Laptops" }) // inspeccionar un documento
```

---

## Comandos Make

```bash
# PostgreSQL
sudo make setup              # construir + iniciar (primera vez)
sudo make build              # construir imagen
sudo make start              # iniciar contenedores
sudo make shell              # abrir pgcli (SQL shell con autocomplete)
sudo make psql               # abrir psql
sudo make pgadmin            # info de acceso a pgAdmin web (http://localhost:80)
sudo make reset              # esquema denormalizado — Módulo 1
sudo make reset-normalized   # esquema normalizado — Módulos 2 y 3
sudo make benchmark          # medir rendimiento de queries
sudo make logs               # ver logs de PostgreSQL
sudo make bash               # bash dentro del contenedor
sudo make stop               # detener contenedores
sudo make clean              # borrar todo (contenedores + datos)

# MongoDB
sudo make mongo-start        # levantar MongoDB
sudo make mongo-seed         # poblar desde Postgres (100k documentos)
sudo make mongosh            # abrir shell de MongoDB
sudo make mongo-stop         # detener MongoDB
sudo make hybrid             # demo de consulta híbrida Postgres + MongoDB
```

> Si agregaste tu usuario al grupo docker (`sudo usermod -aG docker $USER`), puedes omitir `sudo`.

---

## Comandos Útiles en pgcli

| Comando | Qué hace |
|---------|----------|
| `\dt` | Listar tablas |
| `\d tabla` | Describir tabla |
| `\di` | Listar índices |
| `\timing on/off` | Activar/desactivar cronómetro |
| `\i archivo.sql` | Ejecutar archivo SQL |
| `F3` | Alternar modo multi-línea |
| `\q` | Salir |

## Comandos Útiles en mongosh

| Comando | Qué hace |
|---------|----------|
| `show dbs` | Listar bases de datos |
| `use workshop` | Cambiar a la base workshop |
| `show collections` | Listar colecciones |
| `db.productos.find().pretty()` | Output formateado |
| `db.productos.countDocuments()` | Contar documentos |
| `db.productos.findOne()` | Primer documento |
| `load('mongo/archivo.js')` | Ejecutar un script |
| `exit` | Salir |

---

## Estructura del Proyecto

```
workshop/
├── Dockerfile
├── Makefile
├── README.md
├── reset-db.sh
├── benchmark.sh
│
├── sql/                          # Scripts SQL
│   ├── 00_extensions.sql
│   ├── 01_bad_schema.sql         # Esquema denormalizado (Módulo 1)
│   ├── 02_normalized_schema.sql  # Esquema normalizado (Módulos 2 y 3)
│   ├── 03_indexes.sql            # Índices
│   ├── 04_migration.sql          # Migración del esquema malo al normalizado
│   ├── 05_ddl.sql  →  12_transactions.sql   # Ejercicios Módulo 2
│   └── 13_sql_hits_a_wall.sql    # El problema que introduce MongoDB
│
├── mongo/                        # Scripts MongoDB (Módulo 3)
│   ├── 01_document_model.js      # Ejercicio 14 — modelo de documentos
│   ├── 02_crud.js                # Ejercicio 15 — CRUD
│   ├── 03_querying.js            # Ejercicio 16 — querying
│   ├── 04_aggregation.js         # Ejercicio 17 — aggregation pipeline
│   ├── 05_hybrid.js              # Ejercicio 18 — sistema híbrido
│   └── 06_closing_the_loop.js   # Ejercicio 19 — cierre
│
├── scripts/                      # Scripts Python
│   ├── generate_bad_data.py      # Datos para Módulo 1
│   ├── generate_normalized_data.py  # Datos para Módulos 2 y 3
│   ├── seed_mongo.py             # Poblar MongoDB desde Postgres
│   └── hybrid_query.py           # Demo consulta híbrida
│
├── diagrams/                     # Diagramas de arquitectura
│   ├── sql_vs_mongo.png
│   ├── hybrid_architecture.png
│   └── *.png / *.dot
│
└── docs/                         # Documentación
    ├── WORKSHOP_SCRIPT.md        # Guía completa auto-guiada
    ├── EXERCISES.md              # Ejercicios Módulos 1 y 2
    ├── EXERCISES_SQL_FUNDAMENTALS.md
    ├── SOLUTIONS.md
    └── SOLUTIONS_SQL_FUNDAMENTALS.md
```

---

## Conexión a PostgreSQL (herramientas externas)

```
Host:     localhost
Port:     5432
Database: workshop
User:     workshop_user
Password: workshop_pass
```

pgAdmin: http://localhost:80 · Email: `admin@workshop.com` · Password: `admin`

---

## Troubleshooting

### "permission denied" al ejecutar Docker

```bash
sudo make setup
# o agregar tu usuario al grupo docker:
sudo usermod -aG docker $USER && logout
```

### Contenedor no inicia

```bash
sudo make clean && sudo make setup
```

### PostgreSQL no responde

```bash
sudo make logs
sudo docker ps | grep workshop
```

### MongoDB no conecta desde mongosh

```bash
# Verificar que workshop-mongo está corriendo
docker ps | grep mongo
# Verificar que ambos contenedores están en la misma red
docker network inspect workshop-net
```

### Empezar de cero

```bash
sudo make clean       # borra contenedores y volúmenes
sudo make setup       # reconstruye
sudo make reset-normalized
sudo make mongo-start && sudo make mongo-seed
```

### Verificar datos cargados

En pgcli:
```sql
SELECT COUNT(*) FROM productos;   -- 100,000
SELECT COUNT(*) FROM pedidos;     -- 50,000
```

En mongosh:
```js
db.productos.countDocuments()     // 100,000
```

---

## Recursos Adicionales

- [Documentación PostgreSQL](https://www.postgresql.org/docs/)
- [pgcli](https://www.pgcli.com/)
- [EXPLAIN Visualizer](https://explain.dalibo.com/)
- [Documentación MongoDB](https://www.mongodb.com/docs/)

---

**Versión**: 3.0 | Fecha: 2026-04-23
