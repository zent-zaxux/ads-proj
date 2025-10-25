#!/bin/bash

# Traffic Pattern Testing Script
# Tests all 5 traffic patterns to demonstrate realistic load modeling

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_URL="http://localhost:8081"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║          TRAFFIC PATTERN MODELING DEMONSTRATION               ║${NC}"
echo -e "${CYAN}║     Realistic Arrival Rate Variations for Order Processing    ║${NC}"
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo ""

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
}

print_step() {
    echo -e "${YELLOW}▶ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Test Pattern Function
test_pattern() {
    local pattern=$1
    local ops_per_sec=$2
    local duration=$3
    local description=$4
    
    print_header "PATTERN: $pattern - $description"
    
    print_step "Starting Traffic Agent with $pattern pattern (${ops_per_sec} ops/sec)..."
    curl -s -X POST "${BASE_URL}/api/agent/traffic/start?opsPerSecond=${ops_per_sec}&pattern=${pattern}" > /dev/null
    print_success "Traffic Agent started"
    
    print_step "Running for ${duration} seconds..."
    sleep $duration
    
    print_step "Getting statistics..."
    stats=$(curl -s "${BASE_URL}/api/agent/traffic/status")
    
    echo ""
    echo -e "${CYAN}┌─────────────────── RESULTS ─────────────────────┐${NC}"
    echo "$stats" | jq '{
        pattern: "'$pattern'",
        totalOps: .totalOperations,
        successful: .successfulOperations,
        failed: .failedOperations,
        successRate: (.successRate | tostring + "%"),
        ordersCreated: .ordersCreated
    }'
    echo -e "${CYAN}└─────────────────────────────────────────────────┘${NC}"
    
    print_step "Stopping Traffic Agent..."
    curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" > /dev/null
    sleep 2
    print_success "Pattern test complete"
}

# Check service health
print_header "CHECKING SERVICE HEALTH"
print_step "Verifying application is running..."
if curl -s "${BASE_URL}/actuator/health" | grep -q "UP"; then
    print_success "Application is UP"
else
    echo -e "${RED}✗ Application is DOWN - please start it first${NC}"
    exit 1
fi

# Cleanup
print_header "CLEANUP - Stopping any running agents"
curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" > /dev/null 2>&1 || true
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" > /dev/null 2>&1 || true
sleep 2

# Start Fulfillment Agent (to process orders)
print_header "STARTING FULFILLMENT AGENT"
print_step "Starting Fulfillment Agent with fast processing..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/start?processingDelayMs=500&batchSize=10" > /dev/null
print_success "Fulfillment Agent running (500ms delay, batch 10)"
echo ""

# Pattern 1: STEADY (Baseline)
test_pattern "STEADY" 5 20 "Normal baseline traffic - constant arrival rate"

# Pattern 2: BURST (Lunch Rush)
test_pattern "BURST" 10 20 "Lunch rush pattern - periodic bursts of activity"

# Pattern 3: SPIKE (Flash Sale)
test_pattern "SPIKE" 8 20 "Flash sale pattern - sudden spike then return to normal"

# Pattern 4: RAMP_UP (Growing Popularity)
test_pattern "RAMP_UP" 10 20 "Growing traffic - gradually increasing load"

# Pattern 5: RANDOM (Realistic Variation)
test_pattern "RANDOM" 8 20 "Random variation - realistic user behavior"

# Final Cleanup
print_header "FINAL CLEANUP"
curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" > /dev/null 2>&1 || true
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" > /dev/null 2>&1 || true

# Summary
print_header "TRAFFIC PATTERN SUMMARY"
echo ""
echo -e "${CYAN}┌────────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                     PATTERN COMPARISON                         │${NC}"
echo -e "${CYAN}├────────────────────────────────────────────────────────────────┤${NC}"
echo -e "${CYAN}│${NC} Pattern      │ Use Case              │ Characteristics      ${CYAN}│${NC}"
echo -e "${CYAN}├──────────────┼───────────────────────┼──────────────────────┤${NC}"
echo -e "${CYAN}│${NC} STEADY       │ Normal traffic        │ Constant rate        ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} BURST        │ Lunch rush            │ Periodic spikes      ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} SPIKE        │ Flash sale            │ Sudden surge         ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} RAMP_UP      │ Viral growth          │ Gradual increase     ${CYAN}│${NC}"
echo -e "${CYAN}│${NC} RANDOM       │ Realistic users       │ Variable arrival     ${CYAN}│${NC}"
echo -e "${CYAN}└──────────────┴───────────────────────┴──────────────────────┘${NC}"
echo ""

echo -e "${GREEN}Key Insight:${NC} Real-world systems don't experience constant traffic."
echo -e "This demonstration shows how the system handles realistic variations"
echo -e "in arrival rates, from steady baseline to sudden spikes."
echo ""

print_success "Traffic pattern testing completed successfully!"
echo ""
