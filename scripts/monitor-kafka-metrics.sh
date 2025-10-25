#!/bin/bash

# Real-time Kafka Metrics Monitor
# Monitors Kafka topics, consumer lag, and throughput during load tests

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

KAFKA_HOME=${KAFKA_HOME:-"/opt/kafka"}
BOOTSTRAP_SERVER=${BOOTSTRAP_SERVER:-"localhost:9092"}
REFRESH_INTERVAL=${REFRESH_INTERVAL:-5}

# Topics to monitor
TOPICS=("user-events" "order-events" "payment-events" "notification-events" "load-events" "performance-events")

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║           KAFKA METRICS REAL-TIME MONITOR                    ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Function to get topic details
get_topic_details() {
    local topic=$1
    
    # Get partition count and offset information
    kafka-topics.sh --bootstrap-server $BOOTSTRAP_SERVER \
        --describe --topic $topic 2>/dev/null | grep -v "Leader" || echo "Topic not found"
}

# Function to get consumer group lag
get_consumer_lag() {
    kafka-consumer-groups.sh --bootstrap-server $BOOTSTRAP_SERVER \
        --describe --all-groups 2>/dev/null | grep -E "GROUP|TOPIC|ads-proj-group" || echo "No consumer groups"
}

# Function to display metrics
display_metrics() {
    clear
    
    echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           KAFKA METRICS - $(date '+%Y-%m-%d %H:%M:%S')           ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════╝${NC}\n"
    
    # Topic Overview
    echo -e "${YELLOW}Topic Overview:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    
    for topic in "${TOPICS[@]}"; do
        echo -e "${BLUE}Topic: ${topic}${NC}"
        
        # Get message count (latest offset)
        offsets=$(kafka-run-class.sh kafka.tools.GetOffsetShell \
            --broker-list $BOOTSTRAP_SERVER \
            --topic $topic \
            --time -1 2>/dev/null | awk -F: '{sum += $3} END {print sum}')
        
        if [ -n "$offsets" ] && [ "$offsets" != "0" ]; then
            echo "  Messages: $offsets"
        else
            echo "  Messages: 0 (or topic doesn't exist)"
        fi
        echo ""
    done
    
    # Consumer Group Lag
    echo -e "${YELLOW}Consumer Group Lag:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    get_consumer_lag
    echo ""
    
    # System Stats
    echo -e "${YELLOW}System Information:${NC}"
    echo "─────────────────────────────────────────────────────────────"
    echo "Refresh Interval: ${REFRESH_INTERVAL}s"
    echo "Press Ctrl+C to exit"
    echo ""
}

# Main monitoring loop
echo -e "${GREEN}Starting real-time monitoring...${NC}"
echo -e "${YELLOW}Checking Kafka connectivity...${NC}\n"

# Verify Kafka is accessible
if kafka-broker-api-versions.sh --bootstrap-server $BOOTSTRAP_SERVER &>/dev/null; then
    echo -e "${GREEN}✓ Connected to Kafka at $BOOTSTRAP_SERVER${NC}\n"
    sleep 2
else
    echo -e "${RED}✗ Cannot connect to Kafka at $BOOTSTRAP_SERVER${NC}"
    echo "Please ensure Kafka is running and accessible."
    exit 1
fi

# Monitoring loop
while true; do
    display_metrics
    sleep $REFRESH_INTERVAL
done
