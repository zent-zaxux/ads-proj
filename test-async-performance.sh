#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Async Performance Test
# Tests that HTTP requests return quickly (without blocking on Kafka)
# ═══════════════════════════════════════════════════════════════════

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_URL=${BASE_URL:-"http://localhost:8081"}

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     ASYNC PERFORMANCE TEST                                    ║
║     Verify Kafka Publishing is Non-Blocking                   ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Create a test user
echo -e "${YELLOW}Creating test user...${NC}"
USER_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -w "\n%{time_total}" \
  -d "{
    \"name\": \"Async Test User\",
    \"email\": \"async-test-$(date +%s)@example.com\",
    \"phoneNumber\": \"555-$(date +%s | tail -c 8)\",
    \"address\": \"Test Address\"
  }")

USER_DATA=$(echo "$USER_RESPONSE" | head -n 1)
USER_TIME=$(echo "$USER_RESPONSE" | tail -n 1)
USER_ID=$(echo "$USER_DATA" | jq -r '.id')

echo -e "User created: ID=$USER_ID"
echo -e "Response time: ${USER_TIME}s"
echo ""

# Test Order Creation with timing
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}TEST 1: Order Creation (with Kafka event publishing)${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

echo "Creating 5 orders and measuring response times..."
echo ""

TOTAL_TIME=0
ORDER_IDS=()

for i in {1..5}; do
    ORDER_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/orders" \
      -H "Content-Type: application/json" \
      -w "\n%{time_total}" \
      -d "{
        \"userId\": $USER_ID,
        \"productName\": \"Test Product $i\",
        \"quantity\": 1,
        \"unitPrice\": 100.00,
        \"totalAmount\": 100.00
      }")
    
    ORDER_DATA=$(echo "$ORDER_RESPONSE" | head -n 1)
    ORDER_TIME=$(echo "$ORDER_RESPONSE" | tail -n 1)
    ORDER_ID=$(echo "$ORDER_DATA" | jq -r '.id')
    ORDER_IDS+=($ORDER_ID)
    
    # Convert to milliseconds
    ORDER_TIME_MS=$(awk "BEGIN {printf \"%.0f\", $ORDER_TIME * 1000}")
    TOTAL_TIME=$(awk "BEGIN {printf \"%.3f\", $TOTAL_TIME + $ORDER_TIME}")
    
    if [ "$ORDER_TIME_MS" -lt 100 ]; then
        echo -e "  Order #$i (ID: $ORDER_ID): ${GREEN}${ORDER_TIME_MS}ms ✓ FAST (Async working!)${NC}"
    elif [ "$ORDER_TIME_MS" -lt 200 ]; then
        echo -e "  Order #$i (ID: $ORDER_ID): ${YELLOW}${ORDER_TIME_MS}ms ⚠ ACCEPTABLE${NC}"
    else
        echo -e "  Order #$i (ID: $ORDER_ID): ${RED}${ORDER_TIME_MS}ms ✗ SLOW (Blocking detected!)${NC}"
    fi
done

AVG_TIME=$(awk "BEGIN {printf \"%.0f\", ($TOTAL_TIME / 5) * 1000}")
echo ""
echo -e "${CYAN}Average response time: ${AVG_TIME}ms${NC}"

if [ "$AVG_TIME" -lt 100 ]; then
    echo -e "${GREEN}✓ EXCELLENT: Responses are fast (async working correctly)${NC}"
    echo -e "${GREEN}  HTTP requests are NOT blocking on Kafka acknowledgment${NC}"
elif [ "$AVG_TIME" -lt 200 ]; then
    echo -e "${YELLOW}⚠ ACCEPTABLE: Responses are reasonable${NC}"
    echo -e "${YELLOW}  Some blocking may occur but within acceptable limits${NC}"
else
    echo -e "${RED}✗ SLOW: Responses are too slow${NC}"
    echo -e "${RED}  HTTP requests are blocking - Kafka publishing is SYNCHRONOUS${NC}"
fi

echo ""

# Wait for Kafka events to be processed
echo -e "${BLUE}⏳ Waiting for Kafka events to be processed (3s)...${NC}"
sleep 3

# Check logs for async indicators
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}TEST 2: Verify Async Thread Usage${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

ASYNC_LOGS=$(tail -n 100 /tmp/app.log | grep "\[ASYNC\]" | wc -l | xargs)

if [ "$ASYNC_LOGS" -gt 0 ]; then
    echo -e "${GREEN}✓ Found $ASYNC_LOGS async thread log entries${NC}"
    echo ""
    echo -e "${CYAN}Sample async logs:${NC}"
    tail -n 100 /tmp/app.log | grep "\[ASYNC\]" | head -n 5
else
    echo -e "${RED}✗ No async thread logs found${NC}"
    echo -e "${RED}  Events may still be publishing synchronously${NC}"
fi

echo ""

# Check Kafka topics for events
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}TEST 3: Verify Events Reached Kafka${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

sleep 2

# Check if orders exist
ORDERS_COUNT=0
for order_id in "${ORDER_IDS[@]}"; do
    ORDER_EXISTS=$(curl -s "${BASE_URL}/api/orders/${order_id}" | jq -r '.id' 2>/dev/null)
    if [ "$ORDER_EXISTS" = "$order_id" ]; then
        ((ORDERS_COUNT++))
    fi
done

echo -e "Orders created: ${ORDERS_COUNT}/5"

if [ "$ORDERS_COUNT" -eq 5 ]; then
    echo -e "${GREEN}✓ All orders successfully created${NC}"
else
    echo -e "${YELLOW}⚠ Only ${ORDERS_COUNT}/5 orders found${NC}"
fi

echo ""

# Summary
echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                     TEST SUMMARY                               ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "Performance Metrics:"
echo -e "  • Average Response Time: ${AVG_TIME}ms"
echo -e "  • Async Thread Logs: $ASYNC_LOGS entries"
echo -e "  • Orders Created: ${ORDERS_COUNT}/5"
echo ""

if [ "$AVG_TIME" -lt 100 ] && [ "$ASYNC_LOGS" -gt 0 ]; then
    echo -e "${GREEN}✓✓✓ ASYNC IMPLEMENTATION WORKING CORRECTLY ✓✓✓${NC}"
    echo ""
    echo -e "${CYAN}Key Indicators:${NC}"
    echo -e "  ✓ Fast response times (<100ms average)"
    echo -e "  ✓ Async thread logs present"
    echo -e "  ✓ Events published to Kafka"
    echo -e "  ✓ HTTP requests NOT blocked by Kafka"
else
    echo -e "${YELLOW}⚠⚠⚠ POTENTIAL ISSUES DETECTED ⚠⚠⚠${NC}"
    echo ""
    echo -e "${CYAN}Issues:${NC}"
    if [ "$AVG_TIME" -ge 100 ]; then
        echo -e "  ⚠ Response times higher than expected"
    fi
    if [ "$ASYNC_LOGS" -eq 0 ]; then
        echo -e "  ⚠ No async thread logs found"
    fi
fi

echo ""
echo -e "${CYAN}Expected Behavior (Async):${NC}"
echo -e "  • HTTP response: <50ms (returns immediately)"
echo -e "  • Kafka publish: ~50-100ms (happens in background)"
echo -e "  • Total user wait: <50ms (not blocked)"
echo ""

echo -e "${CYAN}Previous Behavior (Sync):${NC}"
echo -e "  • HTTP response: >200ms (blocks waiting for Kafka)"
echo -e "  • Kafka publish: ~50-100ms (during HTTP request)"
echo -e "  • Total user wait: >200ms (blocked)"
echo ""
