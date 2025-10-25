#!/bin/bash

# Quick Start Guide for Concurrent Load Testing
# Run this script to execute a simple load test

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║       CONCURRENT LOAD TESTING - QUICK START                  ║
║                                                               ║
║  This script will help you run your first load test          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}\n"

# Step 1: Check prerequisites
echo -e "${YELLOW}Step 1: Checking prerequisites...${NC}"

# Check if application is running
if curl -s -f http://localhost:8081/actuator/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Application is running on port 8081${NC}"
else
    echo -e "${RED}✗ Application is not running!${NC}"
    echo ""
    echo "Please start the application first:"
    echo "  mvn spring-boot:run"
    echo "  or"
    echo "  java -jar target/ads-proj-0.0.1-SNAPSHOT.jar"
    exit 1
fi

# Check if Kafka is accessible
if kafka-broker-api-versions.sh --bootstrap-server localhost:9092 &>/dev/null; then
    echo -e "${GREEN}✓ Kafka is accessible at localhost:9092${NC}"
else
    echo -e "${YELLOW}⚠ Warning: Cannot verify Kafka connection${NC}"
    echo "  Make sure Kafka is running: docker-compose up -d kafka"
fi

# Check if jq is installed
if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓ jq is installed (for pretty JSON output)${NC}"
else
    echo -e "${YELLOW}⚠ jq not found - JSON output will be plain text${NC}"
fi

echo ""

# Step 2: Select test type
echo -e "${YELLOW}Step 2: Select a test type:${NC}"
echo ""
echo "  1) Quick Test (10-50 users, 1 minute) - Recommended for first run"
echo "  2) Gradual Test (10-100 users, 2 minutes)"
echo "  3) Sustained Test (50 users, 2 minutes)"
echo "  4) Spike Test (10-1000 users, 2 minutes)"
echo "  5) Stress Test (10-500 users, 3 minutes)"
echo "  6) Custom Test (specify parameters)"
echo ""
read -p "Enter choice [1-6] (default: 1): " choice
choice=${choice:-1}

echo ""

case $choice in
    1)
        echo -e "${BLUE}Running Quick Test...${NC}"
        TEST_TYPE="quick"
        DURATION=60
        ;;
    2)
        echo -e "${BLUE}Running Gradual Test...${NC}"
        TEST_TYPE="gradual"
        export MIN_USERS=10
        export MAX_USERS=100
        export DURATION=120
        export RAMP_UP=30
        DURATION=120
        ;;
    3)
        echo -e "${BLUE}Running Sustained Test...${NC}"
        TEST_TYPE="sustained"
        export MIN_USERS=50
        export DURATION=120
        DURATION=120
        ;;
    4)
        echo -e "${BLUE}Running Spike Test...${NC}"
        TEST_TYPE="spike"
        DURATION=120
        ;;
    5)
        echo -e "${BLUE}Running Stress Test...${NC}"
        TEST_TYPE="stress"
        DURATION=180
        ;;
    6)
        echo -e "${BLUE}Custom Test Configuration${NC}"
        read -p "Minimum users: " MIN_USERS
        read -p "Maximum users: " MAX_USERS
        read -p "Duration (seconds): " DURATION
        read -p "Ramp-up time (seconds): " RAMP_UP
        export MIN_USERS MAX_USERS DURATION RAMP_UP
        TEST_TYPE="gradual"
        ;;
    *)
        echo -e "${RED}Invalid choice. Defaulting to Quick Test.${NC}"
        TEST_TYPE="quick"
        DURATION=60
        ;;
esac

echo ""

# Step 3: Start monitoring (optional)
echo -e "${YELLOW}Step 3: Would you like to open a metrics monitor in a new terminal? [y/N]${NC}"
read -p "> " monitor_choice

if [[ "$monitor_choice" =~ ^[Yy]$ ]]; then
    if command -v osascript &> /dev/null; then
        # macOS
        osascript -e 'tell app "Terminal" to do script "cd '"$(pwd)"' && ./monitor-kafka-metrics.sh"' &
        echo -e "${GREEN}✓ Opened monitoring terminal${NC}"
    else
        echo -e "${YELLOW}Please open a new terminal and run: ./monitor-kafka-metrics.sh${NC}"
    fi
    sleep 2
fi

echo ""

# Step 4: Run the test
echo -e "${YELLOW}Step 4: Starting load test...${NC}"
echo ""

export TEST_TYPE
./run-concurrent-load-test.sh

echo ""

# Step 5: Show next steps
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Test completed successfully!${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo ""
echo "1. Review the test metrics in the application logs:"
echo "   - Look for 'LOAD TEST METRICS' sections"
echo "   - Check success rates (should be > 95%)"
echo "   - Review average latency (should be < 500ms)"
echo ""
echo "2. Check Kafka consumer lag:"
echo "   kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups"
echo ""
echo "3. View topic message counts:"
echo "   kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic user-events --from-beginning --max-messages 10"
echo ""
echo "4. Run more comprehensive tests:"
echo "   ./test-all-load-scenarios.sh"
echo ""
echo "5. Read the complete guide:"
echo "   cat CONCURRENT_LOAD_TESTING_GUIDE.md"
echo ""
echo -e "${CYAN}Happy Testing! 🚀${NC}"
