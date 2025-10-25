# Concurrent Load Testing System - Quick Reference

## 🚀 Quick Start

```bash
# 1. Make scripts executable
chmod +x *.sh

# 2. Run the interactive quick start
./quick-start-load-test.sh

# 3. Or run a specific test directly
./run-concurrent-load-test.sh TEST_TYPE=quick
```

## 📊 Available Test Types

| Test Type | Users | Duration | Ramp-up | Purpose |
|-----------|-------|----------|---------|---------|
| `quick` | 10-50 | 60s | 10s | Quick validation |
| `gradual` | 10-1000 | 300s | 60s | Scalability test |
| `sustained` | Constant | 300s | 5s | Stability test |
| `spike` | 10-1000 | 120s | 5s | Resilience test |
| `stress` | 10-500 | 180s | 30s | Limit testing |

## 🎯 Key Features

✅ **10-1000 concurrent users** simulation  
✅ **Gradual load increase** with configurable ramp-up  
✅ **Variable message rates** with burst patterns  
✅ **Random delays** (100-2000ms between actions)  
✅ **Simulated failures** (5% failure rate)  
✅ **Real-time metrics** logged every 5 seconds  
✅ **Multiple Kafka topics** (user, order, payment, notification events)  
✅ **Comprehensive reporting** (success rate, latency, throughput)

## 📝 Example Usage

### Example 1: Quick Test
```bash
./run-concurrent-load-test.sh TEST_TYPE=quick
```

### Example 2: Custom Gradual Test
```bash
MIN_USERS=50 MAX_USERS=500 DURATION=600 RAMP_UP=120 \
  ./run-concurrent-load-test.sh
```

### Example 3: All Test Scenarios
```bash
./test-all-load-scenarios.sh
```

### Example 4: REST API
```bash
# Gradual test
curl -X POST "http://localhost:8081/api/concurrent-load/gradual?minUsers=10&maxUsers=1000&durationSeconds=300&rampUpSeconds=60"

# Quick test
curl -X POST "http://localhost:8081/api/concurrent-load/quick-test"

# Stress test
curl -X POST "http://localhost:8081/api/concurrent-load/stress-test"
```

## 📈 Metrics Logged

### Real-time Metrics (every 5 seconds)
- **Active Users**: Current concurrent user count
- **Total Requests**: Cumulative request count
- **Success Rate**: % of successful requests
- **Failure Rate**: % of failed requests
- **Average Latency**: Mean response time (ms)
- **Throughput**: Requests per second
- **Per-Action Breakdown**: Metrics for each event type

### Example Output
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
═══════════════════════════════════════════════════════════
```

## 🔧 Monitoring

### Monitor Kafka Metrics
```bash
./monitor-kafka-metrics.sh
```

### Check Consumer Lag
```bash
kafka-consumer-groups.sh --bootstrap-server localhost:9092 \
  --describe --all-groups
```

### View Topic Messages
```bash
kafka-console-consumer.sh --bootstrap-server localhost:9092 \
  --topic user-events --from-beginning --max-messages 10
```

## 🎬 Complete Demo

```bash
./demo-load-testing.sh
```

This interactive demo shows:
1. Health checks
2. Quick smoke test
3. Gradual load test
4. Kafka topic inspection
5. Consumer lag analysis
6. Available test scenarios
7. Metrics summary

## 📚 Event Distribution

| Event Type | Kafka Topic | Weight | Actions |
|------------|-------------|--------|---------|
| User Events | user-events | 30% | CREATE_USER |
| Order Events | order-events | 35% | CREATE_ORDER, UPDATE_ORDER, CANCEL_ORDER |
| Payment Events | payment-events | 20% | PROCESS_PAYMENT |
| Notification Events | notification-events | 15% | SEND_NOTIFICATION |

## 🎯 Performance Targets

| Metric | Target | Acceptable |
|--------|--------|------------|
| Success Rate | > 99% | > 95% |
| Avg Latency | < 200ms | < 500ms |
| Throughput | Scales linearly | Acceptable degradation |
| Consumer Lag | < 10 messages | < 100 messages |

## 🛠️ Configuration

### Environment Variables
```bash
BASE_URL=http://localhost:8081
MIN_USERS=10
MAX_USERS=1000
DURATION=300
RAMP_UP=60
TEST_TYPE=gradual
```

### Kafka Producer Settings
- **Batch Size**: 16384 bytes
- **Linger MS**: 10ms
- **Buffer Memory**: 32MB
- **Acks**: 1
- **Retries**: 3

## 📖 Full Documentation

For complete details, see: `CONCURRENT_LOAD_TESTING_GUIDE.md`

## 🐛 Troubleshooting

### Application Not Running
```bash
# Check health
curl http://localhost:8081/actuator/health

# Start application
./mvnw spring-boot:run
```

### Kafka Not Accessible
```bash
# Check Kafka
kafka-broker-api-versions.sh --bootstrap-server localhost:9092

# Start Kafka
docker-compose up -d kafka
```

### High Failure Rate
- Check Kafka broker capacity
- Verify database connection pool
- Review application logs
- Increase JVM heap size

## ✅ Success Criteria

A successful load test should show:
- ✅ Success rate > 95%
- ✅ Average latency < 500ms
- ✅ No application crashes
- ✅ Kafka consumer lag < 100 messages
- ✅ Database connections stable
- ✅ Memory usage within limits

## 🚀 Ready to Test!

Start with the quick test to verify everything works:
```bash
./quick-start-load-test.sh
```

Then scale up to full load testing:
```bash
./test-all-load-scenarios.sh
```

Happy Testing! 🎉
