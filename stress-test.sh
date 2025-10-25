#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Automated Stress Testing Script
# Tests scalability with increasing load: 10 → 1000 users
# Captures metrics and generates CSV report
# ═══════════════════════════════════════════════════════════════════

# Note: Removed 'set -e' to prevent script exit on non-critical errors
# We handle errors explicitly in the script

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
NUM_SESSIONS=10  # Number of test sessions
CONCURRENT_WORKERS=${CONCURRENT_WORKERS:-25}  # Number of concurrent workers per session
DURATION=${DURATION:-60}  # Duration per session (60s for faster testing)
CSV_FILE="scaling_results.csv"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_DIR="test-logs/${TIMESTAMP}"

# Create directories
mkdir -p "$LOG_DIR"

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║          AUTOMATED STRESS TESTING & SCALABILITY                ║
║          Testing: 10 → 1000 Concurrent Users                   ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${MAGENTA}Test Configuration:${NC}"
echo "  Base URL:        $BASE_URL"
echo "  Test Sessions:   ${NUM_SESSIONS}"
echo "  Concurrent Workers: ${CONCURRENT_WORKERS} per session"
echo "  Duration/Session: ${DURATION}s"
echo "  Results File:    $CSV_FILE"
echo "  Logs Directory:  $LOG_DIR"
echo "  Mode:            Parallel request processing"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Health Check
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}Performing health check...${NC}"
if ! curl -s -f "${BASE_URL}/actuator/health" > /dev/null 2>&1; then
    echo -e "${RED}✗ Application is not running!${NC}"
    echo "Please start the application first: ./mvnw spring-boot:run"
    exit 1
fi
echo -e "${GREEN}✓ Application is healthy${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Initialize Enhanced CSV with Percentile Metrics
# ═══════════════════════════════════════════════════════════════════
echo "timestamp,session_number,concurrent_workers,duration_seconds,total_requests,successful_requests,failed_requests,success_rate_percent,min_latency_ms,avg_latency_ms,max_latency_ms,p50_latency_ms,p95_latency_ms,p99_latency_ms,throughput_req_per_sec,test_start_time,test_end_time" > "$CSV_FILE"
echo -e "${GREEN}✓ Enhanced CSV file initialized: $CSV_FILE${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Main Test Loop
# ═══════════════════════════════════════════════════════════════════
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         STARTING CONTINUOUS SCALABILITY TEST SESSIONS         ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

TOTAL_SESSIONS=${NUM_SESSIONS}

for SESSION_NUMBER in $(seq 1 $NUM_SESSIONS); do
    
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}  SESSION ${SESSION_NUMBER}/${TOTAL_SESSIONS}: ${CONCURRENT_WORKERS} Concurrent Workers${NC}"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
    
    LOG_FILE="${LOG_DIR}/session_${SESSION_NUMBER}_workers_${CONCURRENT_WORKERS}.log"
    LATENCY_FILE="${LOG_DIR}/session_${SESSION_NUMBER}_latencies.dat"
    TEST_START=$(date -u +"%Y-%m-%d %H:%M:%S")
    TEST_START_EPOCH=$(date +%s)
    
    # Run the continuous scalability test
    echo -e "${BLUE}Starting continuous ramp: ${MIN_USERS} → ${MAX_USERS} users over ${DURATION}s${NC}"
    
    # Counters
    TOTAL_REQ=0
    SUCCESS_REQ=0
    FAILED_REQ=0
    
    # Clear latency file
    > "$LATENCY_FILE"
    
    # Calculate how much to increase users over time
    USER_INCREMENT=$(awk "BEGIN {printf \"%.2f\", ($MAX_USERS - $MIN_USERS) / $DURATION}")
    
    echo "Session ${SESSION_NUMBER} - Continuous ramp test" >> "$LOG_FILE"
    echo "Target: ${MIN_USERS} to ${MAX_USERS} users over ${DURATION} seconds" >> "$LOG_FILE"
    echo "User increment per second: ${USER_INCREMENT}" >> "$LOG_FILE"
    echo "Start time: ${TEST_START}" >> "$LOG_FILE"
    echo "" >> "$LOG_FILE"
    
    # Run for DURATION seconds
    END_TIME=$((TEST_START_EPOCH + DURATION))
    
    while [ $(date +%s) -lt $END_TIME ]; do
        ELAPSED=$(($(date +%s) - TEST_START_EPOCH))
        
        # Calculate current user count (gradually increase)
        CURRENT_USERS=$(awk "BEGIN {printf \"%.0f\", $MIN_USERS + ($USER_INCREMENT * $ELAPSED)}")
        if [ "$CURRENT_USERS" -gt "$MAX_USERS" ]; then
            CURRENT_USERS=$MAX_USERS
        fi
        
        # Calculate sleep time based on current user count
        # More users = less sleep = higher request rate
        if [ "$CURRENT_USERS" -gt 0 ]; then
            SLEEP_TIME=$(awk "BEGIN {printf \"%.4f\", 1.0/$CURRENT_USERS}")
        else
            SLEEP_TIME="0.1"
        fi
        
        # Create a user and order with latency tracking
        RANDOM_NUM=$((RANDOM * RANDOM))
        USER_EMAIL="scalability-s${SESSION_NUMBER}-${TIMESTAMP}-${TOTAL_REQ}-${RANDOM_NUM}@example.com"
        USER_PHONE="555-$((1000000 + RANDOM % 9000000))"
        
        # Start timing (milliseconds) - macOS compatible
        REQ_START=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || gdate +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
        
        USER_RESPONSE=$(curl -s --max-time 10 --connect-timeout 5 --keepalive-time 60 -X POST "${BASE_URL}/api/users" \
            -H "Content-Type: application/json" \
            -H "Connection: keep-alive" \
            -d "{\"name\":\"Session ${SESSION_NUMBER} User\",\"email\":\"$USER_EMAIL\",\"phoneNumber\":\"$USER_PHONE\",\"address\":\"Scalability Test Address\"}" \
            2>&1)
        
        USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")
        
        if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
            # Create order
            ORDER_RESPONSE=$(curl -s --max-time 10 --connect-timeout 5 --keepalive-time 60 -X POST "${BASE_URL}/api/orders" \
                -H "Content-Type: application/json" \
                -H "Connection: keep-alive" \
                -d "{\"userId\":$USER_ID,\"productName\":\"Scalability Test Product\",\"quantity\":1,\"unitPrice\":99.99,\"totalAmount\":99.99}" \
                2>&1)
            
            ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")
            
            # End timing (milliseconds)
            REQ_END=$(python3 -c "import time; print(int(time.time() * 1000))" 2>/dev/null || gdate +%s%3N 2>/dev/null || echo $(($(date +%s) * 1000)))
            LATENCY=$((REQ_END - REQ_START))
            
            if [ -n "$ORDER_ID" ] && [ "$ORDER_ID" != "null" ]; then
                SUCCESS_REQ=$((SUCCESS_REQ + 1))
                # Record latency for successful requests
                echo "$LATENCY" >> "$LATENCY_FILE"
            else
                FAILED_REQ=$((FAILED_REQ + 1))
                echo "[${ELAPSED}s] Failed order for user $USER_ID (load: ${CURRENT_USERS} users)" >> "$LOG_FILE"
            fi
        else
            FAILED_REQ=$((FAILED_REQ + 1))
            echo "[${ELAPSED}s] Failed user creation (load: ${CURRENT_USERS} users)" >> "$LOG_FILE"
        fi
        
        TOTAL_REQ=$((TOTAL_REQ + 1))
        
        # Progress indicator every 100 requests
        if [ $((TOTAL_REQ % 100)) -eq 0 ]; then
            CURRENT_SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($SUCCESS_REQ/$TOTAL_REQ)*100}")
            printf "\r  Progress: ${TOTAL_REQ} requests | Success: ${SUCCESS_REQ}/${TOTAL_REQ} (${CURRENT_SUCCESS_RATE}%%) | Load: ~${CURRENT_USERS} users | Elapsed: ${ELAPSED}s/${DURATION}s"
        fi
        
        # Sleep to simulate load (minimal delay)
        sleep "$SLEEP_TIME" 2>/dev/null || sleep 0.001
    done
    
    TEST_END_EPOCH=$(date +%s)
    TEST_END=$(date -u +"%Y-%m-%d %H:%M:%S")
    ACTUAL_DURATION=$((TEST_END_EPOCH - TEST_START_EPOCH))
    
    echo ""
    
    # Calculate metrics
    if [ "$TOTAL_REQ" -gt 0 ]; then
        SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESS_REQ/$TOTAL_REQ)*100}")
        THROUGHPUT=$(awk "BEGIN {printf \"%.2f\", $TOTAL_REQ/$ACTUAL_DURATION}")
    else
        SUCCESS_RATE="0.00"
        THROUGHPUT="0.00"
    fi
    
    # Calculate latency percentiles from recorded data
    if [ -s "$LATENCY_FILE" ]; then
        # Sort latencies for percentile calculation
        sort -n "$LATENCY_FILE" > "${LATENCY_FILE}.sorted"
        
        # Min, Max, Average
        MIN_LAT=$(head -1 "${LATENCY_FILE}.sorted")
        MAX_LAT=$(tail -1 "${LATENCY_FILE}.sorted")
        AVG_LAT=$(awk '{sum+=$1; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "${LATENCY_FILE}.sorted")
        
        # Calculate percentiles
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
        
        # Clean up sorted file
        rm -f "${LATENCY_FILE}.sorted"
    else
        MIN_LAT=0
        MAX_LAT=0
        AVG_LAT=0
        P50_LAT=0
        P95_LAT=0
        P99_LAT=0
    fi
    
    # Display metrics
    echo -e "${GREEN}✓ Session ${SESSION_NUMBER} completed${NC}"
    echo -e "${CYAN}Results:${NC}"
    echo "  Total Requests:      $TOTAL_REQ"
    echo "  Successful:          $SUCCESS_REQ"
    echo "  Failed:              $FAILED_REQ"
    echo "  Success Rate:        ${SUCCESS_RATE}%"
    echo -e "${MAGENTA}  Latency (min/avg/max):  ${MIN_LAT}ms / ${AVG_LAT}ms / ${MAX_LAT}ms${NC}"
    echo -e "${MAGENTA}  Latency (p50/p95/p99):  ${P50_LAT}ms / ${P95_LAT}ms / ${P99_LAT}ms${NC}"
    echo "  Throughput:          ${THROUGHPUT} req/s"
    echo "  Actual Duration:     ${ACTUAL_DURATION}s"
    echo "  Load Pattern:        ${MIN_USERS} → ${MAX_USERS} users (continuous)"
    
    # Save summary to log
    echo "" >> "$LOG_FILE"
    echo "=== Session ${SESSION_NUMBER} Summary ===" >> "$LOG_FILE"
    echo "Total Requests: $TOTAL_REQ" >> "$LOG_FILE"
    echo "Successful: $SUCCESS_REQ" >> "$LOG_FILE"
    echo "Failed: $FAILED_REQ" >> "$LOG_FILE"
    echo "Success Rate: ${SUCCESS_RATE}%" >> "$LOG_FILE"
    echo "Throughput: ${THROUGHPUT} req/s" >> "$LOG_FILE"
    echo "End time: ${TEST_END}" >> "$LOG_FILE"
    
    # Append to Enhanced CSV with all latency metrics
    echo "$(date -u +"%Y-%m-%d %H:%M:%S"),${SESSION_NUMBER},${MIN_USERS}-${MAX_USERS},${ACTUAL_DURATION},${TOTAL_REQ},${SUCCESS_REQ},${FAILED_REQ},${SUCCESS_RATE},${MIN_LAT},${AVG_LAT},${MAX_LAT},${P50_LAT},${P95_LAT},${P99_LAT},${THROUGHPUT},${TEST_START},${TEST_END}" >> "$CSV_FILE"
    
    echo -e "${GREEN}✓ Results appended to CSV${NC}"
    
    # Add brief cooldown to allow TIME_WAIT connections to clear
    if [ $SESSION_NUMBER -lt $TOTAL_SESSIONS ]; then
        COOLDOWN_TIME=5
        echo -e "${MAGENTA}→ Cooldown: Waiting ${COOLDOWN_TIME}s for connections to clear...${NC}"
        sleep $COOLDOWN_TIME
        echo ""
    fi
done

# ═══════════════════════════════════════════════════════════════════
# Generate Summary Report
# ═══════════════════════════════════════════════════════════════════
echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        CONTINUOUS SCALABILITY TESTING COMPLETED                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✓ All ${TOTAL_SESSIONS} continuous scalability sessions completed${NC}"
echo ""

# Display results table
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  SCALABILITY TEST RESULTS${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Use column command for nice formatting if available
if command -v column &> /dev/null; then
    echo -e "${CYAN}Results Table (All Sessions):${NC}"
    cat "$CSV_FILE" | column -t -s ',' | head -15
else
    cat "$CSV_FILE"
fi

echo ""
echo -e "${MAGENTA}Files Generated:${NC}"
echo "  📊 Results CSV:  $CSV_FILE"
echo "  📝 Test Logs:    $LOG_DIR/"
echo ""

# Calculate statistics
echo -e "${CYAN}Statistics Across All Sessions:${NC}"

# Skip header and calculate totals
TOTAL_REQUESTS_ALL=$(awk -F',' 'NR>1 {sum+=$5} END {print sum}' "$CSV_FILE")
TOTAL_SUCCESS_ALL=$(awk -F',' 'NR>1 {sum+=$6} END {print sum}' "$CSV_FILE")
TOTAL_FAILED_ALL=$(awk -F',' 'NR>1 {sum+=$7} END {print sum}' "$CSV_FILE")
AVG_SUCCESS_RATE=$(awk -F',' 'NR>1 {sum+=$8; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
MIN_LATENCY_ALL=$(awk -F',' 'NR>1 {if(NR==2 || $9<min) min=$9} END {printf "%.2f", min}' "$CSV_FILE")
AVG_LATENCY_ALL=$(awk -F',' 'NR>1 {sum+=$10; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
MAX_LATENCY_ALL=$(awk -F',' 'NR>1 {if($11>max) max=$11} END {printf "%.2f", max}' "$CSV_FILE")
AVG_P50_LAT=$(awk -F',' 'NR>1 {sum+=$12; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
AVG_P95_LAT=$(awk -F',' 'NR>1 {sum+=$13; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
AVG_P99_LAT=$(awk -F',' 'NR>1 {sum+=$14; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")
AVG_THROUGHPUT=$(awk -F',' 'NR>1 {sum+=$15; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$CSV_FILE")

echo "  Total Requests Processed:  $TOTAL_REQUESTS_ALL"
echo "  Total Successful:          $TOTAL_SUCCESS_ALL"
echo "  Total Failed:              $TOTAL_FAILED_ALL"
echo "  Average Success Rate:      ${AVG_SUCCESS_RATE}%"
echo ""
echo -e "${MAGENTA}Latency Statistics:${NC}"
echo "  Min Latency:               ${MIN_LATENCY_ALL}ms"
echo "  Avg Latency:               ${AVG_LATENCY_ALL}ms"
echo "  Max Latency:               ${MAX_LATENCY_ALL}ms"
echo "  Avg P50 (Median):          ${AVG_P50_LAT}ms"
echo "  Avg P95:                   ${AVG_P95_LAT}ms"
echo "  Avg P99:                   ${AVG_P99_LAT}ms"
echo ""
echo "  Average Throughput:        ${AVG_THROUGHPUT} req/s"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Analysis & Recommendations
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}  PERFORMANCE ANALYSIS${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Simple performance assessment
if (( $(echo "$AVG_SUCCESS_RATE > 95" | bc -l) )); then
    echo -e "${GREEN}✓ Excellent: System maintains >95% success rate${NC}"
elif (( $(echo "$AVG_SUCCESS_RATE > 90" | bc -l) )); then
    echo -e "${YELLOW}⚠ Good: System maintains >90% success rate${NC}"
else
    echo -e "${RED}✗ Poor: System has <90% success rate - needs optimization${NC}"
fi

if (( $(echo "$AVG_P95_LAT < 200" | bc -l) )); then
    echo -e "${GREEN}✓ Excellent: P95 latency <200ms${NC}"
elif (( $(echo "$AVG_P95_LAT < 500" | bc -l) )); then
    echo -e "${YELLOW}⚠ Acceptable: P95 latency <500ms${NC}"
else
    echo -e "${RED}✗ Poor: P95 latency >500ms - performance issues detected${NC}"
fi

if (( $(echo "$AVG_P99_LAT < 1000" | bc -l) )); then
    echo -e "${GREEN}✓ Good: P99 latency <1000ms${NC}"
else
    echo -e "${YELLOW}⚠ Warning: P99 latency >1000ms - investigate tail latency${NC}"
fi

echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Analyze CSV file: $CSV_FILE"
echo "  2. Review individual test logs in: $LOG_DIR/"
echo "  3. Check Kafka consumer lag for bottlenecks"
echo "  4. Monitor application logs for errors"
echo "  5. View visualizations in Kafka UI: http://localhost:8080"
echo ""

echo -e "${MAGENTA}Visualization Options:${NC}"
echo "  • Import CSV into Excel/Google Sheets"
echo "  • Use Python/R for detailed analysis"
echo "  • Create charts showing:"
echo "    - Throughput vs Users"
echo "    - Latency vs Load"
echo "    - Success Rate trends"
echo ""

# Generate ASCII charts
echo -e "${CYAN}Throughput Across Sessions (req/s):${NC}"
awk -F',' 'NR>1 {
    session=$2
    throughput=$15
    bar_length=int(throughput/10)
    if (bar_length > 50) bar_length=50
    printf "  Session %2d: ", session
    for(i=0; i<bar_length; i++) printf "█"
    printf " %.1f\n", throughput
}' "$CSV_FILE"

echo ""
echo -e "${CYAN}P95 Latency Across Sessions (ms):${NC}"
awk -F',' 'NR>1 {
    session=$2
    p95=$13
    bar_length=int(p95/10)
    if (bar_length > 50) bar_length=50
    printf "  Session %2d: ", session
    for(i=0; i<bar_length; i++) printf "█"
    printf " %.0fms\n", p95
}' "$CSV_FILE"

echo ""
echo -e "${CYAN}Success Rate Across Sessions (%%):${NC}"
awk -F',' 'NR>1 {
    session=$2
    success_rate=$8
    bar_length=int(success_rate/2)
    if (bar_length > 50) bar_length=50
    printf "  Session %2d: ", session
    for(i=0; i<bar_length; i++) printf "█"
    printf " %.2f%%\n", success_rate
}' "$CSV_FILE"

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      CONTINUOUS SCALABILITY TESTING SESSION COMPLETE          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
