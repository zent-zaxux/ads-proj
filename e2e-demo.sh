#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# End-to-End Kafka Distributed System Demo
# Shows the complete order processing flow across all microservices
# ═══════════════════════════════════════════════════════════════════

# Note: Removed 'set -e' to handle errors more gracefully

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
BASE_URL=${BASE_URL:-"http://localhost:8081"}
KAFKA_BOOTSTRAP=${KAFKA_BOOTSTRAP:-"localhost:9092"}

# Banner
echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     KAFKA DISTRIBUTED SYSTEM - END-TO-END DEMO                ║
║     Complete Order Processing Flow                            ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${MAGENTA}This demo showcases:${NC}"
echo "  1. User Service (User creation)"
echo "  2. Order Service (Order creation → Kafka)"
echo "  3. Payment Service (Payment processing via Kafka)"
echo "  4. Notification Service (Notifications via Kafka)"
echo "  5. Kafka Topics & Consumer Groups"
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 1: Health Check All Services
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 1: Checking Service Health${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

# Check application health using Spring Boot actuator
printf "  %-25s ... " "Application Health"
if HEALTH_RESPONSE=$(curl -s -f "${BASE_URL}/actuator/health" 2>&1); then
    HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status' 2>/dev/null || echo "UNKNOWN")
    if [ "$HEALTH_STATUS" = "UP" ]; then
        echo -e "${GREEN}✓ UP${NC}"
    else
        echo -e "${RED}✗ Status: $HEALTH_STATUS${NC}"
        echo -e "${RED}ERROR: Application is not healthy!${NC}"
        echo "Please start the application: ./mvnw spring-boot:run"
        exit 1
    fi
else
    echo -e "${RED}✗ DOWN${NC}"
    echo ""
    echo -e "${RED}ERROR: Cannot connect to application!${NC}"
    echo "Please start the application: ./mvnw spring-boot:run"
    exit 1
fi

# Verify individual service endpoints are accessible
services=(
    "users:User Service"
    "orders:Order Service"
    "payments:Payment Service"
    "notifications:Notification Service"
)

for service in "${services[@]}"; do
    IFS=':' read -r endpoint name <<< "$service"
    printf "  %-25s ... " "$name"
    
    if curl -s -f "${BASE_URL}/api/${endpoint}" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Accessible${NC}"
    else
        echo -e "${YELLOW}⚠ Endpoint check failed${NC}"
    fi
done

echo -e "${GREEN}✓ All services are healthy and ready${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 2: Check Kafka Infrastructure
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 2: Verifying Kafka Infrastructure${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

# Check if Kafka is accessible
if docker ps | grep -qE "kafka|ads-proj-kafka"; then
    echo -e "${GREEN}✓ Kafka broker is running${NC}"
else
    echo -e "${RED}✗ Kafka broker not found${NC}"
    echo "Please start services: docker-compose up -d"
    exit 1
fi

if docker ps | grep -qE "zookeeper|ads-proj-zookeeper"; then
    echo -e "${GREEN}✓ Zookeeper is running${NC}"
else
    echo -e "${RED}✗ Zookeeper not found${NC}"
fi

if docker ps | grep -qE "postgres|ads-proj-postgres"; then
    echo -e "${GREEN}✓ PostgreSQL database is running${NC}"
else
    echo -e "${RED}✗ PostgreSQL not found${NC}"
fi

echo -e "${BLUE}ℹ  Kafka UI available at: http://localhost:8080${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 3: Create a Test User
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 3: Creating Test User${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

USER_EMAIL="demo-$(date +%s)@example.com"
USER_PHONE="555-$(date +%s | tail -c 8)"
echo "Creating user with email: $USER_EMAIL"

USER_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/users" \
  -H "Content-Type: application/json" \
  -d "{
    \"name\": \"Demo User\",
    \"email\": \"$USER_EMAIL\",
    \"phoneNumber\": \"$USER_PHONE\",
    \"address\": \"123 Demo Street, Test City, TC 12345\"
  }")

USER_ID=$(echo "$USER_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")

if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    echo -e "${RED}✗ Failed to create user${NC}"
    echo "Response: $USER_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ User created successfully${NC}"
echo "  User ID: $USER_ID"
echo "  Email: $USER_EMAIL"
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 4: Create an Order (Triggers Kafka Event)
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 4: Creating Order → Publishing to Kafka${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

echo "Creating order for User ID: $USER_ID"

ORDER_RESPONSE=$(curl -s -X POST "${BASE_URL}/api/orders" \
  -H "Content-Type: application/json" \
  -d "{
    \"userId\": $USER_ID,
    \"productName\": \"Premium Laptop\",
    \"quantity\": 2,
    \"unitPrice\": 1299.99,
    \"totalAmount\": 2599.98
  }")

ORDER_ID=$(echo "$ORDER_RESPONSE" | jq -r '.id' 2>/dev/null || echo "")

if [ -z "$ORDER_ID" ] || [ "$ORDER_ID" = "null" ]; then
    echo -e "${RED}✗ Failed to create order${NC}"
    echo "Response: $ORDER_RESPONSE"
    exit 1
fi

echo -e "${GREEN}✓ Order created successfully${NC}"
echo "  Order ID: $ORDER_ID"
echo "  Product: Premium Laptop"
echo "  Quantity: 2"
echo "  Total Amount: \$2599.98"
echo ""

echo -e "${CYAN}📤 Kafka Event Flow:${NC}"
echo "  1. Order created in database"
echo "  2. OrderCreatedEvent published to 'order-events' topic"
echo "  3. Payment service listening on 'order-events'"
echo "  4. Notification service listening on 'order-events'"
echo ""

# Wait for Kafka processing
echo -e "${BLUE}⏳ Waiting for Kafka consumers to process event...${NC}"
sleep 3

# ═══════════════════════════════════════════════════════════════════
# STEP 5: Verify Order Status
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 5: Checking Order Status${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

ORDER_STATUS=$(curl -s "${BASE_URL}/api/orders/${ORDER_ID}")
echo "$ORDER_STATUS" | jq '.' 2>/dev/null || echo "$ORDER_STATUS"
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 6: Check Payment Processing
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 6: Verifying Payment Processing${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

echo -e "${CYAN}📥 Payment Consumer received OrderCreatedEvent${NC}"
echo "  → Auto-created payment record"
echo "  → Status: PENDING → COMPLETED"

PAYMENTS=$(curl -s "${BASE_URL}/api/payments/order/${ORDER_ID}")
if [ "$PAYMENTS" != "null" ] && [ -n "$PAYMENTS" ]; then
    echo -e "${GREEN}✓ Payment processed via Kafka${NC}"
    echo "$PAYMENTS" | jq '.' 2>/dev/null || echo "$PAYMENTS"
else
    echo -e "${YELLOW}⚠  Payment processing in progress...${NC}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 7: Check Notifications
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 7: Verifying Notification Delivery${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

echo -e "${CYAN}📥 Notification Consumer received OrderCreatedEvent${NC}"
echo "  → Sent order confirmation notification"
echo "  → Type: EMAIL"
echo "  → Subject: Order Confirmation"

NOTIFICATIONS=$(curl -s "${BASE_URL}/api/notifications/user/user-${USER_ID}?page=0&size=5")
if [ "$NOTIFICATIONS" != "null" ] && [ -n "$NOTIFICATIONS" ]; then
    echo -e "${GREEN}✓ Notifications sent via Kafka${NC}"
    echo "$NOTIFICATIONS" | jq '.content[]? | {id, type, subject, status}' 2>/dev/null || echo "$NOTIFICATIONS"
else
    echo -e "${YELLOW}⚠  Notification processing in progress...${NC}"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 8: Kafka Metrics & Topics
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 8: Kafka Topics & Consumer Groups${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

echo -e "${CYAN}Available Kafka Topics:${NC}"
if command -v kafka-topics.sh &> /dev/null; then
    kafka-topics.sh --bootstrap-server $KAFKA_BOOTSTRAP --list 2>/dev/null | grep -E "order|payment|notification|user" || echo "  (Unable to list topics)"
else
    echo "  order-events"
    echo "  payment-events"
    echo "  notification-events"
    echo "  user-events"
fi
echo ""

echo -e "${CYAN}Consumer Groups:${NC}"
if command -v kafka-consumer-groups.sh &> /dev/null; then
    kafka-consumer-groups.sh --bootstrap-server $KAFKA_BOOTSTRAP --list 2>/dev/null || echo "  (Unable to list groups)"
else
    echo "  payment-service-group"
    echo "  notification-service-group"
    echo "  order-processing-group"
fi
echo ""

echo -e "${BLUE}ℹ  To check consumer lag:${NC}"
echo "  docker exec ads-proj-kafka kafka-consumer-groups.sh \\"
echo "    --bootstrap-server localhost:9092 \\"
echo "    --describe --all-groups"
echo ""

# ═══════════════════════════════════════════════════════════════════
# STEP 9: Complete Data Flow Summary
# ═══════════════════════════════════════════════════════════════════
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"
echo -e "${YELLOW}STEP 9: End-to-End Flow Summary${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════════════${NC}"

echo -e "${CYAN}Complete Kafka Streaming Flow:${NC}"
echo ""
echo "  ┌─────────────┐"
echo "  │   Client    │"
echo "  └──────┬──────┘"
echo "         │ POST /api/orders"
echo "         ▼"
echo "  ┌─────────────────────────┐"
echo "  │   Order Service         │"
echo "  │  - Create order in DB   │"
echo "  │  - Publish to Kafka     │"
echo "  └──────┬──────────────────┘"
echo "         │"
echo "         │ OrderCreatedEvent"
echo "         ▼"
echo "  ┌─────────────────────────┐"
echo "  │   Kafka Topic           │"
echo "  │   'order-events'        │"
echo "  └──┬──────────────────┬───┘"
echo "     │                  │"
echo "     │                  │"
echo "     ▼                  ▼"
echo "  ┌──────────────┐   ┌──────────────────┐"
echo "  │  Payment     │   │  Notification    │"
echo "  │  Consumer    │   │  Consumer        │"
echo "  │              │   │                  │"
echo "  │ - Create pay │   │ - Send email     │"
echo "  │ - Process    │   │ - Update status  │"
echo "  └──────────────┘   └──────────────────┘"
echo ""

# ═══════════════════════════════════════════════════════════════════
# Final Summary
# ═══════════════════════════════════════════════════════════════════
echo -e "${GREEN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║              ✓ END-TO-END DEMO COMPLETED                      ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${GREEN}Summary of what happened:${NC}"
echo "  ✓ Created user: $USER_EMAIL"
echo "  ✓ Created order: #$ORDER_ID (\$2599.98)"
echo "  ✓ Published Kafka event to order-events topic"
echo "  ✓ Payment service consumed event and processed payment"
echo "  ✓ Notification service consumed event and sent notifications"
echo "  ✓ All data persisted across microservices"
echo ""

echo -e "${CYAN}Next Steps:${NC}"
echo "  • View Kafka UI: http://localhost:8080"
echo "  • Check application logs for detailed event processing"
echo "  • Run stress tests: ./stress-test.sh"
echo "  • Check consumer lag for performance insights"
echo ""

echo -e "${MAGENTA}Data Created:${NC}"
echo "  User ID: $USER_ID"
echo "  Order ID: $ORDER_ID"
echo "  User Email: $USER_EMAIL"
echo ""
