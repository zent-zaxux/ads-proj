#!/bin/bash

###############################################################################
# Demo Part 1: User Registration + Events
# Demonstrates user creation and Kafka event publishing
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

API_BASE="http://localhost:8081"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     DEMO PART 1: User Registration + Events             ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Instructions
###############################################################################
echo -e "${YELLOW}📋 SETUP INSTRUCTIONS:${NC}"
echo "   Open a SECOND terminal and run this command to monitor Kafka events:"
echo ""
echo -e "${CYAN}   docker exec -it kafka kafka-console-consumer \\${NC}"
echo -e "${CYAN}     --bootstrap-server localhost:9092 \\${NC}"
echo -e "${CYAN}     --topic user-events \\${NC}"
echo -e "${CYAN}     --from-beginning \\${NC}"
echo -e "${CYAN}     --property print.timestamp=true${NC}"
echo ""
echo -e "${YELLOW}   Press ENTER when Terminal 2 is ready...${NC}"
read

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Create User 1: Alice
###############################################################################
echo -e "${YELLOW}[1/3]${NC} Creating User 1: Alice Johnson..."
echo ""

USER1_RESPONSE=$(curl -s -X POST $API_BASE/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Johnson",
    "email": "alice@demo.com",
    "phoneNumber": "+1-555-0101",
    "address": "123 Main St, Boston, MA"
  }')

USER1_ID=$(echo $USER1_RESPONSE | jq -r '.id')

echo "$USER1_RESPONSE" | jq '{
  id: .id,
  name: .name,
  email: .email,
  phoneNumber: .phoneNumber,
  createdAt: .createdAt
}'

echo ""
echo -e "${GREEN}✓${NC} User 1 created with ID: $USER1_ID"
echo ""
echo -e "${CYAN}👀 CHECK TERMINAL 2: You should see USER_REGISTERED event${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Create User 2: Bob
###############################################################################
echo -e "${YELLOW}[2/3]${NC} Creating User 2: Bob Smith..."
echo ""

USER2_RESPONSE=$(curl -s -X POST $API_BASE/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Bob Smith",
    "email": "bob@demo.com",
    "phoneNumber": "+1-555-0102",
    "address": "456 Oak Ave, Cambridge, MA"
  }')

USER2_ID=$(echo $USER2_RESPONSE | jq -r '.id')

echo "$USER2_RESPONSE" | jq '{
  id: .id,
  name: .name,
  email: .email,
  phoneNumber: .phoneNumber,
  createdAt: .createdAt
}'

echo ""
echo -e "${GREEN}✓${NC} User 2 created with ID: $USER2_ID"
echo ""
echo -e "${CYAN}👀 CHECK TERMINAL 2: You should see another USER_REGISTERED event${NC}"
echo ""
echo -e "${YELLOW}Press ENTER to continue...${NC}"
read

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Test Idempotency: Try to create duplicate user
###############################################################################
echo -e "${YELLOW}[3/3]${NC} Testing Idempotency: Creating duplicate user..."
echo ""

DUPLICATE_RESPONSE=$(curl -s -X POST $API_BASE/api/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Alice Johnson",
    "email": "alice@demo.com",
    "phoneNumber": "+1-555-0101",
    "address": "123 Main St, Boston, MA"
  }')

DUPLICATE_ID=$(echo $DUPLICATE_RESPONSE | jq -r '.id')

echo "$DUPLICATE_RESPONSE" | jq '{
  id: .id,
  name: .name,
  email: .email,
  createdAt: .createdAt
}'

echo ""
if [ "$DUPLICATE_ID" = "$USER1_ID" ]; then
    echo -e "${GREEN}✓${NC} Idempotency working! Returned existing user (same ID: $USER1_ID)"
else
    echo -e "${RED}✗${NC} Warning: New user created instead of returning existing"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${GREEN}✅ PART 1 COMPLETED${NC}"
echo ""
echo "Summary:"
echo "  • Created 2 users (Alice and Bob)"
echo "  • Published 2 USER_REGISTERED events to Kafka"
echo "  • Verified idempotent user creation"
echo ""
echo "User IDs for next demos:"
echo "  User 1 (Alice): $USER1_ID"
echo "  User 2 (Bob):   $USER2_ID"
echo ""
echo "Next: Run ./scripts/demo-2-orders.sh"
echo ""

# Save user IDs for next scripts
echo "USER1_ID=$USER1_ID" > /tmp/demo_users.env
echo "USER2_ID=$USER2_ID" >> /tmp/demo_users.env
