# Phase 4: Load Generation - Quick Reference Guide

## 🚀 Quick Start Commands

### Basic Load Tests

```bash
# User Load (100 users, concurrency 20)
curl -X POST "http://localhost:8081/api/load/users?numberOfUsers=100&concurrencyLevel=20"

# Order Load (50 orders, concurrency 10)
curl -X POST "http://localhost:8081/api/load/orders?numberOfOrders=50&concurrencyLevel=10"

# Payment Load (25 payments, concurrency 5)
curl -X POST "http://localhost:8081/api/load/payments?numberOfPayments=25&concurrencyLevel=5"

# Complete Journey (20 journeys, concurrency 5)
curl -X POST "http://localhost:8081/api/load/journey?numberOfJourneys=20&concurrencyLevel=5"
```

### Mixed Operations Tests

```bash
# Mixed User Operations (200 ops)
curl -X POST "http://localhost:8081/api/load/mixed?operations=200&createRatio=0.4&readRatio=0.5&updateRatio=0.1"

# Mixed Order Operations (100 ops)
curl -X POST "http://localhost:8081/api/load/orders/mixed?operations=100"
```

### Advanced Performance Tests

```bash
# Ramp-Up Test (0 to 100 ops in 5 steps)
curl -X POST "http://localhost:8081/api/load/test/ramp-up?maxOperations=100&rampUpSteps=5"

# Sustained Load (10 ops/sec for 60 seconds)
curl -X POST "http://localhost:8081/api/load/test/sustained?operationsPerSecond=10&durationSeconds=60"

# Spike Test (baseline 10, spike to 200)
curl -X POST "http://localhost:8081/api/load/test/spike?baselineOps=10&spikeOps=200"
```

## 📊 Monitoring & Statistics

```bash
# Check User Statistics
curl -s "http://localhost:8081/api/users?page=0&size=1" | jq '.totalElements'

# Check Order Statistics
curl -s "http://localhost:8081/api/orders/stats" | jq '.'

# Check Payment Statistics
curl -s "http://localhost:8081/api/payments/stats" | jq '.'

# View Application Metrics
curl -s "http://localhost:8081/actuator/metrics" | jq '.names'

# View HTTP Request Metrics
curl -s "http://localhost:8081/actuator/metrics/http.server.requests" | jq '.'
```

## 🔧 Configuration Parameters

### Concurrency Levels
- **Low Load**: 1-5 concurrent threads
- **Medium Load**: 10-20 concurrent threads
- **High Load**: 30-50 concurrent threads
- **Stress Test**: 50+ concurrent threads

### Operation Counts
- **Quick Test**: 10-25 operations
- **Standard Test**: 50-100 operations
- **Load Test**: 100-500 operations
- **Stress Test**: 500+ operations

### Recommended Starting Points

| Test Type | Operations | Concurrency | Expected Duration |
|-----------|-----------|-------------|-------------------|
| User Creation | 100 | 20 | ~5 seconds |
| Order Creation | 50 | 10 | ~3 seconds |
| Payment Processing | 25 | 5 | ~10 seconds |
| Complete Journey | 20 | 5 | ~15 seconds |
| Ramp-Up Test | 100 | varies | ~30 seconds |
| Sustained Load | 600 (10/sec×60s) | 10 | 60 seconds |
| Spike Test | 210 total | varies | ~20 seconds |

## 📈 Expected Performance Metrics

### Throughput Benchmarks
- **User Creation**: 20-30 users/sec
- **Order Creation**: 15-25 orders/sec
- **Mixed Order Operations**: 20-30 ops/sec
- **Payment Processing**: 8-12 payments/sec (slower due to gateway simulation)
- **Complete Journey**: 5-8 journeys/sec (full workflow)

### Response Times
- **User API**: 10-20ms average
- **Order API**: 15-30ms average
- **Payment API**: 50-100ms average (includes processing)

### Success Rates
- **User Operations**: ~100% success
- **Order Operations**: ~100% success
- **Payment Operations**: ~90% success (10% simulated gateway failure)
- **Complete Journey**: ~90% success (due to payment gateway)

## 🧪 Testing Scenarios

### Scenario 1: Light Load Test
```bash
# Test system with light load
curl -X POST "http://localhost:8081/api/load/journey?numberOfJourneys=10&concurrencyLevel=2"
```
**Purpose**: Validate basic functionality

### Scenario 2: Standard Load Test
```bash
# Test system with standard load
curl -X POST "http://localhost:8081/api/load/journey?numberOfJourneys=50&concurrencyLevel=10"
```
**Purpose**: Measure normal operating performance

### Scenario 3: High Load Test
```bash
# Test system with high load
curl -X POST "http://localhost:8081/api/load/journey?numberOfJourneys=100&concurrencyLevel=20"
```
**Purpose**: Identify performance bottlenecks

### Scenario 4: Capacity Planning
```bash
# Ramp-up test to find capacity limits
curl -X POST "http://localhost:8081/api/load/test/ramp-up?maxOperations=500&rampUpSteps=10"
```
**Purpose**: Determine system capacity

### Scenario 5: Stability Test
```bash
# Sustained load over time
curl -X POST "http://localhost:8081/api/load/test/sustained?operationsPerSecond=5&durationSeconds=300"
```
**Purpose**: Test system stability over 5 minutes

### Scenario 6: Peak Traffic Simulation
```bash
# Simulate traffic spike
curl -X POST "http://localhost:8081/api/load/test/spike?baselineOps=20&spikeOps=500"
```
**Purpose**: Test handling of sudden traffic increases

## 🎯 Load Testing Strategy

### Phase 1: Baseline Testing (Week 1)
1. Run light load tests
2. Establish baseline metrics
3. Document response times
4. Identify any errors

### Phase 2: Standard Load Testing (Week 2)
1. Run standard load tests
2. Monitor resource utilization
3. Check database performance
4. Verify Kafka event processing

### Phase 3: Stress Testing (Week 3)
1. Run high load tests
2. Identify bottlenecks
3. Monitor error rates
4. Check system recovery

### Phase 4: Capacity Testing (Week 4)
1. Run ramp-up tests
2. Find breaking points
3. Document maximum capacity
4. Plan for scaling

## 🔍 Monitoring Checklist

### During Load Tests, Monitor:
- [ ] CPU utilization
- [ ] Memory usage
- [ ] Database connections
- [ ] Kafka consumer lag
- [ ] Thread pool usage
- [ ] Response times
- [ ] Error rates
- [ ] Success rates

### Application Logs to Check:
```bash
# View recent load generation logs
tail -100 app.log | grep "load generation"

# View performance event logs
tail -100 app.log | grep "Performance"

# View error logs
tail -100 app.log | grep "ERROR"

# View Kafka event logs
tail -100 app.log | grep "Event published"
```

### Kafka Event Monitoring:
```bash
# Access Kafka UI
open http://localhost:8080

# Topics to monitor:
# - user-events
# - order-events
# - payment-events
# - performance-events
```

## 🛠️ Troubleshooting

### Issue: Load test not completing
**Solution:**
```bash
# Check application logs
tail -50 app.log

# Check if application is running
curl http://localhost:8081/api/load/health

# Restart if needed
pkill -f 'spring-boot:run'
./mvnw spring-boot:run > app.log 2>&1 &
```

### Issue: High failure rates
**Possible Causes:**
1. Database connection pool exhausted
2. Thread pool exhausted
3. Network timeouts
4. Kafka producer buffer full

**Solutions:**
- Reduce concurrency level
- Increase database connection pool size
- Increase thread pool size
- Add delays between operations

### Issue: Slow performance
**Debug Steps:**
```bash
# Check metrics
curl http://localhost:8081/actuator/metrics/http.server.requests | jq '.'

# Check database
# Monitor PostgreSQL connections and queries

# Check Kafka
# Monitor Kafka UI for lag and throughput
```

### Issue: Out of memory errors
**Solutions:**
- Reduce batch sizes
- Reduce concurrency
- Increase JVM heap size: `./mvnw spring-boot:run -Dspring-boot.run.jvmArguments="-Xmx2g"`

## 📋 Pre-Test Checklist

Before running load tests:
- [ ] Application is running (`curl http://localhost:8081/api/load/health`)
- [ ] Docker services are running (`docker ps`)
- [ ] Database is accessible
- [ ] Kafka is running and healthy
- [ ] Kafka UI is accessible (http://localhost:8080)
- [ ] Previous load tests have completed
- [ ] Sufficient disk space available
- [ ] Monitoring tools are ready

## 🎨 Custom Test Scripts

### Full System Test
```bash
#!/bin/bash
echo "Running Full System Load Test"

# User load
curl -X POST "http://localhost:8081/api/load/users?numberOfUsers=50&concurrencyLevel=10"
sleep 5

# Order load
curl -X POST "http://localhost:8081/api/load/orders?numberOfOrders=50&concurrencyLevel=10"
sleep 5

# Payment load
curl -X POST "http://localhost:8081/api/load/payments?numberOfPayments=25&concurrencyLevel=5"
sleep 15

# Complete journey
curl -X POST "http://localhost:8081/api/load/journey?numberOfJourneys=30&concurrencyLevel=5"
sleep 20

# Check results
echo "User Count:"
curl -s "http://localhost:8081/api/users?page=0&size=1" | jq '.totalElements'

echo "Order Stats:"
curl -s "http://localhost:8081/api/orders/stats" | jq '.'

echo "Payment Stats:"
curl -s "http://localhost:8081/api/payments/stats" | jq '.'
```

### Performance Benchmark Script
```bash
#!/bin/bash
echo "Running Performance Benchmarks"

# Quick baseline
echo "1. Baseline test..."
curl -X POST "http://localhost:8081/api/load/journey?numberOfJourneys=10&concurrencyLevel=2"
sleep 12

# Medium load
echo "2. Medium load test..."
curl -X POST "http://localhost:8081/api/load/journey?numberOfJourneys=25&concurrencyLevel=5"
sleep 20

# High load
echo "3. High load test..."
curl -X POST "http://localhost:8081/api/load/journey?numberOfJourneys=50&concurrencyLevel=10"
sleep 30

echo "Benchmark complete!"
```

## 📚 API Reference

### Load Generation Endpoints

| Endpoint | Method | Parameters | Description |
|----------|--------|------------|-------------|
| `/api/load/health` | GET | - | Health check |
| `/api/load/users` | POST | numberOfUsers, concurrencyLevel | User creation load |
| `/api/load/mixed` | POST | operations, createRatio, readRatio, updateRatio | Mixed user operations |
| `/api/load/orders` | POST | numberOfOrders, concurrencyLevel | Order creation load |
| `/api/load/orders/mixed` | POST | operations | Mixed order operations |
| `/api/load/payments` | POST | numberOfPayments, concurrencyLevel | Payment processing load |
| `/api/load/journey` | POST | numberOfJourneys, concurrencyLevel | Complete user journey |
| `/api/load/test/ramp-up` | POST | maxOperations, rampUpSteps | Ramp-up load test |
| `/api/load/test/sustained` | POST | operationsPerSecond, durationSeconds | Sustained load test |
| `/api/load/test/spike` | POST | baselineOps, spikeOps | Spike load test |
| `/api/load/quick-test` | POST | - | Quick test (50 users) |

### Response Format
All load generation endpoints return:
```json
{
  "status": "started",
  "message": "Load generation started asynchronously",
  // ... additional parameters
}
```

Tests run asynchronously - check logs for completion status.

## 🎓 Best Practices

1. **Start Small**: Begin with low numbers and increase gradually
2. **Monitor Resources**: Watch CPU, memory, and database during tests
3. **Use Realistic Data**: Random but realistic product names, prices, etc.
4. **Check Kafka**: Monitor Kafka UI for event processing
5. **Review Logs**: Always check logs after tests complete
6. **Measure Baselines**: Establish baseline performance before optimizations
7. **Test Incrementally**: Don't jump from 10 to 10,000 operations
8. **Document Results**: Keep records of test parameters and results
9. **Clean Data**: Periodically clean test data from database
10. **Plan Capacity**: Use results to plan infrastructure scaling

---

**Phase 4 Quick Reference - Ready to Use! 🚀**
