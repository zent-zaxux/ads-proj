#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# TRUE Concurrent Stress Testing Script
# Spawns actual parallel requests to test real throughput
# ═══════════════════════════════════════════════════════════════════

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
BASE_URL=${BASE_URL:-"http://localhost:8081"}
DURATION=${DURATION:-30}  # Duration per test in seconds
CONCURRENT_USERS_LIST=(10 25 50 100 200)  # Test with increasing concurrency
CSV_FILE="concurrent_results.csv"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="concurrent-test-logs/${TIMESTAMP}"

# Create directories
mkdir -p "$LOG_DIR"

# Initialize CSV
echo "timestamp,concurrent_users,duration_seconds,total_requests,successful_requests,failed_requests,success_rate_percent,throughput_req_per_sec,test_start_time,test_end_time" > "$CSV_FILE"

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║          TRUE CONCURRENT LOAD TESTING                          ║
║          Testing Real Parallel Request Handling                ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${MAGENTA}Test Configuration:${NC}"
echo "  Base URL:        $BASE_URL"
echo "  Duration:        ${DURATION}s per test"
echo "  Concurrency:     ${CONCURRENT_USERS_LIST[@]}"
echo "  Results File:    $CSV_FILE"
echo ""

# Health check
echo -e "${YELLOW}Performing health check...${NC}"
if ! curl -s -f "${BASE_URL}/actuator/health" > /dev/null 2>&1; then
    echo -e "${RED}✗ Application is not running!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Application is healthy${NC}"
echo ""

# Function to send a single request
send_request() {
    local worker_id=$1
    local timestamp=$(date +%s%N)
    local user_id=$((RANDOM % 100000 + 10000))
    local phone="555-${user_id}"
    
    # Create user
    response=$(curl -s -w "\n%{http_code}" --max-time 10 --connect-timeout 5 \
        -H "Content-Type: application/json" \
        -H "Connection: keep-alive" \
        --keepalive-time 60 \
        -X POST "${BASE_URL}/api/users" \
        -d "{
            \"name\": \"ConcurrentUser-${worker_id}-${user_id}\",
            \"email\": \"user${user_id}@conctest.com\",
            \"phoneNumber\": \"${phone}\",
            \"address\": \"123 Concurrent Test St\"
        }" 2>/dev/null)
    
    http_code=$(echo "$response" | tail -n1)
    
    if [ "$http_code" = "200" ] || [ "$http_code" = "201" ]; then
        user_data=$(echo "$response" | sed '$d')
        user_id_result=$(echo "$user_data" | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -1)
        
        if [ -n "$user_id_result" ]; then
            # Create order
            order_response=$(curl -s -w "\n%{http_code}" --max-time 10 --connect-timeout 5 \
                -H "Content-Type: application/json" \
                -H "Connection: keep-alive" \
                --keepalive-time 60 \
                -X POST "${BASE_URL}/api/orders" \
                -d "{
                    \"userId\": ${user_id_result},
                    \"productName\": \"Product-${timestamp}\",
                    \"quantity\": 1,
                    \"unitPrice\": 99.99,
                    \"totalAmount\": 99.99
                }" 2>/dev/null)
            
            order_code=$(echo "$order_response" | tail -n1)
            if [ "$order_code" = "200" ] || [ "$order_code" = "201" ]; then
                echo "SUCCESS"
            else
                echo "FAILED"
            fi
        else
            echo "FAILED"
        fi
    else
        echo "FAILED"
    fi
}

# Worker function that continuously sends requests
worker() {
    local worker_id=$1
    local results_file=$2
    local end_time=$3
    
    while [ $(date +%s) -lt $end_time ]; do
        result=$(send_request $worker_id)
        echo "$result" >> "$results_file"
        sleep 0.05  # Small delay between requests (50ms)
    done
}

# Main test loop
for concurrent_users in "${CONCURRENT_USERS_LIST[@]}"; do
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Testing with $concurrent_users concurrent users${NC}"
    echo -e "${YELLOW}Duration: ${DURATION} seconds${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
    
    test_start=$(date -u +"%Y-%m-%d %H:%M:%S")
    start_epoch=$(date +%s)
    end_epoch=$((start_epoch + DURATION))
    
    # Temporary results file for this test
    temp_results="${LOG_DIR}/concurrent_${concurrent_users}_results.txt"
    rm -f "$temp_results"
    touch "$temp_results"
    
    # Spawn concurrent workers in background
    echo -e "${CYAN}Spawning $concurrent_users concurrent workers...${NC}"
    
    for i in $(seq 1 $concurrent_users); do
        worker $i "$temp_results" $end_epoch &
    done
    
    # Show progress
    echo -e "${CYAN}Test in progress... (${DURATION}s)${NC}"
    elapsed=0
    while [ $elapsed -lt $DURATION ]; do
        sleep 5
        elapsed=$((elapsed + 5))
        current_total=$(wc -l < "$temp_results" 2>/dev/null || echo 0)
        current_successful=$(grep -c "SUCCESS" "$temp_results" 2>/dev/null || echo 0)
        current_throughput=$(awk "BEGIN {printf \"%.2f\", $current_total/$elapsed}")
        echo -e "${BLUE}[${elapsed}s/${DURATION}s] Total: $current_total | Successful: $current_successful | Throughput: ${current_throughput} req/s${NC}"
    done
    
    # Wait for all background workers to complete
    wait
    
    test_end=$(date -u +"%Y-%m-%d %H:%M:%S")
    
    # Calculate final metrics
    total=$(wc -l < "$temp_results")
    successful=$(grep -c "SUCCESS" "$temp_results" || echo 0)
    failed=$((total - successful))
    
    if [ $total -gt 0 ]; then
        success_rate=$(awk "BEGIN {printf \"%.2f\", ($successful/$total)*100}")
        throughput=$(awk "BEGIN {printf \"%.2f\", $total/$DURATION}")
    else
        success_rate="0.00"
        throughput="0.00"
    fi
    
    # Append to CSV
    echo "$(date -u +"%Y-%m-%d %H:%M:%S"),$concurrent_users,$DURATION,$total,$successful,$failed,$success_rate,$throughput,$test_start,$test_end" >> "$CSV_FILE"
    
    echo ""
    echo -e "${GREEN}✓ Test completed${NC}"
    echo -e "${GREEN}  Concurrent Users:  $concurrent_users${NC}"
    echo -e "${GREEN}  Total Requests:    $total${NC}"
    echo -e "${GREEN}  Successful:        $successful${NC}"
    echo -e "${GREEN}  Failed:            $failed${NC}"
    echo -e "${GREEN}  Success Rate:      ${success_rate}%${NC}"
    echo -e "${MAGENTA}  Throughput:        ${throughput} req/s${NC}"
    echo ""
    
    # Cooldown
    if [ "$concurrent_users" != "${CONCURRENT_USERS_LIST[-1]}" ]; then
        echo -e "${CYAN}Cooldown: 10 seconds...${NC}"
        sleep 10
    fi
done

# Summary
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Concurrent Load Testing Completed                 ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}Results saved to: ${CSV_FILE}${NC}"
echo -e "${GREEN}Logs saved to: ${LOG_DIR}/${NC}"
echo ""

echo -e "${YELLOW}Results Summary:${NC}"
column -t -s ',' "$CSV_FILE"

echo ""
echo -e "${MAGENTA}Throughput Analysis:${NC}"
awk -F',' 'NR>1 {
    users=$2
    throughput=$8
    bar_length=int(throughput/2)
    if (bar_length > 50) bar_length=50
    printf "  %3d users: ", users
    for(i=0; i<bar_length; i++) printf "█"
    printf " %.2f req/s\n", throughput
}' "$CSV_FILE"

echo ""
echo -e "${GREEN}✓ Testing Complete!${NC}"
