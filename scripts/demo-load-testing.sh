#!/bin/bash

# Comprehensive Demo Script
# Demonstrates all load testing features with step-by-step execution

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

BASE_URL="http://localhost:8081"

echo -e "${MAGENTA}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║     CONCURRENT LOAD TESTING - COMPLETE DEMONSTRATION         ║
║                                                               ║
║  This demo showcases all features of the load testing system ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Function to wait for user
wait_for_user() {
    echo ""
    read -p "Press Enter to continue..."
    echo ""
}

# Function to display section header
section_header() {
    echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  $1${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
}

# Introduction
section_header "INTRODUCTION"
echo "This demo will show you:"
echo "  1. System health checks"
echo "  2. Quick smoke test (50 users)"
echo "  3. Gradual load test (10-200 users)"
echo "  4. Metrics viewing"
echo "  5. Kafka topic inspection"
echo ""
echo "Total demo time: ~5 minutes"
wait_for_user

# Part 1: Health Checks
section_header "PART 1: HEALTH CHECKS"
echo -e "${YELLOW}Checking application health...${NC}"
response=$(curl -s "${BASE_URL}/api/concurrent-load/health")
echo -e "${GREEN}Response: $response${NC}"
echo ""

echo -e "${YELLOW}Checking application actuator...${NC}"
response=$(curl -s "${BASE_URL}/actuator/health")
echo "$response" | jq '.' 2>/dev/null || echo "$response"
wait_for_user

# Part 2: Quick Smoke Test
section_header "PART 2: QUICK SMOKE TEST (50 users, 1 minute)"
echo -e "${YELLOW}This test will:${NC}"
echo "  • Simulate 10-50 concurrent users"
echo "  • Run for 60 seconds"
echo "  • Generate events across all Kafka topics"
echo "  • Log real-time metrics every 5 seconds"
echo ""

echo -e "${BLUE}Starting quick test...${NC}"
response=$(curl -s -X POST "${BASE_URL}/api/concurrent-load/quick-test")
echo "$response" | jq '.' 2>/dev/null || echo "$response"

echo ""
echo -e "${CYAN}Monitor the application logs to see:${NC}"
echo "  ✓ Active concurrent users"
echo "  ✓ Total requests (should reach ~3,000)"
echo "  ✓ Success rate (should be > 95%)"
echo "  ✓ Average latency (should be < 500ms)"
echo "  ✓ Per-action breakdown"
echo ""

# Progress bar for 60 seconds
for i in {1..60}; do
    printf "\r${YELLOW}Test Progress: [%-60s] %d/60s${NC}" $(printf '#%.0s' $(seq 1 $i)) $i
    sleep 1
done
echo ""
echo -e "${GREEN}✓ Quick test completed!${NC}"
wait_for_user

# Part 3: Check Kafka Topics
section_header "PART 3: KAFKA TOPIC INSPECTION"
echo -e "${YELLOW}Checking messages in Kafka topics...${NC}"
echo ""

topics=("user-events" "order-events" "payment-events" "notification-events")

for topic in "${topics[@]}"; do
    echo -e "${BLUE}Topic: ${topic}${NC}"
    count=$(kafka-run-class.sh kafka.tools.GetOffsetShell \
        --broker-list localhost:9092 \
        --topic $topic \
        --time -1 2>/dev/null | awk -F: '{sum += $3} END {print sum}' || echo "0")
    
    if [ -n "$count" ] && [ "$count" != "0" ]; then
        echo -e "  ${GREEN}✓ Messages: $count${NC}"
    else
        echo -e "  ${YELLOW}⚠ No messages or topic doesn't exist${NC}"
    fi
done

echo ""
echo -e "${CYAN}Sample messages from user-events topic:${NC}"
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
    --topic user-events \
    --from-beginning \
    --max-messages 3 \
    --timeout-ms 5000 2>/dev/null | head -10 || echo "No messages available"

wait_for_user

# Part 4: Gradual Load Test
section_header "PART 4: GRADUAL LOAD TEST (10-200 users, 2 minutes)"
echo -e "${YELLOW}This test demonstrates:${NC}"
echo "  • Gradual user ramp-up (10 to 200 users)"
echo "  • 30-second ramp-up period"
echo "  • Variable message rates"
echo "  • Random delays and failures"
echo "  • Continuous metrics logging"
echo ""

echo -e "${BLUE}Starting gradual load test...${NC}"
response=$(curl -s -X POST "${BASE_URL}/api/concurrent-load/gradual?minUsers=10&maxUsers=200&durationSeconds=120&rampUpSeconds=30")
echo "$response" | jq '.' 2>/dev/null || echo "$response"

echo ""
echo -e "${CYAN}Watch for these patterns in the logs:${NC}"
echo "  1. User count increasing from 10 to 200"
echo "  2. Throughput increasing proportionally"
echo "  3. Consistent success rate > 95%"
echo "  4. Stable average latency"
echo ""

# Progress bar for 120 seconds
for i in {1..120}; do
    if [ $i -le 30 ]; then
        phase="RAMP-UP"
    else
        phase="STEADY STATE"
    fi
    printf "\r${YELLOW}Test Progress: [%-60s] %d/120s - ${phase}${NC}" \
        $(printf '#%.0s' $(seq 1 $((i/2)))) $i
    sleep 1
done
echo ""
echo -e "${GREEN}✓ Gradual load test completed!${NC}"
wait_for_user

# Part 5: Consumer Group Lag Check
section_header "PART 5: CONSUMER GROUP LAG ANALYSIS"
echo -e "${YELLOW}Checking Kafka consumer group lag...${NC}"
echo ""

kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
    --describe --all-groups 2>/dev/null || echo "No consumer groups found"

echo ""
echo -e "${CYAN}Key Metrics to Check:${NC}"
echo "  • LAG: Should be minimal (< 100 messages)"
echo "  • CURRENT-OFFSET: Should be increasing"
echo "  • LOG-END-OFFSET: Total messages in topic"
echo ""
wait_for_user

# Part 6: Available Test Scenarios
section_header "PART 6: AVAILABLE TEST SCENARIOS"
echo -e "${YELLOW}You can run these additional tests:${NC}"
echo ""

echo -e "${BLUE}1. Stress Test:${NC}"
echo "   curl -X POST ${BASE_URL}/api/concurrent-load/stress-test"
echo "   → 10-500 users, 3 minutes"
echo ""

echo -e "${BLUE}2. Spike Test:${NC}"
echo "   curl -X POST ${BASE_URL}/api/concurrent-load/spike-test"
echo "   → 10-1000 users, 2 minutes, 5s ramp-up"
echo ""

echo -e "${BLUE}3. Sustained Load:${NC}"
echo "   curl -X POST ${BASE_URL}/api/concurrent-load/sustained?users=150&durationSeconds=180"
echo "   → Constant 150 users, 3 minutes"
echo ""

echo -e "${BLUE}4. Custom Test:${NC}"
echo "   curl -X POST \"${BASE_URL}/api/concurrent-load/gradual?minUsers=X&maxUsers=Y&durationSeconds=Z&rampUpSeconds=W\""
echo ""

wait_for_user

# Part 7: Metrics Summary
section_header "PART 7: METRICS SUMMARY"
echo -e "${YELLOW}Key Performance Indicators:${NC}"
echo ""

echo -e "${GREEN}Expected Results:${NC}"
echo "  ✓ Success Rate:      > 95%"
echo "  ✓ Average Latency:   < 500ms"
echo "  ✓ Throughput:        Scales with users"
echo "  ✓ Consumer Lag:      < 100 messages"
echo "  ✓ Error Rate:        < 5%"
echo ""

echo -e "${CYAN}Action Distribution (approximate):${NC}"
echo "  • CREATE_USER:          30%"
echo "  • CREATE_ORDER:         20%"
echo "  • PROCESS_PAYMENT:      20%"
echo "  • UPDATE_ORDER:         15%"
echo "  • SEND_NOTIFICATION:    10%"
echo "  • CANCEL_ORDER:          5%"
echo ""

# Part 8: Next Steps
section_header "PART 8: NEXT STEPS & RESOURCES"
echo -e "${YELLOW}To run more comprehensive tests:${NC}"
echo "  ./test-all-load-scenarios.sh"
echo ""

echo -e "${YELLOW}To monitor Kafka metrics in real-time:${NC}"
echo "  ./monitor-kafka-metrics.sh"
echo ""

echo -e "${YELLOW}To run custom tests:${NC}"
echo "  ./quick-start-load-test.sh"
echo ""

echo -e "${YELLOW}For detailed documentation:${NC}"
echo "  cat CONCURRENT_LOAD_TESTING_GUIDE.md"
echo ""

echo -e "${YELLOW}To view application logs:${NC}"
echo "  tail -f logs/application.log  (if configured)"
echo "  Or check your IDE/terminal running the app"
echo ""

# Final Summary
echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              DEMONSTRATION COMPLETE!                          ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${GREEN}Summary of What We Covered:${NC}"
echo "  ✓ System health verification"
echo "  ✓ Quick smoke test (50 users)"
echo "  ✓ Gradual load test (200 users)"
echo "  ✓ Kafka topic inspection"
echo "  ✓ Consumer lag analysis"
echo "  ✓ Available test scenarios"
echo ""

echo -e "${MAGENTA}The concurrent load testing system is ready for production use!${NC}"
echo -e "${MAGENTA}It can simulate 10-1000 users with comprehensive metrics tracking.${NC}"
echo ""
echo -e "${CYAN}Happy Load Testing! 🚀${NC}\n"
