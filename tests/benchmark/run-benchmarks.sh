#!/bin/bash
#
# Performance benchmarks for MeTube services
# Measures latency, throughput, and concurrent load
#

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

pass() { echo -e "${GREEN}✓ PASS${NC} $1"; }
fail() { echo -e "${RED}✗ FAIL${NC} $1"; }
info() { echo -e "${BLUE}=== $1 ===${NC}"; }
warn() { echo -e "${YELLOW}⚠ $1${NC}"; }

# Config
METUBE_URL="http://localhost:8088"
DASHBOARD_URL="http://localhost:9090"
LANDING_URL="http://localhost:8086"
WARMUP_REQUESTS=10
BENCHMARK_REQUESTS=50
CONCURRENT_REQUESTS=10
THROUGHPUT_DURATION=5

# Results storage
declare -A LATENCIES
declare -A THROUGHPUTS

time_ms() {
    local start end
    start=$(date +%s%N)
    "$@" > /dev/null 2>&1
    end=$(date +%s%N)
    echo $(((end - start) / 1000000))
}

curl_time() {
    curl -s -o /dev/null -w "%{time_total}" "$@"
}

# Convert curl time_total (seconds with decimal) to integer milliseconds
ms_from_seconds() {
    local sec="$1"
    # Handle formats like 0.012 or .012
    if [[ "$sec" == .* ]]; then
        sec="0$sec"
    fi
    # Multiply by 1000: 0.012 -> 12
    local int_part="${sec%%.*}"
    local frac_part="${sec#*.}"
    # Pad/truncate fractional to 3 digits
    frac_part="${frac_part}000"
    frac_part="${frac_part:0:3}"
    # Remove leading zeros from frac to avoid octal interpretation
    frac_part="$(echo "$frac_part" | sed 's/^0*//')"
    [ -z "$frac_part" ] && frac_part=0
    echo "$((int_part * 1000 + frac_part))"
}

measure_latency() {
    local name="$1"
    local url="$2"
    local total=0 min=999999 max=0
    local times=()

    for ((i=1; i<=BENCHMARK_REQUESTS; i++)); do
        local ms
        ms=$(curl_time "$url")
        ms=$(ms_from_seconds "$ms")
        times+=("$ms")
        total=$((total + ms))
        [ "$ms" -lt "$min" ] && min=$ms
        [ "$ms" -gt "$max" ] && max=$ms
    done

    local avg=$((total / BENCHMARK_REQUESTS))
    # Sort for p50/p95/p99
    IFS=$'\n' sorted=($(sort -n <<<"${times[*]}")); unset IFS
    local p50=${sorted[$((BENCHMARK_REQUESTS / 2))]}
    local p95_idx=$((BENCHMARK_REQUESTS * 95 / 100))
    [ "$p95_idx" -ge "$BENCHMARK_REQUESTS" ] && p95_idx=$((BENCHMARK_REQUESTS - 1))
    local p95=${sorted[$p95_idx]}

    LATENCIES["$name.avg"]=$avg
    LATENCIES["$name.min"]=$min
    LATENCIES["$name.max"]=$max
    LATENCIES["$name.p50"]=$p50
    LATENCIES["$name.p95"]=$p95
}

measure_throughput() {
    local name="$1"
    local url="$2"
    local count=0
    local start end

    start=$(date +%s)
    while true; do
        end=$(date +%s)
        [ $((end - start)) -ge "$THROUGHPUT_DURATION" ] && break
        curl -s -o /dev/null "$url" &
        count=$((count + 1))
        # Limit parallelism to avoid overwhelming the system
        if [ "$count" -ge 100 ]; then
            wait
            count=0
        fi
    done
    wait
    end=$(date +%s)
    local elapsed=$((end - start))
    local rps=$(echo "scale=1; $count / $elapsed" | bc)
    THROUGHPUTS["$name"]=$rps
}

measure_concurrent() {
    local name="$1"
    local url="$2"
    local pids=()
    local start end

    start=$(date +%s%N)
    for ((i=0; i<CONCURRENT_REQUESTS; i++)); do
        curl -s -o /dev/null "$url" &
        pids+=("$!")
    done
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
    end=$(date +%s%N)
    local ms=$(((end - start) / 1000000))
    LATENCIES["$name.concurrent"]=$ms
}

# ── Header ──
echo -e "${CYAN}============================================${NC}"
echo -e "${CYAN}  Performance Benchmarks${NC}"
echo -e "${CYAN}============================================${NC}"

# ── Pre-checks ──
info "Pre-flight checks"
for url in "$LANDING_URL" "$METUBE_URL" "$DASHBOARD_URL"; do
    if ! curl -s -o /dev/null --connect-timeout 2 "$url"; then
        fail "$url not reachable"
        exit 1
    fi
done
pass "All services reachable"

# ── Warmup ──
info "Warming up (${WARMUP_REQUESTS} requests per endpoint)"
for ((i=1; i<=WARMUP_REQUESTS; i++)); do
    curl -s -o /dev/null "$METUBE_URL/history" &
    curl -s -o /dev/null "$DASHBOARD_URL/api/history" &
    curl -s -o /dev/null "$LANDING_URL/health" &
    wait
done
pass "Warmup complete"

# ── Latency Benchmarks ──
info "Latency Benchmarks (${BENCHMARK_REQUESTS} sequential requests)"
measure_latency "metube.history" "$METUBE_URL/history"
measure_latency "metube.version" "$METUBE_URL/version"
measure_latency "dashboard.proxy" "$DASHBOARD_URL/api/history"
measure_latency "landing.health" "$LANDING_URL/health"

# ── Concurrent Benchmarks ──
info "Concurrent Load (${CONCURRENT_REQUESTS} parallel requests)"
measure_concurrent "metube.history" "$METUBE_URL/history"
measure_concurrent "dashboard.proxy" "$DASHBOARD_URL/api/history"

# ── Throughput Benchmarks ──
info "Throughput Benchmarks (${THROUGHPUT_DURATION}s sustained load)"
measure_throughput "metube.history" "$METUBE_URL/history"
measure_throughput "dashboard.proxy" "$DASHBOARD_URL/api/history"

# ── Results ──
info "Benchmark Results"
echo ""
printf "  %-25s %8s %8s %8s %8s %8s\n" "Endpoint" "Min" "Avg" "P50" "P95" "Max"
printf "  %-25s %8s %8s %8s %8s %8s\n" "-------------------------" "--------" "--------" "--------" "--------" "--------"
for key in metube.history metube.version dashboard.proxy landing.health; do
    printf "  %-25s %7dms %7dms %7dms %7dms %7dms\n" \
        "$key" \
        "${LATENCIES["$key.min"]:-0}" \
        "${LATENCIES["$key.avg"]:-0}" \
        "${LATENCIES["$key.p50"]:-0}" \
        "${LATENCIES["$key.p95"]:-0}" \
        "${LATENCIES["$key.max"]:-0}"
done

echo ""
printf "  %-25s %8s\n" "Concurrent Load" "Total Time"
printf "  %-25s %8s\n" "-------------------------" "--------"
for key in metube.history dashboard.proxy; do
    printf "  %-25s %7dms\n" "$key" "${LATENCIES["$key.concurrent"]:-0}"
done

echo ""
printf "  %-25s %8s\n" "Throughput" "Req/s"
printf "  %-25s %8s\n" "-------------------------" "--------"
for key in metube.history dashboard.proxy; do
    printf "  %-25s %7s\n" "$key" "${THROUGHPUTS["$key"]:-0}"
done

echo ""

# ── Thresholds ──
info "Threshold Checks"
THRESHOLD_PASS=true

check_threshold() {
    local name="$1"
    local value="$2"
    local threshold="$3"
    if [ "$value" -le "$threshold" ]; then
        pass "$name: ${value}ms ≤ ${threshold}ms threshold"
    else
        fail "$name: ${value}ms > ${threshold}ms threshold"
        THRESHOLD_PASS=false
    fi
}

check_threshold "Landing Health (avg)" "${LATENCIES["landing.health.avg"]:-999}" 100
check_threshold "MeTube History (avg)" "${LATENCIES["metube.history.avg"]:-999}" 200
check_threshold "Dashboard Proxy (avg)" "${LATENCIES["dashboard.proxy.avg"]:-999}" 300
check_threshold "MeTube History (p95)" "${LATENCIES["metube.history.p95"]:-999}" 500

echo ""
if [ "$THRESHOLD_PASS" = true ]; then
    echo -e "${GREEN}ALL BENCHMARKS PASSED${NC}"
    exit 0
else
    echo -e "${YELLOW}SOME BENCHMARKS EXCEEDED THRESHOLDS${NC}"
    exit 1
fi
