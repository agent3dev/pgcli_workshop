# Workshop de Bases de Datos
**Normalización y Optimización con Índices**

Workshop práctico hands-on con PostgreSQL, Docker y pgcli.

---

## 🎯 Objetivos

Al finalizar este workshop sabrás:

1. ✅ Identificar problemas en esquemas denormalizados
2. ✅ Normalizar una base de datos hasta 3FN
3. ✅ Usar EXPLAIN para diagnosticar consultas lentas
4. ✅ Implementar índices apropiados (B-Tree, GIN, parciales)
5. ✅ Medir mejoras de rendimiento (antes/después)
6. ✅ Comprender trade-offs de diferentes tipos de índices

---

## 🚀 Setup Rápido

### Prerrequisitos

**Recomendado**: Ubuntu 20.04+ o Debian-based Linux

- Docker instalado (`sudo apt install docker.io`)
- Terminal/consola
- **¡Eso es todo!**

### Instalación (3 pasos)

```bash
# 1. Descomprimir el workshop
unzip workshop.zip
cd workshop

# 2. Construir e iniciar (solo primera vez, tarda ~2 minutos)
sudo make setup

# 3. Cargar datos iniciales
sudo make reset
```

**¡Listo!** Ahora puedes empezar.

<details>
<summary>Método alternativo (separar build y start)</summary>

En lugar de `sudo make setup`, puedes ejecutar por separado:

```bash
sudo make build     # Construir imagen
sudo make start     # Crear y arrancar contenedor
sudo make reset     # Cargar datos
```
</details>

---

## 📚 Comandos Principales

```bash
sudo make setup      # Construir + iniciar (primera vez - hace todo!)
sudo make build      # Construir contenedor
sudo make start      # Iniciar workshop
sudo make shell      # Abrir pgcli (SQL shell with auto-complete)
sudo make pgadmin    # Abrir pgAdmin web interface
sudo make reset      # Resetear BD a estado inicial
sudo make benchmark  # Medir rendimiento de queries
sudo make logs       # Ver logs de PostgreSQL
sudo make stop       # Detener contenedor
sudo make clean      # Borrar todo (incluyendo datos)
```

> **Nota**: Si ya agregaste tu usuario al grupo docker (`sudo usermod -aG docker $USER`), puedes omitir `sudo` en todos los comandos.

---

## 📖 Comandos Útiles en pgcli

```sql
\?              -- Ayuda
\l              -- Listar bases de datos
\dt             -- Listar tablas
\d tabla        -- Describir tabla
\di             -- Listar índices
\timing on      -- Activar cronómetro
\x auto         -- Auto-expandir resultados
\q              -- Salir
\i archivo.sql  -- Ejecutar archivo SQL
```

---

## 📂 Estructura del Proyecto

```
workshop/
├── Dockerfile                  # Configuración del contenedor
├── Makefile                    # Comandos make
├── README.md                   # Este archivo
├── reset-db.sh                 # Script para resetear BD
├── benchmark.sh                # Script para medir rendimiento
│
├── sql/                        # Scripts SQL
│   ├── 00_extensions.sql      # Extensiones PostgreSQL
│   ├── 01_bad_schema.sql      # Schema malo (inicio)
│   ├── 02_normalized_schema.sql # Solución normalización
│   ├── 03_indexes.sql          # Solución índices
│   └── queries/
│       ├── slow.sql            # Queries sin optimizar
│       └── fast.sql            # Queries optimizadas
│
├── scripts/                    # Scripts Python
│   └── generate_bad_data.py   # Generador de datos
│
└── docs/                       # Documentación
    ├── EXERCISES.md            # Ejercicios guiados
    └── SOLUTIONS.md            # Soluciones completas
```

---

## 🐛 Troubleshooting

### Error: "permission denied" al ejecutar Docker

Si ves este error, asegúrate de usar `sudo`:

```bash
sudo make setup
sudo make shell
```

**Opcional**: Para no usar sudo en cada comando:

```bash
# Agregar tu usuario al grupo docker
sudo usermod -aG docker $USER

# Cerrar sesión y volver a entrar
logout
```

### Container no inicia

```bash
sudo make clean
sudo make setup
```

### PostgreSQL no responde

```bash
# Ver logs
sudo make logs

# Verificar que el container está corriendo
sudo docker ps | grep workshop
```

### Quiero empezar de cero

```bash
sudo make clean      # Borra todo
sudo make setup      # Reconstruye e inicia
sudo make reset      # Carga datos
```

### No se crearon los datos

```bash
# Resetear de nuevo
sudo make reset

# Verificar
sudo make shell
```

Dentro de pgcli:

```sql
SELECT COUNT(*) FROM productos;
-- Debe mostrar 500,000
```

---

## 💡 Tips

### Ver progreso de queries largas

```bash
# En otra terminal
make logs
```

### Exportar resultados

```sql
\o resultados.txt
SELECT * FROM productos LIMIT 100;
\o
```

### Conectar con herramienta externa

```
Host:     localhost
Port:     5432
Database: workshop
User:     workshop_user
Password: workshop_pass
```

### pgAdmin web interface

pgAdmin corre en un contenedor separado.

Accede a pgAdmin en: http://localhost:80

- Email: admin@workshop.com
- Password: admin

Usa `sudo make pgadmin` para ver las credenciales.

**Nota**: El contenedor incluye un servidor pre-configurado para conectarse a PostgreSQL usando `host.docker.internal` en el puerto 5432.

---

## 📚 Recursos Adicionales

- **Documentación PostgreSQL**: https://www.postgresql.org/docs/
- **pgcli**: https://www.pgcli.com/
- **EXPLAIN Visualizer**: https://explain.dalibo.com/

---

## 🎓 Ejercicios Adicionales

Ver `docs/EXERCISES.md` para ejercicios paso a paso.

Ver `docs/SOLUTIONS.md` para soluciones completas.

---

## 🤝 Soporte

Si tienes problemas:

1. Revisa la sección **Troubleshooting** arriba
2. Verifica logs: `sudo make logs`
3. Pregunta al instructor

---

## 💻 Requisitos del Sistema

**Sistema Operativo**: Ubuntu 20.04+ (recomendado) o Debian-based Linux

**Instalación de Docker**:
```bash
# Ubuntu/Debian
sudo apt update
sudo apt install docker.io

# Verificar
sudo docker --version
```

**Recursos Mínimos**:
- RAM: 4GB disponible
- Disco: 2GB espacio libre
- Procesador: 2 cores

---

**¡Disfruta el workshop!** 🚀

**Plataforma recomendada**: Ubuntu 20.04+
**Versión**: 2.0 | Fecha: 2025-10-22
