#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Autonomous 5-Round Stress Test using Traffic Agent
# ═══════════════════════════════════════════════════════════════════
# 
# This script uses the Traffic Agent and Fulfillment Agent for 
# autonomous load generation and order processing.
#
# Test Configuration:
# - 5 rounds total
# - Each round: 10 → 50 → 100 → 150 → 200 concurrent users
# - Sequential load increase (one level completes before next)
# - Metrics recorded to CSV after each load level
#
# ═══════════════════════════════════════════════════════════════════

set +e  # Continue on errors

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BASE_URL=${BASE_URL:-"http://localhost:8081"}
LOAD_LEVELS=(10 50 100 150 200)  # Sequential load levels
NUM_ROUNDS=5                      # 5 rounds total
DURATION_PER_LEVEL=60            # 60 seconds per load level
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Directory setup
LOG_DIR="./test-logs/autonomous-stress-${TIMESTAMP}"
mkdir -p "$LOG_DIR"

CSV_FILE="${LOG_DIR}/autonomous_stress_results.csv"

# ═══════════════════════════════════════════════════════════════════
# Display Configuration
# ═══════════════════════════════════════════════════════════════════
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       AUTONOMOUS 5-ROUND STRESS TEST (Traffic Agent)         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Test Configuration:${NC}"
echo "  Base URL:             ${BASE_URL}"
echo "  Number of Rounds:     ${NUM_ROUNDS}"
echo "  Load Levels:          ${LOAD_LEVELS[*]} concurrent users"
echo "  Duration per Level:   ${DURATION_PER_LEVEL}s"
echo "  Total Tests:          $((NUM_ROUNDS * ${#LOAD_LEVELS[@]}))"
echo "  Test Mode:            Autonomous (Traffic Agent + Fulfillment Agent)"
echo "  Log Directory:        ${LOG_DIR}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Database Cleanup for Accurate Metrics
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}🧹 Clearing database for accurate fulfillment metrics...${NC}"

# Mark all pending orders as delivered to clear backlog
docker exec postgres psql -U adsuser -d adsdb -c "
UPDATE orders SET status = 'DELIVERED' WHERE status IN ('PENDING', 'CONFIRMED', 'SHIPPED');
DELETE FROM processed_events;
" > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Database cleared - starting with 0 pending orders${NC}"
    
    # Verify cleanup
    PENDING_COUNT=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status != 'DELIVERED';" 2>/dev/null | tr -d ' ')
    echo -e "${CYAN}  Pending orders: ${PENDING_COUNT}${NC}"
else
    echo -e "${YELLOW}⚠ Database cleanup failed (may not be critical)${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Health Checks
# ═══════════════════════════════════════════════════════════════════
echo -e "${BLUE}Performing health checks...${NC}"

# Check application
HEALTH_CHECK=$(curl -s --max-time 5 "${BASE_URL}/actuator/health" || echo "")
if echo "$HEALTH_CHECK" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✓ Application is healthy${NC}"
else
    echo -e "${RED}✗ Application health check failed!${NC}"
    echo "Response: $HEALTH_CHECK"
    exit 1
fi

# Check Traffic Agent
AGENT_HEALTH=$(curl -s --max-time 5 "${BASE_URL}/api/agent/traffic/health" || echo "")
if echo "$AGENT_HEALTH" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✓ Traffic Agent is available${NC}"
else
    echo -e "${RED}✗ Traffic Agent health check failed!${NC}"
    echo "Response: $AGENT_HEALTH"
    exit 1
fi

# Check Fulfillment Agent
FULFILL_HEALTH=$(curl -s --max-time 5 "${BASE_URL}/api/agent/fulfillment/health" || echo "")
if echo "$FULFILL_HEALTH" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✓ Fulfillment Agent is available${NC}"
    
    # Check if Fulfillment Agent is running
    FULFILL_STATUS=$(curl -s "${BASE_URL}/api/agent/fulfillment/status" | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
    if [ "$FULFILL_STATUS" != "RUNNING" ]; then
        echo -e "${YELLOW}⚠ Fulfillment Agent is not running. Starting it with optimized settings...${NC}"
        START_RESULT=$(curl -s -X POST "${BASE_URL}/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1")
        if echo "$START_RESULT" | grep -q '"success":true'; then
            echo -e "${GREEN}✓ Fulfillment Agent started successfully (optimized: 100ms delay, batch 50, poll 1s)${NC}"
        else
            echo -e "${RED}✗ Failed to start Fulfillment Agent${NC}"
        fi
    else
        echo -e "${GREEN}✓ Fulfillment Agent is already running${NC}"
        # Reconfigure with optimized settings if already running
        echo -e "${YELLOW}⚠ Reconfiguring with optimized settings for better performance...${NC}"
        RECONFIG_RESULT=$(curl -s -X POST "${BASE_URL}/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1")
        if echo "$RECONFIG_RESULT" | grep -q '"success":true'; then
            echo -e "${GREEN}✓ Fulfillment Agent reconfigured (optimized: 100ms delay, batch 50, poll 1s)${NC}"
        fi
    fi
else
    echo -e "${YELLOW}⚠ Fulfillment Agent not responding (may not be critical)${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════════
# Initialize CSV
# ═══════════════════════════════════════════════════════════════════
echo "timestamp,round_number,load_level,duration_seconds,orders_created,orders_fulfilled,min_latency_ms,avg_latency_ms,max_latency_ms,p50_latency_ms,p95_latency_ms,p99_latency_ms,throughput_req_per_sec,fulfillment_rate_percent,pattern,test_start_time,test_end_time" > "$CSV_FILE"
echo -e "${GREEN}✓ CSV file initialized: $CSV_FILE${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Helper Functions
# ═══════════════════════════════════════════════════════════════════

# Start Traffic Agent with specific rate
start_traffic_agent() {
    local ops_per_sec=$1
    local pattern=${2:-"STEADY"}
    
    echo -e "${BLUE}Starting Traffic Agent: ${ops_per_sec} ops/sec, pattern: ${pattern}${NC}"
    
    RESPONSE=$(curl -s --max-time 10 \
        -X POST "${BASE_URL}/api/agent/traffic/start?opsPerSecond=${ops_per_sec}&pattern=${pattern}")
    
    if echo "$RESPONSE" | grep -q '"success":true'; then
        echo -e "${GREEN}✓ Traffic Agent started successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start Traffic Agent${NC}"
        echo "Response: $RESPONSE"
        return 1
    fi
}

# Stop Traffic Agent
stop_traffic_agent() {
    echo -e "${BLUE}Stopping Traffic Agent...${NC}"
    
    RESPONSE=$(curl -s --max-time 10 \
        -X POST "${BASE_URL}/api/agent/traffic/stop")
    
    if echo "$RESPONSE" | grep -q '"success":true'; then
        echo -e "${GREEN}✓ Traffic Agent stopped${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠ Traffic Agent stop returned: $RESPONSE${NC}"
        return 1
    fi
}

# Get Traffic Agent statistics
get_traffic_stats() {
    STATS=$(curl -s --max-time 5 "${BASE_URL}/api/agent/traffic/status" || echo "{}")
    echo "$STATS"
}

# Get Fulfillment Agent statistics
get_fulfillment_stats() {
    STATS=$(curl -s --max-time 5 "${BASE_URL}/api/agent/fulfillment/status" || echo "{}")
    echo "$STATS"
}

# Get Order Service statistics (using paginated endpoint)
get_order_stats() {
    STATS=$(curl -s --max-time 5 "${BASE_URL}/api/orders?page=0&size=1" || echo "{}")
    echo "$STATS"
}

# Get Kafka lag information
get_kafka_lag() {
    # This assumes you have a Kafka monitoring endpoint
    # Adjust based on your actual implementation
    LAG=$(curl -s --max-time 5 "${BASE_URL}/actuator/metrics/kafka.consumer.lag" 2>/dev/null || echo "0")
    
    # Extract lag value from Actuator metrics format
    LAG_VALUE=$(echo "$LAG" | jq -r '.measurements[0].value // 0' 2>/dev/null || echo "0")
    echo "$LAG_VALUE"
}

# ═══════════════════════════════════════════════════════════════════
# Main Test Loop - 5 Rounds of Sequential Load Levels
# ═══════════════════════════════════════════════════════════════════
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              STARTING 5-ROUND AUTONOMOUS TEST                  ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_TESTS=$((NUM_ROUNDS * ${#LOAD_LEVELS[@]}))
TEST_COUNTER=0

for ROUND in $(seq 1 $NUM_ROUNDS); do
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║             ROUND ${ROUND}/${NUM_ROUNDS} - LOAD CYCLE 10→200               ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    for LOAD_LEVEL in "${LOAD_LEVELS[@]}"; do
        TEST_COUNTER=$((TEST_COUNTER + 1))
        
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${YELLOW}  Round ${ROUND}/${NUM_ROUNDS} | Load: ${LOAD_LEVEL} users | Test ${TEST_COUNTER}/${TOTAL_TESTS}${NC}"
        echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
        
        LOG_FILE="${LOG_DIR}/round_${ROUND}_load_${LOAD_LEVEL}.log"
        LATENCY_FILE="${LOG_DIR}/round_${ROUND}_load_${LOAD_LEVEL}_latencies.dat"
        TEST_START=$(date -u +"%Y-%m-%d %H:%M:%S")
        TEST_START_EPOCH=$(date +%s)
        
        # Clear latency file
        > "$LATENCY_FILE"
        
        # Determine traffic pattern based on round (for variety)
        case $((ROUND % 5)) in
            1) PATTERN="STEADY" ;;
            2) PATTERN="BURST" ;;
            3) PATTERN="RAMP_UP" ;;
            4) PATTERN="SPIKE" ;;
            0) PATTERN="RANDOM" ;;
        esac
        
        echo "Round ${ROUND} - Load Level ${LOAD_LEVEL}" > "$LOG_FILE"
        echo "Duration: ${DURATION_PER_LEVEL} seconds" >> "$LOG_FILE"
        echo "Pattern: ${PATTERN}" >> "$LOG_FILE"
        echo "Start time: ${TEST_START}" >> "$LOG_FILE"
        echo "" >> "$LOG_FILE"
        
        # Calculate ops/sec to simulate concurrent users
        # Rough estimate: each user makes ~1 request every 2 seconds
        OPS_PER_SEC=$((LOAD_LEVEL / 2))
        if [ "$OPS_PER_SEC" -lt 1 ]; then OPS_PER_SEC=1; fi
        if [ "$OPS_PER_SEC" -gt 100 ]; then OPS_PER_SEC=100; fi
        
        # Start Traffic Agent
        if ! start_traffic_agent $OPS_PER_SEC $PATTERN; then
            echo -e "${RED}✗ Failed to start Traffic Agent for this test${NC}"
            continue
        fi
        
        # Get initial statistics - use database queries for accurate counts
        INITIAL_ORDERS=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders;" 2>/dev/null | tr -d ' ')
        INITIAL_PENDING=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'PENDING';" 2>/dev/null | tr -d ' ')
        INITIAL_DELIVERED=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'DELIVERED';" 2>/dev/null | tr -d ' ')
        
        # Fallback to 0 if queries fail
        INITIAL_ORDERS=${INITIAL_ORDERS:-0}
        INITIAL_PENDING=${INITIAL_PENDING:-0}
        INITIAL_DELIVERED=${INITIAL_DELIVERED:-0}
        
        echo -e "${CYAN}Test running for ${DURATION_PER_LEVEL} seconds...${NC}"
        echo -e "${MAGENTA}Pattern: ${PATTERN} | Ops/sec: ${OPS_PER_SEC}${NC}"
        
        # Monitor progress during test
        ELAPSED=0
        while [ $ELAPSED -lt $DURATION_PER_LEVEL ]; do
            sleep 5
            ELAPSED=$(($(date +%s) - TEST_START_EPOCH))
            
            # Sample latency by making a test request every 5 seconds
            LAT_START=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || echo $(($(date +%s) * 1000)))
            curl -s --max-time 2 "${BASE_URL}/actuator/health" > /dev/null 2>&1
            LAT_END=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || echo $(($(date +%s) * 1000)))
            SAMPLE_LAT=$((LAT_END - LAT_START))
            echo "$SAMPLE_LAT" >> "$LATENCY_FILE"
            
            # Get current stats - use database queries for accurate counts
            CURRENT_ORDERS=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders;" 2>/dev/null | tr -d ' ')
            CURRENT_DELIVERED=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'DELIVERED';" 2>/dev/null | tr -d ' ')
            
            # Fallback to 0 if queries fail
            CURRENT_ORDERS=${CURRENT_ORDERS:-0}
            CURRENT_DELIVERED=${CURRENT_DELIVERED:-0}
            
            ORDERS_CREATED=$((CURRENT_ORDERS - INITIAL_ORDERS))
            ORDERS_FULFILLED=$((CURRENT_DELIVERED - INITIAL_DELIVERED))
            
            if [ $ELAPSED -gt 0 ]; then
                CURRENT_THROUGHPUT=$(awk "BEGIN {printf \"%.2f\", $ORDERS_CREATED/$ELAPSED}")
            else
                CURRENT_THROUGHPUT="0.00"
            fi
            
            printf "\r  [${ELAPSED}s/${DURATION_PER_LEVEL}s] Pattern: ${PATTERN} | Created: ${ORDERS_CREATED} | Fulfilled: ${ORDERS_FULFILLED} | Throughput: ${CURRENT_THROUGHPUT} req/s"
        done
        
        echo ""
        
        # Stop Traffic Agent
        stop_traffic_agent
        
        # Wait a moment for final processing
        echo -e "${BLUE}Waiting 5s for final processing...${NC}"
        sleep 5
        
        TEST_END_EPOCH=$(date +%s)
        TEST_END=$(date -u +"%Y-%m-%d %H:%M:%S")
        ACTUAL_DURATION=$((TEST_END_EPOCH - TEST_START_EPOCH))
        
        # Get final statistics - use database queries for accurate counts
        FINAL_ORDERS=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders;" 2>/dev/null | tr -d ' ')
        FINAL_DELIVERED=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'DELIVERED';" 2>/dev/null | tr -d ' ')
        FINAL_PENDING=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'PENDING';" 2>/dev/null | tr -d ' ')
        
        # Fallback to 0 if queries fail
        FINAL_ORDERS=${FINAL_ORDERS:-0}
        FINAL_DELIVERED=${FINAL_DELIVERED:-0}
        FINAL_PENDING=${FINAL_PENDING:-0}
        
        ORDERS_CREATED=$((FINAL_ORDERS - INITIAL_ORDERS))
        ORDERS_FULFILLED=$((FINAL_DELIVERED - INITIAL_DELIVERED))
        
        # Calculate latency percentiles
        if [ -s "$LATENCY_FILE" ]; then
            sort -n "$LATENCY_FILE" > "${LATENCY_FILE}.sorted"
            
            MIN_LAT=$(head -1 "${LATENCY_FILE}.sorted")
            MAX_LAT=$(tail -1 "${LATENCY_FILE}.sorted")
            AVG_LAT=$(awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "${LATENCY_FILE}.sorted")
            
            TOTAL_SAMPLES=$(wc -l < "${LATENCY_FILE}.sorted")
            
            # P50 (median)
            P50_INDEX=$(awk "BEGIN {printf \"%.0f\", $TOTAL_SAMPLES * 0.50}")
            if [ "$P50_INDEX" -lt 1 ]; then P50_INDEX=1; fi
            P50_LAT=$(sed -n "${P50_INDEX}p" "${LATENCY_FILE}.sorted")
            
            # P95
            P95_INDEX=$(awk "BEGIN {printf \"%.0f\", $TOTAL_SAMPLES * 0.95}")
            if [ "$P95_INDEX" -lt 1 ]; then P95_INDEX=1; fi
            P95_LAT=$(sed -n "${P95_INDEX}p" "${LATENCY_FILE}.sorted")
            
            # P99
            P99_INDEX=$(awk "BEGIN {printf \"%.0f\", $TOTAL_SAMPLES * 0.99}")
            if [ "$P99_INDEX" -lt 1 ]; then P99_INDEX=1; fi
            P99_LAT=$(sed -n "${P99_INDEX}p" "${LATENCY_FILE}.sorted")
            
            rm -f "${LATENCY_FILE}.sorted"
        else
            MIN_LAT=0; MAX_LAT=0; AVG_LAT=0; P50_LAT=0; P95_LAT=0; P99_LAT=0
        fi
        
        # Calculate fulfillment rate and throughput
        if [ "$ORDERS_CREATED" -gt 0 ]; then
            FULFILLMENT_RATE=$(awk "BEGIN {printf \"%.2f\", ($ORDERS_FULFILLED/$ORDERS_CREATED)*100}")
            THROUGHPUT=$(awk "BEGIN {printf \"%.2f\", $ORDERS_CREATED/$ACTUAL_DURATION}")
        else
            FULFILLMENT_RATE="0.00"
            THROUGHPUT="0.00"
        fi
        
        # Display results
        echo -e "${GREEN}✓ Test completed (Round ${ROUND}, Load ${LOAD_LEVEL})${NC}"
        echo -e "${CYAN}Results:${NC}"
        echo "  Load Level:          ${LOAD_LEVEL} concurrent users (simulated)"
        echo "  Pattern:             ${PATTERN}"
        echo "  Orders Created:      ${ORDERS_CREATED}"
        echo "  Orders Fulfilled:    ${ORDERS_FULFILLED}"
        echo "  Orders Pending:      $((FINAL_PENDING - INITIAL_PENDING))"
        echo "  Fulfillment Rate:    ${FULFILLMENT_RATE}%"
        echo -e "${MAGENTA}  Latency (min/avg/max): ${MIN_LAT}ms / ${AVG_LAT}ms / ${MAX_LAT}ms${NC}"
        echo -e "${MAGENTA}  Latency (p50/p95/p99): ${P50_LAT}ms / ${P95_LAT}ms / ${P99_LAT}ms${NC}"
        echo -e "${BLUE}  Throughput:          ${THROUGHPUT} req/s${NC}"
        echo "  Actual Duration:     ${ACTUAL_DURATION}s"
        
        # Save to log file
        echo "" >> "$LOG_FILE"
        echo "=== Test Summary ===" >> "$LOG_FILE"
        echo "Round: ${ROUND}" >> "$LOG_FILE"
        echo "Load Level: ${LOAD_LEVEL} concurrent users" >> "$LOG_FILE"
        echo "Pattern: ${PATTERN}" >> "$LOG_FILE"
        echo "Orders Created: ${ORDERS_CREATED}" >> "$LOG_FILE"
        echo "Orders Fulfilled: ${ORDERS_FULFILLED}" >> "$LOG_FILE"
        echo "Fulfillment Rate: ${FULFILLMENT_RATE}%" >> "$LOG_FILE"
        echo "Latency (min/avg/max): ${MIN_LAT}/${AVG_LAT}/${MAX_LAT}ms" >> "$LOG_FILE"
        echo "Latency (p50/p95/p99): ${P50_LAT}/${P95_LAT}/${P99_LAT}ms" >> "$LOG_FILE"
        echo "Throughput: ${THROUGHPUT} req/s" >> "$LOG_FILE"
        echo "End time: ${TEST_END}" >> "$LOG_FILE"
        
        # Append to CSV
        echo "$(date -u +"%Y-%m-%d %H:%M:%S"),${ROUND},${LOAD_LEVEL},${ACTUAL_DURATION},${ORDERS_CREATED},${ORDERS_FULFILLED},${MIN_LAT},${AVG_LAT},${MAX_LAT},${P50_LAT},${P95_LAT},${P99_LAT},${THROUGHPUT},${FULFILLMENT_RATE},${PATTERN},${TEST_START},${TEST_END}" >> "$CSV_FILE"
        
        echo -e "${GREEN}✓ Results appended to CSV${NC}"
        
        # Cooldown between load levels within a round
        LAST_LOAD_LEVEL=${LOAD_LEVELS[${#LOAD_LEVELS[@]}-1]}
        if [ "$LOAD_LEVEL" != "$LAST_LOAD_LEVEL" ]; then
            COOLDOWN_TIME=10
            echo -e "${MAGENTA}→ Cooldown: Waiting ${COOLDOWN_TIME}s before next load level...${NC}"
            sleep $COOLDOWN_TIME
            echo ""
        fi
    done
    
    # Longer cooldown between rounds
    if [ $ROUND -lt $NUM_ROUNDS ]; then
        ROUND_COOLDOWN=20
        echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║  Round ${ROUND} Complete - Stabilizing before Round $((ROUND + 1))           ║${NC}"
        echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
        echo -e "${MAGENTA}→ Inter-round cooldown: ${ROUND_COOLDOWN}s for system stabilization...${NC}"
        sleep $ROUND_COOLDOWN
        echo ""
    fi
done

# ═══════════════════════════════════════════════════════════════════
# Final Summary
# ═══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           5-ROUND AUTONOMOUS TEST COMPLETED                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ Completed ${NUM_ROUNDS} rounds with ${#LOAD_LEVELS[@]} load levels each${NC}"
echo -e "${YELLOW}Results Directory:${NC} $LOG_DIR"
echo -e "${YELLOW}CSV Results:${NC} $CSV_FILE"
echo ""

# Calculate overall statistics from CSV
if [ -f "$CSV_FILE" ]; then
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Overall Statistics${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    
    TOTAL_ORDERS=$(awk -F',' 'NR>1 {sum+=$5} END {print sum}' "$CSV_FILE")
    TOTAL_FULFILLED=$(awk -F',' 'NR>1 {sum+=$6} END {print sum}' "$CSV_FILE")
    AVG_THROUGHPUT=$(awk -F',' 'NR>1 {sum+=$13; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    AVG_FULFILLMENT=$(awk -F',' 'NR>1 {sum+=$14; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    AVG_P50=$(awk -F',' 'NR>1 {sum+=$10; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    AVG_P95=$(awk -F',' 'NR>1 {sum+=$11; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    AVG_P99=$(awk -F',' 'NR>1 {sum+=$12; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    
    echo "  Total Tests Run:      ${TOTAL_TESTS}"
    echo "  Total Orders Created: ${TOTAL_ORDERS}"
    echo "  Total Orders Fulfilled: ${TOTAL_FULFILLED}"
    echo "  Average Fulfillment Rate: ${AVG_FULFILLMENT}%"
    echo -e "${MAGENTA}  Average Throughput:   ${AVG_THROUGHPUT} req/s${NC}"
    echo -e "${MAGENTA}  Average Latency (p50/p95/p99): ${AVG_P50}ms / ${AVG_P95}ms / ${AVG_P99}ms${NC}"
    
    echo ""
    echo -e "${BLUE}  Performance by Load Level (averaged across all rounds):${NC}"
    for LOAD_LEVEL in "${LOAD_LEVELS[@]}"; do
        LOAD_AVG_THROUGHPUT=$(awk -F',' -v load="$LOAD_LEVEL" 'NR>1 && $3==load {sum+=$13; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
        LOAD_AVG_P95=$(awk -F',' -v load="$LOAD_LEVEL" 'NR>1 && $3==load {sum+=$11; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
        LOAD_FULFILL_RATE=$(awk -F',' -v load="$LOAD_LEVEL" 'NR>1 && $3==load {sum+=$14; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
        echo "    Load ${LOAD_LEVEL}: ${LOAD_AVG_THROUGHPUT} req/s | P95: ${LOAD_AVG_P95}ms | Fulfillment: ${LOAD_FULFILL_RATE}%"
    done
    
    echo ""
    echo -e "${BLUE}  Performance by Traffic Pattern:${NC}"
    for PATTERN in "STEADY" "BURST" "RAMP_UP" "SPIKE" "RANDOM"; do
        PATTERN_THROUGHPUT=$(awk -F',' -v pat="$PATTERN" 'NR>1 && $15==pat {sum+=$13; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
        PATTERN_COUNT=$(awk -F',' -v pat="$PATTERN" 'NR>1 && $15==pat {count++} END {print count}' "$CSV_FILE")
        if [ "$PATTERN_COUNT" -gt 0 ]; then
            echo "    ${PATTERN}: ${PATTERN_THROUGHPUT} req/s (${PATTERN_COUNT} tests)"
        fi
    done
fi

echo ""
echo -e "${GREEN}✓ Autonomous 5-round stress test completed successfully!${NC}"
echo -e "${CYAN}This test used Traffic Agent + Fulfillment Agent for autonomous load generation${NC}"
echo ""
