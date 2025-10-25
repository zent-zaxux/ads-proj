# Concurrent Load Testing System

## Overview

This comprehensive load testing system simulates **10-1000 concurrent users** performing random actions and publishing JSON events to Kafka topics. It features:

- ✅ **Gradual load increase** with configurable ramp-up times
- ✅ **Variable message rates** with burst patterns
- ✅ **Random delays and failures** (5% failure rate simulation)
- ✅ **Comprehensive metrics logging** (success rate, latency, throughput)
- ✅ **Real-time monitoring** of Kafka topics and consumer lag
- ✅ **Multiple test scenarios** (gradual, sustained, spike, stress)

## Architecture

### Components

1. **ConcurrentLoadTestRunner** - Core load testing engine
   - Multi-threaded user simulation
   - Kafka event publishing
   - Metrics collection

2. **LoadTestMetrics** - Metrics collection and reporting
   - Per-action success/failure tracking
   - Latency measurement
   - Throughput calculation

3. **ConcurrentLoadTestService** - Spring service wrapper
   - Async test execution
   - Predefined test scenarios

4. **ConcurrentLoadTestController** - REST API
   - HTTP endpoints for test control
   - Parameter validation

## Event Types Generated

The system generates events across multiple Kafka topics:

| Event Type | Topic | Weight | Actions |
|------------|-------|--------|---------|
| User Events | `user-events` | 30% | CREATE_USER |
| Order Events | `order-events` | 35% | CREATE_ORDER, UPDATE_ORDER, CANCEL_ORDER |
| Payment Events | `payment-events` | 20% | PROCESS_PAYMENT |
| Notification Events | `notification-events` | 15% | SEND_NOTIFICATION |

## Load Test Scenarios

### 1. Quick Smoke Test
```bash
./run-concurrent-load-test.sh TEST_TYPE=quick
```
- **Users**: 10-50
- **Duration**: 60 seconds
- **Purpose**: Basic functionality validation

### 2. Gradual Load Test
```bash
./run-concurrent-load-test.sh TEST_TYPE=gradual MIN_USERS=10 MAX_USERS=1000 DURATION=300 RAMP_UP=60
```
- **Users**: 10-1000 (configurable)
- **Duration**: 300 seconds (configurable)
- **Ramp-up**: 60 seconds (configurable)
- **Purpose**: Test system scalability with controlled load increase

### 3. Sustained Load Test
```bash
./run-concurrent-load-test.sh TEST_TYPE=sustained MIN_USERS=200 DURATION=300
```
- **Users**: Constant (configurable)
- **Duration**: Configurable
- **Purpose**: Test system stability under constant load

### 4. Spike Test
```bash
./run-concurrent-load-test.sh TEST_TYPE=spike
```
- **Users**: 10-1000
- **Duration**: 120 seconds
- **Ramp-up**: 5 seconds (fast spike)
- **Purpose**: Test resilience to sudden traffic increases

### 5. Stress Test
```bash
./run-concurrent-load-test.sh TEST_TYPE=stress
```
- **Users**: 10-500
- **Duration**: 180 seconds
- **Ramp-up**: 30 seconds
- **Purpose**: Push system to limits

## REST API Endpoints

### Start Gradual Load Test
```bash
curl -X POST "http://localhost:8081/api/concurrent-load/gradual?minUsers=10&maxUsers=1000&durationSeconds=300&rampUpSeconds=60"
```

### Run Quick Test
```bash
curl -X POST "http://localhost:8081/api/concurrent-load/quick-test"
```

### Run Stress Test
```bash
curl -X POST "http://localhost:8081/api/concurrent-load/stress-test"
```

### Run Spike Test
```bash
curl -X POST "http://localhost:8081/api/concurrent-load/spike-test"
```

### Run Sustained Load Test
```bash
curl -X POST "http://localhost:8081/api/concurrent-load/sustained?users=200&durationSeconds=300"
```

## Usage Examples

### Example 1: Quick Test via Script
```bash
chmod +x run-concurrent-load-test.sh
./run-concurrent-load-test.sh
```

### Example 2: Custom Gradual Test
```bash
MIN_USERS=50 MAX_USERS=500 DURATION=600 RAMP_UP=120 ./run-concurrent-load-test.sh
```

### Example 3: All Scenarios
```bash
chmod +x test-all-load-scenarios.sh
./test-all-load-scenarios.sh
```

### Example 4: Standalone Java Execution
```bash
cd /Users/zent-zaxux/NTU/ads-proj
mvn clean package

java -cp target/ads-proj-0.0.1-SNAPSHOT.jar:target/lib/* \
  com.umu.ads_proj.loadtest.ConcurrentLoadTestRunner \
  localhost:9092 10 1000 300 60
```

**Parameters:**
1. Bootstrap servers (default: localhost:9092)
2. Minimum users (default: 10)
3. Maximum users (default: 1000)
4. Duration in seconds (default: 300)
5. Ramp-up time in seconds (default: 60)

## Real-time Monitoring

### Monitor Kafka Metrics
```bash
chmod +x monitor-kafka-metrics.sh
./monitor-kafka-metrics.sh
```

This displays:
- Topic message counts
- Consumer group lag
- Real-time updates every 5 seconds

### Check Consumer Groups
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 --describe --all-groups
```

### View Application Logs
The load test logs comprehensive metrics every 5 seconds:
- Active concurrent users
- Total requests
- Success/failure rates
- Average latency
- Throughput (req/sec)
- Per-action breakdown

## Metrics Logged

### Real-time Metrics (every 5 seconds)
```
═══════════════════════════════════════════════════════════
LOAD TEST METRICS [2025-10-24T10:30:45]
───────────────────────────────────────────────────────────
Active Users:     450
Total Requests:   12,580
Successful:       11,951 (95.00%)
Failed:           629 (5.00%)
Avg Latency:      125 ms
Throughput:       75.48 req/sec
───────────────────────────────────────────────────────────
Action Breakdown:
  CREATE_USER - Success: 3,585, Failed: 189, Avg Latency: 118 ms
  CREATE_ORDER - Success: 4,183, Failed: 220, Avg Latency: 128 ms
  PROCESS_PAYMENT - Success: 2,390, Failed: 126, Avg Latency: 135 ms
  UPDATE_ORDER - Success: 1,195, Failed: 63, Avg Latency: 122 ms
  SEND_NOTIFICATION - Success: 1,793, Failed: 94, Avg Latency: 115 ms
  CANCEL_ORDER - Success: 598, Failed: 31, Avg Latency: 130 ms
═══════════════════════════════════════════════════════════
```

### Final Summary
At test completion, detailed final metrics are logged with:
- Total request count
- Overall success/failure rates
- Average latency
- Peak concurrent users
- Detailed per-action breakdown

## Load Test Behavior

### User Simulation
Each simulated user:
1. Performs random actions based on weighted distribution
2. Waits 100-2000ms between actions (variable delay)
3. Has 5% chance of simulated failure per action
4. Occasionally sends burst messages (10% chance, 3-5 messages)
5. Continues until test duration expires

### Failure Scenarios
Simulated failures include:
- Random 5% failure rate
- Timeout simulation (500-1000ms delay)
- Network issue simulation
- Proper error logging and metrics

### Message Rate Variation
- **Normal**: 1 message per 100-2000ms
- **Burst**: 3-5 messages with 50ms delay between them
- **Overall**: Variable throughput based on active users

## Performance Expectations

### Target Metrics
- **Success Rate**: > 95%
- **Average Latency**: < 500ms
- **Throughput**: Scales with user count
- **Kafka Lag**: Minimal (< 100 messages)

### Scalability Validation
The system tests:
- ✅ Horizontal scalability (10 to 1000 users)
- ✅ Kafka throughput handling
- ✅ Database connection pooling
- ✅ Application thread management
- ✅ Error recovery and resilience

## Troubleshooting

### Issue: Tests fail to start
**Solution**: Verify services are running:
```bash
# Check application
curl http://localhost:8081/actuator/health

# Check Kafka
kafka-broker-api-versions.sh --bootstrap-server localhost:9092
```

### Issue: High failure rate
**Solution**: 
- Check Kafka broker capacity
- Verify database connection pool size
- Review application logs for errors
- Increase JVM heap size if needed

### Issue: Low throughput
**Solution**:
- Increase Kafka producer batch size
- Tune `linger.ms` configuration
- Check network latency
- Scale Kafka partitions

## Configuration Tuning

### Kafka Producer Settings (in ConcurrentLoadTestRunner)
```java
props.put(ProducerConfig.BATCH_SIZE_CONFIG, 16384);      // Batch size
props.put(ProducerConfig.LINGER_MS_CONFIG, 10);          // Linger time
props.put(ProducerConfig.BUFFER_MEMORY_CONFIG, 33554432); // Buffer memory
props.put(ProducerConfig.ACKS_CONFIG, "1");              // Acknowledgment level
props.put(ProducerConfig.RETRIES_CONFIG, 3);             // Retry count
```

### Application Thread Pool (AsyncConfig)
Ensure adequate thread pool size:
```java
executor.setCorePoolSize(10);
executor.setMaxPoolSize(100);
executor.setQueueCapacity(500);
```

## Integration with Existing System

The load test system integrates with your existing:
- Kafka topics (user-events, order-events, etc.)
- Event consumers (FulfillmentAgent, NotificationService)
- Database (orders, users, payments)
- Monitoring (Prometheus, Grafana if configured)

## Next Steps

1. **Run Quick Test**: Verify basic functionality
   ```bash
   ./run-concurrent-load-test.sh TEST_TYPE=quick
   ```

2. **Run Gradual Test**: Test scalability
   ```bash
   ./run-concurrent-load-test.sh TEST_TYPE=gradual
   ```

3. **Monitor Metrics**: Watch real-time performance
   ```bash
   ./monitor-kafka-metrics.sh
   ```

4. **Analyze Results**: Review logs and metrics
   - Check application logs
   - Review Kafka consumer lag
   - Validate database performance

5. **Tune and Optimize**: Based on results
   - Adjust Kafka configurations
   - Scale application instances
   - Optimize database queries

## Conclusion

This comprehensive load testing system provides a robust framework for validating your application's scalability, throughput, and resilience under various traffic patterns and conditions.
