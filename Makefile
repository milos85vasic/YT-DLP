# YT-DLP Project — Convenience Makefile
# Use this for common development tasks instead of memorizing script names.

.PHONY: help init start stop restart status smoke audit dev-check build test ci

help:
	@echo "YT-DLP Development Commands"
	@echo "=========================="
	@echo "  make init        - Initialize environment (creates .env, dirs, configs)"
	@echo "  make start       - Start all services (no-VPN mode)"
	@echo "  make stop        - Stop all services"
	@echo "  make restart     - Stop then start all services"
	@echo "  make status      - Show service status + HTTP health checks"
	@echo "  make smoke       - Run E2E smoke tests (requires running services)"
	@echo "  make audit       - Run test suite quality audit"
	@echo "  make dev-check   - Run all pre-push validation gates"
	@echo "  make build       - Build dashboard container image"
	@echo "  make test        - Run full test suite"
	@echo "  make ci          - Run CI-level validation (compose, build, tests)"

init:
	./init

start:
	./start_no_vpn

stop:
	./stop

restart: stop start

status:
	./status

smoke:
	./scripts/smoke-test.sh

audit:
	./scripts/test-audit.sh

dev-check:
	./scripts/dev-check.sh

build:
	podman-compose --profile no-vpn build dashboard || docker-compose --profile no-vpn build dashboard

test:
	./tests/run-tests.sh

ci:
	@echo "=== CI Validation ==="
	@echo "1. Shell syntax..."
	@bash -n init && bash -n start && bash -n stop && bash -n start_no_vpn
	@echo "2. Docker Compose..."
	@docker compose config > /dev/null 2>&1 || docker-compose config > /dev/null 2>&1
	@echo "3. Dashboard build..."
	@cd dashboard && npx ng build --configuration production > /dev/null 2>&1
	@echo "4. Python syntax..."
	@python3 -m py_compile landing/app.py
	@echo "5. Test audit..."
	@./scripts/test-audit.sh
	@echo "=== CI Validation PASSED ==="
