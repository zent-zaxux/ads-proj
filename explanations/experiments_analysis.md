# Performance Experiments Analysis
Generated: 2025-10-24 22:40:35

## Experiment Overview

Testing different configurations of:
- **Kafka Listener Concurrency**: 1, 3, 5, 8, 10 threads
- **HikariCP Maximum Pool Size**: 10, 20, 40 connections
- **Load Pattern**: 10 → 1000 concurrent users over 30s
- **Sessions per Config**: 10 sessions

## Results Summary

| Concurrency | Pool Size | Avg Success Rate | Avg Throughput | Avg Failed | Status |
|-------------|-----------|------------------|----------------|------------|--------|
| 1 | 10 | N/A% | N/A req/s | N/A | ⚠️ Running (0/10) |
| 1 | 20 | 59.02% | 13.14 req/s | 162 | ✓ |
| 1 | 40 | 53.37% | 13.40 req/s | 188 | ✓ |

## Detailed Analysis

### Configuration: Concurrency=1, Pool=10

- **Average Success Rate**: % (min: 0.00%, max: 0.00%)
- **Average Successful Requests**: 
- **Average Failed Requests**: 
- **Average Throughput**:  req/s
- **Stability**: High (variance < 10%)

### Configuration: Concurrency=1, Pool=20

- **Average Success Rate**: 59.02% (min: 53.16%, max: 65.21%)
- **Average Successful Requests**: 232
- **Average Failed Requests**: 162
- **Average Throughput**: 13.14 req/s
- **Stability**: Low (variance ≥ 10%)

### Configuration: Concurrency=1, Pool=40

- **Average Success Rate**: 53.37% (min: 49.76%, max: 58.91%)
- **Average Successful Requests**: 214
- **Average Failed Requests**: 188
- **Average Throughput**: 13.40 req/s
- **Stability**: High (variance < 10%)

## Key Findings

### Best Performing Configuration
- **Configuration**: Concurrency=1, Pool=20
- **Success Rate**: 59.02%

### Observed Bottlenecks

Based on the test results:

1. **Overall Low Success Rate (< 70%)**
   - Even the best configuration shows < 70% success rate
   - Indicates fundamental bottlenecks beyond thread/connection tuning
   - Likely causes:
     - Database query performance (N+1 queries, missing indexes)
     - Synchronous processing blocking request threads
     - Network I/O saturation
     - Kafka producer/consumer lag

2. **High Failure Rate Under Load**
   - Failures increase as concurrent users ramp up
   - Suggests resource exhaustion or timeout issues

3. **Low Throughput (~13 req/s)**
   - Current throughput is very low for modern systems
   - Expected throughput for optimized system: 100-500 req/s

## Recommendations for Further Optimization

### Immediate Actions (High Impact)

1. **Database Query Optimization**
   - Enable SQL query logging temporarily to identify slow queries
   - Check for N+1 query problems
   - Add database indexes on frequently queried columns (user_id, order_id)
   - Consider using @EntityGraph to optimize JPA fetch strategies

2. **Async Processing**
   - Move Kafka event publishing to async (@Async)
   - Use CompletableFuture for non-blocking operations
   - Consider reactive programming (WebFlux) for high concurrency

3. **Kafka Partitioning**
   - Current setup likely uses 1 partition per topic
   - Increase to 5-10 partitions to enable parallel processing
   - Match partition count with consumer concurrency

4. **Connection Pool Validation**
   - Monitor HikariCP metrics for pool exhaustion
   - Check for connection leaks (connections not returned to pool)
   - Enable connection leak detection: `leakDetectionThreshold=2000`

### Medium Priority

5. **Application Profiling**
   - Use JProfiler or VisualVM to identify CPU hotspots
   - Check for thread contention and lock waits
   - Profile memory usage to detect excessive GC

6. **Caching Layer**
   - Add Redis for frequently accessed data
   - Enable second-level Hibernate cache
   - Cache user lookups and reference data

7. **Batch Processing**
   - Enable JDBC batch inserts/updates (already configured)
   - Use batch operations in Kafka consumers
   - Process events in batches instead of one-by-one

### Long-term Improvements

8. **Horizontal Scaling**
   - Deploy multiple application instances behind load balancer
   - Add more Kafka brokers for better throughput
   - Consider database read replicas

9. **Event Sourcing / CQRS**
   - Separate read and write models
   - Use event sourcing for better scalability
   - Implement materialized views for queries

10. **Message Queue Optimization**
   - Consider RabbitMQ or Redis Streams for some use cases
   - Implement backpressure mechanisms
   - Add circuit breakers for external services

## Next Steps

1. **Profile the Application**: Use JProfiler/VisualVM during load test to identify CPU/memory hotspots
2. **Enable SQL Logging**: Temporarily enable `show-sql=true` and `logging.level.org.hibernate.SQL=DEBUG` to identify slow queries
3. **Check Kafka Metrics**: Monitor consumer lag, partition assignment, and message throughput
4. **Review Application Logs**: Look for exceptions, timeouts, or warning messages during load tests
5. **Database Analysis**: Run EXPLAIN ANALYZE on common queries to check execution plans

## Monitoring Queries

```bash
# Check Kafka consumer lag
docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group ads-proj-group

# Check HikariCP metrics
curl -s http://localhost:8081/actuator/metrics/hikaricp.connections.active | jq
curl -s http://localhost:8081/actuator/metrics/hikaricp.connections.idle | jq

# Check database connections
docker exec postgres psql -U adsuser -d adsdb -c "SELECT count(*), state FROM pg_stat_activity GROUP BY state;"

# Check JVM metrics
curl -s http://localhost:8081/actuator/metrics/jvm.memory.used | jq
curl -s http://localhost:8081/actuator/metrics/jvm.threads.live | jq
```

---
*Report generated from experiments/ at Fri Oct 24 22:40:35 CEST 2025*
