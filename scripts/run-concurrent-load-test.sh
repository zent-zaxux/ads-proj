#!/bin/bash

# Concurrent Load Test Runner Script
# Simulates 10-1000 concurrent users with gradual load increase

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
BASE_URL=${BASE_URL:-"http://localhost:8081"}
MIN_USERS=${MIN_USERS:-10}
MAX_USERS=${MAX_USERS:-1000}
DURATION=${DURATION:-300}  # 5 minutes
RAMP_UP=${RAMP_UP:-60}     # 1 minute
TEST_TYPE=${TEST_TYPE:-"gradual"}

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║         CONCURRENT LOAD TEST RUNNER                          ║"
echo "║         Simulating Real-World Traffic Patterns               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Display configuration
echo -e "${BLUE}Test Configuration:${NC}"
echo "  Base URL:        $BASE_URL"
echo "  Test Type:       $TEST_TYPE"
echo "  Min Users:       $MIN_USERS"
echo "  Max Users:       $MAX_USERS"
echo "  Duration:        ${DURATION}s"
echo "  Ramp-up Time:    ${RAMP_UP}s"
echo ""

# Health check
echo -e "${YELLOW}[1/4] Checking service health...${NC}"
if curl -s -f "${BASE_URL}/api/concurrent-load/health" > /dev/null; then
    echo -e "${GREEN}✓ Service is healthy${NC}"
else
    echo -e "${RED}✗ Service is not available. Please start the application first.${NC}"
    exit 1
fi

# Function to run a specific test
run_test() {
    local test_type=$1
    local endpoint=$2
    local params=$3
    
    echo -e "${YELLOW}[2/4] Starting ${test_type} load test...${NC}"
    
    response=$(curl -s -X POST "${BASE_URL}/api/concurrent-load/${endpoint}${params}" \
        -H "Content-Type: application/json")
    
    echo -e "${GREEN}Response:${NC}"
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    echo ""
}

# Function to monitor metrics during test
monitor_metrics() {
    local duration=$1
    echo -e "${YELLOW}[3/4] Monitoring test execution (check application logs for detailed metrics)...${NC}"
    echo ""
    
    # Create a monitoring loop
    end_time=$(($(date +%s) + duration))
    
    while [ $(date +%s) -lt $end_time ]; do
        # Display progress bar
        remaining=$((end_time - $(date +%s)))
        elapsed=$((duration - remaining))
        progress=$((elapsed * 100 / duration))
        
        printf "\r${CYAN}Progress: [%-50s] %d%% | Remaining: %ds${NC}" \
            $(printf '#%.0s' $(seq 1 $((progress / 2)))) \
            $progress \
            $remaining
        
        sleep 2
    done
    
    echo ""
    echo -e "${GREEN}✓ Test duration completed${NC}"
}

# Run the appropriate test based on TEST_TYPE
case "$TEST_TYPE" in
    gradual)
        run_test "Gradual" "gradual" "?minUsers=${MIN_USERS}&maxUsers=${MAX_USERS}&durationSeconds=${DURATION}&rampUpSeconds=${RAMP_UP}"
        monitor_metrics $DURATION
        ;;
    stress)
        run_test "Stress" "stress-test" ""
        monitor_metrics 180  # 3 minutes
        ;;
    sustained)
        run_test "Sustained" "sustained" "?users=${MIN_USERS}&durationSeconds=${DURATION}"
        monitor_metrics $DURATION
        ;;
    spike)
        run_test "Spike" "spike-test" ""
        monitor_metrics 120  # 2 minutes
        ;;
    quick)
        run_test "Quick" "quick-test" ""
        monitor_metrics 60   # 1 minute
        ;;
    *)
        echo -e "${RED}Unknown test type: $TEST_TYPE${NC}"
        echo "Valid types: gradual, stress, sustained, spike, quick"
        exit 1
        ;;
esac

# Summary
echo ""
echo -e "${YELLOW}[4/4] Test Summary${NC}"
echo "═══════════════════════════════════════════════════════════════"
echo -e "${GREEN}✓ Load test completed successfully${NC}"
echo ""
echo "For detailed metrics and analysis, check the application logs:"
echo "  - Success/failure rates"
echo "  - Average latency per action"
echo "  - Throughput (requests/sec)"
echo "  - Action-specific breakdowns"
echo ""
echo "You can also check Kafka topic lag and consumer metrics:"
echo "  kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups"
echo ""
echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                    TEST COMPLETED                             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}"
