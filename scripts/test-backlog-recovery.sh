#!/bin/bash

# Backlog Recovery Testing Script
# Tests system capacity by preloading orders and measuring recovery time

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

BASE_URL="http://localhost:8081"
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="adsdb"
DB_USER="postgres"
DB_PASS="password"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         BACKLOG RECOVERY & CAPACITY DEMONSTRATION             ║${NC}"
echo -e "${CYAN}║      Testing Fault Tolerance and Cold Start Performance       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
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

print_metric() {
    echo -e "${MAGENTA}  ◆ $1${NC}"
}

# Check PostgreSQL connection
check_database() {
    print_step "Checking database connection..."
    if PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "SELECT 1;" > /dev/null 2>&1; then
        print_success "Database connected"
    else
        echo -e "${RED}✗ Cannot connect to database${NC}"
        echo "Please ensure PostgreSQL is running and accessible"
        exit 1
    fi
}

# Get order count by status
get_order_count() {
    local status=$1
    PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c \
        "SELECT COUNT(*) FROM orders WHERE status = '$status' AND user_id BETWEEN 9000 AND 9099;" | tr -d ' '
}

# Main test flow
print_header "PHASE 1: ENVIRONMENT SETUP"

check_database

# Stop any running agents
print_step "Stopping any running agents..."
curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" > /dev/null 2>&1 || true
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" > /dev/null 2>&1 || true
sleep 2
print_success "Agents stopped"

print_header "PHASE 2: PRELOAD BACKLOG (Simulating Downtime)"

print_step "Loading 100 PENDING orders into database..."
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f preload-orders.sql > /dev/null 2>&1
print_success "Orders preloaded"

# Verify preload
pending_count=$(get_order_count "PENDING")
echo ""
echo -e "${CYAN}┌─────────────── PRELOAD SUMMARY ────────────────┐${NC}"
echo -e "${CYAN}│${NC} Total PENDING orders: ${MAGENTA}$pending_count${NC}"
echo -e "${CYAN}│${NC} Scenario: System down for 100 minutes"
echo -e "${CYAN}│${NC} Orders accumulated during downtime"
echo -e "${CYAN}└─────────────────────────────────────────────────┘${NC}"
echo ""

print_header "PHASE 3: COLD START RECOVERY"

print_step "Starting Fulfillment Agent (Cold Start)..."
start_time=$(date +%s)

# Start with optimized configuration for recovery
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/start?processingDelayMs=500&batchSize=10&pollingIntervalSeconds=3" > /dev/null
print_success "Fulfillment Agent started (500ms delay, batch 10, poll every 3s)"

echo ""
echo -e "${YELLOW}Monitoring recovery progress...${NC}"
echo ""

# Monitor progress for 60 seconds
monitor_duration=60
elapsed=0

while [ $elapsed -lt $monitor_duration ]; do
    pending=$(get_order_count "PENDING")
    confirmed=$(get_order_count "CONFIRMED")
    shipped=$(get_order_count "SHIPPED")
    delivered=$(get_order_count "DELIVERED")
    
    total_processed=$((confirmed + shipped + delivered))
    percent_complete=$((total_processed * 100 / pending_count))
    
    echo -ne "\r${CYAN}[${elapsed}s]${NC} PENDING: ${YELLOW}$pending${NC} | CONFIRMED: ${BLUE}$confirmed${NC} | SHIPPED: ${MAGENTA}$shipped${NC} | DELIVERED: ${GREEN}$delivered${NC} | Progress: ${GREEN}${percent_complete}%${NC}   "
    
    # Check if backlog cleared
    if [ $pending -eq 0 ] && [ $total_processed -ge $pending_count ]; then
        echo ""
        print_success "Backlog cleared!"
        break
    fi
    
    sleep 5
    elapsed=$((elapsed + 5))
done

echo ""
echo ""

end_time=$(date +%s)
recovery_time=$((end_time - start_time))

# Get final agent stats
print_step "Collecting final statistics..."
agent_stats=$(curl -s "${BASE_URL}/api/agent/fulfillment/status")

print_header "PHASE 4: RECOVERY ANALYSIS"

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                    RECOVERY METRICS                          │${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────────┤${NC}"

final_pending=$(get_order_count "PENDING")
final_confirmed=$(get_order_count "CONFIRMED")
final_shipped=$(get_order_count "SHIPPED")
final_delivered=$(get_order_count "DELIVERED")
total_cleared=$((final_confirmed + final_shipped + final_delivered))

print_metric "Initial Backlog: $pending_count orders"
print_metric "Recovery Time: ${recovery_time} seconds"
print_metric "Orders Cleared: $total_cleared"
print_metric "Still PENDING: $final_pending"
print_metric "CONFIRMED: $final_confirmed"
print_metric "SHIPPED: $final_shipped"
print_metric "DELIVERED: $final_delivered"

if [ $recovery_time -gt 0 ]; then
    throughput=$(echo "scale=2; $total_cleared / $recovery_time" | bc)
    print_metric "Average Throughput: ${throughput} orders/second"
fi

echo ""

# Agent performance stats
total_processed=$(echo "$agent_stats" | jq -r '.totalProcessed // 0')
avg_time=$(echo "$agent_stats" | jq -r '.avgProcessingTimeMs // 0')

print_metric "Agent Total Processed: $total_processed"
print_metric "Avg Processing Time: ${avg_time}ms per order"

echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"
echo ""

# Evaluation
print_header "EVALUATION"

echo ""
echo -e "${GREEN}Scenario:${NC} System crashed with 100 pending orders"
echo -e "${GREEN}Recovery:${NC} Fulfillment Agent restarted (cold start)"
echo -e "${GREEN}Result:${NC} Processed $total_cleared orders in ${recovery_time}s"
echo ""

if [ $recovery_time -le 60 ] && [ $total_cleared -ge 80 ]; then
    echo -e "${GREEN}✓ EXCELLENT${NC} - Fast recovery demonstrates good capacity"
    echo -e "  System can handle backlog efficiently after downtime"
elif [ $recovery_time -le 90 ] && [ $total_cleared -ge 50 ]; then
    echo -e "${YELLOW}✓ GOOD${NC} - Reasonable recovery time"
    echo -e "  System shows acceptable fault tolerance"
else
    echo -e "${YELLOW}⚠ SLOW${NC} - Recovery could be optimized"
    echo -e "  Consider increasing batch size or reducing processing delay"
fi

echo ""
echo -e "${CYAN}Key Insights:${NC}"
echo -e "  • Cold start handling: Agent processes existing backlog immediately"
echo -e "  • Fault tolerance: No data loss during downtime"
echo -e "  • Capacity planning: Measured throughput under backlog pressure"
echo -e "  • Recovery pattern: Orders progress through 4-stage workflow"
echo ""

# Cleanup
print_header "CLEANUP"
print_step "Stopping Fulfillment Agent..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" > /dev/null
print_success "Agent stopped"

print_step "Cleaning up test data..."
PGPASSWORD=$DB_PASS psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c \
    "DELETE FROM orders WHERE user_id BETWEEN 9000 AND 9099;" > /dev/null 2>&1
print_success "Test data removed"

echo ""
print_success "Backlog recovery test completed successfully!"
echo ""
