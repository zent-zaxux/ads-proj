# System Architecture Diagram

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         MONOLITHIC SPRING BOOT APPLICATION                   │
│                              (Port 8081)                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                         REST API LAYER                              │    │
│  │                                                                      │    │
│  │  UserController    OrderController    PaymentController             │    │
│  │  NotificationController    TrafficAgentController                   │    │
│  │  FulfillmentAgentController                                         │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                       SERVICE LAYER                                 │    │
│  │                                                                      │    │
│  │  UserService          OrderService (@Async)                         │    │
│  │  PaymentService       NotificationService                           │    │
│  │  EventPublisherService    EventConsumerService                      │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                    AUTONOMOUS AGENTS                                │    │
│  │                                                                      │    │
│  │  TrafficAgent              FulfillmentAgent                         │    │
│  │  (Load Generator)          (Order Processor)                        │    │
│  │  • STEADY/BURST/SPIKE      • PENDING → CONFIRMED                    │    │
│  │  • Publishes metrics       • CONFIRMED → SHIPPED                    │    │
│  │                            • SHIPPED → DELIVERED                     │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                    │                                         │
│                                    ▼                                         │
│  ┌────────────────────────────────────────────────────────────────────┐    │
│  │                     DATA ACCESS LAYER                               │    │
│  │                                                                      │    │
│  │  UserRepository      OrderRepository      PaymentRepository         │    │
│  │  NotificationRepository      ProcessedEventRepository               │    │
│  │  (Spring Data JPA with HikariCP Connection Pooling)                 │    │
│  └────────────────────────────────────────────────────────────────────┘    │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
                    │                                    │
                    │                                    │
                    ▼                                    ▼
        ┌─────────────────────┐            ┌─────────────────────────┐
        │   PostgreSQL 17     │            │    Apache Kafka 7.4.0   │
        │   (Port 5432)       │            │    (Port 9092)          │
        │                     │            │                         │
        │  • adsdb database   │            │  • order-events         │
        │  • HikariCP Pool:   │            │  • payment-events       │
        │    - Min: 10 conn   │            │  • notification-events  │
        │    - Max: 20 conn   │            │  • user-events          │
        │                     │            │  • performance-events   │
        └─────────────────────┘            │                         │
                                           │  Consumer Groups:       │
                                           │  • ads-proj-group (20)  │
                                           │  • notification-group   │
                                           └─────────────────────────┘
                                                       │
                                                       ▼
                                           ┌─────────────────────────┐
                                           │     Zookeeper           │
                                           │     (Port 2181)         │
                                           │   • Kafka coordination  │
                                           └─────────────────────────┘
```

---

## Detailed Event Flow Diagram

```
┌─────────────┐
│   Browser   │
│   Client    │
└──────┬──────┘
       │ HTTP POST /api/orders
       │
       ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    SPRING BOOT APPLICATION (8081)                        │
│                                                                          │
│  ┌──────────────────┐                                                   │
│  │ OrderController  │──┐                                                │
│  └──────────────────┘  │                                                │
│           │             │                                                │
│           ▼             │                                                │
│  ┌──────────────────┐  │                                                │
│  │  OrderService    │  │                                                │
│  │  1. Save Order   │  │                                                │
│  │  2. @Async Event │◄─┘                                                │
│  │     Publishing   │                                                   │
│  └────────┬─────────┘                                                   │
│           │                                                              │
│           │ @Async (Fire-and-Forget)                                    │
│           │ ThreadPool: LoadGen-1                                       │
│           ▼                                                              │
│  ┌────────────────────────┐                                             │
│  │ EventPublisherService  │                                             │
│  │ publishOrderEvent()    │                                             │
│  └────────┬───────────────┘                                             │
│           │                                                              │
└───────────┼─────────────────────────────────────────────────────────────┘
            │
            │ Kafka Send (Non-blocking)
            ▼
   ┌────────────────────────────────────────────────────┐
   │           APACHE KAFKA CLUSTER                      │
   │                                                     │
   │  ┌──────────────────┐  ┌──────────────────────┐   │
   │  │  order-events    │  │  payment-events      │   │
   │  │  (5 partitions)  │  │  (5 partitions)      │   │
   │  └──────────────────┘  └──────────────────────┘   │
   │                                                     │
   │  ┌──────────────────┐  ┌──────────────────────┐   │
   │  │notification-events│  │ performance-events   │   │
   │  │  (5 partitions)  │  │  (5 partitions)      │   │
   │  └──────────────────┘  └──────────────────────┘   │
   │                                                     │
   │  ┌──────────────────┐                              │
   │  │  user-events     │                              │
   │  │  (5 partitions)  │                              │
   │  └──────────────────┘                              │
   └─────────────────────────────────────────────────────┘
            │                              │
            │ Consumed by                  │ Consumed by
            │ ads-proj-group               │ notification-group
            ▼                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                    SPRING BOOT APPLICATION (8081)                        │
│                                                                          │
│  ┌──────────────────────────────────────────────────────────────┐      │
│  │              EventConsumerService                             │      │
│  │                                                               │      │
│  │  @KafkaListener(topics = "order-events")                     │      │
│  │  handleOrderEvent() {                                         │      │
│  │    1. Check idempotency (processed_events table)             │      │
│  │    2. Auto-create payment if ORDER_CREATED                   │      │
│  │    3. Publish payment-events                                 │      │
│  │  }                                                            │      │
│  │                                                               │      │
│  │  @KafkaListener(topics = "payment-events")                   │      │
│  │  handlePaymentEvent() {                                      │      │
│  │    1. Check idempotency                                      │      │
│  │    2. Update order status                                    │      │
│  │    3. Publish notification-events                            │      │
│  │  }                                                            │      │
│  │                                                               │      │
│  │  @KafkaListener(topics = "notification-events")              │      │
│  │  handleNotificationEvent() {                                 │      │
│  │    1. Check idempotency                                      │      │
│  │    2. Create notification record                             │      │
│  │    3. Send to user                                           │      │
│  │  }                                                            │      │
│  └──────────────────────────────────────────────────────────────┘      │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
            │
            │ JPA + HikariCP
            ▼
   ┌──────────────────────────────────────┐
   │       POSTGRESQL DATABASE             │
   │                                       │
   │  • users                              │
   │  • orders                             │
   │  • payments                           │
   │  • notifications                      │
   │  • processed_events (idempotency)    │
   └──────────────────────────────────────┘
```

---

## Autonomous Agents Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         TRAFFIC AGENT                                    │
│                     (Autonomous Load Generator)                          │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Start:  POST /api/agent/traffic/start?opsPerSecond=10&pattern=STEADY  │
│  Stop:   POST /api/agent/traffic/stop                                   │
│  Status: GET /api/agent/traffic/status                                  │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  Generates random operations:                                   │    │
│  │  • 30% CREATE_USER                                              │    │
│  │  • 40% CREATE_ORDER                                             │    │
│  │  • 10% CREATE_PAYMENT                                           │    │
│  │  • 15% UPDATE_ORDER_STATUS                                      │    │
│  │  •  5% CANCEL_ORDER                                             │    │
│  │                                                                  │    │
│  │  Traffic Patterns:                                              │    │
│  │  • STEADY - Constant rate (10 ops/sec)                          │    │
│  │  • BURST - Periodic spikes every 10s                            │    │
│  │  • SPIKE - Random large bursts                                  │    │
│  │  • RAMP_UP - Gradually increasing                               │    │
│  │  • RANDOM - Unpredictable timing                                │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Publishes to: performance-events topic                                 │
│  • Agent lifecycle events (START, STOP, PAUSE, RESUME)                  │
│  • Metrics every 10s (operations, success rate, throughput)             │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                              │
                              │ Creates orders
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      FULFILLMENT AGENT                                   │
│                   (Autonomous Order Processor)                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Start:  POST /api/agent/fulfillment/start?processingDelayMs=100       │
│                   &batchSize=50&pollingIntervalSeconds=1                │
│  Stop:   POST /api/agent/fulfillment/stop                               │
│  Pause:  POST /api/agent/fulfillment/pause (for lag testing)            │
│  Resume: POST /api/agent/fulfillment/resume                             │
│  Status: GET /api/agent/fulfillment/status                              │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  Processing Pipeline (every 1 second):                          │    │
│  │                                                                  │    │
│  │  1. Fetch batch of PENDING orders (batch size: 50)             │    │
│  │     SELECT * FROM orders WHERE status='PENDING' LIMIT 50        │    │
│  │                                                                  │    │
│  │  2. Process in parallel (16 threads via CompletableFuture)     │    │
│  │     • PENDING → CONFIRMED (with 100ms delay)                    │    │
│  │     • saveAll() batch update                                    │    │
│  │                                                                  │    │
│  │  3. Fetch batch of CONFIRMED orders (batch size: 50)           │    │
│  │     • CONFIRMED → SHIPPED (with 100ms delay)                    │    │
│  │     • saveAll() batch update                                    │    │
│  │                                                                  │    │
│  │  4. Fetch batch of SHIPPED orders (batch size: 50)             │    │
│  │     • SHIPPED → DELIVERED (with 100ms delay)                    │    │
│  │     • saveAll() batch update                                    │    │
│  │                                                                  │    │
│  │  Optimization Techniques:                                       │    │
│  │  ✅ JPA saveAll() batch operations (reduces DB roundtrips)     │    │
│  │  ✅ Parallel processing with CompletableFuture (16 threads)    │    │
│  │  ✅ Database indexing on status column                          │    │
│  │  ✅ Configurable processing delays (10-2000ms)                  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Publishes to: performance-events topic                                 │
│  • Agent lifecycle events (START, STOP, PAUSE, RESUME)                  │
│  • Processing metrics (throughput, backlog, latency)                    │
│                                                                          │
│  Metrics tracked:                                                        │
│  • totalProcessed: Total state transitions (PENDING→CONFIRMED counts)   │
│  • ordersConfirmed: Orders in CONFIRMED state                           │
│  • ordersShipped: Orders in SHIPPED state                               │
│  • ordersDelivered: Orders in DELIVERED state                           │
│  • currentBacklog: PENDING orders count                                 │
│  • avgProcessingTimeMs: Average time per state transition               │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Observability & Monitoring Stack

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY ENDPOINTS                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Spring Boot Actuator (Port 8081):                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  /actuator/health                                               │    │
│  │  • Overall status: UP/DOWN                                      │    │
│  │  • Database (PostgreSQL): UP/DOWN                               │    │
│  │  • Disk space: UP/DOWN                                          │    │
│  │  • Ping: UP                                                     │    │
│  │                                                                  │    │
│  │  /actuator/metrics                                              │    │
│  │  • hikaricp.connections.active                                  │    │
│  │  • hikaricp.connections.idle                                    │    │
│  │  • hikaricp.connections.pending                                 │    │
│  │  • jvm.memory.used                                              │    │
│  │  • http.server.requests                                         │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Agent Status APIs:                                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  GET /api/agent/traffic/status                                  │    │
│  │  {                                                               │    │
│  │    "agentId": "TRAFFIC-AGENT-abc123",                           │    │
│  │    "status": "RUNNING",                                         │    │
│  │    "totalOperations": 1830,                                     │    │
│  │    "successfulOperations": 1274,                                │    │
│  │    "successRate": 69.6,                                         │    │
│  │    "uptimeSeconds": 180                                         │    │
│  │  }                                                               │    │
│  │                                                                  │    │
│  │  GET /api/agent/fulfillment/status                              │    │
│  │  {                                                               │    │
│  │    "agentId": "FULFILLMENT-AGENT-xyz789",                       │    │
│  │    "status": "RUNNING",                                         │    │
│  │    "totalProcessed": 2151,                                      │    │
│  │    "ordersDelivered": 717,                                      │    │
│  │    "currentBacklog": 5,                                         │    │
│  │    "avgProcessingTimeMs": 114                                   │    │
│  │  }                                                               │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
                              │
                              │ Visualized by
                              ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                        KAFKA UI (Port 8080)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Topics View:                                                            │
│  • order-events        - Messages: 2661  - Lag: 1730                    │
│  • payment-events      - Messages: 1500  - Lag: 0                       │
│  • notification-events - Messages: 1200  - Lag: 0                       │
│  • user-events         - Messages: 800   - Lag: 0                       │
│  • performance-events  - Messages: 500   - Lag: 0                       │
│                                                                          │
│  Consumer Groups View:                                                   │
│  • ads-proj-group      - Members: 20  - State: STABLE - Lag: 1730      │
│  • notification-group  - Members: 10  - State: STABLE - Lag: 0         │
│                                                                          │
│  Partitions View:                                                        │
│  • Shows partition distribution and consumer assignments                │
│  • Real-time message rates (in/out per second)                          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Fault Tolerance Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      FAULT TOLERANCE LAYERS                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  Layer 1: Async Event Publishing                                        │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  @Async + ThreadPoolTaskExecutor                                │    │
│  │  • Non-blocking Kafka sends                                     │    │
│  │  • Prevents cascade failures                                    │    │
│  │  • 10 core threads, 50 max threads                              │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 2: Idempotency                                                    │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  processed_events table with UUID                               │    │
│  │  • Prevents duplicate processing                                │    │
│  │  • Unique constraint on (event_id, service_name, event_type)   │    │
│  │  • Checked before every Kafka event processing                  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 3: Connection Pooling                                             │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  HikariCP with auto-recovery                                    │    │
│  │  • Min: 10, Max: 20 connections                                 │    │
│  │  • Connection timeout: 30s                                      │    │
│  │  • Validation timeout: 5s                                       │    │
│  │  • Auto-replacement of stale connections                        │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 4: Kafka Consumer Retry                                          │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  Spring Kafka with auto-retry                                   │    │
│  │  • 3 retry attempts × 1s backoff                                │    │
│  │  • Consumer group rebalancing on failure                        │    │
│  │  • Manual offset commit for at-least-once delivery              │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 5: Health Checks                                                  │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  Spring Actuator + Custom Indicators                            │    │
│  │  • Database connectivity check                                  │    │
│  │  • Disk space check                                             │    │
│  │  • Application readiness probe                                  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 6: Transactional Boundaries                                       │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  @Transactional with proper isolation                           │    │
│  │  • ACID guarantees for critical operations                      │    │
│  │  • Automatic rollback on exceptions                             │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 7: Event-Driven Choreography                                      │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  Decoupled services via Kafka                                   │    │
│  │  • No direct service-to-service calls                           │    │
│  │  • Failure isolation between components                         │    │
│  │  • Async message passing                                        │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Layer 8: Thread Pool Management                                         │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │  Custom ThreadPoolTaskExecutor                                  │    │
│  │  • Resource isolation (prevents thread starvation)              │    │
│  │  • Bounded queue (100 tasks)                                    │    │
│  │  • Clear thread naming (LoadGen-*)                              │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Deployment Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DOCKER COMPOSE STACK                                  │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  compose.yaml - Infrastructure Services                                 │
│  ┌────────────────────────────────────────────────────────────────┐    │
│  │                                                                  │    │
│  │  ┌──────────────────┐    ┌──────────────────┐                 │    │
│  │  │   PostgreSQL 17  │    │   Zookeeper      │                 │    │
│  │  │   Port: 5432     │    │   Port: 2181     │                 │    │
│  │  │   DB: adsdb      │    │                  │                 │    │
│  │  └──────────────────┘    └────────┬─────────┘                 │    │
│  │                                   │                            │    │
│  │  ┌──────────────────┐             │                           │    │
│  │  │   Kafka 7.4.0    │◄────────────┘                           │    │
│  │  │   Port: 9092     │                                          │    │
│  │  │   Topics: 5      │                                          │    │
│  │  └──────────────────┘                                          │    │
│  │                                                                  │    │
│  │  ┌──────────────────┐                                          │    │
│  │  │   Kafka UI       │                                          │    │
│  │  │   Port: 8080     │                                          │    │
│  │  │   Web UI         │                                          │    │
│  │  └──────────────────┘                                          │    │
│  │                                                                  │    │
│  └────────────────────────────────────────────────────────────────┘    │
│                                                                          │
│  Application Deployment Options:                                        │
│                                                                          │
│  Option 1: Local Development                                            │
│  ./mvnw spring-boot:run                                                 │
│  • Hot reload with DevTools                                             │
│  • Connects to localhost:5432 (PostgreSQL)                              │
│  • Connects to localhost:9092 (Kafka)                                   │
│                                                                          │
│  Option 2: Docker Container                                             │
│  docker build -t ads-proj:latest .                                      │
│  docker run -p 8081:8081 \                                              │
│    --network ads-proj_default \                                         │
│    -e SPRING_DATASOURCE_URL=jdbc:postgresql://postgres:5432/adsdb \    │
│    -e SPRING_KAFKA_BOOTSTRAP_SERVERS=kafka:9092 \                       │
│    ads-proj:latest                                                      │
│  • Uses Docker DNS (postgres:5432, kafka:9092)                          │
│  • Production-ready deployment                                          │
│                                                                          │
└──────────────────────────────────────────────────────────────────────────┘
```

---

## Key Architectural Decisions

### 1. Monolithic vs Microservices
**Decision**: Monolithic Spring Boot application with modular service layer  
**Rationale**: 
- Simplifies deployment and reduces operational complexity
- All services share same JVM, reducing inter-service latency
- Kafka provides async decoupling between logical services
- Easier to refactor into microservices later if needed

### 2. Async Event Publishing
**Decision**: Fire-and-forget with `@Async` + no callbacks  
**Rationale**:
- 31× faster response time (250ms → 8ms)
- Non-blocking reduces thread pool exhaustion
- Kafka guarantees delivery with `acks=all` + idempotency
- Prevents cascade failures

### 3. Idempotency with Database Table
**Decision**: `processed_events` table with unique constraints  
**Rationale**:
- Survives application restarts
- Handles Kafka consumer rebalancing
- Prevents duplicate processing on retries
- Simple to implement and maintain

### 4. HikariCP Connection Pooling
**Decision**: 10 min, 20 max connections with 5s validation  
**Rationale**:
- Auto-recovery from database failures
- Connection leak prevention
- Efficient resource utilization
- Validated connection health before use

### 5. Autonomous Agents
**Decision**: In-process agents vs external load generators  
**Rationale**:
- Simpler deployment (no external dependencies)
- Direct access to application services
- Real-time metrics publishing to Kafka
- Pause/resume for lag testing

### 6. Kafka Topic Design
**Decision**: 5 separate topics (order, payment, notification, user, performance)  
**Rationale**:
- Clear separation of concerns
- Independent scaling per topic
- Easier consumer group management
- Dedicated performance metrics topic

### 7. Consumer Group Strategy
**Decision**: `ads-proj-group` (20 consumers) + `notification-group` (10 consumers)  
**Rationale**:
- Parallel processing across partitions
- Load balancing within consumer group
- Independent scaling per service type
- Automatic rebalancing on failures

---

## Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| **Average Response Time** | 8ms | After async optimization |
| **Throughput** | 18.97 req/s | Single instance |
| **Order Processing** | 22 orders/s | Fulfillment agent |
| **Connection Pool** | 10-20 | HikariCP |
| **Thread Pool** | 10-50 | Async operations |
| **Kafka Partitions** | 5 per topic | Parallel processing |
| **Consumer Lag** | 0-1730 | Varies by load |
| **Recovery Time** | 10-25s | Fault injection tests |

---

**Note**: This diagram reflects the actual implementation as of November 26, 2025, based on the verified codebase structure.
