#!/bin/bash

# Quick test to verify fulfillment rate calculation accuracy

set +e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_URL="http://localhost:8081"

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║         FULFILLMENT RATE ACCURACY VERIFICATION TEST           ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Step 1: Clear database
echo -e "${YELLOW}Step 1: Clearing database...${NC}"
docker exec postgres psql -U adsuser -d adsdb -c "
UPDATE orders SET status = 'DELIVERED' WHERE status IN ('PENDING', 'CONFIRMED', 'SHIPPED');
DELETE FROM processed_events;
" > /dev/null 2>&1

sleep 2

# Verify cleanup
PENDING=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status != 'DELIVERED';" | tr -d ' ')
echo -e "${GREEN}✓ Pending orders after cleanup: ${PENDING}${NC}"
echo ""

# Step 2: Get initial counts
echo -e "${YELLOW}Step 2: Getting initial counts...${NC}"
INITIAL_TOTAL=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders;" | tr -d ' ')
INITIAL_DELIVERED=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'DELIVERED';" | tr -d ' ')
INITIAL_PENDING=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'PENDING';" | tr -d ' ')

echo "  Total Orders: ${INITIAL_TOTAL}"
echo "  Delivered: ${INITIAL_DELIVERED}"
echo "  Pending: ${INITIAL_PENDING}"
echo ""

# Step 3: Start fulfillment agent
echo -e "${YELLOW}Step 3: Starting fulfillment agent...${NC}"
curl -s -X POST "${BASE_URL}/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1" > /dev/null
sleep 2
echo -e "${GREEN}✓ Fulfillment agent started${NC}"
echo ""

# Step 4: Create some orders using traffic agent
echo -e "${YELLOW}Step 4: Creating orders (5 ops/sec for 20 seconds)...${NC}"
curl -s -X POST "${BASE_URL}/api/agent/traffic/start?opsPerSecond=5&pattern=STEADY" > /dev/null
echo "  Running traffic agent..."

# Monitor for 20 seconds
for i in {1..4}; do
    sleep 5
    CURRENT_TOTAL=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders;" | tr -d ' ')
    CURRENT_DELIVERED=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'DELIVERED';" | tr -d ' ')
    CURRENT_PENDING=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'PENDING';" | tr -d ' ')
    
    CREATED=$((CURRENT_TOTAL - INITIAL_TOTAL))
    DELIVERED=$((CURRENT_DELIVERED - INITIAL_DELIVERED))
    PENDING=$((CURRENT_PENDING - INITIAL_PENDING))
    
    echo "  [${i}×5s] Created: ${CREATED}, Delivered: ${DELIVERED}, Pending: ${PENDING}"
done

# Stop traffic agent
curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" > /dev/null
echo -e "${GREEN}✓ Traffic agent stopped${NC}"
echo ""

# Step 5: Wait for fulfillment to catch up
echo -e "${YELLOW}Step 5: Waiting 10s for fulfillment to complete...${NC}"
sleep 10

# Step 6: Get final counts
echo -e "${YELLOW}Step 6: Final counts...${NC}"
FINAL_TOTAL=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders;" | tr -d ' ')
FINAL_DELIVERED=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'DELIVERED';" | tr -d ' ')
FINAL_PENDING=$(docker exec postgres psql -U adsuser -d adsdb -t -c "SELECT COUNT(*) FROM orders WHERE status = 'PENDING';" | tr -d ' ')

ORDERS_CREATED=$((FINAL_TOTAL - INITIAL_TOTAL))
ORDERS_FULFILLED=$((FINAL_DELIVERED - INITIAL_DELIVERED))
ORDERS_PENDING=$((FINAL_PENDING - INITIAL_PENDING))

echo "  Total Orders: ${FINAL_TOTAL} (was ${INITIAL_TOTAL})"
echo "  Delivered: ${FINAL_DELIVERED} (was ${INITIAL_DELIVERED})"
echo "  Pending: ${FINAL_PENDING} (was ${INITIAL_PENDING})"
echo ""

# Step 7: Calculate metrics
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                     TEST RESULTS                               ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "  Orders Created:      ${ORDERS_CREATED}"
echo "  Orders Fulfilled:    ${ORDERS_FULFILLED}"
echo "  Orders Pending:      ${ORDERS_PENDING}"

if [ "$ORDERS_CREATED" -gt 0 ]; then
    FULFILLMENT_RATE=$(awk "BEGIN {printf \"%.2f\", ($ORDERS_FULFILLED/$ORDERS_CREATED)*100}")
    echo -e "${GREEN}  Fulfillment Rate:    ${FULFILLMENT_RATE}%${NC}"
    
    # Analysis
    echo ""
    echo -e "${BLUE}Analysis:${NC}"
    if (( $(echo "$FULFILLMENT_RATE > 90" | bc -l) )) && (( $(echo "$FULFILLMENT_RATE <= 110" | bc -l) )); then
        echo -e "  ${GREEN}✓ Fulfillment rate is accurate (~100%)${NC}"
        echo -e "  ${GREEN}✓ Agent is keeping up with order creation${NC}"
    elif (( $(echo "$FULFILLMENT_RATE > 110" | bc -l) )); then
        echo -e "  ${YELLOW}⚠ Fulfillment rate > 110% - may indicate:${NC}"
        echo "    - Agent processing faster than creation (good!)"
        echo "    - Or potential counting issue"
    else
        echo -e "  ${YELLOW}⚠ Fulfillment rate < 90% - agent falling behind${NC}"
        echo "    - Consider increasing agent capacity"
    fi
    
    if [ "$ORDERS_PENDING" -gt 0 ]; then
        echo -e "  ${YELLOW}⚠ ${ORDERS_PENDING} orders still pending (backlog)${NC}"
    else
        echo -e "  ${GREEN}✓ No pending orders (all processed)${NC}"
    fi
else
    echo -e "${RED}✗ No orders were created!${NC}"
fi

echo ""
echo -e "${GREEN}✓ Verification test completed${NC}"
