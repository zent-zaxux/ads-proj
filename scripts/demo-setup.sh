#!/bin/bash

###############################################################################
# Demo Setup Script
# Prepares the environment for live demonstration
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           DEMO ENVIRONMENT SETUP                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Step 1: Clean existing environment
###############################################################################
echo -e "${YELLOW}[1/5]${NC} Cleaning existing environment..."

# Stop any running Spring Boot processes
if pgrep -f "spring-boot:run" > /dev/null; then
    echo "   Stopping existing Spring Boot processes..."
    pkill -f "spring-boot:run"
    sleep 2
fi

# Stop Docker containers
echo "   Stopping Docker containers..."
docker compose down -v > /dev/null 2>&1 || true

# Clean Docker volumes
echo "   Cleaning Docker volumes..."
docker volume prune -f > /dev/null 2>&1 || true

# Remove old logs and PID files
rm -f app.log app.pid nohup.out

echo -e "${GREEN}✓${NC} Environment cleaned"
echo ""

###############################################################################
# Step 2: Start infrastructure services
###############################################################################
echo -e "${YELLOW}[2/5]${NC} Starting infrastructure services..."

docker compose up -d

# Wait for services to be ready
echo "   Waiting for PostgreSQL..."
for i in {1..30}; do
    if docker exec postgres pg_isready -U adsuser > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo "   Waiting for Kafka..."
for i in {1..30}; do
    if docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1; then
        break
    fi
    sleep 1
done

echo -e "${GREEN}✓${NC} Infrastructure services ready"
echo ""

###############################################################################
# Step 3: Start Spring Boot application in background
###############################################################################
echo -e "${YELLOW}[3/5]${NC} Starting Spring Boot application..."

# Start application in background
nohup ./mvnw spring-boot:run > app.log 2>&1 &
APP_PID=$!
echo $APP_PID > app.pid

echo "   Application PID: $APP_PID"
echo "   Logs: tail -f app.log"

# Wait for application to be ready
echo "   Waiting for application startup..."
for i in {1..60}; do
    if curl -s http://localhost:8081/actuator/health > /dev/null 2>&1; then
        HEALTH_STATUS=$(curl -s http://localhost:8081/actuator/health | jq -r '.status')
        if [ "$HEALTH_STATUS" = "UP" ]; then
            echo -e "${GREEN}✓${NC} Application is UP and healthy"
            break
        fi
    fi
    
    if [ $i -eq 60 ]; then
        echo -e "${RED}✗${NC} Application failed to start within 60 seconds"
        echo "   Check logs: tail -f app.log"
        exit 1
    fi
    
    printf "   Attempt %d/60...\r" $i
    sleep 1
done
echo ""

###############################################################################
# Step 4: Verify Kafka topics
###############################################################################
echo -e "${YELLOW}[4/5]${NC} Verifying Kafka topics..."

TOPICS=$(docker exec kafka kafka-topics \
    --list \
    --bootstrap-server localhost:9092 2>/dev/null)

echo "$TOPICS" | while read topic; do
    if [ ! -z "$topic" ]; then
        echo "   ✓ $topic"
    fi
done

echo ""

###############################################################################
# Step 5: System health check
###############################################################################
echo -e "${YELLOW}[5/5]${NC} Final health check..."

# Check PostgreSQL
PG_STATUS=$(docker exec postgres pg_isready -U adsuser 2>&1 | grep -o "accepting connections" || echo "NOT READY")
if [ "$PG_STATUS" = "accepting connections" ]; then
    echo -e "   PostgreSQL: ${GREEN}✓ UP${NC}"
else
    echo -e "   PostgreSQL: ${RED}✗ DOWN${NC}"
fi

# Check Kafka
KAFKA_STATUS=$(docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092 > /dev/null 2>&1 && echo "UP" || echo "DOWN")
if [ "$KAFKA_STATUS" = "UP" ]; then
    echo -e "   Kafka:      ${GREEN}✓ UP${NC}"
else
    echo -e "   Kafka:      ${RED}✗ DOWN${NC}"
fi

# Check Spring Boot
APP_STATUS=$(curl -s http://localhost:8081/actuator/health | jq -r '.status' 2>/dev/null || echo "DOWN")
if [ "$APP_STATUS" = "UP" ]; then
    echo -e "   Spring Boot: ${GREEN}✓ UP${NC}"
else
    echo -e "   Spring Boot: ${RED}✗ DOWN${NC}"
fi

# Start Fulfillment Agent (IMPORTANT: needed for order processing)
if [ "$APP_STATUS" = "UP" ]; then
    echo ""
    echo "🏭 Starting Fulfillment Agent..."
    AGENT_START=$(curl -s -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1")
    AGENT_STATUS=$(echo $AGENT_START | jq -r '.success' 2>/dev/null || echo "false")
    
    if [ "$AGENT_STATUS" = "true" ]; then
        AGENT_ID=$(echo $AGENT_START | jq -r '.agentId')
        echo -e "   Fulfillment: ${GREEN}✓ STARTED${NC} ($AGENT_ID)"
    else
        echo -e "   Fulfillment: ${YELLOW}⚠ NOT STARTED${NC} (may already be running)"
    fi
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              DEMO ENVIRONMENT READY! 🎬                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo "Next steps:"
echo "  1. Run: ./scripts/demo-1-users.sh          (User Registration)"
echo "  2. Run: ./scripts/demo-2-orders.sh         (Order Creation)"
echo "  3. Run: ./scripts/demo-3-notifications.sh  (Notifications)"
echo "  4. Run: ./scripts/demo-4-traffic.sh        (Traffic Simulation)"
echo "  5. Run: ./scripts/demo-5-fulfillment.sh    (Fulfillment Agent)"
echo "  6. Run: ./scripts/demo-summary.sh          (Summary Report)"
echo ""
echo "Monitor logs: tail -f app.log | grep -E 'ORDER|USER|PAYMENT|NOTIF|Fulfillment'"
echo "Stop app: kill \$(cat app.pid)"
echo ""
