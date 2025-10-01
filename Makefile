# Internet Speed Test Monitor - Makefile
# Convenient commands for managing the Docker Compose stack

#* Setup
.PHONY: $(shell sed -n -e '/^$$/ { n ; /^[^ .\#][^ ]*:/ { s/:.*$$// ; p ; } ; }' $(MAKEFILE_LIST))
.DEFAULT_GOAL := help

# Default target
help: ## Show this help message
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'

# include .env

# Build and start services
build: ## Build the speedtest container image
	docker-compose build

up: ## Start all services in detached mode
	docker-compose up -d --build --remove-orphans

start: up ## Alias for 'up'

# Stop and cleanup
down: ## Stop and remove all containers
	docker-compose down

stop: down ## Alias for 'down'

# Restart services
restart: ## Restart all services
	docker-compose restart

restart-speedtest: ## Restart only the speedtest service
	docker-compose restart speedtest

restart-grafana: ## Restart only the Grafana service
	docker-compose restart grafana

restart-postgres: ## Restart only the PostgreSQL service
	docker-compose restart postgres

# Monitoring and logs
logs: ## Show logs from all services
	docker-compose logs -f

logs-speedtest: ## Show logs from speedtest service only
	docker-compose logs -f speedtest

logs-grafana: ## Show logs from Grafana service only
	docker-compose logs -f grafana

logs-postgres: ## Show logs from PostgreSQL service only
	docker-compose logs -f postgres

status: ## Show status of all containers
	docker-compose ps

# Development and testing
test: ## Run a single speed test manually
	docker-compose exec speedtest python speedtest_monitor.py

shell-speedtest: ## Open shell in speedtest container
	docker-compose exec speedtest /bin/bash

shell-grafana: ## Open shell in Grafana container
	docker-compose exec grafana /bin/sh

shell-postgres: ## Open shell in PostgreSQL container
	docker-compose exec postgres /bin/bash

psql: ## Connect to PostgreSQL database
	docker-compose exec postgres psql -U speedtest_user -d speedtest

db-stats: ## Show database statistics
	@echo "Database statistics:"
	@docker-compose exec postgres psql -U speedtest_user -d speedtest -c "SELECT COUNT(*) as total_tests, MIN(timestamp) as first_test, MAX(timestamp) as last_test FROM speed_tests;"

db-cleanup: ## Remove old data (specify DAYS=30 to keep last 30 days)
	@if [ -z "$(DAYS)" ]; then echo "Usage: make db-cleanup DAYS=30"; exit 1; fi
	@echo "Removing speed test data older than $(DAYS) days..."
	@docker-compose exec postgres psql -U speedtest_user -d speedtest -c "DELETE FROM speed_tests WHERE timestamp < NOW() - INTERVAL '$(DAYS) days';"
	@echo "Cleanup completed."

# Data management
backup: ## Backup all persistent data
	@echo "Backing up PostgreSQL database..."
	docker-compose exec postgres pg_dump -U speedtest_user speedtest > speedtest-backup-$$(date +%Y%m%d-%H%M%S).sql
	@echo "Backing up Grafana data..."
	docker-compose stop grafana
	docker run --rm -v speedtest-monitor_grafana-data:/data -v $(PWD):/backup alpine tar czf /backup/grafana-backup-$$(date +%Y%m%d-%H%M%S).tar.gz /data
	docker-compose start grafana
	@echo "Backup completed. Files saved in current directory."

restore-postgres: ## Restore PostgreSQL from backup (specify BACKUP_FILE=filename.sql)
	@if [ -z "$(BACKUP_FILE)" ]; then echo "Usage: make restore-postgres BACKUP_FILE=backup-filename.sql"; exit 1; fi
	@echo "Restoring PostgreSQL database from $(BACKUP_FILE)..."
	cat $(BACKUP_FILE) | docker-compose exec -T postgres psql -U speedtest_user speedtest
	@echo "PostgreSQL restored from $(BACKUP_FILE)"

restore-grafana: ## Restore Grafana from backup (specify BACKUP_FILE=filename.tar.gz)
	@if [ -z "$(BACKUP_FILE)" ]; then echo "Usage: make restore-grafana BACKUP_FILE=backup-filename.tar.gz"; exit 1; fi
	docker-compose stop grafana
	docker run --rm -v speedtest-monitor_grafana-data:/data -v $(PWD):/backup alpine sh -c "rm -rf /data/* && tar xzf /backup/$(BACKUP_FILE) -C /"
	docker-compose start grafana
	@echo "Grafana restored from $(BACKUP_FILE)"

# Updates and maintenance
update: ## Pull latest images and restart services
	docker-compose pull
	docker-compose up -d

pull: ## Pull latest images without restarting
	docker-compose pull

# Cleanup
clean: ## Remove all containers, networks, and volumes (WARNING: This will delete all data!)
	@echo "WARNING: This will delete all data including speed test history!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	docker-compose down -v --remove-orphans
	docker system prune -f

clean-volumes: ## Remove only Docker volumes (WARNING: This will delete all data!)
	@echo "WARNING: This will delete all data including speed test history!"
	@read -p "Are you sure? Type 'yes' to continue: " confirm && [ "$$confirm" = "yes" ]
	docker-compose down -v

# Service URLs
urls: ## Show service URLs and access information
	@echo "Service URLs:"
	@echo "  Grafana Dashboard: http://localhost:3000 (admin/admin)"
	@echo "  PostgreSQL DB:    localhost:5432 (speedtest_user/changeme123)"
	@echo ""
	@echo "For remote access, replace 'localhost' with your Raspberry Pi's IP address"

# Quick setup
setup: ## Initial setup - start services (no .env file needed)
	@echo "Starting services..."
	docker-compose up -d
	@echo ""
	@echo "Services are starting up. Access Grafana at http://localhost:3000"
	@echo "Default credentials: admin/admin"
	@echo "PostgreSQL credentials: speedtest_user/changeme123"

# Grafana setup
setup-grafana: ## Setup Grafana data source and import dashboard
	./grafana/setup-grafana.sh

# Health check
health: ## Check if all services are healthy
	@echo "Checking service health..."
	@docker-compose ps
	@echo ""
	@echo "Testing PostgreSQL connection..."
	@docker-compose exec postgres pg_isready -U speedtest_user -d speedtest && echo "PostgreSQL is healthy" || echo "PostgreSQL not responding"
	@echo ""
	@echo "Testing Grafana connection..."
	@curl -s http://localhost:3000/api/health > /dev/null && echo "Grafana is healthy" || echo "Grafana not responding"
	@echo ""
	@echo "Recent speedtest logs:"
	@docker-compose logs --tail=10 speedtest
