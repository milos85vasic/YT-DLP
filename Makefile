# YT-DLP Project — Convenience Makefile
# Use this for common development tasks instead of memorizing script names.

.PHONY: help init start stop restart status smoke audit dev-check build test ci validate chaos install boot boot-status boot-stop

help:
	@echo "YT-DLP Development Commands"
	@echo "=========================="
	@echo "  make install     - Full install: env setup + systemd --user wiring + reboot persistence"
	@echo "  make boot        - Start everything via systemctl --user, verify loopback + LAN reachability"
	@echo "  make boot-status - Show systemd --user service status for all units"
	@echo "  make boot-stop   - Stop all systemd --user managed services"
	@echo "  make init        - Initialize environment (creates .env, dirs, configs)"
	@echo "  make start       - Start all services (no-VPN mode, direct podman-compose — dev use)"
	@echo "  make stop        - Stop all services (direct podman-compose — dev use)"
	@echo "  make restart     - Stop then start all services"
	@echo "  make status      - Show service status + HTTP health checks"
	@echo "  make smoke       - Run E2E smoke tests (requires running services)"
	@echo "  make audit       - Run test suite quality audit"
	@echo "  make dev-check   - Run all pre-push validation gates"
	@echo "  make build       - Build dashboard container image"
	@echo "  make test        - Run full test suite"
	@echo "  make ci          - Run CI-level validation (compose, build, tests)"
	@echo "  make validate    - Validate API contract"
	@echo "  make chaos       - Run chaos tests"

install:
	./install

boot:
	./boot

boot-status:
	./scripts/service/status-systemd.sh

boot-stop:
	./scripts/service/stop-systemd.sh

init:
	./scripts/setup/init

start:
	./scripts/service/start_no_vpn

stop:
	./scripts/service/stop

restart: stop start

status:
	./scripts/service/status

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

validate:
	./scripts/validate-contract.sh

chaos:
	./tests/test-chaos.sh

ci:
	@echo "=== CI Validation ==="
	@echo "1. Shell syntax..."
	@bash -n scripts/setup/init && bash -n scripts/service/start && bash -n scripts/service/stop && bash -n scripts/service/start_no_vpn
	@bash -n install && bash -n boot && bash -n scripts/setup/setup-systemd.sh && bash -n scripts/lifecycle/boot.sh && bash -n scripts/lifecycle/enable-persistence.sh && bash -n scripts/service/start-systemd.sh && bash -n scripts/service/stop-systemd.sh && bash -n scripts/service/status-systemd.sh && bash -n scripts/service/restart-systemd.sh
	@echo "2. Docker Compose..."
	@docker compose config > /dev/null 2>&1 || docker-compose config > /dev/null 2>&1 || podman-compose config > /dev/null 2>&1
	@echo "3. Dashboard build..."
	@cd dashboard && npx ng build --configuration production > /dev/null 2>&1
	@echo "4. Python syntax..."
	@python3 -m py_compile landing/app.py
	@echo "5. Test audit..."
	@./scripts/test-audit.sh
	@echo "6. Contract validation..."
	@./scripts/validate-contract.sh
	@echo "=== CI Validation PASSED ==="
