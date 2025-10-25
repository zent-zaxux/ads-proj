#!/bin/bash

# Advanced Load Test Scenarios
# Multiple test patterns to validate system scalability and resilience

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

BASE_URL=${BASE_URL:-"http://localhost:8081"}

echo -e "${MAGENTA}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║        COMPREHENSIVE LOAD TEST SUITE                         ║"
echo "║        Multiple Scenarios for System Validation              ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Function to run test and display results
run_scenario() {
    local name=$1
    local endpoint=$2
    local params=$3
    local duration=$4
    
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${YELLOW}Scenario: ${name}${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    
    echo -e "${BLUE}Starting test...${NC}"
    response=$(curl -s -X POST "${BASE_URL}/api/concurrent-load/${endpoint}${params}" \
        -H "Content-Type: application/json")
    
    echo "$response" | jq '.' 2>/dev/null || echo "$response"
    
    echo -e "${YELLOW}Test duration: ${duration}s - Monitor application logs for metrics${NC}"
    
    # Progress indicator
    for i in $(seq 1 $duration); do
        printf "\r${CYAN}Progress: [%-50s] %d%%${NC}" \
            $(printf '#%.0s' $(seq 1 $((i * 50 / duration)))) \
            $((i * 100 / duration))
        sleep 1
    done
    
    echo -e "\n${GREEN}✓ Scenario completed${NC}\n"
    sleep 3
}

# Scenario 1: Quick Smoke Test
echo -e "${MAGENTA}[1/7] Quick Smoke Test${NC}"
echo "Purpose: Verify basic system functionality with light load"
run_scenario "Quick Smoke Test (10-50 users, 1 min)" "quick-test" "" 60

# Scenario 2: Gradual Ramp-Up (Small)
echo -e "${MAGENTA}[2/7] Gradual Ramp-Up - Small Scale${NC}"
echo "Purpose: Test gradual load increase with moderate user count"
run_scenario "Gradual Load (10-100 users, 2 min)" "gradual" "?minUsers=10&maxUsers=100&durationSeconds=120&rampUpSeconds=30" 120

# Scenario 3: Sustained Load
echo -e "${MAGENTA}[3/7] Sustained Load Test${NC}"
echo "Purpose: Test system stability under constant load"
run_scenario "Sustained Load (200 users, 3 min)" "sustained" "?users=200&durationSeconds=180" 180

# Scenario 4: Spike Test
echo -e "${MAGENTA}[4/7] Spike Test${NC}"
echo "Purpose: Test system resilience to sudden traffic spikes"
run_scenario "Spike Test (10-1000 users, 2 min)" "spike-test" "" 120

# Scenario 5: Stress Test
echo -e "${MAGENTA}[5/7] Stress Test${NC}"
echo "Purpose: Push system to limits and identify breaking points"
run_scenario "Stress Test (10-500 users, 3 min)" "stress-test" "" 180

# Scenario 6: High Volume Gradual
echo -e "${MAGENTA}[6/7] High Volume Gradual Test${NC}"
echo "Purpose: Test maximum capacity with controlled ramp-up"
run_scenario "High Volume (50-1000 users, 5 min)" "gradual" "?minUsers=50&maxUsers=1000&durationSeconds=300&rampUpSeconds=90" 300

# Scenario 7: Endurance Test
echo -e "${MAGENTA}[7/7] Endurance Test${NC}"
echo "Purpose: Test system stability over extended period"
run_scenario "Endurance Test (150 users, 5 min)" "sustained" "?users=150&durationSeconds=300" 300

# Final Summary
echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║             ALL TEST SCENARIOS COMPLETED                      ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}Summary:${NC}"
echo "  ✓ 7 different load test scenarios executed"
echo "  ✓ Tested gradual, sustained, spike, and stress patterns"
echo "  ✓ User range: 10 to 1000 concurrent users"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Check application logs for detailed metrics"
echo "  2. Review Kafka consumer lag:"
echo "     kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups"
echo "  3. Check Prometheus/Grafana dashboards (if configured)"
echo "  4. Analyze database performance metrics"
echo ""
echo -e "${BLUE}Key Metrics to Review:${NC}"
echo "  • Success rate (should be > 95%)"
echo "  • Average latency (should be < 500ms)"
echo "  • Throughput (requests per second)"
echo "  • Error patterns and types"
echo "  • Kafka consumer lag"
echo "  • Database connection pool usage"
echo ""
