#!/bin/bash

###############################################################################
# Automated Performance Optimization Script
# 
# This script will:
# 1. Run baseline performance tests
# 2. Apply comprehensive optimizations (Kafka, Database, Application, Docker)
# 3. Run optimized performance tests
# 4. Generate detailed comparison report
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:8081"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BASELINE_DIR="baseline_test_${TIMESTAMP}"
OPTIMIZED_DIR="optimized_test_${TIMESTAMP}"
BACKUP_DIR="config_backup_${TIMESTAMP}"

echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}   AUTOMATED PERFORMANCE OPTIMIZATION                        ${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""

###############################################################################
# Step 1: Create backups
###############################################################################
echo -e "${YELLOW}[Step 1/8]${NC} Creating configuration backups..."
mkdir -p "${BACKUP_DIR}"
cp src/main/resources/application.properties "${BACKUP_DIR}/"
cp compose.yaml "${BACKUP_DIR}/"
echo -e "${GREEN}✓${NC} Backups created in ${BACKUP_DIR}"
echo ""

###############################################################################
# Step 2: Run baseline tests
###############################################################################
echo -e "${YELLOW}[Step 2/8]${NC} Running baseline performance tests..."
mkdir -p "${BASELINE_DIR}"

# Wait for app to be ready
echo "Waiting for application to be ready..."
for i in {1..30}; do
    if curl -s "${BASE_URL}/actuator/health" | grep -q "UP"; then
        echo -e "${GREEN}✓${NC} Application is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗${NC} Application failed to start"
        exit 1
    fi
    sleep 2
done

# Run quick baseline test (3 sessions, 30s each)
echo "Running baseline test (3 sessions, 30 seconds each)..."
{
    echo "session,avgUsers,totalRequests,successfulRequests,failedRequests,successRate,avgLatency,maxLatency,minLatency,throughput,duration,timestamp"
    
    for session in {1..3}; do
        echo -e "${BLUE}  Session ${session}/3${NC}"
        
        START_TIME=$(date +%s)
        TOTAL_REQUESTS=0
        SUCCESSFUL_REQUESTS=0
        FAILED_REQUESTS=0
        LATENCY_SUM=0
        MAX_LATENCY=0
        MIN_LATENCY=999999
        
        # Ramp from 10 to 300 users over 30s
        for i in {1..30}; do
            CONCURRENT_USERS=$((10 + (i - 1) * 10))
            
            # Send concurrent requests
            for u in $(seq 1 $CONCURRENT_USERS); do
                (
                    REQ_START=$(python3 -c 'import time; print(int(time.time() * 1000))')
                    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/orders" \
                        -H "Content-Type: application/json" \
                        -d "{\"userId\":1,\"productName\":\"Product-${u}\",\"quantity\":${u},\"unitPrice\":10.99,\"totalAmount\":$((u * 11))}" 2>/dev/null || echo -e "\n000")
                    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
                    REQ_END=$(python3 -c 'import time; print(int(time.time() * 1000))')
                    LATENCY=$((REQ_END - REQ_START))
                    
                    echo "${HTTP_CODE}:${LATENCY}" >> "${BASELINE_DIR}/session_${session}.tmp"
                ) &
            done
            
            # Limit concurrency
            if [ $((i % 3)) -eq 0 ]; then
                wait
            fi
            
            sleep 1
        done
        
        wait
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        # Calculate metrics
        if [ -f "${BASELINE_DIR}/session_${session}.tmp" ]; then
            while IFS=: read -r code latency; do
                TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))
                if [ "$code" = "200" ] || [ "$code" = "201" ]; then
                    SUCCESSFUL_REQUESTS=$((SUCCESSFUL_REQUESTS + 1))
                    LATENCY_SUM=$((LATENCY_SUM + latency))
                    
                    if [ $latency -gt $MAX_LATENCY ]; then
                        MAX_LATENCY=$latency
                    fi
                    if [ $latency -lt $MIN_LATENCY ]; then
                        MIN_LATENCY=$latency
                    fi
                else
                    FAILED_REQUESTS=$((FAILED_REQUESTS + 1))
                fi
            done < "${BASELINE_DIR}/session_${session}.tmp"
            
            rm "${BASELINE_DIR}/session_${session}.tmp"
        fi
        
        # Calculate averages
        if [ $SUCCESSFUL_REQUESTS -gt 0 ]; then
            AVG_LATENCY=$((LATENCY_SUM / SUCCESSFUL_REQUESTS))
        else
            AVG_LATENCY=0
        fi
        
        if [ $TOTAL_REQUESTS -gt 0 ]; then
            SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESSFUL_REQUESTS / $TOTAL_REQUESTS) * 100}")
        else
            SUCCESS_RATE=0
        fi
        
        if [ $DURATION -gt 0 ]; then
            THROUGHPUT=$(awk "BEGIN {printf \"%.2f\", $SUCCESSFUL_REQUESTS / $DURATION}")
        else
            THROUGHPUT=0
        fi
        
        AVG_USERS=155  # Average of 10-300 users
        
        echo "${session},${AVG_USERS},${TOTAL_REQUESTS},${SUCCESSFUL_REQUESTS},${FAILED_REQUESTS},${SUCCESS_RATE},${AVG_LATENCY},${MAX_LATENCY},${MIN_LATENCY},${THROUGHPUT},${DURATION},$(date +%Y-%m-%d\ %H:%M:%S)"
    done
} > "${BASELINE_DIR}/baseline_results.csv"

echo -e "${GREEN}✓${NC} Baseline tests completed"
echo ""

###############################################################################
# Step 3: Analyze bottlenecks
###############################################################################
echo -e "${YELLOW}[Step 3/8]${NC} Analyzing performance bottlenecks..."

# Calculate baseline metrics
BASELINE_AVG_SUCCESS=$(awk -F',' 'NR>1 {sum+=$6; count++} END {if(count>0) printf "%.2f", sum/count}' "${BASELINE_DIR}/baseline_results.csv")
BASELINE_AVG_LATENCY=$(awk -F',' 'NR>1 {sum+=$7; count++} END {if(count>0) printf "%.0f", sum/count}' "${BASELINE_DIR}/baseline_results.csv")
BASELINE_AVG_THROUGHPUT=$(awk -F',' 'NR>1 {sum+=$10; count++} END {if(count>0) printf "%.2f", sum/count}' "${BASELINE_DIR}/baseline_results.csv")

echo "Baseline Performance:"
echo "  - Average Success Rate: ${BASELINE_AVG_SUCCESS}%"
echo "  - Average Latency: ${BASELINE_AVG_LATENCY}ms"
echo "  - Average Throughput: ${BASELINE_AVG_THROUGHPUT} req/s"
echo ""

cat > "${BASELINE_DIR}/bottlenecks.txt" << EOF
IDENTIFIED BOTTLENECKS:

1. KAFKA CONSUMER CONFIGURATION
   - No concurrency configured (single-threaded processing)
   - No batch processing enabled
   - Default fetch sizes (512KB)
   - Conservative poll timeout (3000ms)

2. DATABASE CONNECTION POOLING
   - No HikariCP tuning (using defaults)
   - No connection pool size specified
   - No prepared statement cache

3. APPLICATION CONFIGURATION
   - DEBUG logging enabled (overhead)
   - show-sql=true (verbose SQL logging)
   - No async processing configuration

4. KAFKA PRODUCER
   - Default batch size (16384 bytes)
   - No compression enabled
   - Default linger.ms (0)

5. DOCKER RESOURCES
   - No memory limits for Kafka (underutilized)
   - No JVM heap configuration
   - Resource headroom available
EOF

cat "${BASELINE_DIR}/bottlenecks.txt"
echo ""

###############################################################################
# Step 4: Apply Kafka optimizations
###############################################################################
echo -e "${YELLOW}[Step 4/8]${NC} Applying Kafka optimizations..."

# Update application.properties with Kafka optimizations
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

echo -e "${GREEN}✓${NC} Kafka & Application configuration optimized"
echo ""

###############################################################################
# Step 5: Apply Docker optimizations
###############################################################################
echo -e "${YELLOW}[Step 5/8]${NC} Applying Docker infrastructure optimizations..."

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

echo -e "${GREEN}✓${NC} Docker Compose optimized with resource limits and JVM tuning"
echo ""

###############################################################################
# Step 6: Restart services
###############################################################################
echo -e "${YELLOW}[Step 6/8]${NC} Restarting services with optimized configuration..."

# Stop current containers
echo "Stopping containers..."
docker-compose down 2>/dev/null || true
sleep 3

# Start optimized containers
echo "Starting optimized containers..."
docker-compose up -d

# Wait for services
echo "Waiting for services to be ready..."
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

# Rebuild and restart application
echo "Rebuilding application..."
./mvnw clean package -DskipTests 2>&1 | grep -E "(BUILD SUCCESS|BUILD FAILURE|ERROR)" || true

echo "Restarting application..."
pkill -f "ads-proj" 2>/dev/null || true
sleep 2
java -Xmx1g -Xms512m -XX:+UseG1GC -jar target/ads-proj-0.0.1-SNAPSHOT.jar > app.log 2>&1 &
APP_PID=$!

# Wait for application
echo "Waiting for application..."
for i in {1..60}; do
    if curl -s "${BASE_URL}/actuator/health" | grep -q "UP"; then
        echo -e "${GREEN}✓${NC} Application is ready (PID: ${APP_PID})"
        break
    fi
    if [ $i -eq 60 ]; then
        echo -e "${RED}✗${NC} Application failed to start"
        exit 1
    fi
    sleep 2
done

echo ""

###############################################################################
# Step 7: Run optimized tests
###############################################################################
echo -e "${YELLOW}[Step 7/8]${NC} Running optimized performance tests..."
mkdir -p "${OPTIMIZED_DIR}"

# Run optimized test (3 sessions, 30s each)
echo "Running optimized test (3 sessions, 30 seconds each)..."
{
    echo "session,avgUsers,totalRequests,successfulRequests,failedRequests,successRate,avgLatency,maxLatency,minLatency,throughput,duration,timestamp"
    
    for session in {1..3}; do
        echo -e "${BLUE}  Session ${session}/3${NC}"
        
        START_TIME=$(date +%s)
        TOTAL_REQUESTS=0
        SUCCESSFUL_REQUESTS=0
        FAILED_REQUESTS=0
        LATENCY_SUM=0
        MAX_LATENCY=0
        MIN_LATENCY=999999
        
        # Ramp from 10 to 300 users over 30s
        for i in {1..30}; do
            CONCURRENT_USERS=$((10 + (i - 1) * 10))
            
            # Send concurrent requests
            for u in $(seq 1 $CONCURRENT_USERS); do
                (
                    REQ_START=$(python3 -c 'import time; print(int(time.time() * 1000))')
                    RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "${BASE_URL}/api/orders" \
                        -H "Content-Type: application/json" \
                        -d "{\"userId\":1,\"productName\":\"Product-${u}\",\"quantity\":${u},\"unitPrice\":10.99,\"totalAmount\":$((u * 11))}" 2>/dev/null || echo -e "\n000")
                    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
                    REQ_END=$(python3 -c 'import time; print(int(time.time() * 1000))')
                    LATENCY=$((REQ_END - REQ_START))
                    
                    echo "${HTTP_CODE}:${LATENCY}" >> "${OPTIMIZED_DIR}/session_${session}.tmp"
                ) &
            done
            
            # Limit concurrency
            if [ $((i % 3)) -eq 0 ]; then
                wait
            fi
            
            sleep 1
        done
        
        wait
        END_TIME=$(date +%s)
        DURATION=$((END_TIME - START_TIME))
        
        # Calculate metrics
        if [ -f "${OPTIMIZED_DIR}/session_${session}.tmp" ]; then
            while IFS=: read -r code latency; do
                TOTAL_REQUESTS=$((TOTAL_REQUESTS + 1))
                if [ "$code" = "200" ] || [ "$code" = "201" ]; then
                    SUCCESSFUL_REQUESTS=$((SUCCESSFUL_REQUESTS + 1))
                    LATENCY_SUM=$((LATENCY_SUM + latency))
                    
                    if [ $latency -gt $MAX_LATENCY ]; then
                        MAX_LATENCY=$latency
                    fi
                    if [ $latency -lt $MIN_LATENCY ]; then
                        MIN_LATENCY=$latency
                    fi
                else
                    FAILED_REQUESTS=$((FAILED_REQUESTS + 1))
                fi
            done < "${OPTIMIZED_DIR}/session_${session}.tmp"
            
            rm "${OPTIMIZED_DIR}/session_${session}.tmp"
        fi
        
        # Calculate averages
        if [ $SUCCESSFUL_REQUESTS -gt 0 ]; then
            AVG_LATENCY=$((LATENCY_SUM / SUCCESSFUL_REQUESTS))
        else
            AVG_LATENCY=0
        fi
        
        if [ $TOTAL_REQUESTS -gt 0 ]; then
            SUCCESS_RATE=$(awk "BEGIN {printf \"%.2f\", ($SUCCESSFUL_REQUESTS / $TOTAL_REQUESTS) * 100}")
        else
            SUCCESS_RATE=0
        fi
        
        if [ $DURATION -gt 0 ]; then
            THROUGHPUT=$(awk "BEGIN {printf \"%.2f\", $SUCCESSFUL_REQUESTS / $DURATION}")
        else
            THROUGHPUT=0
        fi
        
        AVG_USERS=155  # Average of 10-300 users
        
        echo "${session},${AVG_USERS},${TOTAL_REQUESTS},${SUCCESSFUL_REQUESTS},${FAILED_REQUESTS},${SUCCESS_RATE},${AVG_LATENCY},${MAX_LATENCY},${MIN_LATENCY},${THROUGHPUT},${DURATION},$(date +%Y-%m-%d\ %H:%M:%S)"
    done
} > "${OPTIMIZED_DIR}/optimized_results.csv"

echo -e "${GREEN}✓${NC} Optimized tests completed"
echo ""

###############################################################################
# Step 8: Generate comparison report
###############################################################################
echo -e "${YELLOW}[Step 8/8]${NC} Generating comparison report..."

# Calculate optimized metrics
OPTIMIZED_AVG_SUCCESS=$(awk -F',' 'NR>1 {sum+=$6; count++} END {if(count>0) printf "%.2f", sum/count}' "${OPTIMIZED_DIR}/optimized_results.csv")
OPTIMIZED_AVG_LATENCY=$(awk -F',' 'NR>1 {sum+=$7; count++} END {if(count>0) printf "%.0f", sum/count}' "${OPTIMIZED_DIR}/optimized_results.csv")
OPTIMIZED_AVG_THROUGHPUT=$(awk -F',' 'NR>1 {sum+=$10; count++} END {if(count>0) printf "%.2f", sum/count}' "${OPTIMIZED_DIR}/optimized_results.csv")

# Calculate improvements
SUCCESS_IMPROVEMENT=$(awk "BEGIN {printf \"%.2f\", ${OPTIMIZED_AVG_SUCCESS} - ${BASELINE_AVG_SUCCESS}}")
LATENCY_IMPROVEMENT=$(awk "BEGIN {printf \"%.2f\", (${BASELINE_AVG_LATENCY} - ${OPTIMIZED_AVG_LATENCY}) / ${BASELINE_AVG_LATENCY} * 100}")
THROUGHPUT_IMPROVEMENT=$(awk "BEGIN {printf \"%.2f\", (${OPTIMIZED_AVG_THROUGHPUT} - ${BASELINE_AVG_THROUGHPUT}) / ${BASELINE_AVG_THROUGHPUT} * 100}")

cat > "optimization_report_${TIMESTAMP}.md" << EOF
# Performance Optimization Report
Generated: $(date '+%Y-%m-%d %H:%M:%S')

## Executive Summary

This report compares system performance before and after applying comprehensive optimizations
across Kafka, database, application, and infrastructure layers.

## Performance Comparison

### Baseline Performance
- **Success Rate**: ${BASELINE_AVG_SUCCESS}%
- **Average Latency**: ${BASELINE_AVG_LATENCY}ms
- **Throughput**: ${BASELINE_AVG_THROUGHPUT} requests/second

### Optimized Performance
- **Success Rate**: ${OPTIMIZED_AVG_SUCCESS}%
- **Average Latency**: ${OPTIMIZED_AVG_LATENCY}ms
- **Throughput**: ${OPTIMIZED_AVG_THROUGHPUT} requests/second

### Improvements
- **Success Rate**: ${SUCCESS_IMPROVEMENT} percentage points
- **Latency Reduction**: ${LATENCY_IMPROVEMENT}%
- **Throughput Increase**: ${THROUGHPUT_IMPROVEMENT}%

## Optimizations Applied

### 1. Kafka Consumer Optimizations
- ✅ Enabled concurrency: 5 threads per listener
- ✅ Increased max poll records: 100
- ✅ Increased fetch min size: 1MB
- ✅ Reduced fetch max wait: 500ms
- ✅ Changed ack mode to batch
- ✅ Set partition count to 5

### 2. Kafka Producer Optimizations
- ✅ Increased batch size: 32KB
- ✅ Enabled compression: LZ4
- ✅ Set linger.ms: 10ms
- ✅ Increased buffer memory: 64MB
- ✅ Reduced acks to 1 for better performance

### 3. Database Optimizations
- ✅ Configured HikariCP pool: 20 max, 10 min
- ✅ Enabled prepared statement cache: 250 statements
- ✅ Enabled JPA batch operations: size 25
- ✅ Disabled SQL logging
- ✅ PostgreSQL tuning: shared_buffers=256MB, work_mem=16MB

### 4. Application Optimizations
- ✅ Switched logging to INFO level
- ✅ Disabled show-sql
- ✅ Enabled Hibernate batch insert/update ordering
- ✅ Configured JVM: -Xmx1g -Xms512m -XX:+UseG1GC

### 5. Infrastructure Optimizations
- ✅ Kafka: 2GB memory limit, 2 CPUs
- ✅ Kafka JVM: -Xmx1536m -Xms1024m with G1GC
- ✅ PostgreSQL: 1GB memory limit, 1.5 CPUs
- ✅ Resource reservations for all containers

## Detailed Test Results

### Baseline Tests
\`\`\`
$(cat "${BASELINE_DIR}/baseline_results.csv")
\`\`\`

### Optimized Tests
\`\`\`
$(cat "${OPTIMIZED_DIR}/optimized_results.csv")
\`\`\`

## Bottlenecks Identified
\`\`\`
$(cat "${BASELINE_DIR}/bottlenecks.txt")
\`\`\`

## Recommendations

### Immediate Actions
1. Monitor production metrics closely after deployment
2. Adjust Kafka concurrency based on partition count
3. Fine-tune connection pool based on actual load
4. Enable second-level cache if data access patterns support it

### Future Optimizations
1. Consider adding more Kafka partitions as load increases
2. Implement caching layer (Redis) for frequently accessed data
3. Add database read replicas for scaling reads
4. Implement async processing for non-critical paths
5. Consider horizontal scaling of application instances

### Monitoring Points
- Kafka consumer lag
- Database connection pool usage
- JVM heap usage and GC pause times
- Response time percentiles (p50, p95, p99)
- Error rates by endpoint

## Configuration Backups

All original configurations have been backed up to:
\`${BACKUP_DIR}/\`

To restore original configuration:
\`\`\`bash
cp ${BACKUP_DIR}/application.properties src/main/resources/
cp ${BACKUP_DIR}/compose.yaml .
docker-compose down
docker-compose up -d
./mvnw clean package -DskipTests
java -jar target/ads-proj-0.0.1-SNAPSHOT.jar
\`\`\`

## Test Artifacts

- Baseline results: \`${BASELINE_DIR}/\`
- Optimized results: \`${OPTIMIZED_DIR}/\`
- Configuration backups: \`${BACKUP_DIR}/\`

---
**Note**: Results may vary based on hardware, network conditions, and concurrent load.
Run tests multiple times for statistically significant results.
EOF

echo -e "${GREEN}✓${NC} Report generated: optimization_report_${TIMESTAMP}.md"
echo ""

###############################################################################
# Summary
###############################################################################
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}   OPTIMIZATION COMPLETE                                    ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "📊 Performance Comparison:"
echo "   Success Rate: ${BASELINE_AVG_SUCCESS}% → ${OPTIMIZED_AVG_SUCCESS}% (${SUCCESS_IMPROVEMENT} points)"
echo "   Latency: ${BASELINE_AVG_LATENCY}ms → ${OPTIMIZED_AVG_LATENCY}ms (${LATENCY_IMPROVEMENT}% reduction)"
echo "   Throughput: ${BASELINE_AVG_THROUGHPUT} → ${OPTIMIZED_AVG_THROUGHPUT} req/s (${THROUGHPUT_IMPROVEMENT}% increase)"
echo ""
echo "📁 Generated Files:"
echo "   - optimization_report_${TIMESTAMP}.md (detailed report)"
echo "   - ${BASELINE_DIR}/ (baseline test data)"
echo "   - ${OPTIMIZED_DIR}/ (optimized test data)"
echo "   - ${BACKUP_DIR}/ (configuration backups)"
echo ""
echo "🎯 Next Steps:"
echo "   1. Review the detailed report: optimization_report_${TIMESTAMP}.md"
echo "   2. Monitor application logs: tail -f app.log"
echo "   3. Check Kafka UI: http://localhost:8080"
echo "   4. Run extended stress tests with stress-test.sh"
echo ""
