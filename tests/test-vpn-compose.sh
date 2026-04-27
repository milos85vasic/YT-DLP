#!/bin/bash
#
# tests/test-vpn-compose.sh
#
# VPN profile static-validation tests — compose-only, NO boot.
#
# These tests assert that the `vpn` profile in docker-compose.yml is
# wired correctly:
#   1. The 4 expected services exist under that profile.
#   2. metube (vpn) chains its network namespace into openvpn-yt-dlp
#      via `network_mode: service:openvpn-yt-dlp` and exposes NO
#      ports of its own (which would silently do nothing in the
#      shared-namespace mode).
#   3. landing-vpn binds the host-facing port 8087 (the public entry
#      point, since metube cannot bind ports under shared-namespace).
#   4. openvpn-yt-dlp has the required cap_add NET_ADMIN + tun device.
#   5. The compose config validates with the active runtime.
#
# We DON'T boot the vpn profile here because that would need:
#   - a valid .ovpn file at $VPN_OVPN_PATH
#   - valid vpn-auth.txt credentials
# Live VPN connectivity is the operator's responsibility, validated
# manually with `./check-vpn`. This file guards the wiring.
#
# NOTE: do NOT use `set -e` / `set -u` at file scope — when run-tests.sh
# sources this file, those flags would leak into the orchestrator.

PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
COMPOSE_FILE="${COMPOSE_FILE:-$PROJECT_DIR/docker-compose.yml}"

# shellcheck disable=SC1091
[ -f "$PROJECT_DIR/tests/test-helpers.sh" ] && source "$PROJECT_DIR/tests/test-helpers.sh"

_vpn_compose_runtime() {
    if command -v podman-compose >/dev/null 2>&1; then
        echo "podman-compose"
    elif command -v podman >/dev/null 2>&1 && podman compose version >/dev/null 2>&1; then
        echo "podman compose"
    elif command -v docker-compose >/dev/null 2>&1; then
        echo "docker-compose"
    elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        echo "docker compose"
    else
        echo ""
    fi
}

test_vpn_compose_validates() {
    if [ ! -f "$COMPOSE_FILE" ]; then
        echo "compose file not found at $COMPOSE_FILE"
        return 1
    fi
    local cmd
    cmd=$(_vpn_compose_runtime)
    if [ -z "$cmd" ]; then
        echo "no compose runtime available"
        return 1
    fi
    if ! $cmd -f "$COMPOSE_FILE" --profile vpn config >/dev/null 2>/tmp/vpn-compose-config.err; then
        echo "vpn profile compose config failed:"
        cat /tmp/vpn-compose-config.err | head -n 10
        return 1
    fi
}

test_vpn_compose_has_expected_services() {
    if [ ! -f "$COMPOSE_FILE" ]; then return 1; fi
    # Services that must exist under the vpn profile (or shared with it).
    local missing=0
    for svc in openvpn-yt-dlp metube landing-vpn yt-dlp-cli; do
        if ! grep -qE "^[[:space:]]*${svc}:" "$COMPOSE_FILE"; then
            echo "vpn profile missing service: $svc"
            missing=1
        fi
    done
    [ "$missing" -eq 0 ]
}

test_vpn_metube_uses_shared_network_namespace() {
    # The `metube` (vpn) service must inherit openvpn-yt-dlp's network
    # namespace via `network_mode: service:openvpn-yt-dlp`. Without
    # this, no traffic from metube goes through the VPN tunnel.
    if ! awk '/^  metube:/{flag=1} flag && /^  [a-z]/ && !/^  metube:/{flag=0} flag && /network_mode:[[:space:]]*"?service:openvpn-yt-dlp"?/' "$COMPOSE_FILE" | grep -q "network_mode"; then
        echo "metube (vpn) is not chained into openvpn-yt-dlp's network namespace"
        return 1
    fi
}

test_vpn_metube_exposes_no_own_ports() {
    # Under network_mode: service:..., `ports:` on the dependent
    # service is silently a no-op — it would imply binding the host,
    # which only the network namespace owner can do. Catch any
    # accidental `ports:` block under metube (vpn) so a future
    # regression doesn't ship a misleading config.
    if awk '/^  metube:/{flag=1; next} flag && /^  [a-z]/ && !/^  metube:/{flag=0} flag' "$COMPOSE_FILE" | grep -qE "^[[:space:]]+ports:"; then
        echo "metube (vpn) has its own ports: block — these silently do nothing under network_mode: service:openvpn-yt-dlp"
        echo "Public entry points must come from the openvpn-yt-dlp ports block or from landing-vpn."
        return 1
    fi
}

test_vpn_landing_vpn_publishes_8087() {
    # landing-vpn is the user-facing entry point on :8087. If this
    # mapping is missing, the vpn profile has no externally reachable
    # surface (since metube can't bind under shared namespace).
    if ! awk '/^  landing-vpn:/{flag=1} flag && /^  [a-z]/ && !/^  landing-vpn:/{flag=0} flag' "$COMPOSE_FILE" | grep -qE '"?8087:'; then
        echo "landing-vpn does not publish port 8087 (no public entry point on the vpn profile)"
        return 1
    fi
}

test_every_service_has_mem_limit() {
    # CONST-033 OOM-cascade defence: every compose service MUST have
    # an explicit mem_limit so a runaway process inside one container
    # can't pull the user session down via the kernel OOM killer.
    # Without this, neighbour-project incidents like 2026-04-27 22:22
    # (V8/python3 pod OOM-cascade → user@1000.service: status=9/KILL)
    # repeat. Anti-bluff (CONST-034): we don't trust eyeballed yaml —
    # we extract every service name from the resolved compose config
    # and require each one to declare mem_limit.
    if [ ! -f "$COMPOSE_FILE" ]; then return 1; fi

    # Resolve the compose to a normalised form so we don't have to
    # parse the original yaml's anchors/inheritance.
    local cmd
    cmd=$(_vpn_compose_runtime)
    if [ -z "$cmd" ]; then
        echo "no compose runtime available — cannot resolve"
        return 1
    fi
    local resolved
    resolved=$($cmd -f "$COMPOSE_FILE" config 2>/dev/null) || {
        echo "compose config failed to resolve"
        return 1
    }

    # Walk every top-level service block, look for mem_limit inside.
    # awk emits "service_name|HAS_LIMIT|VALUE" per service.
    local report missing
    report=$(echo "$resolved" | python3 <<'PY' 2>&1
import sys, yaml
try:
    doc = yaml.safe_load(sys.stdin.read()) or {}
except Exception as e:
    print(f"PARSE_ERROR: {e}", file=sys.stderr)
    sys.exit(2)

services = doc.get("services", {}) or {}
missing = []
for name, body in services.items():
    body = body or {}
    if "mem_limit" not in body:
        missing.append(name)
        print(f"  MISSING: {name}")
    else:
        print(f"  OK: {name} = {body['mem_limit']}")

if missing:
    print(f"FAIL_COUNT: {len(missing)}")
    sys.exit(1)
sys.exit(0)
PY
)
    if [ $? -ne 0 ]; then
        echo "$report"
        echo "Some compose services have no mem_limit. Add one to each — see CONST-033."
        return 1
    fi
}

test_vpn_openvpn_has_required_capabilities() {
    # openvpn-yt-dlp needs NET_ADMIN + /dev/net/tun to bring up the
    # tunnel. Without either, the tunnel never comes up and the whole
    # vpn profile is dead.
    local block
    block=$(awk '/^  openvpn-yt-dlp:/{flag=1} flag && /^  [a-z]/ && !/^  openvpn-yt-dlp:/{flag=0} flag' "$COMPOSE_FILE")
    if ! echo "$block" | grep -q "NET_ADMIN"; then
        echo "openvpn-yt-dlp missing cap_add: NET_ADMIN"
        return 1
    fi
    if ! echo "$block" | grep -q "/dev/net/tun"; then
        echo "openvpn-yt-dlp missing /dev/net/tun device"
        return 1
    fi
}

run_vpn_compose_tests() {
    if type log_info &> /dev/null; then
        log_info "Running VPN Compose Tests..."
    else
        echo "[INFO] Running VPN Compose Tests..."
    fi

    if type run_test &> /dev/null; then
        run_test "test_vpn_compose_validates" test_vpn_compose_validates
        run_test "test_vpn_compose_has_expected_services" test_vpn_compose_has_expected_services
        run_test "test_vpn_metube_uses_shared_network_namespace" test_vpn_metube_uses_shared_network_namespace
        run_test "test_vpn_metube_exposes_no_own_ports" test_vpn_metube_exposes_no_own_ports
        run_test "test_vpn_landing_vpn_publishes_8087" test_vpn_landing_vpn_publishes_8087
        run_test "test_vpn_openvpn_has_required_capabilities" test_vpn_openvpn_has_required_capabilities
        run_test "test_every_service_has_mem_limit" test_every_service_has_mem_limit
    else
        local pass=0 fail=0
        for t in test_vpn_compose_validates test_vpn_compose_has_expected_services test_vpn_metube_uses_shared_network_namespace test_vpn_metube_exposes_no_own_ports test_vpn_landing_vpn_publishes_8087 test_vpn_openvpn_has_required_capabilities test_every_service_has_mem_limit; do
            if "$t"; then pass=$((pass+1)); else fail=$((fail+1)); fi
        done
        echo "Pass: $pass  Fail: $fail"
        [ "$fail" -eq 0 ]
    fi
}

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_vpn_compose_tests
fi
