# Testing Scripts Reference Guide

## 📋 Available Scripts

### 1. **e2e-demo.sh** - End-to-End Demonstration
Complete walkthrough of the Kafka-based distributed system showing all services working together.

#### What it does:
1. ✅ Checks health of all microservices (User, Order, Payment, Notification)
2. ✅ Verifies Kafka infrastructure (Broker, Zookeeper, PostgreSQL)
3. ✅ Creates a test user
4. ✅ Creates an order → Publishes Kafka event
5. ✅ Verifies payment processing via Kafka consumer
6. ✅ Verifies notification delivery via Kafka consumer
7. ✅ Shows Kafka topics and consumer groups
8. ✅ Displays complete data flow visualization

#### Usage:
```bash
./e2e-demo.sh
```

#### Output:
- Step-by-step visualization of the entire flow
- Real order/user/payment data creation
- Kafka event processing verification
- Complete microservices interaction demo

---

### 2. **stress-test.sh** - Automated Stress Testing
Runs 10 progressive load tests with increasing concurrent users (10 → 1000).

#### What it does:
1. ✅ Runs 10 test iterations automatically
2. ✅ Tests with: 10, 50, 100, 200, 300, 500, 700, 800, 900, 1000 users
3. ✅ Captures detailed metrics for each run
4. ✅ Generates CSV report with all results
5. ✅ Saves individual test logs
6. ✅ Provides performance analysis and recommendations

#### Usage:
```bash
./stress-test.sh
```

#### Custom Configuration:
```bash
# Test with custom duration
DURATION=120 ./stress-test.sh

# Test with different URL
BASE_URL=http://localhost:8082 ./stress-test.sh

# Combined
DURATION=90 BASE_URL=http://localhost:8081 ./stress-test.sh
```

#### Output Files:
- **scaling_results.csv** - Complete metrics for all test runs
- **test-logs/[timestamp]/** - Individual test log files

#### CSV Columns:
```
timestamp, run_number, user_count, duration_seconds, 
total_requests, successful_requests, failed_requests, 
success_rate_percent, avg_latency_ms, requests_per_sec,
test_start_time, test_end_time
```

---

## 🚀 Quick Start

### Prerequisites
```bash
# 1. Start infrastructure
docker-compose up -d

# 2. Start application
./mvnw spring-boot:run

# 3. Wait for startup (check logs)
```

### Run End-to-End Demo
```bash
./e2e-demo.sh
```

### Run Stress Tests
```bash
./stress-test.sh
```

---

## 📊 Understanding the Results

### Success Rate
- **>95%**: Excellent performance
- **90-95%**: Good performance
- **<90%**: Needs optimization

### Average Latency
- **<200ms**: Excellent
- **200-500ms**: Acceptable
- **>500ms**: Performance issues

### Throughput
- Requests per second the system can handle
- Higher is better
- Compare across different user loads

---

## 🔍 Analyzing Results

### View CSV in Excel/Google Sheets
```bash
# Open the CSV file
open scaling_results.csv
```

### Command Line Analysis
```bash
# View formatted results
cat scaling_results.csv | column -t -s ','

# Get summary statistics
awk -F',' 'NR>1 {sum+=$10; count++} END {print "Avg Throughput:", sum/count}' scaling_results.csv
```

### Check Kafka Consumer Lag
```bash
docker exec ads-proj-kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --all-groups
```

### View Kafka UI
```
http://localhost:8080
```

---

## 🎯 End-to-End Flow Explained

```
1. User Creation
   ↓
2. Order Creation (POST /api/orders)
   ↓
3. OrderService saves to PostgreSQL
   ↓
4. OrderService publishes OrderCreatedEvent → Kafka topic: 'order-events'
   ↓
   ├─→ 5a. PaymentService consumes event
   │      ├─ Creates payment record
   │      ├─ Processes payment
   │      └─ Updates payment status
   │
   └─→ 5b. NotificationService consumes event
          ├─ Creates notification record
          ├─ Sends email/SMS
          └─ Updates notification status
   ↓
6. All data persisted across microservices
```

---

## 🛠️ Troubleshooting

### Application Not Running
```bash
# Check if app is running
curl http://localhost:8081/api/users/health

# Start application
./mvnw spring-boot:run
```

### Kafka Not Running
```bash
# Check Docker containers
docker ps | grep kafka

# Start Kafka
docker-compose up -d

# Check Kafka logs
docker logs ads-proj-kafka
```

### No Metrics in CSV
The stress test script estimates metrics if the API doesn't return them.
To get accurate metrics, ensure your concurrent load test endpoints return:
- totalRequests / total
- successfulRequests / successful
- failedRequests / failed
- averageLatencyMs / avgLatency
- requestsPerSecond / throughput

---

## 📈 Performance Optimization Tips

1. **Database Connection Pooling**
   - Increase pool size for higher loads
   - Monitor connection usage

2. **Kafka Consumer Tuning**
   - Adjust `max.poll.records`
   - Increase consumer instances
   - Check consumer lag

3. **Application Resources**
   - Increase JVM heap size
   - Tune thread pool sizes
   - Enable caching where appropriate

4. **Async Processing**
   - Use async endpoints for long operations
   - Implement proper error handling
   - Monitor thread pool utilization

---

## 🎨 Visualization Ideas

Create charts showing:
- **Throughput vs User Count** (line/bar chart)
- **Latency vs Load** (line chart)
- **Success Rate Trends** (line chart)
- **Request Distribution** (pie chart: success vs failed)

Example Python snippet:
```python
import pandas as pd
import matplotlib.pyplot as plt

df = pd.read_csv('scaling_results.csv')
plt.plot(df['user_count'], df['requests_per_sec'])
plt.xlabel('Concurrent Users')
plt.ylabel('Throughput (req/s)')
plt.title('System Scalability')
plt.show()
```

---

## 📝 Notes

- Each stress test run includes a 15-second cooldown period
- Logs are saved with timestamps for tracking
- CSV file can be imported into any spreadsheet tool
- Test duration and user counts are configurable
- All services must be healthy before running tests

---

## 🆘 Support

For issues or questions:
1. Check application logs: `tail -f logs/application.log`
2. Check Kafka logs: `docker logs ads-proj-kafka`
3. Verify all services: `docker ps`
4. Review test logs in: `test-logs/[timestamp]/`
