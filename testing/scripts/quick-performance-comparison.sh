#!/bin/bash

##############################################################################
# Quick Performance Comparison Test
#
# Simple test to demonstrate sync vs async performance without app restarts.
# Uses the existing Traffic Agent with different Kafka modes.
#
# Usage:
#   1. Start app with SYNC mode: Set app.kafka.publishing.mode=sync
#   2. Run: ./quick-performance-comparison.sh sync
#   3. Stop app, change to ASYNC mode: app.kafka.publishing.mode=async
#   4. Run: ./quick-performance-comparison.sh async
#   5. View combined results in CSV
##############################################################################

set -e

MODE=${1:-async}
ROUNDS=${2:-3}
APP_URL="http://localhost:8081"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="test-logs/perf-comparison-${MODE}-${TIMESTAMP}"
COMBINED_CSV="test-logs/performance_comparison_combined.csv"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Performance Test - ${MODE} Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Create log directory
mkdir -p "${LOG_DIR}"

# Initialize combined CSV if doesn't exist
if [ ! -f "${COMBINED_CSV}" ]; then
    cat > "${COMBINED_CSV}" << EOF
Mode,Round,Orders_Created,Orders_Fulfilled,Fulfillment_Rate_%,Avg_Latency_ms,P50_ms,P95_ms,P99_ms,Throughput_req_per_sec,Test_Duration_sec
EOF
    echo -e "${YELLOW}📋 Created combined results file: ${COMBINED_CSV}${NC}"
fi

##############################################################################
# Function: Check application
##############################################################################
check_app() {
    echo -e "${BLUE}🔍 Checking application (expecting ${MODE} mode)...${NC}"
    if curl -s "${APP_URL}/actuator/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Application is running${NC}"
        
        # Check current mode in logs
        echo "Current Kafka publishing mode should be: ${MODE}"
        echo ""
        return 0
    else
        echo -e "${RED}❌ Application is not running!${NC}"
        echo "Please start the application with:"
        echo "  1. Set app.kafka.publishing.mode=${MODE} in application.properties"
        echo "  2. Run: ./mvnw spring-boot:run"
        exit 1
    fi
}

##############################################################################
# Function: Clear database
##############################################################################
clear_database() {
    echo -e "${BLUE}🗑️  Clearing database...${NC}"
    docker exec postgres psql -U adsuser -d adsdb -c "TRUNCATE TABLE users, orders, payments, notifications, processed_events CASCADE;" > /dev/null 2>&1
    echo -e "${GREEN}✅ Database cleared${NC}"
}

##############################################################################
# Function: Get order counts
##############################################################################
get_order_counts() {
    local created=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders;" | tr -d ' ' | tr -d '\n')
    local fulfilled=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status='DELIVERED';" | tr -d ' ' | tr -d '\n')
    
    echo "${created},${fulfilled}"
}

##############################################################################
# Function: Run single test round
##############################################################################
run_round() {
    local round=$1
    local log_file="${LOG_DIR}/round${round}.log"
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  ${MODE} Mode - Round ${round}/${ROUNDS}${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Clear database
    clear_database
    
    # Start Traffic Agent
    echo "Starting Traffic Agent (10 ops/sec, STEADY pattern)..."
    curl -s -X POST "${APP_URL}/api/agent/traffic/start?opsPerSecond=10&pattern=STEADY" > /dev/null
    echo -e "${GREEN}✅ Traffic Agent started${NC}"
    
    # Start Fulfillment Agent
    echo "Starting Fulfillment Agent..."
    curl -s -X POST "${APP_URL}/api/agent/fulfillment/start?processingDelayMs=10&batchSize=100&pollingIntervalSeconds=1" > /dev/null
    echo -e "${GREEN}✅ Fulfillment Agent started${NC}"
    
    echo ""
    echo "Running test for 60 seconds..."
    
    # Sample latencies during test
    latency_file="${LOG_DIR}/round${round}-latency.txt"
    > "${latency_file}"
    
    local start_time=$(date +%s)
    local end_time=$((start_time + 60))
    
    while [ $(date +%s) -lt ${end_time} ]; do
        # Use Python for millisecond precision (works on macOS)
        local req_start=$(python3 -c "import time; print(int(time.time() * 1000))")
        
        # Test order creation endpoint latency
        curl -s -X GET "${APP_URL}/api/orders?page=0&size=10" > /dev/null 2>&1
        
        local req_end=$(python3 -c "import time; print(int(time.time() * 1000))")
        local latency=$((req_end - req_start))
        echo "$latency" >> "${latency_file}"
        
        sleep 1
    done
    
    local actual_duration=$(($(date +%s) - start_time))
    
    # Stop Traffic Agent first (stop creating new orders)
    echo ""
    echo "Stopping Traffic Agent..."
    curl -s -X POST "${APP_URL}/api/agent/traffic/stop" > /dev/null
    echo -e "${GREEN}✅ Traffic Agent stopped${NC}"
    
    # Wait for Fulfillment Agent to process remaining orders
    echo "Waiting 20 seconds for Fulfillment Agent to process remaining orders..."
    sleep 20
    
    # Now stop Fulfillment Agent
    echo "Stopping Fulfillment Agent..."
    curl -s -X POST "${APP_URL}/api/agent/fulfillment/stop" > /dev/null
    echo -e "${GREEN}✅ Fulfillment Agent stopped${NC}"
    
    # Wait a bit more for final commits
    echo "Waiting 5 seconds for final database commits..."
    sleep 5
    
    # Get results
    local counts=$(get_order_counts)
    local created=$(echo $counts | cut -d',' -f1)
    local fulfilled=$(echo $counts | cut -d',' -f2)
    
    local fulfillment_rate=0
    if [ $created -gt 0 ]; then
        fulfillment_rate=$(awk "BEGIN {printf \"%.2f\", ($fulfilled/$created)*100}")
    fi
    
    local throughput=$(awk "BEGIN {printf \"%.2f\", $created/$actual_duration}")
    
    # Calculate latency statistics
    sort -n "${latency_file}" -o "${latency_file}"
    local sample_count=$(wc -l < "${latency_file}" | tr -d ' ')
    
    if [ $sample_count -gt 0 ]; then
        local avg_latency=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "${latency_file}")
        local p50_index=$(awk "BEGIN {printf \"%.0f\", ${sample_count}*0.50}")
        local p95_index=$(awk "BEGIN {printf \"%.0f\", ${sample_count}*0.95}")
        local p99_index=$(awk "BEGIN {printf \"%.0f\", ${sample_count}*0.99}")
        
        local p50=$(sed -n "${p50_index}p" "${latency_file}")
        local p95=$(sed -n "${p95_index}p" "${latency_file}")
        local p99=$(sed -n "${p99_index}p" "${latency_file}")
    else
        local avg_latency=0
        local p50=0
        local p95=0
        local p99=0
    fi
    
    # Display results
    echo ""
    echo -e "${GREEN}✅ Test completed!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Results:"
    echo "  Orders created:     ${created}"
    echo "  Orders fulfilled:   ${fulfilled}"
    echo "  Fulfillment rate:   ${fulfillment_rate}%"
    echo "  Test duration:      ${actual_duration}s"
    echo "  Throughput:         ${throughput} orders/s"
    echo ""
    echo "API Latency (sampled):"
    echo "  Average:            ${avg_latency} ms"
    echo "  P50 (median):       ${p50} ms"
    echo "  P95:                ${p95} ms"
    echo "  P99:                ${p99} ms"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Append to combined CSV
    echo "${MODE},${round},${created},${fulfilled},${fulfillment_rate},${avg_latency},${p50},${p95},${p99},${throughput},${actual_duration}" >> "${COMBINED_CSV}"
}

##############################################################################
# Main Execution
##############################################################################

check_app

# Run test rounds
for ((round=1; round<=${ROUNDS}; round++)); do
    run_round ${round}
    
    if [ ${round} -lt ${ROUNDS} ]; then
        echo "Waiting 5 seconds before next round..."
        sleep 5
        echo ""
    fi
done

##############################################################################
# Display Summary
##############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Summary for ${MODE} Mode (${ROUNDS} rounds)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Calculate averages for this mode
avg_latency=$(awk -F',' -v mode="${MODE}" 'NR>1 && $1==mode {sum+=$6; count++} END {printf "%.2f", sum/count}' "${COMBINED_CSV}")
avg_throughput=$(awk -F',' -v mode="${MODE}" 'NR>1 && $1==mode {sum+=$10; count++} END {printf "%.2f", sum/count}' "${COMBINED_CSV}")
avg_p95=$(awk -F',' -v mode="${MODE}" 'NR>1 && $1==mode {sum+=$8; count++} END {printf "%.2f", sum/count}' "${COMBINED_CSV}")
avg_fulfillment=$(awk -F',' -v mode="${MODE}" 'NR>1 && $1==mode {sum+=$5; count++} END {printf "%.2f", sum/count}' "${COMBINED_CSV}")

echo "Average Metrics:"
echo "  Avg Latency:        ${avg_latency} ms"
echo "  P95 Latency:        ${avg_p95} ms"
echo "  Throughput:         ${avg_throughput} orders/s"
echo "  Fulfillment Rate:   ${avg_fulfillment}%"
echo ""

echo -e "${GREEN}✅ Test completed for ${MODE} mode!${NC}"
echo ""
echo "Results appended to: ${COMBINED_CSV}"
echo ""
echo "Next steps:"
if [ "${MODE}" = "sync" ]; then
    echo "  1. Stop the application"
    echo "  2. Change app.kafka.publishing.mode=async in application.properties"
    echo "  3. Restart application"
    echo "  4. Run: ./quick-performance-comparison.sh async ${ROUNDS}"
else
    echo "  View combined results: cat ${COMBINED_CSV} | column -t -s,"
    echo "  Or open ${COMBINED_CSV} in Excel/Google Sheets"
fi
echo ""
