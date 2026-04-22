.PHONY: build start setup stop reset reset-normalized clean shell psql pgadmin logs benchmark help bash mongo-start mongo-stop mongosh mongo-seed hybrid

help:
	@echo "Workshop Commands:"
	@echo "  sudo make setup      - Build and start (first time - does everything!)"
	@echo "  sudo make build      - Build the workshop container"
	@echo "  sudo make start      - Start workshop environment"
	@echo "  sudo make shell      - Open pgcli (SQL shell with auto-complete)"
	@echo "  sudo make psql       - Open psql (standard PostgreSQL client)"
	@echo "  sudo make pgadmin    - Open pgAdmin web interface (http://localhost:5050)"
	@echo "  sudo make reset            - Reset database to BAD schema (Module 1)"
	@echo "  sudo make reset-normalized - Reset to normalized schema (Module 2/3)"
	@echo "  sudo make mongo-start      - Start MongoDB container"
	@echo "  sudo make mongo-seed       - Seed MongoDB from Postgres catalog"
	@echo "  sudo make mongosh          - Open MongoDB shell"
	@echo "  sudo make mongo-stop       - Stop MongoDB container"
	@echo "  sudo make benchmark  - Run performance benchmark"
	@echo "  sudo make logs       - Show PostgreSQL logs"
	@echo "  sudo make bash       - Open bash shell in container"
	@echo "  sudo make stop       - Stop workshop"
	@echo "  sudo make clean      - Remove container and data"

setup: build start
	@echo ""
	@echo "🎉 Setup complete! Now run:"
	@echo "   sudo make reset"

build:
	@echo "🔨 Building workshop container..."
	@docker build -t workshop-db .
	@echo "✅ Build complete!"

start:
	@echo "🚀 Starting workshop environment..."
	@if ! docker image inspect workshop-db >/dev/null 2>&1; then \
		echo "❌ Error: Image 'workshop-db' not found."; \
		echo "   Run 'sudo make build' first!"; \
		exit 1; \
	fi
		@if docker ps -a --format '{{.Names}}' | grep -q '^workshop$$'; then \
			if ! docker ps --format '{{.Names}}' | grep -q '^workshop$$'; then \
				echo "▶️  Starting stopped container..."; \
				docker start workshop; \
			else \
				echo "✅ Container already running"; \
			fi; \
		else \
			echo "📦 Creating new container..."; \
			docker run -d --name workshop -p 5432:5432 -v workshop-data:/var/lib/postgresql/data workshop-db; \
		fi
		@if ! docker ps --format '{{.Names}}' | grep -q '^workshop-pgadmin$$'; then \
			if docker ps -a --format '{{.Names}}' | grep -q '^workshop-pgadmin$$'; then \
				echo "▶️  Starting pgAdmin..."; \
				docker start workshop-pgadmin; \
			else \
				echo "📦 Starting pgAdmin..."; \
				docker run -d --name workshop-pgadmin -p 80:80 -v workshop-pgadmin-data:/var/lib/pgadmin --add-host host.docker.internal:host-gateway -e PGADMIN_DEFAULT_EMAIL=admin@workshop.com -e PGADMIN_DEFAULT_PASSWORD=admin -e PGADMIN_CONFIG_SERVERS_JSON='{"workshop_db": {"Name": "Workshop DB", "Group": "Servers", "Host": "host.docker.internal", "Port": 5432, "Username": "workshop_user", "Password": "workshop_pass", "Database": "workshop"}}' dpage/pgadmin4; \
			fi; \
		fi
	@echo "⏳ Waiting for PostgreSQL to be ready..."
	@sleep 3
	@docker exec workshop pg_isready -U workshop_user -d workshop > /dev/null 2>&1 || sleep 2
	@echo ""
	@echo "✅ Workshop ready!"
	@echo ""
	@echo "Next steps:"
	@echo "  sudo make reset     - Load initial bad database"
	@echo "  sudo make shell     - Open SQL shell"
	@echo "  sudo make pgadmin   - Show pgAdmin access info"

stop:
	@echo "🛑 Stopping workshop..."
	@docker stop workshop workshop-pgadmin 2>/dev/null || true

reset:
	@echo "🔄 Resetting database to bad schema (Module 1)..."
	@docker exec workshop reset-db $(if $(p),-p $(p)) $(if $(o),-o $(o))
	@echo ""
	@echo "✅ Database reset complete!"
	@echo "   Connect with: make shell"

reset-normalized:
	@echo "🔄 Resetting database to normalized schema (Module 2/3)..."
	@docker exec workshop bash -c "\
		psql -U \$$PGUSER -d \$$PGDATABASE -c 'DROP SCHEMA public CASCADE; CREATE SCHEMA public; GRANT ALL ON SCHEMA public TO workshop_user; GRANT ALL ON SCHEMA public TO public;' && \
		psql -U \$$PGUSER -d \$$PGDATABASE -f /workshop/sql/00_extensions.sql && \
		psql -U \$$PGUSER -d \$$PGDATABASE -f /workshop/sql/02_normalized_schema.sql && \
		python3 /workshop/scripts/generate_normalized_data.py"
	@echo ""
	@echo "✅ Normalized schema ready!"
	@echo "   Connect with: make shell"

clean:
	@echo "🗑️  Removing containers and data..."
	@docker rm -f workshop workshop-pgadmin 2>/dev/null || true
	@docker volume rm workshop-data workshop-pgadmin-data 2>/dev/null || true
	@echo "✅ All data removed"

shell:
	@echo "🐚 Opening pgcli (type \\q to exit)..."
	@echo ""
	@docker exec -it workshop pgcli -U workshop_user -d workshop

psql:
	@echo "🐚 Opening psql (type \\q to exit)..."
	@echo ""
	@docker exec -it workshop psql -U workshop_user -d workshop

pgadmin:
	@echo "🌐 pgAdmin web interface:"
	@echo "   URL: http://localhost:80"
	@echo "   Email: admin@workshop.com"
	@echo "   Password: admin"
	@echo ""
	@echo "   (Open in your browser)"

logs:
	@docker logs -f workshop

benchmark:
	@docker exec workshop benchmark

bash:
	@docker exec -it workshop bash

# ── MongoDB ───────────────────────────────────────────────────

mongo-start:
	@echo "🍃 Starting MongoDB..."
	@docker network inspect workshop-net >/dev/null 2>&1 || docker network create workshop-net
	@if docker ps -a --format '{{.Names}}' | grep -q '^workshop-mongo$$'; then \
		if ! docker ps --format '{{.Names}}' | grep -q '^workshop-mongo$$'; then \
			docker start workshop-mongo; \
		else \
			echo "✅ MongoDB already running"; \
		fi; \
	else \
		docker run -d --name workshop-mongo \
			--network workshop-net \
			-p 27017:27017 \
			-v workshop-mongo-data:/data/db \
			mongo:7; \
	fi
	@docker network connect workshop-net workshop 2>/dev/null || true
	@echo "⏳ Waiting for MongoDB..."
	@sleep 3
	@echo "✅ MongoDB ready on port 27017"

mongo-stop:
	@docker stop workshop-mongo 2>/dev/null || true
	@echo "🛑 MongoDB stopped"

mongosh:
	@echo "🐚 Opening mongosh (type exit to quit)..."
	@docker run --rm -it \
		--network workshop-net \
		-v $(PWD)/mongo:/workshop/mongo \
		-w /workshop \
		mongo:7 \
		mongosh mongodb://workshop-mongo:27017/workshop

hybrid:
	@echo "🔀 Running hybrid query (Postgres order + MongoDB catalog)..."
	@docker run --rm \
		--network workshop-net \
		-e PGHOST=workshop \
		-e PGDATABASE=workshop \
		-e PGUSER=workshop_user \
		-e PGPASSWORD=workshop_pass \
		-e MONGO_HOST=workshop-mongo \
		-v $(PWD)/scripts:/scripts \
		python:3.11-slim \
		bash -c "pip install psycopg2-binary pymongo -q && python /scripts/hybrid_query.py"

mongo-seed:
	@echo "🌱 Seeding MongoDB from Postgres catalog..."
	@docker run --rm \
		--network workshop-net \
		-e PGHOST=workshop \
		-e PGDATABASE=workshop \
		-e PGUSER=workshop_user \
		-e PGPASSWORD=workshop_pass \
		-e MONGO_HOST=workshop-mongo \
		-v $(PWD)/scripts:/scripts \
		python:3.11-slim \
		bash -c "pip install psycopg2-binary pymongo -q && python /scripts/seed_mongo.py"
	@echo "✅ MongoDB seeded"
