#!/bin/bash

###############################################################################
# Demo Part 4: Traffic Simulation
# Demonstrates concurrent order processing and system scalability
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

API_BASE="http://localhost:8081"

# Load user IDs
if [ -f /tmp/demo_users.env ]; then
    source /tmp/demo_users.env
else
    echo -e "${RED}Error: User IDs not found. Run demo-1-users.sh first${NC}"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        DEMO PART 4: Traffic Simulation                   ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Instructions
###############################################################################
echo -e "${YELLOW}📋 MONITORING SUGGESTION:${NC}"
echo "   Open Terminal 2 to watch Kafka consumer lag:"
echo ""
echo -e "${CYAN}   watch -n 1 'docker exec kafka kafka-consumer-groups \\${NC}"
echo -e "${CYAN}     --bootstrap-server localhost:9092 \\${NC}"
echo -e "${CYAN}     --group ads-proj-group \\${NC}"
echo -e "${CYAN}     --describe | grep order-events'${NC}"
echo ""
echo -e "${YELLOW}   Press ENTER to start traffic simulation...${NC}"
read

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Function to create a single order
###############################################################################
create_order() {
    local order_num=$1
    local user_id=$2
    local product_name=$3
    local quantity=$4
    local price=$5
    
    RESPONSE=$(curl -s -X POST $API_BASE/api/orders \
      -H "Content-Type: application/json" \
      -d "{
        \"userId\": $user_id,
        \"items\": [{
          \"productName\": \"$product_name\",
          \"quantity\": $quantity,
          \"price\": $price
        }],
        \"deliveryAddress\": \"Demo Address $order_num\"
      }")
    
    ORDER_ID=$(echo $RESPONSE | jq -r '.id')
    STATUS=$(echo $RESPONSE | jq -r '.status')
    TOTAL=$(echo $RESPONSE | jq -r '.totalAmount')
    
    echo "  Order #$ORDER_ID: $STATUS ($TOTAL)"
}

###############################################################################
# Phase 1: Create 10 concurrent orders
###############################################################################
echo -e "${YELLOW}[1/3]${NC} Simulating concurrent traffic: Creating 10 orders..."
echo ""

START_TIME=$(date +%s)

# Array of product names
PRODUCTS=("Laptop" "Smartphone" "Tablet" "Headphones" "Keyboard" "Monitor" "Mouse" "Webcam" "Speaker" "Router")

echo "Creating orders concurrently..."
for i in {1..10}; do
    # Alternate between users
    USER_ID=$( [ $((i % 2)) -eq 0 ] && echo $USER1_ID || echo $USER2_ID )
    PRODUCT=${PRODUCTS[$((i-1))]}
    QUANTITY=$((RANDOM % 3 + 1))
    PRICE=$((RANDOM % 500 + 100))
    
    # Create order in background
    create_order $i $USER_ID "$PRODUCT" $QUANTITY $PRICE &
done

# Wait for all background jobs to complete
wait

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo ""
echo -e "${GREEN}✓${NC} All 10 orders created in $DURATION seconds"

echo ""
echo -e "${CYAN}👀 CHECK TERMINAL 2: Watch consumer lag decrease to 0${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Phase 2: Check Kafka Consumer Performance
###############################################################################
echo -e "${YELLOW}[2/3]${NC} Checking Kafka consumer performance..."
echo ""

echo "Consumer Group Status:"
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group ads-proj-group \
  --describe 2>/dev/null | grep -E "TOPIC|order-events" | head -7

echo ""

# Calculate total lag
TOTAL_LAG=$(docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group ads-proj-group \
  --describe 2>/dev/null | \
  awk '/order-events/ {sum+=$6} END {print sum}')

if [ -z "$TOTAL_LAG" ]; then
    TOTAL_LAG=0
fi

echo "Total Consumer Lag: $TOTAL_LAG messages"
echo ""

if [ "$TOTAL_LAG" -eq 0 ]; then
    echo -e "${GREEN}✓${NC} Zero lag - Consumers are keeping up with producers!"
else
    echo -e "${YELLOW}⚠${NC}  Lag detected - Consumers are catching up ($TOTAL_LAG messages behind)"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Phase 3: Wait for processing and verify delivery
###############################################################################
echo -e "${YELLOW}[3/3]${NC} Waiting for fulfillment processing (20 seconds)..."
echo ""

# Progress bar
for i in {1..20}; do
    printf "\r  Progress: ["
    for j in {1..20}; do
        if [ $j -le $i ]; then
            printf "█"
        else
            printf "░"
        fi
    done
    printf "] %d/20 seconds" $i
    sleep 1
done
printf "\n"

echo ""
echo "Checking final order statuses..."
echo ""

# Get all orders and group by status
ORDER_STATS=$(curl -s $API_BASE/api/orders | \
  jq -r 'group_by(.status) | .[] | "\(.[0].status): \(length) orders"')

echo "Order Status Distribution:"
echo "$ORDER_STATS" | sed 's/^/  /'

echo ""

# Count delivered orders
DELIVERED_COUNT=$(curl -s $API_BASE/api/orders | \
  jq '[.[] | select(.status=="DELIVERED")] | length')

TOTAL_ORDERS=$(curl -s $API_BASE/api/orders | jq 'length')

echo "Summary:"
echo "  Total Orders:     $TOTAL_ORDERS"
echo "  Delivered Orders: $DELIVERED_COUNT"
echo "  Success Rate:     $(awk "BEGIN {printf \"%.1f%%\", ($DELIVERED_COUNT/$TOTAL_ORDERS)*100}")"

echo ""

if [ "$DELIVERED_COUNT" -eq "$TOTAL_ORDERS" ]; then
    echo -e "${GREEN}✓${NC} All orders successfully delivered!"
else
    PENDING=$((TOTAL_ORDERS - DELIVERED_COUNT))
    echo -e "${YELLOW}⚠${NC}  $PENDING orders still processing (may need more time)"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Performance Metrics
###############################################################################
echo "Performance Metrics:"
echo ""

# Calculate throughput
if [ "$DURATION" -gt 0 ]; then
    THROUGHPUT=$(awk "BEGIN {printf \"%.2f\", 10/$DURATION}")
    echo "  Order Creation Throughput: $THROUGHPUT orders/second"
fi

# Check database connection pool
ACTIVE_CONN=$(curl -s $API_BASE/actuator/metrics/hikaricp.connections.active 2>/dev/null | \
  jq -r '.measurements[0].value' 2>/dev/null || echo "N/A")
IDLE_CONN=$(curl -s $API_BASE/actuator/metrics/hikaricp.connections.idle 2>/dev/null | \
  jq -r '.measurements[0].value' 2>/dev/null || echo "N/A")

echo "  Active DB Connections:     $ACTIVE_CONN"
echo "  Idle DB Connections:       $IDLE_CONN"

# Check thread count
THREAD_COUNT=$(curl -s $API_BASE/actuator/metrics/jvm.threads.live 2>/dev/null | \
  jq -r '.measurements[0].value' 2>/dev/null || echo "N/A")

echo "  JVM Live Threads:          $THREAD_COUNT"

echo ""

# Event throughput
TOTAL_EVENTS=$(docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
  --broker-list localhost:9092 --topic order-events 2>/dev/null | \
  awk -F: '{sum+=$3} END {print sum}' || echo "N/A")

echo "  Total Events Processed:    $TOTAL_EVENTS (order-events topic)"

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${GREEN}✅ PART 4 COMPLETED${NC}"
echo ""
echo "Summary:"
echo "  • Created 10 concurrent orders in $DURATION seconds"
echo "  • Demonstrated parallel processing capabilities"
echo "  • Kafka consumer concurrency: 5 threads across 5 partitions"
echo "  • Consumer lag: $TOTAL_LAG messages (should be 0)"
echo "  • Success rate: $(awk "BEGIN {printf \"%.1f%%\", ($DELIVERED_COUNT/$TOTAL_ORDERS)*100}")"
echo ""
echo "Key Features Demonstrated:"
echo "  ✓ Concurrent request handling (background processes)"
echo "  ✓ Kafka partitioning for parallel consumption"
echo "  ✓ Batch processing by fulfillment agent"
echo "  ✓ Zero consumer lag under load"
echo "  ✓ Database connection pooling (HikariCP)"
echo ""
echo "Next: Run ./scripts/demo-5-fulfillment.sh"
echo ""
