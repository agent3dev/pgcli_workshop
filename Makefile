.PHONY: build start setup stop reset clean shell psql pgadmin logs benchmark help bash

help:
	@echo "Workshop Commands:"
	@echo "  sudo make setup      - Build and start (first time - does everything!)"
	@echo "  sudo make build      - Build the workshop container"
	@echo "  sudo make start      - Start workshop environment"
	@echo "  sudo make shell      - Open pgcli (SQL shell with auto-complete)"
	@echo "  sudo make psql       - Open psql (standard PostgreSQL client)"
	@echo "  sudo make pgadmin    - Open pgAdmin web interface (http://localhost:5050)"
	@echo "  sudo make reset      - Reset database to BAD schema"
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
	@echo "🔄 Resetting database..."
	@docker exec workshop reset-db $(if $(p),-p $(p)) $(if $(o),-o $(o))
	@echo ""
	@echo "✅ Database reset complete!"
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
