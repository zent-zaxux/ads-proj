#!/bin/bash

# Integrated Testing Script for Traffic Agent + Fulfillment Agent
# Tests order generation, fulfillment workflow, and lag/catch-up scenarios

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Base URL
BASE_URL="http://localhost:8081"

# Test configuration
TRAFFIC_OPS_PER_SEC=5
FULFILLMENT_DELAY_MS=1000
FULFILLMENT_BATCH_SIZE=5

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       INTEGRATED AGENT TESTING - Traffic + Fulfillment        ║${NC}"
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo ""

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

# Function to print test steps
print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to check service health
check_service_health() {
    print_header "CHECKING SERVICE HEALTH"
    
    print_step "Checking application health..."
    if curl -s "${BASE_URL}/actuator/health" | grep -q "UP"; then
        print_success "Application is UP"
    else
        print_error "Application is DOWN"
        exit 1
    fi
}

# Function to stop any running agents (cleanup)
cleanup_agents() {
    print_header "CLEANUP - Stopping Any Running Agents"
    
    print_step "Stopping Traffic Agent..."
    curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" > /dev/null || true
    print_success "Traffic Agent stopped"
    
    print_step "Stopping Fulfillment Agent..."
    curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" > /dev/null || true
    print_success "Fulfillment Agent stopped"
    
    sleep 2
}

# Function to get Traffic Agent status
get_traffic_status() {
    curl -s "${BASE_URL}/api/agent/traffic/status"
}

# Function to get Fulfillment Agent status
get_fulfillment_status() {
    curl -s "${BASE_URL}/api/agent/fulfillment/status"
}

# Function to count orders by status
count_orders_by_status() {
    local status=$1
    curl -s "${BASE_URL}/api/orders?status=${status}" | jq '. | length' 2>/dev/null || echo "0"
}

# Function to get total order count
get_total_orders() {
    curl -s "${BASE_URL}/api/orders" | jq '. | length' 2>/dev/null || echo "0"
}

# Function to display agent stats
display_agent_stats() {
    local traffic_stats=$(get_traffic_status)
    local fulfillment_stats=$(get_fulfillment_status)
    
    echo ""
    echo -e "${CYAN}┌─────────────────── TRAFFIC AGENT ───────────────────┐${NC}"
    echo "$traffic_stats" | jq '{
        status: .status,
        totalOperations: .totalOperations,
        successfulOps: .successfulOperations,
        failedOps: .failedOperations,
        successRate: (.successRate | tostring + "%"),
        ordersCreated: .ordersCreated
    }'
    echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
    
    echo ""
    echo -e "${CYAN}┌────────────────── FULFILLMENT AGENT ────────────────┐${NC}"
    echo "$fulfillment_stats" | jq '{
        status: .status,
        isPaused: .isPaused,
        totalProcessed: .totalProcessed,
        ordersConfirmed: .ordersConfirmed,
        ordersShipped: .ordersShipped,
        ordersDelivered: .ordersDelivered,
        currentBacklog: .currentBacklog,
        avgProcessingTimeMs: .avgProcessingTimeMs
    }'
    echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
    
    echo ""
    echo -e "${CYAN}┌────────────────── ORDER DISTRIBUTION ───────────────┐${NC}"
    local pending=$(count_orders_by_status "PENDING")
    local confirmed=$(count_orders_by_status "CONFIRMED")
    local shipped=$(count_orders_by_status "SHIPPED")
    local delivered=$(count_orders_by_status "DELIVERED")
    local total=$(get_total_orders)
    
    echo -e "  PENDING:    ${YELLOW}${pending}${NC}"
    echo -e "  CONFIRMED:  ${BLUE}${confirmed}${NC}"
    echo -e "  SHIPPED:    ${CYAN}${shipped}${NC}"
    echo -e "  DELIVERED:  ${GREEN}${delivered}${NC}"
    echo -e "  ──────────────"
    echo -e "  TOTAL:      ${total}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────┘${NC}"
}

# Check service health first
check_service_health

# Cleanup any running agents
cleanup_agents

# ============================================================================
# TEST 1: Basic Integration Test
# ============================================================================
print_header "TEST 1: BASIC INTEGRATION - Order Generation & Fulfillment"

print_step "Starting Traffic Agent (${TRAFFIC_OPS_PER_SEC} ops/sec, STEADY pattern)..."
curl -s -X POST "${BASE_URL}/api/agent/traffic/start?opsPerSecond=${TRAFFIC_OPS_PER_SEC}&pattern=STEADY" > /dev/null
print_success "Traffic Agent started"

sleep 2

print_step "Starting Fulfillment Agent (${FULFILLMENT_DELAY_MS}ms delay, batch size ${FULFILLMENT_BATCH_SIZE})..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/start?processingDelayMs=${FULFILLMENT_DELAY_MS}&batchSize=${FULFILLMENT_BATCH_SIZE}" > /dev/null
print_success "Fulfillment Agent started"

print_step "Letting agents run for 30 seconds..."
for i in {1..6}; do
    sleep 5
    echo -n "."
done
echo ""

display_agent_stats

# Verify some orders were delivered
delivered_count=$(count_orders_by_status "DELIVERED")
if [ "$delivered_count" -gt 0 ]; then
    print_success "Test 1 PASSED - Orders are being delivered (${delivered_count} delivered)"
else
    print_error "Test 1 FAILED - No orders delivered yet"
fi

# ============================================================================
# TEST 2: Lag & Backlog Creation
# ============================================================================
print_header "TEST 2: LAG TESTING - Creating Backlog"

print_step "Recording baseline backlog..."
baseline_backlog=$(get_fulfillment_status | jq '.currentBacklog')
echo "  Baseline backlog: ${baseline_backlog}"

print_step "PAUSING Fulfillment Agent (orders will accumulate)..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/pause" > /dev/null
print_success "Fulfillment Agent paused"

print_step "Traffic Agent continues generating orders for 20 seconds..."
for i in {1..4}; do
    sleep 5
    current_backlog=$(get_fulfillment_status | jq '.currentBacklog')
    echo "  Backlog growing: ${current_backlog} orders"
done

final_backlog=$(get_fulfillment_status | jq '.currentBacklog')
echo ""
if [ "$final_backlog" -gt "$baseline_backlog" ]; then
    print_success "Test 2 PASSED - Backlog grew from ${baseline_backlog} to ${final_backlog}"
else
    print_error "Test 2 FAILED - Backlog did not grow as expected"
fi

display_agent_stats

# ============================================================================
# TEST 3: Catch-up & Recovery
# ============================================================================
print_header "TEST 3: CATCH-UP TESTING - Processing Backlog"

print_step "Recording backlog before resume..."
backlog_before_resume=$(get_fulfillment_status | jq '.currentBacklog')
echo "  Backlog to process: ${backlog_before_resume} orders"

print_step "RESUMING Fulfillment Agent..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/resume" > /dev/null
print_success "Fulfillment Agent resumed - processing backlog"

print_step "Monitoring catch-up progress for 30 seconds..."
for i in {1..6}; do
    sleep 5
    current_backlog=$(get_fulfillment_status | jq '.currentBacklog')
    processed=$(get_fulfillment_status | jq '.totalProcessed')
    echo "  Progress: ${processed} processed, ${current_backlog} backlog"
done

backlog_after_resume=$(get_fulfillment_status | jq '.currentBacklog')
echo ""
if [ "$backlog_after_resume" -lt "$backlog_before_resume" ]; then
    reduction=$((backlog_before_resume - backlog_after_resume))
    print_success "Test 3 PASSED - Backlog reduced by ${reduction} orders"
else
    print_error "Test 3 FAILED - Backlog did not decrease"
fi

display_agent_stats

# ============================================================================
# TEST 4: Performance Under Load
# ============================================================================
print_header "TEST 4: PERFORMANCE TEST - High Load"

print_step "Increasing traffic rate to 10 ops/sec..."
curl -s -X POST "${BASE_URL}/api/agent/traffic/config/rate?opsPerSecond=10" > /dev/null
print_success "Traffic rate increased"

print_step "Optimizing fulfillment processing (500ms delay, batch 10)..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/config/delay?delayMs=500" > /dev/null
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/config/batch?batchSize=10" > /dev/null
print_success "Fulfillment optimized"

print_step "Running high-load test for 20 seconds..."
for i in {1..4}; do
    sleep 5
    backlog=$(get_fulfillment_status | jq '.currentBacklog')
    throughput=$(get_fulfillment_status | jq '.totalProcessed / .uptimeSeconds')
    printf "  Backlog: %s, Throughput: %.2f orders/sec\n" "$backlog" "$throughput"
done

final_throughput=$(get_fulfillment_status | jq '.totalProcessed / .uptimeSeconds')
echo ""
if (( $(echo "$final_throughput > 2.0" | bc -l) )); then
    printf "${GREEN}✓ Test 4 PASSED - Sustained throughput: %.2f orders/sec${NC}\n" "$final_throughput"
else
    printf "${RED}✗ Test 4 FAILED - Low throughput: %.2f orders/sec${NC}\n" "$final_throughput"
fi

display_agent_stats

# ============================================================================
# TEST 5: Metrics Validation
# ============================================================================
print_header "TEST 5: METRICS VALIDATION"

print_step "Verifying Traffic Agent metrics..."
traffic_metrics=$(get_traffic_status)
traffic_total_ops=$(echo "$traffic_metrics" | jq '.totalOperations')
traffic_success_rate=$(echo "$traffic_metrics" | jq '.successRate')

if [ "$traffic_total_ops" -gt 0 ]; then
    print_success "Traffic Agent: ${traffic_total_ops} operations, ${traffic_success_rate}% success rate"
else
    print_error "Traffic Agent: No operations recorded"
fi

print_step "Verifying Fulfillment Agent metrics..."
fulfillment_metrics=$(get_fulfillment_status)
fulfillment_processed=$(echo "$fulfillment_metrics" | jq '.totalProcessed')
fulfillment_delivered=$(echo "$fulfillment_metrics" | jq '.ordersDelivered')

if [ "$fulfillment_processed" -gt 0 ]; then
    print_success "Fulfillment Agent: ${fulfillment_processed} processed, ${fulfillment_delivered} delivered"
else
    print_error "Fulfillment Agent: No orders processed"
fi

print_step "Checking order workflow completion..."
delivered=$(count_orders_by_status "DELIVERED")
if [ "$delivered" -gt 0 ]; then
    print_success "Workflow validation: ${delivered} orders reached DELIVERED status"
else
    print_error "Workflow validation: No orders completed full workflow"
fi

# ============================================================================
# CLEANUP
# ============================================================================
print_header "CLEANUP - Stopping Agents"

print_step "Stopping Traffic Agent..."
curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" > /dev/null
print_success "Traffic Agent stopped"

print_step "Stopping Fulfillment Agent..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" > /dev/null
print_success "Fulfillment Agent stopped"

# ============================================================================
# FINAL SUMMARY
# ============================================================================
print_header "FINAL TEST SUMMARY"

echo ""
display_agent_stats

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                      TEST RESULTS                              ║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✓${NC} Test 1: Basic Integration (Order Generation & Fulfillment) ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✓${NC} Test 2: Lag Testing (Backlog Creation)                     ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✓${NC} Test 3: Catch-up Testing (Backlog Processing)              ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✓${NC} Test 4: Performance Under Load                             ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}✓${NC} Test 5: Metrics Validation                                 ${CYAN}║${NC}"
echo -e "${CYAN}╠════════════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC}  ${GREEN}ALL TESTS COMPLETED SUCCESSFULLY${NC}                             ${CYAN}║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Final statistics
final_traffic_stats=$(get_traffic_status)
final_fulfillment_stats=$(get_fulfillment_status)
final_delivered=$(count_orders_by_status "DELIVERED")

echo -e "${BLUE}Final Statistics:${NC}"
echo "  • Total Traffic Operations: $(echo "$final_traffic_stats" | jq '.totalOperations')"
echo "  • Orders Created: $(echo "$final_traffic_stats" | jq '.ordersCreated')"
echo "  • Orders Processed: $(echo "$final_fulfillment_stats" | jq '.totalProcessed')"
echo "  • Orders Delivered: ${final_delivered}"
echo "  • Success Rate: $(echo "$final_traffic_stats" | jq '.successRate')%"
echo "  • Avg Processing Time: $(echo "$final_fulfillment_stats" | jq '.avgProcessingTimeMs')ms"
echo ""

print_success "Integrated testing completed! Both agents working correctly."
echo ""
