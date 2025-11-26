#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Observability Demonstration Script
# ═══════════════════════════════════════════════════════════════════
#
# This script demonstrates all observability features:
# 1. Spring Actuator health endpoints
# 2. Autonomous agent metrics
# 3. Kafka performance metrics
# 4. System monitoring during operation
#
# Usage: ./observability-demo.sh
#
# ═══════════════════════════════════════════════════════════════════

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:8081"
KAFKA_UI_URL="http://localhost:8080"
DEMO_DURATION=60  # Run demo for 60 seconds

# ═══════════════════════════════════════════════════════════════════
# Utility Functions
# ═══════════════════════════════════════════════════════════════════

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_info() {
    echo -e "${MAGENTA}ℹ${NC} $1"
}

wait_for_user() {
    echo ""
    echo -e "${YELLOW}Press ENTER to continue...${NC}"
    read
}

check_service() {
    local url=$1
    local service_name=$2
    
    if curl -s "$url" > /dev/null 2>&1; then
        print_success "$service_name is running"
        return 0
    else
        print_error "$service_name is not running"
        return 1
    fi
}

# ═══════════════════════════════════════════════════════════════════
# Main Demo Script
# ═══════════════════════════════════════════════════════════════════

print_header "OBSERVABILITY DEMONSTRATION"

echo -e "${BOLD}This demo will showcase:${NC}"
echo "  1. Spring Actuator health monitoring"
echo "  2. Traffic Agent metrics"
echo "  3. Fulfillment Agent metrics"
echo "  4. Real-time system monitoring"
echo "  5. Kafka UI for consumer lag"
echo ""

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 1: Check Prerequisites
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 1: Checking Prerequisites"

print_step "Checking if application is running..."
if ! check_service "$BASE_URL/actuator/health" "Application"; then
    print_error "Application is not running. Please start it with: ./mvnw spring-boot:run"
    exit 1
fi

print_step "Checking if Kafka UI is accessible..."
if ! check_service "$KAFKA_UI_URL" "Kafka UI"; then
    print_warning "Kafka UI is not accessible at $KAFKA_UI_URL"
    print_info "Start Kafka UI with: docker-compose up -d"
fi

echo ""
print_success "Prerequisites check complete!"

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 2: Spring Actuator Health Endpoint
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 2: Spring Actuator Health Monitoring"

print_step "Fetching system health from /actuator/health..."
echo ""

HEALTH_RESPONSE=$(curl -s "$BASE_URL/actuator/health")
echo "$HEALTH_RESPONSE" | jq '.'

echo ""
HEALTH_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.status')

if [ "$HEALTH_STATUS" = "UP" ]; then
    print_success "System status: $HEALTH_STATUS"
    
    # Check individual components
    DB_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.components.db.status // "UNKNOWN"')
    KAFKA_STATUS=$(echo "$HEALTH_RESPONSE" | jq -r '.components.kafka.status // "UNKNOWN"')
    
    echo ""
    print_info "Component Status:"
    echo "  • Database (PostgreSQL): $DB_STATUS"
    echo "  • Kafka: $KAFKA_STATUS"
    echo "  • Ping: UP"
else
    print_warning "System status: $HEALTH_STATUS"
fi

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 3: Database Connection Pool Metrics
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 3: Database Connection Pool Metrics"

print_step "Fetching HikariCP connection pool metrics..."
echo ""

ACTIVE_CONNECTIONS=$(curl -s "$BASE_URL/actuator/metrics/hikaricp.connections.active" | jq -r '.measurements[0].value // 0')
IDLE_CONNECTIONS=$(curl -s "$BASE_URL/actuator/metrics/hikaricp.connections.idle" | jq -r '.measurements[0].value // 0')
TOTAL_CONNECTIONS=$(curl -s "$BASE_URL/actuator/metrics/hikaricp.connections" | jq -r '.measurements[0].value // 0')

print_info "Connection Pool Status:"
echo "  • Active connections: $ACTIVE_CONNECTIONS"
echo "  • Idle connections: $IDLE_CONNECTIONS"
echo "  • Total connections: $TOTAL_CONNECTIONS"
echo "  • Max pool size: 20"

if (( $(echo "$ACTIVE_CONNECTIONS > 15" | bc -l) )); then
    print_warning "High connection usage detected (>75% of pool)"
else
    print_success "Connection pool usage is healthy"
fi

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 4: Start Traffic Agent
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 4: Starting Traffic Agent"

print_step "Starting Traffic Agent (10 ops/sec, STEADY pattern)..."

START_RESPONSE=$(curl -s -X POST "$BASE_URL/api/agent/traffic/start?opsPerSecond=10&pattern=STEADY")
echo "$START_RESPONSE" | jq '.'

if [ $(echo "$START_RESPONSE" | jq -r '.success') = "true" ]; then
    print_success "Traffic Agent started successfully"
else
    print_error "Failed to start Traffic Agent"
    exit 1
fi

echo ""
print_info "Waiting 5 seconds for agent to generate initial traffic..."
sleep 5

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 5: Traffic Agent Metrics
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 5: Traffic Agent Metrics"

print_step "Fetching Traffic Agent status..."
echo ""

TRAFFIC_STATUS=$(curl -s "$BASE_URL/api/agent/traffic/status")
echo "$TRAFFIC_STATUS" | jq '.'

echo ""
AGENT_STATUS=$(echo "$TRAFFIC_STATUS" | jq -r '.status')
TOTAL_OPS=$(echo "$TRAFFIC_STATUS" | jq -r '.totalOperations')
SUCCESS_OPS=$(echo "$TRAFFIC_STATUS" | jq -r '.successfulOperations')
FAILED_OPS=$(echo "$TRAFFIC_STATUS" | jq -r '.failedOperations')
SUCCESS_RATE=$(echo "$TRAFFIC_STATUS" | jq -r '.successRate')

print_info "Traffic Agent Metrics:"
echo "  • Status: $AGENT_STATUS"
echo "  • Total Operations: $TOTAL_OPS"
echo "  • Successful: $SUCCESS_OPS"
echo "  • Failed: $FAILED_OPS"
echo "  • Success Rate: ${SUCCESS_RATE}%"

if (( $(echo "$SUCCESS_RATE > 95" | bc -l) )); then
    print_success "High success rate - system is healthy"
else
    print_warning "Success rate below 95% - investigate issues"
fi

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 6: Start Fulfillment Agent
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 6: Starting Fulfillment Agent"

print_step "Starting Fulfillment Agent (100ms delay, 50 batch size)..."

FULFILL_START=$(curl -s -X POST "$BASE_URL/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1")
echo "$FULFILL_START" | jq '.'

if [ $(echo "$FULFILL_START" | jq -r '.success') = "true" ]; then
    print_success "Fulfillment Agent started successfully"
else
    print_error "Failed to start Fulfillment Agent"
fi

echo ""
print_info "Waiting 10 seconds for agent to process orders..."
sleep 10

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 7: Fulfillment Agent Metrics
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 7: Fulfillment Agent Metrics"

print_step "Fetching Fulfillment Agent status..."
echo ""

FULFILL_STATUS=$(curl -s "$BASE_URL/api/agent/fulfillment/status")
echo "$FULFILL_STATUS" | jq '.'

echo ""
FULFILL_AGENT_STATUS=$(echo "$FULFILL_STATUS" | jq -r '.status')
TOTAL_PROCESSED=$(echo "$FULFILL_STATUS" | jq -r '.totalProcessed // 0')
ORDERS_DELIVERED=$(echo "$FULFILL_STATUS" | jq -r '.ordersDelivered // 0')
BACKLOG=$(echo "$FULFILL_STATUS" | jq -r '.currentBacklog // 0')
AVG_PROCESSING_TIME=$(echo "$FULFILL_STATUS" | jq -r '.avgProcessingTimeMs // 0')

# Calculate fulfillment rate (handle null/empty values)
if [ -n "$TOTAL_PROCESSED" ] && [ "$TOTAL_PROCESSED" != "null" ] && [ "$TOTAL_PROCESSED" -gt 0 ] 2>/dev/null; then
    FULFILLMENT_RATE=$(echo "scale=2; $ORDERS_DELIVERED * 100 / $TOTAL_PROCESSED" | bc)
else
    FULFILLMENT_RATE="0"
    TOTAL_PROCESSED="0"
fi

# Ensure BACKLOG is a valid number
if [ -z "$BACKLOG" ] || [ "$BACKLOG" = "null" ]; then
    BACKLOG="0"
fi

print_info "Fulfillment Agent Metrics:"
echo "  • Status: $FULFILL_AGENT_STATUS"
echo "  • Orders Processed: $TOTAL_PROCESSED"
echo "  • Orders Delivered: $ORDERS_DELIVERED"
echo "  • Fulfillment Rate: ${FULFILLMENT_RATE}%"
echo "  • Current Backlog: $BACKLOG orders"
echo "  • Avg Processing Time: ${AVG_PROCESSING_TIME}ms"

if [ "$BACKLOG" -gt 100 ] 2>/dev/null; then
    print_warning "Backlog is growing - may need to scale"
elif [ "$BACKLOG" -gt 50 ] 2>/dev/null; then
    print_warning "Moderate backlog detected"
else
    print_success "Backlog is under control"
fi

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 8: Real-Time Monitoring
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 8: Real-Time Monitoring"

print_info "Monitoring system for 30 seconds..."
print_info "Press Ctrl+C to stop early"
echo ""

for i in {1..6}; do
    echo -e "${CYAN}── Monitoring Sample $i/6 (every 5 seconds) ──${NC}"
    
    # Get current metrics
    HEALTH=$(curl -s "$BASE_URL/actuator/health" | jq -r '.status')
    TRAFFIC=$(curl -s "$BASE_URL/api/agent/traffic/status")
    FULFILL=$(curl -s "$BASE_URL/api/agent/fulfillment/status")
    
    TOTAL_OPS=$(echo "$TRAFFIC" | jq -r '.totalOperations // 0')
    SUCCESS_RATE=$(echo "$TRAFFIC" | jq -r '.successRate // 0')
    BACKLOG=$(echo "$FULFILL" | jq -r '.currentBacklog // 0')
    PROCESSED=$(echo "$FULFILL" | jq -r '.totalProcessed // 0')
    
    echo "  Health: $HEALTH"
    echo "  Traffic: $TOTAL_OPS operations (${SUCCESS_RATE}% success)"
    echo "  Fulfillment: $PROCESSED processed, $BACKLOG backlog"
    echo ""
    
    if [ $i -lt 6 ]; then
        sleep 5
    fi
done

print_success "Monitoring complete!"

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 9: Performance Events Topic
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 9: Performance Events Topic Examples"

print_info "Autonomous agents publish operational telemetry to the performance-events topic"
echo ""

print_step "Example events published to performance-events topic:"
echo ""

print_info "1. Traffic Agent - START Event:"
cat << 'EOF'
{
  "eventId": "perf-12345-67890",
  "eventType": "AGENT_EVENT",
  "timestamp": "2025-11-25T19:13:32.365Z",
  "serviceSource": "traffic-agent",
  "testType": "TRAFFIC-AGENT-78060103",
  "action": "SYSTEM_HEALTHY",
  "details": "STARTED: Traffic agent started with pattern: STEADY"
}
EOF

echo ""
print_info "2. Traffic Agent - Periodic Metrics (every 10 seconds):"
cat << 'EOF'
{
  "eventId": "perf-12345-67891",
  "eventType": "AGENT_METRICS",
  "timestamp": "2025-11-25T19:14:10.456Z",
  "serviceSource": "traffic-agent",
  "testType": "TRAFFIC-AGENT-78060103",
  "numberOfOperations": 1830,
  "action": "SYSTEM_HEALTHY",
  "details": "Agent TRAFFIC-AGENT-78060103: Total=1830, Success=1274 (69.6%), Failed=556"
}
EOF

echo ""
print_info "3. Fulfillment Agent - START Event:"
cat << 'EOF'
{
  "eventId": "perf-22345-67892",
  "eventType": "AGENT_EVENT",
  "timestamp": "2025-11-25T19:13:44.476Z",
  "serviceSource": "fulfillment-agent",
  "testType": "FULFILLMENT-AGENT-08a0703c",
  "action": "SYSTEM_HEALTHY",
  "details": "STARTED: Fulfillment agent started. Polling every 1s"
}
EOF

echo ""
print_info "4. Fulfillment Agent - Processing Metrics (after each batch):"
cat << 'EOF'
{
  "eventId": "perf-22345-67893",
  "eventType": "FULFILLMENT_METRICS",
  "timestamp": "2025-11-25T19:14:20.123Z",
  "serviceSource": "fulfillment-agent",
  "testType": "FULFILLMENT-AGENT-08a0703c",
  "numberOfOperations": 2151,
  "action": "SYSTEM_HEALTHY",
  "details": "Processed batch: 50 orders, Total: 2151, Delivered: 717, Backlog: 5, Avg Time: 114ms"
}
EOF

echo ""
print_info "5. Agent Pause/Resume Events (for lag testing):"
cat << 'EOF'
{
  "eventId": "perf-12345-67894",
  "eventType": "AGENT_EVENT",
  "timestamp": "2025-11-25T19:15:00.000Z",
  "serviceSource": "traffic-agent",
  "testType": "TRAFFIC-AGENT-78060103",
  "action": "SYSTEM_HEALTHY",
  "details": "PAUSED: Traffic agent paused for lag testing"
}

{
  "eventId": "perf-12345-67895",
  "eventType": "AGENT_EVENT",
  "timestamp": "2025-11-25T19:16:00.000Z",
  "serviceSource": "traffic-agent",
  "testType": "TRAFFIC-AGENT-78060103",
  "action": "SYSTEM_HEALTHY",
  "details": "RESUMED: Traffic agent resumed after 60 seconds"
}
EOF

echo ""
print_step "Key Metrics in Performance Events:"
echo "  • Throughput: numberOfOperations, operations per second"
echo "  • Latency: Average processing time in milliseconds"
echo "  • Success Rate: Percentage of successful operations"
echo "  • Backlog: Current pending orders count"
echo "  • Lifecycle: Agent start, stop, pause, resume events"
echo ""

print_step "These events enable:"
echo "  ✓ Real-time monitoring dashboards"
echo "  ✓ Historical trend analysis"
echo "  ✓ Automated alerting (e.g., high backlog, agent stopped)"
echo "  ✓ Audit trail for troubleshooting"
echo "  ✓ Integration with Prometheus/Grafana"
echo ""

print_info "View actual events in Kafka UI:"
echo "  1. Navigate to: ${KAFKA_UI_URL}"
echo "  2. Click 'Topics' → 'performance-events'"
echo "  3. Click 'Messages' tab"
echo ""

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 10: Kafka UI Instructions
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 10: Kafka UI - Consumer Lag Monitoring"

print_info "Kafka UI provides visual monitoring of consumer groups and message lag"
echo ""

print_step "To access Kafka UI:"
echo ""
echo "  1. Open your browser"
echo "  2. Navigate to: ${KAFKA_UI_URL}"
echo "  3. Click on 'Consumers' tab"
echo "  4. Look for these consumer groups:"
echo "     • ads-proj-group"
echo "     • notification-group"
echo ""

print_step "What to check in Kafka UI:"
echo ""
echo "  • Consumer Lag: Should be 0 or low (<100) for healthy system"
echo "  • Topics: order-events, payment-events, notification-events"
echo "  • Partitions: Check all partitions are being consumed"
echo "  • Message Rate: Observe incoming/outgoing message rates"
echo ""

print_info "Opening Kafka UI in browser (if available)..."

# Try to open browser (macOS)
if command -v open &> /dev/null; then
    open "$KAFKA_UI_URL" 2>/dev/null || true
elif command -v xdg-open &> /dev/null; then
    xdg-open "$KAFKA_UI_URL" 2>/dev/null || true
fi

wait_for_user

# ═══════════════════════════════════════════════════════════════════
# Step 11: Summary and Cleanup
# ═══════════════════════════════════════════════════════════════════

print_header "STEP 11: Final Summary"

print_step "Collecting final metrics..."
echo ""

# Final health check
FINAL_HEALTH=$(curl -s "$BASE_URL/actuator/health" | jq -r '.status')
FINAL_TRAFFIC=$(curl -s "$BASE_URL/api/agent/traffic/status")
FINAL_FULFILL=$(curl -s "$BASE_URL/api/agent/fulfillment/status")

FINAL_TOTAL_OPS=$(echo "$FINAL_TRAFFIC" | jq -r '.totalOperations // 0')
FINAL_SUCCESS_RATE=$(echo "$FINAL_TRAFFIC" | jq -r '.successRate // 0')
FINAL_PROCESSED=$(echo "$FINAL_FULFILL" | jq -r '.totalProcessed // 0')
FINAL_BACKLOG=$(echo "$FINAL_FULFILL" | jq -r '.currentBacklog // 0')

print_info "Final System State:"
echo ""
echo "  ${BOLD}System Health:${NC} $FINAL_HEALTH"
echo ""
echo "  ${BOLD}Traffic Agent:${NC}"
echo "    • Total Operations: $FINAL_TOTAL_OPS"
echo "    • Success Rate: ${FINAL_SUCCESS_RATE}%"
echo ""
echo "  ${BOLD}Fulfillment Agent:${NC}"
echo "    • Orders Processed: $FINAL_PROCESSED"
echo "    • Current Backlog: $FINAL_BACKLOG"
echo ""

print_step "Do you want to stop the agents? (y/n)"
read -r STOP_AGENTS

if [ "$STOP_AGENTS" = "y" ] || [ "$STOP_AGENTS" = "Y" ]; then
    print_step "Stopping Traffic Agent..."
    curl -s -X POST "$BASE_URL/api/agent/traffic/stop" > /dev/null
    print_success "Traffic Agent stopped"
    
    print_step "Stopping Fulfillment Agent..."
    curl -s -X POST "$BASE_URL/api/agent/fulfillment/stop" > /dev/null
    print_success "Fulfillment Agent stopped"
else
    print_info "Agents are still running. Stop manually when done."
fi

echo ""
print_header "OBSERVABILITY DEMO COMPLETE!"

echo -e "${GREEN}${BOLD}✓ Successfully demonstrated:${NC}"
echo "  1. Spring Actuator health monitoring"
echo "  2. Database connection pool metrics"
echo "  3. Traffic Agent real-time metrics"
echo "  4. Fulfillment Agent performance tracking"
echo "  5. Real-time system monitoring"
echo "  6. Performance events topic structure"
echo ""

print_info "Key Observability Endpoints:"
echo "  • Health: ${BASE_URL}/actuator/health"
echo "  • Metrics: ${BASE_URL}/actuator/metrics"
echo "  • Traffic Status: ${BASE_URL}/api/agent/traffic/status"
echo "  • Fulfillment Status: ${BASE_URL}/api/agent/fulfillment/status"
echo "  • Kafka UI: ${KAFKA_UI_URL}"
echo ""

print_info "For your report, you can now:"
echo "  1. Screenshot the JSON responses shown above"
echo "  2. Take screenshots from Kafka UI showing consumer lag"
echo "  3. Reference the metrics collected during this demo"
echo "  4. Use the monitoring timeline as an example"
echo ""

print_success "Demo completed successfully!"
echo ""
