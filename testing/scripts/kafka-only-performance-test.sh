#!/bin/bash

##############################################################################
# Isolated Kafka Publishing Performance Test
#
# This test measures ONLY Kafka publishing time by calling a dedicated
# endpoint that publishes to Kafka WITHOUT any database operations.
#
# This isolates the async improvement to demonstrate:
# - SYNC mode: 50-100ms (blocking, waits for Kafka ACK)
# - ASYNC mode: 1-5ms (non-blocking, fire-and-forget)
##############################################################################

set -e

# Configuration
APP_URL="http://localhost:8081"
ITERATIONS=${1:-1000}  # Default 1000 iterations
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="test-logs/kafka-only-${TIMESTAMP}"
RESULTS_CSV="${LOG_DIR}/kafka_only_results.csv"
APP_PROPERTIES="src/main/resources/application.properties"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Isolated Kafka Publishing Performance Test${NC}"
echo -e "${BLUE}  Measuring ONLY Kafka Publishing Time (No Database)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Test Configuration:"
echo "  - Iterations per mode: ${ITERATIONS}"
echo "  - Endpoint: POST /api/test/kafka-only"
echo "  - Measurement: Pure Kafka publishing latency"
echo ""

# Create log directory
mkdir -p "${LOG_DIR}"

# Initialize CSV
cat > "${RESULTS_CSV}" << EOF
Mode,Iteration,Latency_ms
EOF

echo -e "${YELLOW}📋 Created results file: ${RESULTS_CSV}${NC}"
echo ""

##############################################################################
# Function: Check application
##############################################################################
check_application() {
    echo -e "${BLUE}🔍 Checking application status...${NC}"
    if curl -s "${APP_URL}/actuator/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Application is running${NC}"
        return 0
    else
        echo -e "${RED}❌ Application is not running!${NC}"
        exit 1
    fi
}

##############################################################################
# Function: Get current mode
##############################################################################
get_kafka_mode() {
    grep "app.kafka.publishing.mode=" "${APP_PROPERTIES}" | cut -d'=' -f2
}

##############################################################################
# Function: Run Kafka-only test
##############################################################################
run_kafka_test() {
    local mode=$1
    local latency_file="${LOG_DIR}/${mode}-latencies.txt"
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Testing ${mode} Mode - ${ITERATIONS} iterations${NC}"
    echo -e "${BLUE}  Measuring pure Kafka publishing latency${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
    
    # Clear latency file
    > "${latency_file}"
    
    echo "Running ${ITERATIONS} Kafka publish operations..."
    
    for ((i=1; i<=${ITERATIONS}; i++)); do
        # Measure Kafka publishing time
        local start=$(python3 -c "import time; print(int(time.time() * 1000))")
        
        # Call Kafka-only endpoint (publishes without DB operations)
        local response=$(curl -s -w "\n%{http_code}" -X POST "${APP_URL}/api/test/kafka-only" \
            -H "Content-Type: application/json" \
            -d "{\"testId\":${i}, \"message\":\"Test message ${i}\"}" 2>/dev/null)
        
        local end=$(python3 -c "import time; print(int(time.time() * 1000))")
        local latency=$((end - start))
        
        local http_code=$(echo "$response" | tail -n1)
        
        # Record if successful
        if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
            echo "$latency" >> "${latency_file}"
            echo "${mode},${i},${latency}" >> "${RESULTS_CSV}"
        fi
        
        # Progress indicator every 100 iterations
        if [ $((i % 100)) -eq 0 ]; then
            echo "  Progress: ${i}/${ITERATIONS} iterations completed"
        fi
    done
    
    echo ""
    echo -e "${GREEN}✅ Test completed!${NC}"
    
    # Calculate statistics
    local total=$(wc -l < "${latency_file}" | tr -d ' ')
    
    if [ $total -eq 0 ]; then
        echo -e "${RED}❌ No successful requests completed${NC}"
        return
    fi
    
    # Sort for percentile calculations
    sort -n "${latency_file}" -o "${latency_file}"
    
    local min=$(head -n1 "${latency_file}")
    local max=$(tail -n1 "${latency_file}")
    local avg=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "${latency_file}")
    
    local p50_index=$(awk "BEGIN {printf \"%.0f\", ${total}*0.50}")
    local p95_index=$(awk "BEGIN {printf \"%.0f\", ${total}*0.95}")
    local p99_index=$(awk "BEGIN {printf \"%.0f\", ${total}*0.99}")
    
    local p50=$(sed -n "${p50_index}p" "${latency_file}")
    local p95=$(sed -n "${p95_index}p" "${latency_file}")
    local p99=$(sed -n "${p99_index}p" "${latency_file}")
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "${mode} Mode - Kafka Publishing Latency Statistics:"
    echo "  Successful requests: ${total}"
    echo "  Average latency:     ${avg} ms"
    echo "  Min latency:         ${min} ms"
    echo "  Max latency:         ${max} ms"
    echo "  P50 (median):        ${p50} ms"
    echo "  P95:                 ${p95} ms"
    echo "  P99:                 ${p99} ms"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

##############################################################################
# Main Execution
##############################################################################

check_application

current_mode=$(get_kafka_mode)
echo -e "${YELLOW}📍 Current Kafka publishing mode: ${current_mode}${NC}"
echo ""
echo -e "${YELLOW}⚠️  Make sure you've set the correct mode in application.properties${NC}"
echo ""
read -p "Continue with current mode (${current_mode})? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo ""
run_kafka_test "${current_mode}"

echo -e "${GREEN}✅ Test completed for ${current_mode} mode!${NC}"
echo ""
echo "Results saved to:"
echo "  📊 CSV file: ${RESULTS_CSV}"
echo "  📁 Log directory: ${LOG_DIR}"
echo ""
echo "Next steps:"
if [ "${current_mode}" = "sync" ]; then
    echo "  1. Stop the application: pkill -f 'spring-boot:run'"
    echo "  2. Change app.kafka.publishing.mode=async in application.properties"
    echo "  3. Restart application: ./mvnw spring-boot:run"
    echo "  4. Run: ./kafka-only-performance-test.sh ${ITERATIONS}"
else
    echo "  Compare results from both modes:"
    echo "    - SYNC mode should show ~50-100ms latency (blocking)"
    echo "    - ASYNC mode should show ~1-10ms latency (non-blocking)"
    echo ""
    echo "  Generate comparison report:"
    echo "    python3 analyze-kafka-results.py"
fi
echo ""
