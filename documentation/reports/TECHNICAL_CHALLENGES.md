# Technical Challenges

## Challenge 1: Synchronous to Asynchronous Kafka Publishing

Initially, the system used synchronous Kafka publishing to guarantee message delivery and simplify debugging. Each API call waited for a broker acknowledgment before returning, ensuring that all events (e.g., order-created, payment-initiated) safely persisted. However, this approach introduced blocking latency, limiting scalability under high concurrency as threads were held waiting for acknowledgments. This issue has since been resolved by migrating to asynchronous Kafka publishing, enabling the application to continue processing while Kafka acknowledgments are handled in the background. The change significantly reduced request latency from 250ms to 8ms (31× improvement), improved throughput from approximately 4 requests per second to 18.97 requests per second (4.7× improvement), and stabilized performance during high-load scenarios without compromising delivery reliability through the continued use of `acks=all` and idempotency guarantees.

## Challenge 2: Insufficient Observability Tools

Early iterations of the system lacked sufficient observability tools, making it challenging to identify where performance degradation occurred. Metrics such as Kafka Consumer Lag, thread pool saturation, and database connection pool utilization were not initially exposed. The system was subsequently enhanced with Spring Boot Actuator endpoints (`/actuator/health`, `/actuator/metrics`), Kafka UI integration for real-time consumer lag monitoring, and custom agent status APIs (`/api/agent/traffic/status`, `/api/agent/fulfillment/status`) that expose throughput, latency, and fulfillment rates. This transition from reactive troubleshooting to proactive monitoring was instrumental in identifying and resolving the performance bottlenecks described below, enabling operators to track HikariCP connection pool health, thread pool saturation, and Kafka consumer lag in real-time.

## Challenge 3: Kafka Consumer Lag

An early challenge involved Kafka consumer lag, where message backlogs accumulated faster than consumers could process events during burst traffic, particularly when the TrafficAgent generated high-volume order streams while the FulfillmentAgent processed only 2.5 orders per second. Profiling revealed excessive simulated warehouse delays (2000ms per order), small batch sizes (5 orders) causing frequent database roundtrips, and infrequent polling intervals (5 seconds). Performance tuning reduced processing delay from 2000ms to 100ms through configurable parameters, increased batch size from 5 to 50 orders using JPA `saveAll()` batch operations, and shortened polling intervals from 5 seconds to 1 second for more responsive consumption. These optimizations improved throughput by 8.8×, allowing sustained processing of 22 orders per second (approximately 1,320 orders per minute) and full lag recovery within 60 seconds after traffic spikes. Additional consumer-group rebalancing enabled dynamic partition redistribution during horizontal scaling, ensuring throughput scaled proportionally with service instances.

## Challenge 4: Database Connection Pool Optimization Under High Concurrency

Concurrent stress tests revealed the importance of minimizing database connection hold times to maximize throughput. The system uses HikariCP with a maximum of 20 connections (10 minimum idle), which proved sufficient for typical workloads but required optimization under sustained high concurrency. Initial synchronous implementations held database connections throughout the entire request lifecycle, including Kafka event publishing, which could take 200-250ms due to network round-trips for broker acknowledgments. By implementing asynchronous event publishing with the `@Async` annotation and a dedicated `ThreadPoolTaskExecutor` (10 core threads, 50 maximum threads), the system reduced connection hold time from the full request duration (~250ms) to just the database transaction time (~8-10ms). This 25× reduction in hold time effectively increased the connection pool's capacity, enabling the system to sustain 400+ concurrent users without exhaustion. Connection pool parameters were further tuned with a 30-second connection timeout and 600-second idle timeout to balance connection availability with resource efficiency, as validated through Spring Actuator's HikariCP metrics endpoint (`/actuator/metrics/hikaricp.connections.active`).

## Challenge 5: Static Service Discovery

Service endpoints rely on environment-specific configuration with hardcoded hostnames (e.g., `kafka:9092` for Docker deployments, `localhost:9092` for local development) in `application.properties`. While sufficient for single-environment deployment, this approach limits flexibility during infrastructure changes or multi-region scaling. The system currently uses Spring profiles to manage environment-specific configurations, but lacks runtime service registration and discovery. Future work involves integrating Spring Cloud Consul or Eureka to enable dynamic service registration and discovery, supporting advanced deployment strategies such as blue-green deployments, canary releases, and geographic load balancing across multiple data centers or cloud regions.

---

## Performance Impact Summary

| Challenge | Before | After | Improvement |
|-----------|--------|-------|-------------|
| Request Latency | 250ms | 8ms | 31× faster |
| Throughput | ~4 req/s | 18.97 req/s | 4.7× improvement |
| Order Processing | 2.5 orders/s | 22 orders/s | 8.8× improvement |
| Connection Hold Time | 250ms | 8-10ms | 25× reduction |
| Fulfillment Rate | 27.77% | 95%+ | 3.4× improvement |

---

## Documentation References

- **Async Implementation**: [`docs/ASYNC_IMPLEMENTATION_SUMMARY.md`](docs/ASYNC_IMPLEMENTATION_SUMMARY.md), [`docs/TRUE_ASYNC_IMPLEMENTATION.md`](docs/TRUE_ASYNC_IMPLEMENTATION.md)
- **Fulfillment Optimization**: [`docs/FULFILLMENT_OPTIMIZATION_IMPLEMENTATION.md`](docs/FULFILLMENT_OPTIMIZATION_IMPLEMENTATION.md)
- **Observability Examples**: [`docs/OBSERVABILITY_EXAMPLES.md`](docs/OBSERVABILITY_EXAMPLES.md)
- **Fault Tolerance**: [`FAULT_TOLERANCE_REPORT.md`](FAULT_TOLERANCE_REPORT.md)
