#!/bin/bash

# Traffic Agent Test Script
# This script tests all features of the Traffic Agent

echo "========================================"
echo "   TRAFFIC AGENT TEST SUITE"
echo "========================================"
echo ""

BASE_URL="http://localhost:8081"

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print test header
print_test() {
    echo -e "${BLUE}>>> TEST: $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Test 1: Health Check
print_test "1. Health Check"
response=$(curl -s "$BASE_URL/api/agent/traffic/health")
echo "$response" | jq '.'
if echo "$response" | jq -e '.status == "UP"' > /dev/null; then
    print_success "Agent is UP and running"
else
    print_error "Agent health check failed"
    exit 1
fi
echo ""

# Test 2: List Available Patterns
print_test "2. List Available Traffic Patterns"
curl -s "$BASE_URL/api/agent/traffic/patterns" | jq '.'
print_success "Retrieved available patterns"
echo ""

# Test 3: Start Agent (STEADY pattern)
print_test "3. Start Agent with STEADY pattern (5 ops/sec)"
response=$(curl -s -X POST "$BASE_URL/api/agent/traffic/start?opsPerSecond=5&pattern=STEADY")
echo "$response" | jq '.'
if echo "$response" | jq -e '.success == true' > /dev/null; then
    print_success "Agent started successfully"
else
    print_error "Failed to start agent"
    exit 1
fi
echo ""

# Wait for agent to generate some traffic
print_info "Waiting 10 seconds for traffic generation..."
sleep 10

# Test 4: Check Status
print_test "4. Check Agent Status"
status=$(curl -s "$BASE_URL/api/agent/traffic/status")
echo "$status" | jq '.'
total_ops=$(echo "$status" | jq -r '.totalOperations')
success_ops=$(echo "$status" | jq -r '.successfulOperations')
if [ "$total_ops" -gt 0 ]; then
    print_success "Agent generated $total_ops operations ($success_ops successful)"
else
    print_error "No operations generated"
fi
echo ""

# Test 5: Pause Agent (for lag testing)
print_test "5. Pause Agent (Lag Simulation)"
response=$(curl -s -X POST "$BASE_URL/api/agent/traffic/pause")
echo "$response" | jq '.'
if echo "$response" | jq -e '.success == true' > /dev/null; then
    print_success "Agent paused successfully"
    print_info "Messages will now accumulate in Kafka (lag simulation)"
else
    print_error "Failed to pause agent"
fi
echo ""

# Wait while paused
print_info "Waiting 5 seconds while agent is paused..."
sleep 5

# Check status while paused
print_test "6. Check Status While Paused"
status=$(curl -s "$BASE_URL/api/agent/traffic/status")
echo "$status" | jq '.'
is_paused=$(echo "$status" | jq -r '.paused')
if [ "$is_paused" = "true" ]; then
    print_success "Agent is paused"
else
    print_error "Agent should be paused but isn't"
fi
echo ""

# Test 7: Resume Agent
print_test "7. Resume Agent (Lag Recovery)"
response=$(curl -s -X POST "$BASE_URL/api/agent/traffic/resume")
echo "$response" | jq '.'
if echo "$response" | jq -e '.success == true' > /dev/null; then
    print_success "Agent resumed successfully"
    print_info "Agent will catch up on accumulated messages"
else
    print_error "Failed to resume agent"
fi
echo ""

# Wait for catch-up
print_info "Waiting 5 seconds for catch-up..."
sleep 5

# Test 8: Change Traffic Pattern to BURST
print_test "8. Change Traffic Pattern to BURST"
response=$(curl -s -X POST "$BASE_URL/api/agent/traffic/pattern?pattern=BURST")
echo "$response" | jq '.'
if echo "$response" | jq -e '.success == true' > /dev/null; then
    print_success "Pattern changed to BURST"
    print_info "Note: Need to restart agent to apply new pattern"
else
    print_error "Failed to change pattern"
fi
echo ""

# Test 9: Change Rate
print_test "9. Change Operations Rate to 10 ops/sec"
response=$(curl -s -X POST "$BASE_URL/api/agent/traffic/rate?opsPerSecond=10")
echo "$response" | jq '.'
if echo "$response" | jq -e '.success == true' > /dev/null; then
    print_success "Rate changed to 10 ops/sec"
    print_info "Note: Need to restart agent to apply new rate"
else
    print_error "Failed to change rate"
fi
echo ""

# Test 10: Stop Agent
print_test "10. Stop Agent"
response=$(curl -s -X POST "$BASE_URL/api/agent/traffic/stop")
echo "$response" | jq '.'
if echo "$response" | jq -e '.success == true' > /dev/null; then
    print_success "Agent stopped successfully"
else
    print_error "Failed to stop agent"
fi
echo ""

# Final Status Check
print_test "11. Final Status Check"
status=$(curl -s "$BASE_URL/api/agent/traffic/status")
echo "$status" | jq '.'
is_running=$(echo "$status" | jq -r '.running')
if [ "$is_running" = "false" ]; then
    print_success "Agent is stopped"
else
    print_error "Agent should be stopped but isn't"
fi
echo ""

# Summary
echo "========================================"
echo "   TEST SUMMARY"
echo "========================================"
total_ops=$(echo "$status" | jq -r '.totalOperations')
success_ops=$(echo "$status" | jq -r '.successfulOperations')
failed_ops=$(echo "$status" | jq -r '.failedOperations')
success_rate=$(echo "$status" | jq -r '.successRate')

echo -e "${GREEN}Total Operations: $total_ops${NC}"
echo -e "${GREEN}Successful: $success_ops${NC}"
echo -e "${RED}Failed: $failed_ops${NC}"
echo -e "${YELLOW}Success Rate: $success_rate%${NC}"
echo ""

# Test additional endpoints
print_test "12. Test Notification Service Integration"
print_info "Checking notifications generated by Traffic Agent..."
notif_stats=$(curl -s "$BASE_URL/api/notifications/stats")
echo "$notif_stats" | jq '.'
print_success "Notification stats retrieved"
echo ""

print_test "13. Check Orders Created"
orders=$(curl -s "$BASE_URL/api/orders")
order_count=$(echo "$orders" | jq '. | length')
print_success "Found $order_count orders in database"
echo ""

print_test "14. Check Users Created"
users=$(curl -s "$BASE_URL/api/users")
user_count=$(echo "$users" | jq '. | length')
print_success "Found $user_count users in database"
echo ""

echo "========================================"
echo "   ALL TESTS COMPLETED!"
echo "========================================"
echo ""
echo "Next steps:"
echo "1. Check Kafka UI: http://localhost:8090"
echo "2. View performance-events topic for metrics"
echo "3. Try different traffic patterns (BURST, SPIKE, RAMP_UP, RANDOM)"
echo "4. Monitor lag in consumer groups during pause/resume"
echo ""
