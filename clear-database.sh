#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Database Cleanup Script
# Clears all test data from the database for fresh test runs
# ═══════════════════════════════════════════════════════════════════

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

BASE_URL=${BASE_URL:-"http://localhost:8081"}

echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║              DATABASE CLEANUP - CLEAR ALL DATA                ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if application is running
echo -e "${BLUE}Checking application health...${NC}"
HEALTH_CHECK=$(curl -s --max-time 5 "${BASE_URL}/actuator/health" || echo "")
if ! echo "$HEALTH_CHECK" | grep -q '"status":"UP"'; then
    echo -e "${RED}✗ Application is not running!${NC}"
    echo "Please start the application first: ./mvnw spring-boot:run"
    exit 1
fi
echo -e "${GREEN}✓ Application is running${NC}"
echo ""

# Get current counts
echo -e "${YELLOW}Current database state:${NC}"
ORDER_COUNT=$(curl -s "${BASE_URL}/api/orders?page=0&size=1" | jq -r '.totalElements // 0' 2>/dev/null || echo "0")
USER_COUNT=$(curl -s "${BASE_URL}/api/users?page=0&size=1" | jq -r '.totalElements // 0' 2>/dev/null || echo "0")
PAYMENT_COUNT=$(curl -s "${BASE_URL}/api/payments?page=0&size=1" | jq -r '.totalElements // 0' 2>/dev/null || echo "0")

echo "  Orders:      $ORDER_COUNT"
echo "  Users:       $USER_COUNT"
echo "  Payments:    $PAYMENT_COUNT"
echo ""

# Confirm deletion
echo -e "${YELLOW}⚠  WARNING: This will delete ALL data from the database!${NC}"
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo -e "${BLUE}Operation cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}Starting database cleanup...${NC}"

# Stop agents first
echo -e "${BLUE}1. Stopping autonomous agents...${NC}"

# Stop Traffic Agent
TRAFFIC_STOP=$(curl -s -X POST "${BASE_URL}/api/agent/traffic/stop" 2>/dev/null)
if echo "$TRAFFIC_STOP" | grep -q '"success":true'; then
    echo -e "   ${GREEN}✓ Traffic Agent stopped${NC}"
else
    echo -e "   ${YELLOW}⚠ Traffic Agent already stopped${NC}"
fi

# Stop Fulfillment Agent
FULFILL_STOP=$(curl -s -X POST "${BASE_URL}/api/agent/fulfillment/stop" 2>/dev/null)
if echo "$FULFILL_STOP" | grep -q '"success":true'; then
    echo -e "   ${GREEN}✓ Fulfillment Agent stopped${NC}"
else
    echo -e "   ${YELLOW}⚠ Fulfillment Agent already stopped${NC}"
fi

echo ""
echo -e "${BLUE}2. Clearing database tables...${NC}"

# Use PostgreSQL to clear tables
# Note: Adjust credentials if different from default
PGPASSWORD="adspass" psql -h localhost -U adsuser -d adsdb -c "
BEGIN;
TRUNCATE TABLE notifications CASCADE;
TRUNCATE TABLE payments CASCADE;
TRUNCATE TABLE orders CASCADE;
TRUNCATE TABLE users CASCADE;
COMMIT;
" 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "   ${GREEN}✓ Database tables cleared successfully${NC}"
else
    echo -e "   ${YELLOW}⚠ Direct database access failed, trying via API...${NC}"
    
    # Alternative: Delete via API (slower but works if DB access not available)
    echo -e "   ${BLUE}Deleting via API endpoints...${NC}"
    
    # Note: This assumes you have delete endpoints
    # You may need to implement bulk delete endpoints if they don't exist
    echo -e "   ${YELLOW}⚠ API-based deletion not implemented${NC}"
    echo -e "   ${YELLOW}   Please restart the application to reset the database${NC}"
fi

echo ""
echo -e "${BLUE}3. Verifying cleanup...${NC}"

sleep 2

# Get new counts
NEW_ORDER_COUNT=$(curl -s "${BASE_URL}/api/orders?page=0&size=1" | jq -r '.totalElements // 0' 2>/dev/null || echo "0")
NEW_USER_COUNT=$(curl -s "${BASE_URL}/api/users?page=0&size=1" | jq -r '.totalElements // 0' 2>/dev/null || echo "0")
NEW_PAYMENT_COUNT=$(curl -s "${BASE_URL}/api/payments?page=0&size=1" | jq -r '.totalElements // 0' 2>/dev/null || echo "0")

echo "  Orders:      $ORDER_COUNT → $NEW_ORDER_COUNT"
echo "  Users:       $USER_COUNT → $NEW_USER_COUNT"
echo "  Payments:    $PAYMENT_COUNT → $NEW_PAYMENT_COUNT"

echo ""
if [ "$NEW_ORDER_COUNT" -eq 0 ] && [ "$NEW_USER_COUNT" -eq 0 ] && [ "$NEW_PAYMENT_COUNT" -eq 0 ]; then
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✓ DATABASE CLEANUP COMPLETED                     ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}The database is now clean and ready for fresh testing!${NC}"
else
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║              ⚠ CLEANUP PARTIALLY COMPLETED                    ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${YELLOW}Some data may remain. Consider restarting the application.${NC}"
fi

echo ""
echo -e "${CYAN}Note: To reset Fulfillment Agent metrics, restart the application.${NC}"
echo ""
