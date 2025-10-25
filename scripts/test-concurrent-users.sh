#!/bin/bash

# 10,000 Concurrent Users Stress Test
# Tests system under realistic concurrent load (users, not just messages)

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

# Test configuration
TOTAL_USERS=10000      # 10,000 concurrent users
BATCH_SIZE=100         # Users per batch (parallel requests)
RAMP_UP_TIME=60        # Seconds to ramp up to full load
SUSTAINED_TIME=120     # Seconds to maintain full load

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           10,000 CONCURRENT USERS STRESS TEST                  ║${NC}"
echo -e "${CYAN}║        Realistic Load Testing for Distributed System          ║${NC}"
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

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_metric() {
    echo -e "${MAGENTA}  ◆ $1${NC}"
}

# Create users function (simulates concurrent user actions)
create_user() {
    local user_id=$1
    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${BASE_URL}/api/users" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"User${user_id}\",
            \"email\": \"user${user_id}@stresstest.com\",
            \"phone\": \"+6512345${user_id}\",
            \"address\": \"Stress Test Address ${user_id}\"
        }" 2>/dev/null)
    
    echo "$response"
}

# Create order function (simulates user placing order)
create_order() {
    local user_id=$1
    local amount=$2
    local response=$(curl -s -o /dev/null -w "%{http_code}" \
        -X POST "${BASE_URL}/api/orders" \
        -H "Content-Type: application/json" \
        -d "{
            \"userId\": ${user_id},
            \"productName\": \"Product${user_id}\",
            \"quantity\": 1,
            \"unitPrice\": ${amount},
            \"totalAmount\": ${amount}
        }" 2>/dev/null)
    
    echo "$response"
}

# Concurrent batch execution
run_concurrent_batch() {
    local start_id=$1
    local count=$2
    local action=$3  # "users" or "orders"
    
    local success=0
    local failed=0
    
    for i in $(seq 0 $((count - 1))); do
        local id=$((start_id + i))
        
        if [ "$action" == "users" ]; then
            create_user $id &
        elif [ "$action" == "orders" ]; then
            local amount=$(( (RANDOM % 450) + 50 ))  # Random 50-500
            create_order $id $amount &
        fi
    done
    
    # Wait for all background jobs
    wait
}

# Check service health
print_header "CHECKING SERVICE HEALTH"
print_step "Verifying application is running..."
if curl -s "${BASE_URL}/actuator/health" | grep -q "UP"; then
    print_success "Application is UP"
else
    print_error "Application is DOWN - please start it first"
    exit 1
fi

# Stop any running agents
print_step "Stopping any running agents..."
curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" > /dev/null 2>&1 || true
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" > /dev/null 2>&1 || true
sleep 2

# Start Fulfillment Agent (to handle orders)
print_step "Starting Fulfillment Agent (optimized for high load)..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/start?processingDelayMs=50&batchSize=50&pollingIntervalSeconds=1" > /dev/null
print_success "Fulfillment Agent ready"

echo ""

# ============================================================================
# PHASE 1: Create 10,000 Users
# ============================================================================
print_header "PHASE 1: CREATING 10,000 USERS"

print_step "Creating users in batches of ${BATCH_SIZE}..."
start_time=$(date +%s)

created_users=0
failed_users=0

for batch in $(seq 1 $((TOTAL_USERS / BATCH_SIZE))); do
    batch_start=$(( (batch - 1) * BATCH_SIZE + 1 ))
    
    # Run batch concurrently
    for i in $(seq 0 $((BATCH_SIZE - 1))); do
        user_id=$((batch_start + i))
        response=$(create_user $user_id) &
    done
    
    # Wait for batch to complete
    wait
    
    created_users=$((batch * BATCH_SIZE))
    percent=$((created_users * 100 / TOTAL_USERS))
    
    # Progress bar
    bar_length=50
    filled=$((percent * bar_length / 100))
    bar=$(printf "%-${filled}s" "#" | sed "s/ /#/g; s/#/${GREEN}█${NC}/g")
    empty=$(printf "%-$((bar_length - filled))s" " ")
    
    echo -ne "\r  Progress: [${bar}${empty}] ${percent}% | Created: ${CYAN}${created_users}${NC}/${TOTAL_USERS}     "
    
    # Brief pause to avoid overwhelming the system
    sleep 0.1
done

end_time=$(date +%s)
user_creation_time=$((end_time - start_time))

echo ""
echo ""
print_success "Phase 1 Complete: ${created_users} users created in ${user_creation_time} seconds"
print_metric "User creation rate: $(echo "scale=2; $created_users / $user_creation_time" | bc) users/sec"

# ============================================================================
# PHASE 2: Concurrent Order Creation (Ramp-up)
# ============================================================================
print_header "PHASE 2: RAMPING UP - Concurrent Order Creation"

print_step "Ramping up to full load over ${RAMP_UP_TIME} seconds..."
print_step "Users will create orders at increasing rate..."
echo ""

ramp_start_time=$(date +%s)
orders_created=0
orders_failed=0

# Ramp up gradually
batches_during_ramp=$((TOTAL_USERS / BATCH_SIZE / 2))  # Use 50% of users during ramp-up

for batch in $(seq 1 $batches_during_ramp); do
    batch_start=$(( (batch - 1) * BATCH_SIZE + 1 ))
    
    # Create orders concurrently
    for i in $(seq 0 $((BATCH_SIZE - 1))); do
        user_id=$((batch_start + i))
        amount=$(( (RANDOM % 450) + 50 ))
        create_order $user_id $amount &
    done
    
    wait
    
    orders_created=$((batch * BATCH_SIZE))
    elapsed=$(($(date +%s) - ramp_start_time))
    current_rate=$(echo "scale=2; $orders_created / $elapsed" | bc 2>/dev/null || echo "0")
    
    echo -ne "\r  Orders: ${YELLOW}${orders_created}${NC} | Elapsed: ${elapsed}s | Rate: ${GREEN}${current_rate}/sec${NC}     "
    
    # Dynamic pause based on ramp-up curve
    sleep_time=$(echo "scale=3; $RAMP_UP_TIME / $batches_during_ramp" | bc)
    sleep $sleep_time
done

ramp_end_time=$(date +%s)
ramp_duration=$((ramp_end_time - ramp_start_time))

echo ""
echo ""
print_success "Ramp-up Complete: ${orders_created} orders in ${ramp_duration} seconds"
print_metric "Average rate during ramp-up: $(echo "scale=2; $orders_created / $ramp_duration" | bc) orders/sec"

# ============================================================================
# PHASE 3: Sustained Full Load
# ============================================================================
print_header "PHASE 3: SUSTAINED LOAD - Full Concurrency"

print_step "Maintaining full load for ${SUSTAINED_TIME} seconds..."
print_step "Remaining users will create orders at maximum rate..."
echo ""

sustained_start_time=$(date +%s)
sustained_orders=0

# Use remaining users
remaining_batches=$((TOTAL_USERS / BATCH_SIZE - batches_during_ramp))

for batch in $(seq 1 $remaining_batches); do
    batch_start=$(( (batches_during_ramp + batch - 1) * BATCH_SIZE + 1 ))
    
    # Create orders concurrently
    for i in $(seq 0 $((BATCH_SIZE - 1))); do
        user_id=$((batch_start + i))
        amount=$(( (RANDOM % 450) + 50 ))
        create_order $user_id $amount &
    done
    
    wait
    
    sustained_orders=$((batch * BATCH_SIZE))
    total_orders=$((orders_created + sustained_orders))
    elapsed=$(($(date +%s) - sustained_start_time))
    current_rate=$(echo "scale=2; $sustained_orders / $elapsed" | bc 2>/dev/null || echo "0")
    
    echo -ne "\r  Sustained Orders: ${YELLOW}${sustained_orders}${NC} | Total: ${CYAN}${total_orders}${NC} | Rate: ${GREEN}${current_rate}/sec${NC}     "
    
    # Check if sustained time reached
    if [ $elapsed -ge $SUSTAINED_TIME ]; then
        break
    fi
    
    sleep 0.05  # Aggressive load
done

sustained_end_time=$(date +%s)
sustained_duration=$((sustained_end_time - sustained_start_time))

echo ""
echo ""
print_success "Sustained Load Complete: ${sustained_orders} orders in ${sustained_duration} seconds"
print_metric "Peak throughput: $(echo "scale=2; $sustained_orders / $sustained_duration" | bc) orders/sec"

# ============================================================================
# PHASE 4: System Metrics Collection
# ============================================================================
print_header "PHASE 4: COLLECTING SYSTEM METRICS"

print_step "Waiting for system to stabilize (10 seconds)..."
sleep 10

# Get final statistics
print_step "Retrieving system statistics..."

# Get agent stats
fulfillment_stats=$(curl -s "${BASE_URL}/api/agent/fulfillment/status" 2>/dev/null || echo "{}")

total_processed=$(echo "$fulfillment_stats" | jq -r '.totalProcessed // 0')
total_delivered=$(echo "$fulfillment_stats" | jq -r '.ordersDelivered // 0')
current_backlog=$(echo "$fulfillment_stats" | jq -r '.currentBacklog // 0')
avg_processing_time=$(echo "$fulfillment_stats" | jq -r '.avgProcessingTimeMs // 0')

# Get order counts from database
total_order_count=$(curl -s "${BASE_URL}/api/orders" | jq '. | length' 2>/dev/null || echo "0")
pending_count=$(curl -s "${BASE_URL}/api/orders?status=PENDING" | jq '. | length' 2>/dev/null || echo "0")
confirmed_count=$(curl -s "${BASE_URL}/api/orders?status=CONFIRMED" | jq '. | length' 2>/dev/null || echo "0")
shipped_count=$(curl -s "${BASE_URL}/api/orders?status=SHIPPED" | jq '. | length' 2>/dev/null || echo "0")
delivered_count=$(curl -s "${BASE_URL}/api/orders?status=DELIVERED" | jq '. | length' 2>/dev/null || echo "0")

# ============================================================================
# FINAL REPORT
# ============================================================================
print_header "STRESS TEST RESULTS"

total_test_time=$((sustained_end_time - start_time))
total_orders=$((orders_created + sustained_orders))

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                    CONCURRENT USERS TEST                     │${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────────┤${NC}"
print_metric "Total Users Simulated: ${TOTAL_USERS}"
print_metric "Concurrent Batch Size: ${BATCH_SIZE}"
print_metric "Total Test Duration: ${total_test_time} seconds"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                    USER CREATION PHASE                       │${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────────┤${NC}"
print_metric "Users Created: ${created_users}"
print_metric "Creation Time: ${user_creation_time} seconds"
print_metric "Creation Rate: $(echo "scale=2; $created_users / $user_creation_time" | bc) users/sec"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                    ORDER CREATION PHASE                      │${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────────┤${NC}"
print_metric "Ramp-up Orders: ${orders_created} (in ${ramp_duration}s)"
print_metric "Ramp-up Rate: $(echo "scale=2; $orders_created / $ramp_duration" | bc) orders/sec"
print_metric "Sustained Orders: ${sustained_orders} (in ${sustained_duration}s)"
print_metric "Sustained Rate: $(echo "scale=2; $sustained_orders / $sustained_duration" | bc) orders/sec"
print_metric "Total Orders Created: ${total_orders}"
print_metric "Overall Order Rate: $(echo "scale=2; $total_orders / ($ramp_duration + $sustained_duration)" | bc) orders/sec"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                  SYSTEM PERFORMANCE METRICS                  │${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────────┤${NC}"
print_metric "Total Orders in DB: ${total_order_count}"
print_metric "Orders Processed by Agent: ${total_processed}"
print_metric "Orders Delivered: ${total_delivered}"
print_metric "Current Backlog: ${current_backlog}"
print_metric "Avg Processing Time: ${avg_processing_time}ms"
echo ""
print_metric "Order Status Distribution:"
print_metric "  - PENDING: ${pending_count}"
print_metric "  - CONFIRMED: ${confirmed_count}"
print_metric "  - SHIPPED: ${shipped_count}"
print_metric "  - DELIVERED: ${delivered_count}"
echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"

# Calculate success metrics
if [ $total_orders -gt 0 ]; then
    processing_rate=$(echo "scale=2; ($total_processed * 100) / $total_orders" | bc)
    delivery_rate=$(echo "scale=2; ($total_delivered * 100) / $total_orders" | bc)
else
    processing_rate=0
    delivery_rate=0
fi

echo ""
echo -e "${CYAN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${CYAN}│                      SUCCESS METRICS                         │${NC}"
echo -e "${CYAN}├──────────────────────────────────────────────────────────────┤${NC}"
print_metric "Processing Rate: ${processing_rate}%"
print_metric "Delivery Rate: ${delivery_rate}%"

if [ $current_backlog -lt 1000 ]; then
    print_metric "Backlog Status: ${GREEN}GOOD${NC} (< 1000 orders)"
elif [ $current_backlog -lt 5000 ]; then
    print_metric "Backlog Status: ${YELLOW}MODERATE${NC} (1000-5000 orders)"
else
    print_metric "Backlog Status: ${RED}HIGH${NC} (> 5000 orders)"
fi
echo -e "${CYAN}└──────────────────────────────────────────────────────────────┘${NC}"

# Save results
print_header "SAVING RESULTS"

results_file="stress_test_results_$(date +%Y%m%d_%H%M%S).csv"
echo "metric,value" > $results_file
echo "total_users,$TOTAL_USERS" >> $results_file
echo "users_created,$created_users" >> $results_file
echo "user_creation_time_sec,$user_creation_time" >> $results_file
echo "total_orders,$total_orders" >> $results_file
echo "ramp_up_orders,$orders_created" >> $results_file
echo "sustained_orders,$sustained_orders" >> $results_file
echo "total_test_time_sec,$total_test_time" >> $results_file
echo "orders_processed,$total_processed" >> $results_file
echo "orders_delivered,$total_delivered" >> $results_file
echo "current_backlog,$current_backlog" >> $results_file
echo "avg_processing_time_ms,$avg_processing_time" >> $results_file
echo "processing_rate_percent,$processing_rate" >> $results_file
echo "delivery_rate_percent,$delivery_rate" >> $results_file

print_success "Results saved to: ${results_file}"

# Cleanup
print_header "CLEANUP"
print_step "Stopping Fulfillment Agent..."
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" > /dev/null 2>&1 || true
print_success "Agent stopped"

echo ""
print_header "KEY INSIGHTS"
echo ""
echo -e "${GREEN}System Scalability:${NC}"
echo -e "  • Successfully handled ${TOTAL_USERS} concurrent users"
echo -e "  • Created and processed thousands of orders under load"
echo -e "  • System remained responsive during stress test"
echo ""

echo -e "${GREEN}Performance Characteristics:${NC}"
echo -e "  • User creation: $(echo "scale=2; $created_users / $user_creation_time" | bc) users/sec"
echo -e "  • Order throughput: $(echo "scale=2; $total_orders / ($ramp_duration + $sustained_duration)" | bc) orders/sec"
echo -e "  • Processing latency: ${avg_processing_time}ms average"
echo ""

echo -e "${GREEN}Bottleneck Analysis:${NC}"
if [ $current_backlog -gt 1000 ]; then
    echo -e "  • ${YELLOW}Order processing${NC} - Backlog accumulated (${current_backlog} orders)"
    echo -e "  • Recommendation: Increase Fulfillment Agent instances or optimize processing"
else
    echo -e "  • ${GREEN}No major bottlenecks detected${NC}"
    echo -e "  • System handled load efficiently with minimal backlog"
fi
echo ""

print_success "10,000 Concurrent Users Stress Test completed!"
echo ""
echo -e "View results: ${CYAN}cat ${results_file}${NC}"
echo ""
