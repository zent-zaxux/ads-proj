#!/bin/bash

###############################################################################
# Demo Part 2: Order Creation + Event Flow
# Demonstrates order lifecycle and event-driven workflow
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

# Load user IDs from previous script
if [ -f /tmp/demo_users.env ]; then
    source /tmp/demo_users.env
else
    echo -e "${RED}Error: User IDs not found. Run demo-1-users.sh first${NC}"
    exit 1
fi

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DEMO PART 2: Order Creation + Event Flow            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Instructions
###############################################################################
echo -e "${YELLOW}📋 SETUP INSTRUCTIONS:${NC}"
echo "   You need TWO monitoring terminals:"
echo ""
echo -e "${CYAN}   Terminal 2 - Monitor order-events:${NC}"
echo -e "${CYAN}   docker exec -it kafka kafka-console-consumer \\${NC}"
echo -e "${CYAN}     --bootstrap-server localhost:9092 \\${NC}"
echo -e "${CYAN}     --topic order-events \\${NC}"
echo -e "${CYAN}     --from-beginning \\${NC}"
echo -e "${CYAN}     --property print.timestamp=true${NC}"
echo ""
echo -e "${CYAN}   Terminal 3 - Monitor fulfillment logs:${NC}"
echo -e "${CYAN}   tail -f app.log | grep -E 'FulfillmentAgent|PENDING|PROCESSING|SHIPPED|DELIVERED'${NC}"
echo ""
echo -e "${YELLOW}   Press ENTER when both terminals are ready...${NC}"
read

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Create Order for Alice
###############################################################################
echo -e "${YELLOW}[1/2]${NC} Creating order for Alice (User ID: $USER1_ID)..."
echo ""
echo "Order items:"
echo "  • MacBook Pro: $2,499.00 × 1"
echo "  • Magic Mouse: $79.00 × 1"
echo "  • Total: $2,578.00"
echo ""

ORDER_RESPONSE=$(curl -s -X POST $API_BASE/api/orders \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": $USER1_ID,
    \"items\": [
      {
        \"productName\": \"MacBook Pro\",
        \"quantity\": 1,
        \"price\": 2499.00
      },
      {
        \"productName\": \"Magic Mouse\",
        \"quantity\": 1,
        \"price\": 79.00
      }
    ],
    \"deliveryAddress\": \"123 Main St, Boston, MA\"
  }")

ORDER_ID=$(echo $ORDER_RESPONSE | jq -r '.id')

echo "$ORDER_RESPONSE" | jq '{
  id: .id,
  userId: .userId,
  status: .status,
  totalAmount: .totalAmount,
  createdAt: .createdAt
}'

echo ""
echo -e "${GREEN}✓${NC} Order created with ID: $ORDER_ID"
echo ""
echo -e "${CYAN}👀 CHECK TERMINAL 2: You should see ORDER_CREATED event${NC}"
echo -e "${CYAN}👀 CHECK TERMINAL 3: Fulfillment agent should start processing${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to watch status transitions...${NC}"
read

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Watch Order Status Transitions
###############################################################################
echo -e "${YELLOW}[2/2]${NC} Watching order status transitions (16 seconds)..."
echo ""
echo "Expected flow: PENDING → PROCESSING → PAYMENT_COMPLETED → SHIPPED → DELIVERED"
echo ""

for i in {1..8}; do
    STATUS=$(curl -s $API_BASE/api/orders/$ORDER_ID | jq -r '.status')
    TIMESTAMP=$(date +"%H:%M:%S")
    
    case $STATUS in
        "PENDING")
            echo -e "[$TIMESTAMP] Order $ORDER_ID: ${YELLOW}⏳ $STATUS${NC}"
            ;;
        "PROCESSING")
            echo -e "[$TIMESTAMP] Order $ORDER_ID: ${CYAN}⚙️  $STATUS${NC}"
            ;;
        "PAYMENT_COMPLETED")
            echo -e "[$TIMESTAMP] Order $ORDER_ID: ${BLUE}💳 $STATUS${NC}"
            ;;
        "SHIPPED")
            echo -e "[$TIMESTAMP] Order $ORDER_ID: ${MAGENTA}📦 $STATUS${NC}"
            ;;
        "DELIVERED")
            echo -e "[$TIMESTAMP] Order $ORDER_ID: ${GREEN}✅ $STATUS${NC}"
            ;;
        *)
            echo -e "[$TIMESTAMP] Order $ORDER_ID: $STATUS"
            ;;
    esac
    
    sleep 2
done

echo ""
FINAL_STATUS=$(curl -s $API_BASE/api/orders/$ORDER_ID | jq -r '.status')

if [ "$FINAL_STATUS" = "DELIVERED" ]; then
    echo -e "${GREEN}✓${NC} Order successfully delivered!"
else
    echo -e "${YELLOW}⚠${NC}  Order is in $FINAL_STATUS state (may need more time)"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Show Full Order Details
###############################################################################
echo "Full order details:"
echo ""
curl -s $API_BASE/api/orders/$ORDER_ID | jq '{
  id: .id,
  userId: .userId,
  status: .status,
  totalAmount: .totalAmount,
  items: .items | length,
  createdAt: .createdAt,
  updatedAt: .updatedAt
}'

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${GREEN}✅ PART 2 COMPLETED${NC}"
echo ""
echo "Summary:"
echo "  • Created order #$ORDER_ID for Alice"
echo "  • Published ORDER_CREATED event to Kafka"
echo "  • Fulfillment agent processed order through all states"
echo "  • Final status: $FINAL_STATUS"
echo ""
echo "Events published:"
echo "  • ORDER_CREATED"
echo "  • ORDER_UPDATED (PROCESSING)"
echo "  • PAYMENT_INITIATED"
echo "  • PAYMENT_COMPLETED"
echo "  • ORDER_UPDATED (SHIPPED)"
echo "  • ORDER_UPDATED (DELIVERED)"
echo ""
echo "Next: Run ./scripts/demo-3-notifications.sh"
echo ""

# Save order ID for next scripts
echo "ORDER_ID=$ORDER_ID" > /tmp/demo_order.env
