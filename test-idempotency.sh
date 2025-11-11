#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Idempotency Test Script
# Tests that duplicate Kafka messages are properly deduplicated
# ═══════════════════════════════════════════════════════════════════

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

BASE_URL="http://localhost:8081"

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}       IDEMPOTENCY TEST - Message Deduplication${NC}"
echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""

# Step 1: Check application health
echo -e "${YELLOW}[1/6] Checking application health...${NC}"
HEALTH=$(curl -s ${BASE_URL}/actuator/health | jq -r '.status')
if [ "$HEALTH" = "UP" ]; then
    echo -e "${GREEN}✓ Application is healthy${NC}"
else
    echo -e "${RED}✗ Application is not healthy${NC}"
    exit 1
fi
echo ""

# Step 2: Create a test user
echo -e "${YELLOW}[2/6] Creating test user...${NC}"
USER_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/users \
    -H "Content-Type: application/json" \
    -d '{
        "name": "Idempotency Test User",
        "email": "idempotency-'$(date +%s)'@test.com",
        "phoneNumber": "+1234567890",
        "address": "123 Test Street"
    }')

USER_ID=$(echo $USER_RESPONSE | jq -r '.id')
echo -e "${GREEN}✓ User created with ID: ${USER_ID}${NC}"
echo ""

# Step 3: Create a test order (this will trigger Kafka event)
echo -e "${YELLOW}[3/6] Creating test order...${NC}"
ORDER_RESPONSE=$(curl -s -X POST ${BASE_URL}/api/orders \
    -H "Content-Type: application/json" \
    -d "{
        \"userId\": ${USER_ID},
        \"productName\": \"Test Product\",
        \"quantity\": 1,
        \"unitPrice\": 99.99
    }")

ORDER_ID=$(echo $ORDER_RESPONSE | jq -r '.id')
echo -e "${GREEN}✓ Order created with ID: ${ORDER_ID}${NC}"
echo "Order details:"
echo $ORDER_RESPONSE | jq .
echo ""

# Step 4: Wait for Kafka consumers to process
echo -e "${YELLOW}[4/6] Waiting for Kafka consumers to process (10 seconds)...${NC}"
sleep 10
echo -e "${GREEN}✓ Wait complete${NC}"
echo ""

# Step 5: Check processed_events table
echo -e "${YELLOW}[5/6] Checking processed_events in database...${NC}"
PROCESSED_COUNT=$(docker exec postgres psql -U adsuser -d adsdb -t -c \
    "SELECT COUNT(*) FROM processed_events WHERE aggregate_id = '${ORDER_ID}';" | tr -d ' ')

echo -e "${GREEN}✓ Found ${PROCESSED_COUNT} processed event(s) for Order #${ORDER_ID}${NC}"

if [ $PROCESSED_COUNT -gt 0 ]; then
    echo "Processed events:"
    docker exec postgres psql -U adsuser -d adsdb -c \
        "SELECT event_id, event_type, consumer_group, processed_at FROM processed_events WHERE aggregate_id = '${ORDER_ID}';"
fi
echo ""

# Step 6: Check for duplicate prevention
echo -e "${YELLOW}[6/6] Verifying no duplicate processing occurred...${NC}"

# Check payments (should be exactly 1 payment)
PAYMENT_COUNT=$(docker exec postgres psql -U adsuser -d adsdb -t -c \
    "SELECT COUNT(*) FROM payments WHERE order_id = ${ORDER_ID};" | tr -d ' ')

echo -e "Payments for Order #${ORDER_ID}: ${PAYMENT_COUNT}"

# Check notifications (should be exactly 1 notification)
NOTIFICATION_COUNT=$(docker exec postgres psql -U adsuser -d adsdb -t -c \
    "SELECT COUNT(*) FROM notifications WHERE order_id = ${ORDER_ID};" | tr -d ' ')

echo -e "Notifications for Order #${ORDER_ID}: ${NOTIFICATION_COUNT}"

echo ""

# Verify results
if [ "$PAYMENT_COUNT" = "1" ] && [ "$NOTIFICATION_COUNT" = "1" ]; then
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✅ SUCCESS: Idempotency working correctly!${NC}"
    echo -e "${GREEN}   - Exactly 1 payment created${NC}"
    echo -e "${GREEN}   - Exactly 1 notification created${NC}"
    echo -e "${GREEN}   - No duplicate processing detected${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
else
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}⚠️  WARNING: Unexpected counts detected${NC}"
    echo -e "${RED}   - Expected 1 payment, found: ${PAYMENT_COUNT}${NC}"
    echo -e "${RED}   - Expected 1 notification, found: ${NOTIFICATION_COUNT}${NC}"
    echo -e "${RED}════════════════════════════════════════════════════════════${NC}"
fi

echo ""
echo -e "${BLUE}Test completed at $(date)${NC}"
