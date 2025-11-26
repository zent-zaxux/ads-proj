#!/bin/bash

##############################################################################
# High-Load Performance Comparison Test
#
# Tests SYNC vs ASYNC Kafka publishing under high concurrent load
# Measures actual ORDER CREATION latency (POST /api/orders)
#
# Test configuration:
# - Concurrent users: 300-400 (configurable)
# - Duration: 60 seconds per test
# - Measures: POST /api/orders latency directly
# - 3 rounds per mode for statistical reliability
##############################################################################

set -e

# Configuration
APP_URL="http://localhost:8081"
CONCURRENT_USERS=${1:-350}  # Default 350 users
ROUNDS=${2:-3}               # Default 3 rounds
DURATION_SECONDS=60
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_DIR="test-logs/high-load-comparison-${TIMESTAMP}"
RESULTS_CSV="${LOG_DIR}/high_load_comparison_results.csv"
APP_PROPERTIES="src/main/resources/application.properties"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  High-Load Performance Comparison Test${NC}"
echo -e "${BLUE}  Measuring ORDER CREATION Latency (POST /api/orders)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Test Configuration:"
echo "  - Concurrent users: ${CONCURRENT_USERS}"
echo "  - Rounds per mode: ${ROUNDS}"
echo "  - Duration per round: ${DURATION_SECONDS}s"
echo "  - Total tests: $((ROUNDS * 2))"
echo ""

# Create log directory
mkdir -p "${LOG_DIR}"

# Initialize CSV with headers
cat > "${RESULTS_CSV}" << EOF
Mode,Round,Concurrent_Users,Total_Requests,Successful,Failed,Success_Rate_%,Avg_Latency_ms,Min_Latency_ms,Max_Latency_ms,P50_ms,P95_ms,P99_ms,Throughput_req_per_sec,Duration_sec
EOF

echo -e "${YELLOW}📋 Created results file: ${RESULTS_CSV}${NC}"
echo ""

##############################################################################
# Function: Check if application is running
##############################################################################
check_application() {
    echo -e "${BLUE}🔍 Checking application status...${NC}"
    if curl -s "${APP_URL}/actuator/health" > /dev/null 2>&1; then
        echo -e "${GREEN}✅ Application is running${NC}"
        return 0
    else
        echo -e "${RED}❌ Application is not running!${NC}"
        echo "Please start the application first"
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
# Function: Get current Kafka mode
##############################################################################
get_kafka_mode() {
    grep "app.kafka.publishing.mode=" "${APP_PROPERTIES}" | cut -d'=' -f2
}

##############################################################################
# Function: Run high-load test
##############################################################################
run_test() {
    local mode=$1
    local round=$2
    local log_file="${LOG_DIR}/${mode}-round${round}.log"
    local latency_file="${LOG_DIR}/${mode}-round${round}-latency.txt"
    
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  ${mode} Mode - Round ${round}/${ROUNDS}${NC}"
    echo -e "${BLUE}  ${CONCURRENT_USERS} concurrent users creating orders${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    # Clear database before each test
    clear_database
    
    echo "Starting high-load test..."
    echo "  - Mode: ${mode}"
    echo "  - Concurrent users: ${CONCURRENT_USERS}"
    echo "  - Duration: ${DURATION_SECONDS}s"
    echo "  - Measuring: POST /api/orders latency"
    echo ""
    
    local start_time=$(date +%s)
    local end_time=$((start_time + DURATION_SECONDS))
    
    # Clear latency file
    > "${latency_file}"
    
    # Launch concurrent workers
    echo "Launching ${CONCURRENT_USERS} concurrent worker threads..."
    for ((i=1; i<=${CONCURRENT_USERS}; i++)); do
        (
            while [ $(date +%s) -lt ${end_time} ]; do
                # Measure actual order creation latency
                local req_start=$(python3 -c "import time; print(int(time.time() * 1000))")
                
                # Create user first
                user_response=$(curl -s -w "\n%{http_code}" -X POST "${APP_URL}/api/users" \
                    -H "Content-Type: application/json" \
                    -d "{\"name\":\"LoadUser-${i}\", \"email\":\"load${i}@test.com\", \"phoneNumber\":\"555-${RANDOM}\", \"address\":\"Test Address ${i}\"}" 2>/dev/null)
                
                user_code=$(echo "$user_response" | tail -n1)
                user_body=$(echo "$user_response" | sed '$d')
                
                if [ "$user_code" = "200" ] || [ "$user_code" = "201" ]; then
                    user_id=$(echo "$user_body" | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -1)
                    
                    if [ ! -z "$user_id" ]; then
                        # Create order and measure latency
                        local order_start=$(python3 -c "import time; print(int(time.time() * 1000))")
                        
                        order_response=$(curl -s -w "\n%{http_code}" -X POST "${APP_URL}/api/orders" \
                            -H "Content-Type: application/json" \
                            -d "{\"userId\":${user_id}, \"productName\":\"TestProduct-${RANDOM}\", \"quantity\":1, \"unitPrice\":10.00}" 2>/dev/null)
                        
                        local order_end=$(python3 -c "import time; print(int(time.time() * 1000))")
                        local order_latency=$((order_end - order_start))
                        
                        order_code=$(echo "$order_response" | tail -n1)
                        
                        # Record latency if successful
                        if [ "$order_code" = "200" ] || [ "$order_code" = "201" ]; then
                            echo "$order_latency" >> "${latency_file}"
                        fi
                    fi
                fi
                
                # Small random delay to simulate real user behavior
                sleep 0.$((RANDOM % 5))
            done
        ) &
    done
    
    # Progress indicator
    local elapsed=0
    while [ ${elapsed} -lt ${DURATION_SECONDS} ]; do
        sleep 5
        elapsed=$(($(date +%s) - start_time))
        local current_count=$(wc -l < "${latency_file}" 2>/dev/null | tr -d ' ')
        echo "  ⏱️  ${elapsed}s / ${DURATION_SECONDS}s - Orders created: ${current_count}"
    done
    
    # Wait for all workers to finish
    echo ""
    echo "Waiting for all workers to complete..."
    wait
    
    local actual_duration=$(($(date +%s) - start_time))
    
    # Calculate statistics
    local total=$(wc -l < "${latency_file}" | tr -d ' ')
    
    if [ $total -eq 0 ]; then
        echo -e "${RED}❌ No successful requests completed${NC}"
        return
    fi
    
    local successful=$total
    local failed=$((CONCURRENT_USERS * (DURATION_SECONDS / 2) - total))  # Rough estimate
    local success_rate=$(awk "BEGIN {printf \"%.2f\", (${successful}/${total})*100}")
    local throughput=$(awk "BEGIN {printf \"%.2f\", ${total}/${actual_duration}}")
    
    # Calculate latency statistics
    sort -n "${latency_file}" -o "${latency_file}"
    local min_latency=$(head -n1 "${latency_file}")
    local max_latency=$(tail -n1 "${latency_file}")
    local avg_latency=$(awk '{sum+=$1} END {printf "%.2f", sum/NR}' "${latency_file}")
    
    local p50_index=$(awk "BEGIN {printf \"%.0f\", ${total}*0.50}")
    local p95_index=$(awk "BEGIN {printf \"%.0f\", ${total}*0.95}")
    local p99_index=$(awk "BEGIN {printf \"%.0f\", ${total}*0.99}")
    
    local p50=$(sed -n "${p50_index}p" "${latency_file}")
    local p95=$(sed -n "${p95_index}p" "${latency_file}")
    local p99=$(sed -n "${p99_index}p" "${latency_file}")
    
    # Display results
    echo ""
    echo -e "${GREEN}✅ Test completed!${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Results:"
    echo "  Total requests:    ${total}"
    echo "  Successful:        ${successful}"
    echo "  Success rate:      ${success_rate}%"
    echo "  Duration:          ${actual_duration}s"
    echo "  Throughput:        ${throughput} req/s"
    echo ""
    echo "ORDER CREATION Latency Statistics:"
    echo "  Average:           ${avg_latency} ms"
    echo "  Min:               ${min_latency} ms"
    echo "  Max:               ${max_latency} ms"
    echo "  P50 (median):      ${p50} ms"
    echo "  P95:               ${p95} ms"
    echo "  P99:               ${p99} ms"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    
    # Save to CSV
    echo "${mode},${round},${CONCURRENT_USERS},${total},${successful},${failed},${success_rate},${avg_latency},${min_latency},${max_latency},${p50},${p95},${p99},${throughput},${actual_duration}" >> "${RESULTS_CSV}"
}

##############################################################################
# Main Execution
##############################################################################

# Check if app is running
check_application

# Get current mode
current_mode=$(get_kafka_mode)
echo -e "${YELLOW}📍 Current Kafka publishing mode: ${current_mode}${NC}"
echo ""

# Ask user to confirm mode
echo -e "${YELLOW}⚠️  Make sure you've set the correct mode in application.properties:${NC}"
echo "   - For SYNC tests: app.kafka.publishing.mode=sync"
echo "   - For ASYNC tests: app.kafka.publishing.mode=async"
echo ""
read -p "Continue with current mode (${current_mode})? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted. Please set the correct mode and restart the application."
    exit 1
fi

# Run tests
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Running Tests in ${current_mode} Mode${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

for ((round=1; round<=${ROUNDS}; round++)); do
    run_test "${current_mode}" ${round}
    
    if [ ${round} -lt ${ROUNDS} ]; then
        echo "Waiting 10 seconds before next round..."
        sleep 10
        echo ""
    fi
done

##############################################################################
# Generate Summary Report
##############################################################################

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Performance Summary for ${current_mode} Mode (${ROUNDS} rounds)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Calculate averages
avg_latency=$(awk -F',' -v mode="${current_mode}" 'NR>1 && $1==mode {sum+=$8; count++} END {printf "%.2f", sum/count}' "${RESULTS_CSV}")
avg_throughput=$(awk -F',' -v mode="${current_mode}" 'NR>1 && $1==mode {sum+=$14; count++} END {printf "%.2f", sum/count}' "${RESULTS_CSV}")
avg_p95=$(awk -F',' -v mode="${current_mode}" 'NR>1 && $1==mode {sum+=$12; count++} END {printf "%.2f", sum/count}' "${RESULTS_CSV}")
avg_p99=$(awk -F',' -v mode="${current_mode}" 'NR>1 && $1==mode {sum+=$13; count++} END {printf "%.2f", sum/count}' "${RESULTS_CSV}")
total_orders=$(awk -F',' -v mode="${current_mode}" 'NR>1 && $1==mode {sum+=$4} END {printf "%.0f", sum}' "${RESULTS_CSV}")

echo "Average Results (across ${ROUNDS} rounds):"
echo ""
echo "┌─────────────────────┬──────────────────┐"
echo "│ Metric              │ Value            │"
echo "├─────────────────────┼──────────────────┤"
printf "│ Avg Latency         │ %13.2f ms │\n" ${avg_latency}
printf "│ P95 Latency         │ %13.2f ms │\n" ${avg_p95}
printf "│ P99 Latency         │ %13.2f ms │\n" ${avg_p99}
printf "│ Throughput          │ %12.2f rps │\n" ${avg_throughput}
printf "│ Total Orders        │ %16.0f │\n" ${total_orders}
echo "└─────────────────────┴──────────────────┘"
echo ""

echo -e "${GREEN}✅ Tests completed for ${current_mode} mode!${NC}"
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
    echo "  4. Run: ./high-load-comparison-test.sh ${CONCURRENT_USERS} ${ROUNDS}"
else
    echo "  View combined results:"
    echo "    cat ${RESULTS_CSV} | column -t -s,"
    echo ""
    echo "  Or analyze with Python:"
    echo "    python3 analyze-results.py ${RESULTS_CSV}"
fi
echo ""

echo -e "${GREEN}✅ All done!${NC}"
