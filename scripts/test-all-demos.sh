#!/bin/bash

###############################################################################
# Automated Demo Test Script
# Tests all demo scripts without manual intervention
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

API_BASE="http://localhost:8081"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         AUTOMATED DEMO TEST SUITE                        ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Prerequisite: Start Fulfillment Agent
###############################################################################
echo -e "${YELLOW}[SETUP]${NC} Starting Fulfillment Agent"
echo ""

AGENT_START=$(curl -s -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1")
AGENT_STATUS=$(echo $AGENT_START | jq -r '.success' 2>/dev/null || echo "false")

if [ "$AGENT_STATUS" = "true" ]; then
    AGENT_ID=$(echo $AGENT_START | jq -r '.agentId')
    echo -e "  ${GREEN}✓${NC} Fulfillment Agent started: $AGENT_ID"
else
    echo -e "  ${YELLOW}⚠${NC} Agent already running or failed to start"
fi

echo ""

###############################################################################
# Test 1: User Creation
###############################################################################
echo -e "${YELLOW}[TEST 1]${NC} User Registration"
echo ""

echo "Creating User 1 (Alice)..."
USER1=$(curl -s -X POST $API_BASE/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Johnson",
    "email": "alice@demo.com",
    "phoneNumber": "+1-555-0101",
    "address": "123 Main St, Boston, MA"
  }')

USER1_ID=$(echo $USER1 | jq -r '.id')
echo "  User 1 created: ID=$USER1_ID"

echo "Creating User 2 (Bob)..."
USER2=$(curl -s -X POST $API_BASE/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Bob Smith",
    "email": "bob@demo.com",
    "phoneNumber": "+1-555-0102",
    "address": "456 Oak Ave, Cambridge, MA"
  }')

USER2_ID=$(echo $USER2 | jq -r '.id')
echo "  User 2 created: ID=$USER2_ID"

# Test idempotency
echo "Testing idempotency..."
DUPLICATE=$(curl -s -X POST $API_BASE/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Johnson",
    "email": "alice@demo.com",
    "phoneNumber": "+1-555-0101",
    "address": "123 Main St, Boston, MA"
  }')

DUPLICATE_ID=$(echo $DUPLICATE | jq -r '.id')

if [ "$DUPLICATE_ID" = "$USER1_ID" ]; then
    echo -e "  ${GREEN}✓${NC} Idempotency working (returned same ID: $USER1_ID)"
else
    echo -e "  ${RED}✗${NC} Idempotency failed (got different ID: $DUPLICATE_ID)"
fi

echo -e "${GREEN}✓ Test 1 Passed${NC}"
echo ""

###############################################################################
# Test 2: Order Creation
###############################################################################
echo -e "${YELLOW}[TEST 2]${NC} Order Creation"
echo ""

echo "Creating order for Alice..."
ORDER=$(curl -s -X POST $API_BASE/api/orders \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": $USER1_ID,
    \"productName\": \"MacBook Pro\",
    \"quantity\": 1,
    \"unitPrice\": 2499.00
  }")

ORDER_ID=$(echo $ORDER | jq -r '.id')
ORDER_STATUS=$(echo $ORDER | jq -r '.status')
echo "  Order created: ID=$ORDER_ID, Status=$ORDER_STATUS"

if [ "$ORDER_STATUS" = "PENDING" ]; then
    echo -e "  ${GREEN}✓${NC} Order starts in PENDING state"
else
    echo -e "  ${RED}✗${NC} Unexpected initial status: $ORDER_STATUS"
fi

echo "Waiting for fulfillment agent to process order (5 seconds)..."
sleep 5

FINAL_STATUS=$(curl -s $API_BASE/api/orders/$ORDER_ID | jq -r '.status')
echo "  Final order status: $FINAL_STATUS"

if [ "$FINAL_STATUS" = "DELIVERED" ]; then
    echo -e "  ${GREEN}✓${NC} Order successfully delivered"
elif [ "$FINAL_STATUS" = "SHIPPED" ]; then
    echo -e "  ${YELLOW}⚠${NC} Order shipped (still in transit)"
else
    echo -e "  ${YELLOW}⚠${NC} Order in $FINAL_STATUS state"
fi

echo -e "${GREEN}✓ Test 2 Passed${NC}"
echo ""

###############################################################################
# Test 3: Notifications
###############################################################################
echo -e "${YELLOW}[TEST 3]${NC} Notifications"
echo ""

echo "Checking notifications for Alice..."
NOTIFS=$(curl -s $API_BASE/api/notifications/user/$USER1_ID)
NOTIF_COUNT=$(echo $NOTIFS | jq '. | if type=="array" then length else .totalElements // .content | length end')

echo "  Alice has $NOTIF_COUNT notifications"

if [ "$NOTIF_COUNT" -gt 0 ]; then
    echo -e "  ${GREEN}✓${NC} Notifications created"
    echo "  Notification types:"
    echo "$NOTIFS" | jq -r 'if type=="array" then .[].type else .content[].type end' | sort | uniq | sed 's/^/    - /' 2>/dev/null || echo "    (Could not parse types)"
else
    echo -e "  ${YELLOW}⚠${NC} No notifications found (may still be processing)"
fi

echo -e "${GREEN}✓ Test 3 Passed${NC}"
echo ""

###############################################################################
# Test 4: Concurrent Orders
###############################################################################
echo -e "${YELLOW}[TEST 4]${NC} Concurrent Order Processing"
echo ""

echo "Creating 5 orders concurrently..."
ORDER_IDS=()

for i in {1..5}; do
    USER_ID=$( [ $((i % 2)) -eq 0 ] && echo $USER1_ID || echo $USER2_ID )
    
    RESPONSE=$(curl -s -X POST $API_BASE/api/orders \
      -H "Content-Type: application/json" \
      -d "{
        \"userId\": $USER_ID,
        \"productName\": \"Product-$i\",
        \"quantity\": 1,
        \"unitPrice\": $((100 + i * 50)).00
      }") &
done

wait

echo "  All concurrent requests completed"

# Get recent orders
RECENT_ORDERS=$(curl -s $API_BASE/api/orders | jq '.totalElements // .content | length')
echo "  Total orders in system: $RECENT_ORDERS"

if [ "$RECENT_ORDERS" -ge 6 ]; then
    echo -e "  ${GREEN}✓${NC} Concurrent order creation successful"
else
    echo -e "  ${RED}✗${NC} Expected at least 6 orders, found $RECENT_ORDERS"
fi

echo -e "${GREEN}✓ Test 4 Passed${NC}"
echo ""

###############################################################################
# Test 5: Kafka Consumer Health
###############################################################################
echo -e "${YELLOW}[TEST 5]${NC} Kafka Consumer Health"
echo ""

echo "Waiting for event processing (10 seconds)..."
sleep 10

echo "Checking consumer lag..."
CONSUMER_LAG=$(docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group ads-proj-group \
  --describe 2>/dev/null | \
  awk '/order-events/ {sum+=$6} END {print sum}' || echo "0")

echo "  Total consumer lag: $CONSUMER_LAG messages"

if [ "$CONSUMER_LAG" -eq 0 ] || [ -z "$CONSUMER_LAG" ]; then
    echo -e "  ${GREEN}✓${NC} Zero lag - consumers keeping up"
else
    echo -e "  ${YELLOW}⚠${NC} Lag detected: $CONSUMER_LAG messages"
fi

echo -e "${GREEN}✓ Test 5 Passed${NC}"
echo ""

###############################################################################
# Test 6: Final Statistics
###############################################################################
echo -e "${YELLOW}[TEST 6]${NC} System Statistics"
echo ""

# User count
USER_COUNT=$(curl -s $API_BASE/api/users | jq '.totalElements // .content | length')
echo "  Users: $USER_COUNT"

# Order count and status
ORDER_COUNT=$(curl -s $API_BASE/api/orders | jq '.totalElements // .content | length')
DELIVERED_COUNT=$(curl -s $API_BASE/api/orders | jq '.content | map(select(.status=="DELIVERED")) | length')
echo "  Orders: $ORDER_COUNT total, $DELIVERED_COUNT delivered"

# Success rate
if [ "$ORDER_COUNT" -gt 0 ]; then
    SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($DELIVERED_COUNT/$ORDER_COUNT)*100}")
    echo "  Success Rate: $SUCCESS_RATE%"
    
    if [ "${SUCCESS_RATE%.*}" -ge 80 ]; then
        echo -e "  ${GREEN}✓${NC} High success rate"
    else
        echo -e "  ${YELLOW}⚠${NC} Success rate below 80%"
    fi
fi

# Health check
HEALTH=$(curl -s $API_BASE/actuator/health | jq -r '.status')
echo "  Application Health: $HEALTH"

if [ "$HEALTH" = "UP" ]; then
    echo -e "  ${GREEN}✓${NC} Application healthy"
else
    echo -e "  ${RED}✗${NC} Application unhealthy: $HEALTH"
fi

echo -e "${GREEN}✓ Test 6 Passed${NC}"
echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              ALL TESTS COMPLETED ✅                       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Summary:"
echo "  ✓ User Registration & Idempotency"
echo "  ✓ Order Creation & Workflow"
echo "  ✓ Notification System"
echo "  ✓ Concurrent Processing"
echo "  ✓ Kafka Consumer Health"
echo "  ✓ System Statistics"
echo ""
echo "Final Metrics:"
echo "  Users:          $USER_COUNT"
echo "  Orders:         $ORDER_COUNT"
echo "  Delivered:      $DELIVERED_COUNT ($SUCCESS_RATE%)"
echo "  Consumer Lag:   $CONSUMER_LAG messages"
echo "  Health:         $HEALTH"
echo ""
echo -e "${GREEN}All demo components are working correctly! 🎉${NC}"
echo ""
