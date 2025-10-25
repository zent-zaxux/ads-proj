#!/bin/bash

###############################################################################
# Quick Performance Optimization Script
# Applies all optimizations and runs a validation test
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="config_backup_${TIMESTAMP}"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   QUICK PERFORMANCE OPTIMIZATION                           ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Step 1: Backup current configuration
###############################################################################
echo -e "${YELLOW}[1/5]${NC} Creating configuration backups..."
mkdir -p "${BACKUP_DIR}"
cp src/main/resources/application.properties "${BACKUP_DIR}/"
cp compose.yaml "${BACKUP_DIR}/"
echo -e "${GREEN}✓${NC} Backups created in ${BACKUP_DIR}"
echo ""

###############################################################################
# Step 2: Apply optimized application.properties
###############################################################################
echo -e "${YELLOW}[2/5]${NC} Applying application optimizations..."

cat > src/main/resources/application.properties << 'EOF'
# Application Configuration
spring.application.name=ads-proj
server.port=8081

# Database Configuration
spring.datasource.url=jdbc:postgresql://localhost:5432/adsdb
spring.datasource.username=adsuser
spring.datasource.password=adspass
spring.datasource.driver-class-name=org.postgresql.Driver

# JPA/Hibernate Configuration - OPTIMIZED
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=false
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.PostgreSQLDialect
spring.jpa.properties.hibernate.format_sql=false
spring.jpa.properties.hibernate.jdbc.batch_size=25
spring.jpa.properties.hibernate.order_inserts=true
spring.jpa.properties.hibernate.order_updates=true
spring.jpa.properties.hibernate.jdbc.batch_versioned_data=true

# HikariCP Connection Pool - OPTIMIZED
spring.datasource.hikari.maximum-pool-size=20
spring.datasource.hikari.minimum-idle=10
spring.datasource.hikari.connection-timeout=30000
spring.datasource.hikari.idle-timeout=600000
spring.datasource.hikari.max-lifetime=1800000
spring.datasource.hikari.auto-commit=true
spring.datasource.hikari.data-source-properties.cachePrepStmts=true
spring.datasource.hikari.data-source-properties.prepStmtCacheSize=250
spring.datasource.hikari.data-source-properties.prepStmtCacheSqlLimit=2048

# Kafka Configuration
spring.kafka.bootstrap-servers=localhost:9092

# Kafka Consumer Configuration - OPTIMIZED
spring.kafka.consumer.group-id=ads-proj-group
spring.kafka.consumer.auto-offset-reset=earliest
spring.kafka.consumer.key-deserializer=org.apache.kafka.common.serialization.StringDeserializer
spring.kafka.consumer.value-deserializer=org.springframework.kafka.support.serializer.JsonDeserializer
spring.kafka.consumer.properties.spring.json.trusted.packages=*
spring.kafka.consumer.enable-auto-commit=false
spring.kafka.consumer.max-poll-records=100
spring.kafka.consumer.fetch-min-size=1048576
spring.kafka.consumer.fetch-max-wait=500
spring.kafka.listener.ack-mode=batch
spring.kafka.listener.concurrency=5

# Kafka Producer Configuration - OPTIMIZED
spring.kafka.producer.key-serializer=org.apache.kafka.common.serialization.StringSerializer
spring.kafka.producer.value-serializer=org.springframework.kafka.support.serializer.JsonSerializer
spring.kafka.producer.acks=1
spring.kafka.producer.retries=3
spring.kafka.producer.batch-size=32768
spring.kafka.producer.linger-ms=10
spring.kafka.producer.compression-type=lz4
spring.kafka.producer.buffer-memory=67108864

# Kafka Admin Configuration
spring.kafka.admin.auto-create=true

# Custom Kafka Topics
app.kafka.topics.user-events=user-events
app.kafka.topics.order-events=order-events
app.kafka.topics.payment-events=payment-events
app.kafka.topics.notification-events=notification-events
app.kafka.topics.performance-events=performance-events

# Logging Configuration - OPTIMIZED
logging.level.root=INFO
logging.level.com.umu.ads_proj=INFO
logging.level.org.springframework.kafka=WARN
logging.level.org.apache.kafka=WARN
logging.level.org.hibernate.SQL=WARN
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=WARN

# Management and Actuator
management.endpoints.web.exposure.include=health,info,metrics,prometheus
management.endpoint.health.show-details=when-authorized
management.metrics.export.prometheus.enabled=true
EOF

echo -e "${GREEN}✓${NC} Application configuration optimized"
echo ""

###############################################################################
# Step 3: Apply optimized Docker Compose
###############################################################################
echo -e "${YELLOW}[3/5]${NC} Applying Docker infrastructure optimizations..."

cat > compose.yaml << 'EOF'
services:
  zookeeper:
    image: confluentinc/cp-zookeeper:7.4.0
    hostname: zookeeper
    container_name: zookeeper
    ports:
      - "2181:2181"
    environment:
      ZOOKEEPER_CLIENT_PORT: 2181
      ZOOKEEPER_TICK_TIME: 2000
    mem_limit: 512m
    mem_reservation: 256m
    cpus: 1.0

  kafka:
    image: confluentinc/cp-kafka:7.4.0
    hostname: kafka
    container_name: kafka
    depends_on:
      - zookeeper
    ports:
      - "9092:9092"
    environment:
      KAFKA_BROKER_ID: 1
      KAFKA_ZOOKEEPER_CONNECT: 'zookeeper:2181'
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: PLAINTEXT:PLAINTEXT,PLAINTEXT_HOST:PLAINTEXT
      KAFKA_ADVERTISED_LISTENERS: PLAINTEXT://kafka:29092,PLAINTEXT_HOST://localhost:9092
      KAFKA_OFFSETS_TOPIC_REPLICATION_FACTOR: 1
      KAFKA_TRANSACTION_STATE_LOG_MIN_ISR: 1
      KAFKA_TRANSACTION_STATE_LOG_REPLICATION_FACTOR: 1
      KAFKA_AUTO_CREATE_TOPICS_ENABLE: 'true'
      KAFKA_NUM_PARTITIONS: 5
      KAFKA_HEAP_OPTS: "-Xmx1536m -Xms1024m"
      KAFKA_JVM_PERFORMANCE_OPTS: "-XX:+UseG1GC -XX:MaxGCPauseMillis=20 -XX:InitiatingHeapOccupancyPercent=35"
    mem_limit: 2g
    mem_reservation: 1g
    cpus: 2.0

  postgres:
    image: postgres:15-alpine
    container_name: postgres
    ports:
      - "5432:5432"
    environment:
      POSTGRES_DB: adsdb
      POSTGRES_USER: adsuser
      POSTGRES_PASSWORD: adspass
      POSTGRES_INITDB_ARGS: "-c shared_buffers=256MB -c max_connections=100"
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./preload-orders.sql:/docker-entrypoint-initdb.d/preload-orders.sql
    command: 
      - "postgres"
      - "-c"
      - "shared_buffers=256MB"
      - "-c"
      - "max_connections=100"
      - "-c"
      - "work_mem=16MB"
      - "-c"
      - "maintenance_work_mem=128MB"
      - "-c"
      - "effective_cache_size=1GB"
    mem_limit: 1g
    mem_reservation: 512m
    cpus: 1.5

  kafka-ui:
    image: provectuslabs/kafka-ui:latest
    container_name: kafka-ui
    depends_on:
      - kafka
      - zookeeper
    ports:
      - "8080:8080"
    environment:
      KAFKA_CLUSTERS_0_NAME: local
      KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS: kafka:29092
      KAFKA_CLUSTERS_0_ZOOKEEPER: zookeeper:2181
    mem_limit: 512m
    mem_reservation: 256m
    cpus: 0.5

volumes:
  postgres-data:
EOF

echo -e "${GREEN}✓${NC} Docker Compose optimized"
echo ""

###############################################################################
# Step 4: Restart services
###############################################################################
echo -e "${YELLOW}[4/5]${NC} Restarting services with optimized configuration..."

# Stop containers
echo "Stopping containers..."
docker-compose down
sleep 3

# Start optimized containers
echo "Starting optimized containers..."
docker-compose up -d
sleep 15

# Wait for Kafka
echo "Waiting for Kafka..."
for i in {1..30}; do
    if docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092 &>/dev/null; then
        echo -e "${GREEN}✓${NC} Kafka is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗${NC} Kafka failed to start"
        exit 1
    fi
    sleep 2
done

# Rebuild application
echo "Rebuilding application..."
./mvnw clean package -DskipTests

# Restart application
echo "Restarting application..."
pkill -f "ads-proj" 2>/dev/null || true
sleep 2
nohup java -Xmx1g -Xms512m -XX:+UseG1GC -jar target/ads-proj-0.0.1-SNAPSHOT.jar > app.log 2>&1 &
APP_PID=$!

# Wait for application
echo "Waiting for application..."
for i in {1..60}; do
    if curl -s "http://localhost:8081/actuator/health" | grep -q "UP"; then
        echo -e "${GREEN}✓${NC} Application is ready (PID: ${APP_PID})"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}✗${NC} Application failed to start"
        tail -50 app.log
        exit 1
    fi
    sleep 2
done

echo ""

###############################################################################
# Step 5: Validation test
###############################################################################
echo -e "${YELLOW}[5/5]${NC} Running validation test..."

# Create test user
echo "Creating test user..."
USER_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/users" \
    -H "Content-Type: application/json" \
    -d '{"name":"Test User","email":"test@example.com","phoneNumber":"1234567890","address":"123 Test St"}')
USER_ID=$(echo "$USER_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -1)

if [ -z "$USER_ID" ]; then
    echo -e "${RED}✗${NC} Failed to create user"
    exit 1
fi
echo -e "${GREEN}✓${NC} User created: ID=$USER_ID"

# Create test order
echo "Creating test order..."
ORDER_RESPONSE=$(curl -s -X POST "http://localhost:8081/api/orders" \
    -H "Content-Type: application/json" \
    -d "{\"userId\":${USER_ID},\"productName\":\"Test Product\",\"quantity\":1,\"unitPrice\":99.99,\"totalAmount\":99.99}")
ORDER_ID=$(echo "$ORDER_RESPONSE" | grep -o '"id":[0-9]*' | grep -o '[0-9]*' | head -1)

if [ -z "$ORDER_ID" ]; then
    echo -e "${RED}✗${NC} Failed to create order"
    exit 1
fi
echo -e "${GREEN}✓${NC} Order created: ID=$ORDER_ID"

# Wait for Kafka processing
echo "Waiting for Kafka event processing..."
sleep 3

# Check application logs
echo "Recent application logs:"
tail -20 app.log | grep -E "(order|payment|notification)" || echo "No recent event logs found"

echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   OPTIMIZATION COMPLETE                                    ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "✅ Applied Optimizations:"
echo ""
echo "📊 Kafka Consumer:"
echo "   - Concurrency: 5 threads per listener"
echo "   - Batch processing: 100 records max"
echo "   - Fetch size: 1MB"
echo "   - Compression: LZ4"
echo ""
echo "💾 Database:"
echo "   - HikariCP pool: 20 max, 10 min connections"
echo "   - Prepared statement cache: 250 statements"
echo "   - JPA batch operations: 25 records"
echo "   - PostgreSQL shared_buffers: 256MB"
echo ""
echo "🚀 Application:"
echo "   - Logging: INFO level (reduced verbosity)"
echo "   - JVM: -Xmx1g -Xms512m with G1GC"
echo "   - SQL logging: disabled"
echo ""
echo "🐳 Docker:"
echo "   - Kafka: 2GB mem, 2 CPUs, heap 1.5GB"
echo "   - PostgreSQL: 1GB mem, 1.5 CPUs"
echo "   - Resource limits set for all containers"
echo ""
echo "📁 Configuration Backups: ${BACKUP_DIR}/"
echo ""
echo "🎯 Next Steps:"
echo "   1. Run stress tests: ./stress-test.sh"
echo "   2. Monitor application: tail -f app.log"
echo "   3. Check Kafka UI: http://localhost:8080"
echo "   4. View metrics: http://localhost:8081/actuator/prometheus"
echo ""
echo "To restore original configuration:"
echo "   cp ${BACKUP_DIR}/* src/main/resources/"
echo "   cp ${BACKUP_DIR}/compose.yaml ."
echo ""
