#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Enhanced Concurrent Stress Test with Latency Percentiles
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
NUM_SESSIONS=${NUM_SESSIONS:-10}
MIN_WORKERS=${MIN_WORKERS:-10}
MAX_WORKERS=${MAX_WORKERS:-400}  # Reduced to avoid system resource exhaustion
DURATION=${DURATION:-90}  # Longer duration to accommodate worker ramp-up
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

# Directory setup
LOG_DIR="./test-logs/stress-test-concurrent-${TIMESTAMP}"
mkdir -p "$LOG_DIR"

CSV_FILE="${LOG_DIR}/concurrent_stress_test_results.csv"

# ═══════════════════════════════════════════════════════════════════
# Display Configuration
# ═══════════════════════════════════════════════════════════════════
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    ENHANCED CONCURRENT STRESS TEST - WITH LATENCY METRICS     ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}Test Configuration:${NC}"
echo "  Base URL:             ${BASE_URL}"
echo "  Number of Sessions:   ${NUM_SESSIONS}"
echo "  Workers per Session:  ${MIN_WORKERS} → ${MAX_WORKERS} (gradual ramp-up)"
echo "  Duration per Session: ${DURATION}s"
echo "  Test Mode:            Continuous worker scaling"
echo "  Log Directory:        ${LOG_DIR}"
echo ""

# Health check
echo -e "${BLUE}Checking application health...${NC}"
HEALTH_CHECK=$(curl -s --max-time 5 "${BASE_URL}/actuator/health" || echo "")
if echo "$HEALTH_CHECK" | grep -q '"status":"UP"'; then
    echo -e "${GREEN}✓ Application is healthy${NC}"
else
    echo -e "${RED}✗ Application health check failed!${NC}"
    echo "Response: $HEALTH_CHECK"
    exit 1
fi
echo ""

# Initialize CSV
echo "timestamp,session_number,concurrent_workers,duration_seconds,total_requests,successful_requests,failed_requests,success_rate_percent,min_latency_ms,avg_latency_ms,max_latency_ms,p50_latency_ms,p95_latency_ms,p99_latency_ms,throughput_req_per_sec,test_start_time,test_end_time" > "$CSV_FILE"
echo -e "${GREEN}✓ CSV file initialized: $CSV_FILE${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Worker Function
# ═══════════════════════════════════════════════════════════════════
worker_process() {
    local worker_id=$1
    local session_num=$2
    local end_time=$3
    local results_file=$4
    local latency_file=$5
    
    while [ $(date +%s) -lt $end_time ]; do
        RANDOM_NUM=$((RANDOM * RANDOM))
        USER_EMAIL="worker${worker_id}-s${session_num}-${TIMESTAMP}-${RANDOM_NUM}@test.com"
        USER_PHONE="555-$((1000000 + RANDOM % 9000000))"
        
        # Start timing (milliseconds) - macOS compatible
        REQ_START=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || gdate +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
        
        # Create user
        USER_RESPONSE=$(curl -s --max-time 10 --connect-timeout 5 --keepalive-time 60 \
            -X POST "${BASE_URL}/api/users" \
            -H "Content-Type: application/json" \
            -H "Connection: keep-alive" \
            -d "{\"name\":\"Worker${worker_id}\",\"email\":\"$USER_EMAIL\",\"phoneNumber\":\"$USER_PHONE\",\"address\":\"Test Address\"}" \
            2>&1)
        
        USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")
        
        if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
            # Create order
            ORDER_RESPONSE=$(curl -s --max-time 10 --connect-timeout 5 --keepalive-time 60 \
                -X POST "${BASE_URL}/api/orders" \
                -H "Content-Type: application/json" \
                -H "Connection: keep-alive" \
                -d "{\"userId\":$USER_ID,\"productName\":\"Product\",\"quantity\":1,\"unitPrice\":99.99,\"totalAmount\":99.99}" \
                2>&1)
            
            ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")
            
            # End timing
            REQ_END=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || gdate +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
            LATENCY=$((REQ_END - REQ_START))
            
            if [ -n "$ORDER_ID" ] && [ "$ORDER_ID" != "null" ]; then
                echo "SUCCESS" >> "$results_file"
                echo "$LATENCY" >> "$latency_file"
            else
                echo "FAILED" >> "$results_file"
            fi
        else
            echo "FAILED" >> "$results_file"
        fi
        
        # Small delay to prevent overwhelming the system
        sleep 0.05
    done
}

# ═══════════════════════════════════════════════════════════════════
# Main Test Loop
# ═══════════════════════════════════════════════════════════════════
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         STARTING CONCURRENT STRESS TEST SESSIONS              ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_SESSIONS=${NUM_SESSIONS}

for SESSION_NUMBER in $(seq 1 $TOTAL_SESSIONS); do
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  SESSION ${SESSION_NUMBER}/${TOTAL_SESSIONS}: Ramping ${MIN_WORKERS} → ${MAX_WORKERS} Workers${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    
    LOG_FILE="${LOG_DIR}/session_${SESSION_NUMBER}_ramp_${MIN_WORKERS}_to_${MAX_WORKERS}.log"
    LATENCY_FILE="${LOG_DIR}/session_${SESSION_NUMBER}_latencies.dat"
    RESULTS_FILE="${LOG_DIR}/session_${SESSION_NUMBER}_results.dat"
    TEST_START=$(date -u +"%Y-%m-%d %H:%M:%S")
    TEST_START_EPOCH=$(date +%s)
    END_TIME=$((TEST_START_EPOCH + DURATION))
    
    # Clear temporary files
    > "$LATENCY_FILE"
    > "$RESULTS_FILE"
    
    echo "Session ${SESSION_NUMBER} - ${MIN_WORKERS} to ${MAX_WORKERS} concurrent workers (gradual ramp)" > "$LOG_FILE"
    echo "Duration: ${DURATION} seconds" >> "$LOG_FILE"
    echo "Start time: ${TEST_START}" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    echo -e "${BLUE}Spawning workers gradually from ${MIN_WORKERS} to ${MAX_WORKERS} over ${DURATION}s${NC}"
    
    # Calculate worker increment rate
    WORKER_INCREMENT_RATE=$(awk "BEGIN {printf \"%.4f\", ($MAX_WORKERS - $MIN_WORKERS) / $DURATION}")
    
    # Track spawned worker PIDs
    WORKER_PIDS=()
    CURRENT_WORKERS=0
    
    # Start with initial workers
    for worker_id in $(seq 1 $MIN_WORKERS); do
        worker_process $worker_id $SESSION_NUMBER $END_TIME "$RESULTS_FILE" "$LATENCY_FILE" &
        WORKER_PIDS+=($!)
    done
    CURRENT_WORKERS=$MIN_WORKERS
    NEXT_WORKER_ID=$((MIN_WORKERS + 1))
    
    echo -e "${CYAN}Started with ${MIN_WORKERS} workers, ramping up...${NC}"
    
    # Monitor progress and spawn new workers gradually
    echo -e "${CYAN}Test in progress...${NC}"
    ELAPSED=0
    LAST_SPAWN_TIME=0
    
    while [ $ELAPSED -lt $DURATION ]; do
        sleep 1
        ELAPSED=$(($(date +%s) - TEST_START_EPOCH))
        
        # Calculate target worker count based on elapsed time
        TARGET_WORKERS=$(awk "BEGIN {target = $MIN_WORKERS + ($WORKER_INCREMENT_RATE * $ELAPSED); if(target > $MAX_WORKERS) target = $MAX_WORKERS; printf \"%.0f\", target}")
        
        # Spawn new workers if needed
        while [ $CURRENT_WORKERS -lt $TARGET_WORKERS ] && [ $CURRENT_WORKERS -lt $MAX_WORKERS ]; do
            worker_process $NEXT_WORKER_ID $SESSION_NUMBER $END_TIME "$RESULTS_FILE" "$LATENCY_FILE" &
            WORKER_PIDS+=($!)
            NEXT_WORKER_ID=$((NEXT_WORKER_ID + 1))
            CURRENT_WORKERS=$((CURRENT_WORKERS + 1))
        done
        
        # Progress update every 5 seconds
        if [ $((ELAPSED % 5)) -eq 0 ]; then
            CURRENT_TOTAL=$(wc -l < "$RESULTS_FILE" 2>/dev/null || echo 0)
            CURRENT_SUCCESS=$(grep -c "SUCCESS" "$RESULTS_FILE" 2>/dev/null || echo 0)
            CURRENT_THROUGHPUT=$(awk "BEGIN {if($ELAPSED>0) printf \"%.2f\", $CURRENT_TOTAL/$ELAPSED; else print \"0\"}")
            printf "\r  [${ELAPSED}s/${DURATION}s] Workers: ${CURRENT_WORKERS}/${MAX_WORKERS} | Requests: ${CURRENT_TOTAL} | Success: ${CURRENT_SUCCESS} | Throughput: ${CURRENT_THROUGHPUT} req/s"
        fi
    done
    
    # Wait for all workers to finish
    wait
    
    echo ""
    
    TEST_END_EPOCH=$(date +%s)
    TEST_END=$(date -u +"%Y-%m-%d %H:%M:%S")
    ACTUAL_DURATION=$((TEST_END_EPOCH - TEST_START_EPOCH))
    
    # Calculate metrics from results
    TOTAL_REQ=$(wc -l < "$RESULTS_FILE" 2>/dev/null || echo 0)
    SUCCESS_REQ=$(grep -c "SUCCESS" "$RESULTS_FILE" 2>/dev/null || echo 0)
    FAILED_REQ=$((TOTAL_REQ - SUCCESS_REQ))
    
    if [ "$TOTAL_REQ" -gt 0 ]; then
        SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESS_REQ/$TOTAL_REQ)*100}")
        THROUGHPUT=$(awk "BEGIN {printf \"%.2f\", $TOTAL_REQ/$ACTUAL_DURATION}")
    else
        SUCCESS_RATE="0.00"
        THROUGHPUT="0.00"
    fi
    
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
    
    # Display metrics
    echo -e "${GREEN}✓ Session ${SESSION_NUMBER} completed${NC}"
    echo -e "${CYAN}Results:${NC}"
    echo "  Worker Range:        ${MIN_WORKERS} → ${MAX_WORKERS} (peak: ${CURRENT_WORKERS})"
    echo "  Total Requests:      $TOTAL_REQ"
    echo "  Successful:          $SUCCESS_REQ"
    echo "  Failed:              $FAILED_REQ"
    echo "  Success Rate:        ${SUCCESS_RATE}%"
    echo -e "${MAGENTA}  Latency (min/avg/max): ${MIN_LAT}ms / ${AVG_LAT}ms / ${MAX_LAT}ms${NC}"
    echo -e "${MAGENTA}  Latency (p50/p95/p99): ${P50_LAT}ms / ${P95_LAT}ms / ${P99_LAT}ms${NC}"
    echo -e "${BLUE}  Throughput:          ${THROUGHPUT} req/s${NC}"
    echo "  Actual Duration:     ${ACTUAL_DURATION}s"
    
    # Save summary to log
    echo "" >> "$LOG_FILE"
    echo "=== Session ${SESSION_NUMBER} Summary ===" >> "$LOG_FILE"
    echo "Worker Range: ${MIN_WORKERS} → ${MAX_WORKERS}" >> "$LOG_FILE"
    echo "Total Requests: $TOTAL_REQ" >> "$LOG_FILE"
    echo "Successful: $SUCCESS_REQ" >> "$LOG_FILE"
    echo "Failed: $FAILED_REQ" >> "$LOG_FILE"
    echo "Success Rate: ${SUCCESS_RATE}%" >> "$LOG_FILE"
    echo "Throughput: ${THROUGHPUT} req/s" >> "$LOG_FILE"
    echo "Latency (min/avg/max): ${MIN_LAT}/${AVG_LAT}/${MAX_LAT}ms" >> "$LOG_FILE"
    echo "Latency (p50/p95/p99): ${P50_LAT}/${P95_LAT}/${P99_LAT}ms" >> "$LOG_FILE"
    echo "End time: ${TEST_END}" >> "$LOG_FILE"
    
    # Append to CSV with all latency metrics
    echo "$(date -u +"%Y-%m-%d %H:%M:%S"),${SESSION_NUMBER},${MIN_WORKERS}-${MAX_WORKERS},${ACTUAL_DURATION},${TOTAL_REQ},${SUCCESS_REQ},${FAILED_REQ},${SUCCESS_RATE},${MIN_LAT},${AVG_LAT},${MAX_LAT},${P50_LAT},${P95_LAT},${P99_LAT},${THROUGHPUT},${TEST_START},${TEST_END}" >> "$CSV_FILE"
    
    echo -e "${GREEN}✓ Results appended to CSV${NC}"
    
    # Cooldown between sessions
    if [ $SESSION_NUMBER -lt $TOTAL_SESSIONS ]; then
        COOLDOWN_TIME=15
        echo -e "${MAGENTA}→ Cooldown: Waiting ${COOLDOWN_TIME}s for system to stabilize...${NC}"
        sleep $COOLDOWN_TIME
        echo ""
    fi
done

# ═══════════════════════════════════════════════════════════════════
# Final Summary
# ═══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                  TEST SUITE COMPLETED                          ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✓ All ${TOTAL_SESSIONS} sessions completed${NC}"
echo -e "${YELLOW}Results Directory:${NC} $LOG_DIR"
echo -e "${YELLOW}CSV Results:${NC} $CSV_FILE"
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Overall Statistics (from CSV)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Calculate overall statistics from CSV
if [ -f "$CSV_FILE" ]; then
    TOTAL_REQUESTS=$(awk -F',' 'NR>1 {sum+=$5} END {print sum}' "$CSV_FILE")
    TOTAL_SUCCESS=$(awk -F',' 'NR>1 {sum+=$6} END {print sum}' "$CSV_FILE")
    TOTAL_FAILED=$(awk -F',' 'NR>1 {sum+=$7} END {print sum}' "$CSV_FILE")
    AVG_THROUGHPUT=$(awk -F',' 'NR>1 {sum+=$15; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    AVG_SUCCESS_RATE=$(awk -F',' 'NR>1 {sum+=$8; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    AVG_P50=$(awk -F',' 'NR>1 {sum+=$12; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    AVG_P95=$(awk -F',' 'NR>1 {sum+=$13; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    AVG_P99=$(awk -F',' 'NR>1 {sum+=$14; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
    
    echo "  Total Requests:      ${TOTAL_REQUESTS}"
    echo "  Total Successful:    ${TOTAL_SUCCESS}"
    echo "  Total Failed:        ${TOTAL_FAILED}"
    echo "  Average Success Rate: ${AVG_SUCCESS_RATE}%"
    echo -e "${MAGENTA}  Average Throughput:   ${AVG_THROUGHPUT} req/s${NC}"
    echo -e "${MAGENTA}  Average Latency (p50/p95/p99): ${AVG_P50}ms / ${AVG_P95}ms / ${AVG_P99}ms${NC}"
fi

echo ""
echo -e "${GREEN}✓ Enhanced concurrent stress test completed successfully!${NC}"
echo ""
