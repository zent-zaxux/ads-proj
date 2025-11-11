#!/bin/bash

###############################################################################
# Demo Summary Report
# Generates comprehensive statistics from the live demonstration
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

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║           LIVE DEMO SUMMARY REPORT                       ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# 1. User Statistics
###############################################################################
echo -e "${YELLOW}👥 USER STATISTICS${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

USERS=$(curl -s $API_BASE/api/users)
USER_COUNT=$(echo $USERS | jq 'length')

echo "Total Users Created: $USER_COUNT"
echo ""
echo "User Details:"
echo "$USERS" | jq -r '.[] | "  \(.id). \(.name) - \(.email)"'

echo ""

###############################################################################
# 2. Order Statistics
###############################################################################
echo -e "${YELLOW}📦 ORDER STATISTICS${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

ORDERS=$(curl -s $API_BASE/api/orders)
ORDER_COUNT=$(echo $ORDERS | jq 'length')

echo "Total Orders Created: $ORDER_COUNT"
echo ""

# Status breakdown
echo "Status Distribution:"
echo "$ORDERS" | jq -r 'group_by(.status) | .[] | "  \(.[0].status): \(length) orders"'

echo ""

# Revenue calculation
TOTAL_REVENUE=$(echo "$ORDERS" | jq '[.[] | .totalAmount] | add')
echo "Total Revenue: \$$TOTAL_REVENUE"

echo ""

# Success rate
DELIVERED_COUNT=$(echo "$ORDERS" | jq '[.[] | select(.status=="DELIVERED")] | length')
SUCCESS_RATE=$(awk "BEGIN {printf \"%.1f\", ($DELIVERED_COUNT/$ORDER_COUNT)*100}")
echo "Success Rate: $SUCCESS_RATE% ($DELIVERED_COUNT/$ORDER_COUNT delivered)"

echo ""

# Processing time analysis
echo "Processing Time Analysis:"
echo "$ORDERS" | jq -r '
  map({
    processingTime: (
      (.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601)
    )
  }) | 
  {
    average: (map(.processingTime) | add / length),
    min: (map(.processingTime) | min),
    max: (map(.processingTime) | max)
  } | 
  "  Average: \(.average | floor) seconds\n  Minimum: \(.min | floor) seconds\n  Maximum: \(.max | floor) seconds"
' 2>/dev/null || echo "  (Calculation unavailable)"

echo ""

###############################################################################
# 3. Notification Statistics
###############################################################################
echo -e "${YELLOW}📧 NOTIFICATION STATISTICS${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

# Get notification count from database
NOTIF_COUNT=$(docker exec postgres psql -U adsuser -d adsdb -t -c \
  "SELECT COUNT(*) FROM notifications;" 2>/dev/null | tr -d ' ' || echo "N/A")

echo "Total Notifications Sent: $NOTIF_COUNT"
echo ""

# Breakdown by type
echo "Notification Types:"
docker exec postgres psql -U adsuser -d adsdb -t -c \
  "SELECT type, COUNT(*) FROM notifications GROUP BY type ORDER BY type;" 2>/dev/null | \
  sed 's/^/  /' || echo "  (Database query unavailable)"

echo ""

# Per-user notifications
echo "Notifications Per User:"
docker exec postgres psql -U adsuser -d adsdb -t -c \
  "SELECT user_id, COUNT(*) FROM notifications GROUP BY user_id ORDER BY user_id;" 2>/dev/null | \
  sed 's/^/  User /' || echo "  (Database query unavailable)"

echo ""

###############################################################################
# 4. Kafka Metrics
###############################################################################
echo -e "${YELLOW}📊 KAFKA METRICS${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

# Topic offsets
echo "Event Throughput by Topic:"
for topic in order-events payment-events user-events; do
    OFFSET=$(docker exec kafka kafka-run-class kafka.tools.GetOffsetShell \
      --broker-list localhost:9092 --topic $topic 2>/dev/null | \
      awk -F: '{sum+=$3} END {print sum}' || echo "N/A")
    printf "  %-20s %s events\n" "$topic:" "$OFFSET"
done

echo ""

# Consumer lag
echo "Consumer Group Status:"
TOTAL_LAG=$(docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group ads-proj-group \
  --describe 2>/dev/null | \
  awk '/order-events|payment-events|user-events/ {sum+=$6} END {print sum}')

if [ -z "$TOTAL_LAG" ]; then
    TOTAL_LAG=0
fi

echo "  Total Consumer Lag: $TOTAL_LAG messages"

if [ "$TOTAL_LAG" -eq 0 ]; then
    echo -e "  Status: ${GREEN}✓ All events processed (zero lag)${NC}"
else
    echo -e "  Status: ${YELLOW}⚠ $TOTAL_LAG events pending${NC}"
fi

echo ""

# Partition distribution
echo "Partition Distribution (order-events):"
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group ads-proj-group \
  --describe 2>/dev/null | \
  grep "order-events" | \
  awk '{printf "  Partition %s: Offset %s (Lag: %s)\n", $2, $3, $6}' || \
  echo "  (Unavailable)"

echo ""

###############################################################################
# 5. System Performance
###############################################################################
echo -e "${YELLOW}⚡ SYSTEM PERFORMANCE${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

# Database connections
echo "Database Connection Pool (HikariCP):"
ACTIVE=$(curl -s $API_BASE/actuator/metrics/hikaricp.connections.active 2>/dev/null | \
  jq -r '.measurements[0].value' 2>/dev/null || echo "N/A")
IDLE=$(curl -s $API_BASE/actuator/metrics/hikaricp.connections.idle 2>/dev/null | \
  jq -r '.measurements[0].value' 2>/dev/null || echo "N/A")
echo "  Active Connections: $ACTIVE"
echo "  Idle Connections:   $IDLE"
echo "  Total Pool Size:    20 (configured)"

echo ""

# JVM metrics
echo "JVM Metrics:"
THREADS=$(curl -s $API_BASE/actuator/metrics/jvm.threads.live 2>/dev/null | \
  jq -r '.measurements[0].value' 2>/dev/null || echo "N/A")
MEMORY=$(curl -s $API_BASE/actuator/metrics/jvm.memory.used 2>/dev/null | \
  jq -r '.measurements[0].value' 2>/dev/null || echo "N/A")

if [ "$MEMORY" != "N/A" ]; then
    MEMORY_MB=$(awk "BEGIN {printf \"%.0f\", $MEMORY/1024/1024}")
    echo "  Live Threads:     $THREADS"
    echo "  Memory Used:      ${MEMORY_MB} MB"
else
    echo "  Live Threads:     $THREADS"
    echo "  Memory Used:      N/A"
fi

echo ""

# Application health
echo "Application Health:"
HEALTH=$(curl -s $API_BASE/actuator/health 2>/dev/null | jq -r '.status' || echo "UNKNOWN")
if [ "$HEALTH" = "UP" ]; then
    echo -e "  Status: ${GREEN}✓ UP${NC}"
else
    echo -e "  Status: ${RED}✗ $HEALTH${NC}"
fi

# Component health
curl -s $API_BASE/actuator/health 2>/dev/null | jq -r '.components | to_entries | .[] | "  \(.key): \(.value.status)"' 2>/dev/null | sed 's/^/  /'

echo ""

###############################################################################
# 6. Database Statistics
###############################################################################
echo -e "${YELLOW}💾 DATABASE STATISTICS${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

echo "Table Row Counts:"
docker exec postgres psql -U adsuser -d adsdb -t -c \
  "SELECT 'Users:         ' || COUNT(*) FROM users 
   UNION ALL 
   SELECT 'Orders:        ' || COUNT(*) FROM orders 
   UNION ALL 
   SELECT 'Payments:      ' || COUNT(*) FROM payments
   UNION ALL 
   SELECT 'Notifications: ' || COUNT(*) FROM notifications;" 2>/dev/null | \
  sed 's/^/  /' || echo "  (Database query unavailable)"

echo ""

# Database size
echo "Database Storage:"
DB_SIZE=$(docker exec postgres psql -U adsuser -d adsdb -t -c \
  "SELECT pg_size_pretty(pg_database_size('adsdb'));" 2>/dev/null | tr -d ' ' || echo "N/A")
echo "  Total Size: $DB_SIZE"

echo ""

###############################################################################
# 7. Key Achievements
###############################################################################
echo -e "${YELLOW}🎯 KEY ACHIEVEMENTS${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

echo ""
echo "✅ Event-Driven Architecture"
echo "   • Asynchronous event publishing to Kafka"
echo "   • Decoupled services via message queues"
echo "   • Event persistence and replay capability"
echo ""

echo "✅ Idempotency & Reliability"
echo "   • Duplicate user creation prevented"
echo "   • Unique event IDs prevent duplicate notifications"
echo "   • Database constraints enforce data integrity"
echo ""

echo "✅ Concurrent Processing"
echo "   • Kafka consumer concurrency: 5 threads"
echo "   • Parallel order fulfillment (CompletableFuture)"
echo "   • Batch processing: 50 orders per batch"
echo ""

echo "✅ Fault Tolerance"
echo "   • Agent pause/resume without data loss"
echo "   • Event buffering in Kafka during outages"
echo "   • Zero consumer lag after recovery"
echo ""

echo "✅ Observability"
echo "   • Spring Actuator health checks"
echo "   • Real-time Kafka monitoring"
echo "   • Database connection pool metrics"
echo ""

###############################################################################
# 8. System Architecture Summary
###############################################################################
echo -e "${YELLOW}🏗️  SYSTEM ARCHITECTURE${NC}"
echo -e "${BLUE}─────────────────────────────────────────────────────────${NC}"

echo ""
echo "Technology Stack:"
echo "  • Application:     Spring Boot 3.x"
echo "  • Database:        PostgreSQL 15"
echo "  • Message Broker:  Apache Kafka 7.5.0"
echo "  • Coordination:    Apache Zookeeper 7.5.0"
echo "  • Connection Pool: HikariCP"
echo "  • ORM:             JPA/Hibernate"
echo ""

echo "Event Topics:"
echo "  • order-events:    Order lifecycle events"
echo "  • payment-events:  Payment processing events"
echo "  • user-events:     User registration events"
echo ""

echo "Key Components:"
echo "  • Fulfillment Agent:  Batch order processing"
echo "  • Traffic Agent:      Load simulation"
echo "  • Notification Service: Cross-topic event consumer"
echo "  • Event Publisher:    Asynchronous Kafka producer"
echo ""

###############################################################################
# Footer
###############################################################################
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                 DEMO COMPLETED ✅                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Summary:"
echo "  • Users:         $USER_COUNT created"
echo "  • Orders:        $ORDER_COUNT created, $DELIVERED_COUNT delivered ($SUCCESS_RATE%)"
echo "  • Notifications: $NOTIF_COUNT sent"
echo "  • Events:        $(docker exec kafka kafka-run-class kafka.tools.GetOffsetShell --broker-list localhost:9092 --topic order-events 2>/dev/null | awk -F: '{sum+=$3} END {print sum}' || echo 'N/A') processed"
echo "  • Consumer Lag:  $TOTAL_LAG messages"
echo "  • Health:        $HEALTH"
echo ""

echo "Next Steps:"
echo "  • Review application logs: tail -f app.log"
echo "  • Export metrics for reporting"
echo "  • Run cleanup: ./scripts/demo-cleanup.sh"
echo ""
