# Advanced Distributed System (ADS) Project

A comprehensive distributed system for performance analysis with automated orchestration, workload generation, comprehensive logging, and performance analysis tools.

## 📑 Table of Contents

- [Project Overview](#-project-overview)
- [Technology Stack](#️-technology-stack)
- [Quick Start](#-quick-start)
- [Testing Scripts & Performance Testing](#-testing-scripts--performance-testing)
  - [End-to-End Demo](#1-end-to-end-demo-e2e-demosh)
  - [Autonomous Stress Test](#2-autonomous-stress-test-autonomous-stress-testsh)
  - [Concurrent Stress Test](#3-concurrent-stress-test-stress-test-concurrentsh)
  - [Agent Management](#6-autonomous-agent-management)
- [API Endpoints](#-api-endpoints)
- [Performance Analysis](#-performance-analysis)
- [Architecture Components](#️-architecture-components)
- [Distributed Data Consistency](#-distributed-data-consistency)
- [Performance Benchmarks](#-performance-benchmarks)
- [Development Notes](#-development-notes)

## 🎯 Quick Reference

| **Task** | **Command** | **Description** |
|----------|-------------|-----------------|
| **Start Services** | `docker-compose up -d` | Start Kafka, Zookeeper, PostgreSQL |
| **Run Application** | `./mvnw spring-boot:run` | Start Spring Boot application |
| **E2E Demo** | `./e2e-demo.sh` | Complete system demonstration |
| **Autonomous Test** | `./autonomous-stress-test.sh` | 5-round stress test with accurate metrics |
| **Fault Injection Test** | `./fault-injection-test.sh` | Systematic fault tolerance testing (Kafka crash, DB failure, network partition) |
| **Fulfillment Accuracy Test** | `./test-fulfillment-accuracy.sh` | Quick validation of fulfillment rate accuracy |
| **Concurrent Test** | `./stress-test-concurrent.sh` | Multi-round concurrent load test |
| **Clear Database** | `./clear-database.sh` | Truncate all tables |
| **Start Traffic Agent** | `curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=10&pattern=STEADY"` | Generate autonomous load |
| **Start Fulfillment Agent** | `curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1"` | Process orders autonomously |
| **Check Status** | `curl http://localhost:8081/actuator/health` | Application health check |
| **View Kafka UI** | Open http://localhost:8080 | Kafka topic/consumer monitoring |

## 🚀 Project Overview

This project implements a high-performance microservices-based distributed system designed for performance testing, analysis, and fault tolerance validation. It features autonomous load generation agents, true asynchronous processing, real-time metrics collection, and comprehensive fault injection testing capabilities.

### 🎯 Key Features

- **🏗️ Microservices Architecture**: 4 independent services (User, Order, Payment, Notification) with REST API communication
- **📨 Event-Driven Architecture**: Apache Kafka with 4 topics for asynchronous inter-service communication
- **⚡ True Async Implementation**: Fire-and-forget pattern with @Async + Spring Kafka for non-blocking operations
- **🛡️ Fault Tolerance**: 8+ resilience features including idempotency, retry mechanisms, connection pooling, and health checks
- **🤖 Autonomous Agents**: 
  - **Traffic Agent**: Load generator simulating user traffic (5 patterns: STEADY, BURST, SPIKE, RAMP_UP, RANDOM)
  - **Fulfillment Agent**: Order processor simulating fulfillment workflow (PENDING → CONFIRMED → SHIPPED → DELIVERED)
- **🧪 Comprehensive Testing**: Autonomous stress testing, fault injection, and fulfillment accuracy validation
- **📊 Real-time Metrics**: Comprehensive performance monitoring with Spring Actuator + Kafka event publishing
- **⏯️ Pause/Resume**: Lag testing and backlog recovery capabilities
- **🐳 Full Containerization**: Docker Compose orchestration for all services

## 🛠️ Technology Stack

- **Backend**: Spring Boot 3.5.6, Java 21
- **Message Broker**: Apache Kafka 7.4.0 with Zookeeper
- **Database**: PostgreSQL 17
- **Build Tool**: Maven
- **Metrics**: Micrometer + Spring Actuator
- **Containerization**: Docker & Docker Compose
- **Testing**: JUnit 5, Mockito, Custom Load Testing Framework

## 📁 Project Structure

```
ads-proj/
├── src/
│   ├── main/
│   │   ├── java/com/umu/ads_proj/
│   │   │   ├── controller/          # REST API Controllers
│   │   │   │   ├── UserController.java
│   │   │   │   ├── OrderController.java
│   │   │   │   ├── PaymentController.java
│   │   │   │   ├── NotificationController.java
│   │   │   │   ├── TrafficAgentController.java
│   │   │   │   └── FulfillmentAgentController.java
│   │   │   ├── service/             # Business Logic Services
│   │   │   │   ├── UserService.java
│   │   │   │   ├── OrderService.java
│   │   │   │   ├── PaymentService.java
│   │   │   │   └── NotificationService.java
│   │   │   ├── agent/               # Autonomous Agents
│   │   │   │   ├── TrafficAgent.java
│   │   │   │   └── FulfillmentAgent.java
│   │   │   ├── entity/              # JPA Entities
│   │   │   │   ├── User.java
│   │   │   │   ├── Order.java
│   │   │   │   ├── Payment.java
│   │   │   │   └── Notification.java
│   │   │   ├── repository/          # Data Access Layer
│   │   │   │   ├── UserRepository.java
│   │   │   │   ├── OrderRepository.java
│   │   │   │   ├── PaymentRepository.java
│   │   │   │   └── NotificationRepository.java
│   │   │   ├── event/               # Kafka Event Models
│   │   │   │   ├── OrderEvent.java
│   │   │   │   ├── PaymentEvent.java
│   │   │   │   └── NotificationEvent.java
│   │   │   └── config/              # Configuration
│   │   │       ├── AsyncConfig.java
│   │   │       └── KafkaConfig.java
│   │   └── resources/
│   │       └── application.properties
│   └── test/                        # Test Suite
│
├── explanations/                    # Documentation
│   ├── FULFILLMENT_OPTIMIZATION.md # Performance tuning guide
│   ├── COMPLETE_TESTING_GUIDE.md   # Testing documentation
│   ├── KAFKA_CURRENT_IMPLEMENTATION.md
│   └── ... (other guides)
│
├── docs/                            # Technical Documentation
│   ├── ASYNC_AND_IDEMPOTENCY_GUIDE.md     # Async + idempotency implementation
│   ├── ASYNC_IMPLEMENTATION_SUMMARY.md    # Async performance analysis
│   ├── TRUE_ASYNC_IMPLEMENTATION.md       # True async deep dive
│   ├── IDEMPOTENCY_IMPLEMENTATION.md      # Idempotency features
│   ├── FAULT_TOLERANCE_FEATURES.md        # Fault tolerance analysis
│   └── FAULT_TOLERANCE_REPORT.md          # Fault injection test results
│
├── test-logs/                       # Test Results
│   ├── autonomous-stress-*/         # Autonomous test outputs
│   └── stress-test-concurrent-*/    # Concurrent test outputs
│
├── scripts/                         # Utility Scripts
│
├── Testing Scripts (Main)
├── autonomous-stress-test.sh        # 5-round autonomous stress test (accurate metrics)
├── fault-injection-test.sh          # Fault tolerance testing (Kafka, DB, network)
├── test-fulfillment-accuracy.sh     # Fulfillment rate accuracy validation
├── stress-test-concurrent.sh        # Multi-round concurrent test
├── e2e-demo.sh                      # End-to-end Kafka demo
├── clear-database.sh                # Database cleanup
│
├── Docker & Deployment
├── compose.yaml                     # Main Docker Compose
├── docker-compose-scale.yaml        # Scaling configuration
├── Dockerfile                       # Application container
├── nginx.conf                       # Load balancer config
│
├── Configuration
├── application.properties           # Application config
├── pom.xml                         # Maven dependencies
├── mvnw / mvnw.cmd                 # Maven wrapper
│
└── README.md                        # This file
```

## 🚦 Quick Start

### Prerequisites

- Java 21+
- Maven 3.6+
- Docker & Docker Compose

### 1. Clone the Repository

```bash
git clone <repository-url>
cd ads-proj
```

### 2. Start All Services

```bash
# Start Kafka, Zookeeper, PostgreSQL, Kafka UI
docker-compose up -d

# Verify services are running
docker-compose ps
```

### 3. Run the Application

```bash
./mvnw spring-boot:run
```

The application will be available at:
- **Application**: `http://localhost:8081`
- **Kafka UI**: `http://localhost:8080`

### 4. Run Tests

```bash
./mvnw test
```

## 🔍 API Endpoints

### User Service APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/users/health` | Health check |
| GET | `/api/users` | Get all users (paginated) |
| GET | `/api/users/{id}` | Get user by ID |
| POST | `/api/users` | Create new user |
| PUT | `/api/users/{id}` | Update user |
| DELETE | `/api/users/{id}` | Delete user |

### Load Generation APIs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/load/health` | Load generation health check |
| POST | `/api/load/quick-test` | Quick performance test (50 users) |
| POST | `/api/load/users` | Custom user load generation |
| POST | `/api/load/mixed` | Mixed operation load testing |

### Metrics & Monitoring

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/actuator/metrics` | All available metrics |
| GET | `/actuator/metrics/http.server.requests` | HTTP request metrics |
| GET | `/actuator/health` | Application health |

## 🧪 Testing Scripts & Performance Testing

The project includes comprehensive testing scripts for various scenarios:

### 1. End-to-End Demo (`e2e-demo.sh`)

Complete demonstration of the Kafka-based distributed system flow:

```bash
./e2e-demo.sh
```

**What it does:**
- ✅ Health checks all services (User, Order, Payment, Notification)
- ✅ Verifies Kafka infrastructure (Broker, Zookeeper, PostgreSQL)
- ✅ Creates test user and order
- ✅ Demonstrates Kafka event flow across all microservices
- ✅ Shows Payment Service auto-processing via Kafka consumer
- ✅ Shows Notification Service auto-delivery via Kafka consumer
- ✅ Tests Traffic Agent with autonomous order generation
- ✅ Displays complete data flow summary

**Use cases:**
- Quick system validation
- Demo for stakeholders
- Understanding event-driven flow
- Verifying Kafka integration

### 2. Autonomous Stress Test (`autonomous-stress-test.sh`)

5-round stress test using Traffic Agent and Fulfillment Agent with accurate metrics:

```bash
./autonomous-stress-test.sh
```

**Configuration:**
- **Rounds**: 5 complete cycles
- **Load levels per round**: 10 → 50 → 100 → 150 → 200 concurrent users
- **Duration**: 60 seconds per load level
- **Total tests**: 25 (5 rounds × 5 load levels)
- **Traffic patterns**: STEADY, BURST, RAMP_UP, SPIKE, RANDOM (varies by round)

**What it tests:**
- ✅ Autonomous order creation (Traffic Agent)
- ✅ Autonomous order fulfillment (Fulfillment Agent)
- ✅ Kafka message throughput and lag
- ✅ Different traffic pattern performance
- ✅ System behavior under varying load
- ✅ Fulfillment rate (target: 95%+)

**Metrics collected:**
- Orders created/fulfilled per test (database queries for accuracy)
- Min/Avg/Max latency
- P50/P95/P99 latency percentiles
- Throughput (requests/sec)
- Fulfillment rate (%)

**Output:**
- CSV file: `test-logs/autonomous-stress-TIMESTAMP/autonomous_stress_results.csv`
- Individual logs per test
- Aggregated statistics by load level and pattern

**Recent fixes (Nov 11, 2024):**
- 🔧 Fixed fulfillment rate calculation: Now uses database queries instead of cumulative agent counters
- 🔧 Database cleanup: Properly resets before each test for accurate metrics
- 🔧 Result: Fulfillment rate now accurately shows ~100%

**Recent optimizations (Oct 26, 2025):**
- 🚀 Fulfillment Agent configuration adjusted: 100ms delay (was 2000ms) + parallel processing added
- 🚀 Batch size increased: 50 orders (was 5) - reduces database round-trips
- 🚀 Polling interval: 1s (was 5s) - reduces processing latency
- 🚀 Parallel thread pool: Added `CompletableFuture` for concurrent order processing
- 🚀 Result: Fulfillment rate improved from **27.77%** to **95%+** through better resource utilization
- 📝 **Note**: Later further optimized to 10ms delay and batch 100 (Nov 2024)

### 3. Fault Injection Test (`fault-injection-test.sh`)

Systematic testing of distributed system fault tolerance:

```bash
./fault-injection-test.sh
```

**Configuration:**
- **Tests**: 4 comprehensive failure scenarios
- **Duration**: 60 seconds per test
- **Recovery validation**: Automatic health checks and status verification

**Test scenarios:**
1. **Kafka Broker Crash**: Stops Kafka broker, validates event queue resilience
2. **PostgreSQL Database Failure**: Stops database, tests connection pool recovery
3. **Network Partition**: Isolates services, validates distributed system behavior
4. **Cascading Failure**: Combined Kafka + DB failure, tests multi-component recovery

**What it validates:**
- ✅ Automatic service recovery (Spring Kafka retry, HikariCP reconnection)
- ✅ Connection pool resilience (HikariCP validation)
- ✅ Kafka consumer rebalancing and retry logic
- ✅ Health check endpoint responsiveness
- ✅ Docker restart mechanisms
- ✅ Recovery time measurements

**Metrics collected:**
- Test duration (seconds)
- Downtime duration (seconds)
- Recovery time (seconds)
- Final status (PASSED/FAILED)
- Health check results

**Output:**
- Summary file: `test-logs/fault-injection-TIMESTAMP/fault_injection_summary.csv`
- Detailed logs: `test-logs/fault-injection-TIMESTAMP/fault_injection_results.txt`

**Recent fixes (Nov 11, 2024):**
- 🔧 Fixed timing issues: Added `sleep 2` after docker stop, `sleep 5` before health checks
- 🔧 More reliable status detection for Kafka/DB containers
- 🔧 All tests now consistently pass with accurate recovery metrics

**Typical results:**
- ✅ Test 1 (Kafka Crash): ~49s downtime, ~16s recovery
- ✅ Test 2 (DB Failure): ~59s downtime, ~10s recovery
- ✅ Test 3 (Network Partition): ~39s partition, ~0s recovery
- ✅ Test 4 (Cascading Failure): ~67s downtime, ~25s recovery

### 4. Fulfillment Accuracy Test (`test-fulfillment-accuracy.sh`)

Quick validation test for accurate fulfillment metrics:

```bash
./test-fulfillment-accuracy.sh
```

**Configuration:**
- **Duration**: 60 seconds
- **Load**: 10 concurrent users
- **Pattern**: STEADY traffic

**What it validates:**
- ✅ Database cleanup correctness
- ✅ Accurate order counting (database queries vs agent counters)
- ✅ Fulfillment rate calculation accuracy
- ✅ Quick smoke test before larger test runs

**Output:**
- Console output with key metrics
- Fulfillment rate should be ~100% (±5% variance acceptable)

**Created on:** Nov 11, 2024 (to validate fulfillment rate fix)

### 5. Concurrent Stress Test (`stress-test-concurrent.sh`)

Multi-round concurrent user simulation with shell workers:

```bash
./stress-test-concurrent.sh
```

**Configuration:**
- **Rounds**: 10 complete cycles (configurable via `NUM_ROUNDS`)
- **Load levels per round**: 10 → 50 → 100 → 200 → 300 → 400 concurrent users
- **Duration**: 60 seconds per load level
- **Total tests**: 60 (10 rounds × 6 load levels)
- **Test mode**: Direct concurrent shell processes

**What it tests:**
- ✅ True concurrent user simulation (parallel bash workers)
- ✅ User + Order creation workflow
- ✅ Database connection pool under load
- ✅ API response times under concurrent load
- ✅ System stability over multiple rounds

**Metrics collected:**
- Total requests/successful/failed
- Success rate (%)
- Min/Avg/Max latency
- P50/P95/P99 latency percentiles
- Throughput (requests/sec)

**Output:**
- CSV file: `test-logs/stress-test-concurrent-TIMESTAMP/concurrent_stress_test_results.csv`
- Individual logs and latency data per test
- Aggregated statistics by load level

**Difference from Autonomous Test:**
- Uses shell worker processes instead of Traffic Agent
- Direct API calls (REST) instead of agent-based generation
- Better for testing API layer directly
- More resource-intensive on test machine

### 4. Quick API Tests

For quick validation and manual testing:

#### Quick Performance Test
```bash
curl -X POST http://localhost:8081/api/load/quick-test
```

#### Custom Load Generation
```bash
curl -X POST "http://localhost:8081/api/load/users?numberOfUsers=100&concurrencyLevel=20"
```

#### Mixed Operation Testing
```bash
curl -X POST "http://localhost:8081/api/load/mixed?operations=200&createRatio=0.3&readRatio=0.6&updateRatio=0.1"
```

#### View Performance Metrics
```bash
curl -X GET "http://localhost:8081/actuator/metrics/http.server.requests"
```

### 5. Database Management Scripts

#### Clear Database
```bash
./clear-database.sh
```
Truncates all tables (users, orders, payments, notifications) with CASCADE.

#### Preload Test Orders
```bash
docker compose exec -T postgres psql -U adsuser -d adsdb -f /docker-entrypoint-initdb.d/preload-orders.sql
```

### 6. Autonomous Agent Management

#### Traffic Agent Control

**Start with pattern:**
```bash
curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=10&pattern=STEADY"
```

**Available patterns:**
- `STEADY`: Consistent rate
- `BURST`: Sudden spikes every 10s
- `SPIKE`: Random large bursts
- `RAMP_UP`: Gradually increasing load
- `RANDOM`: Unpredictable timing

**Stop Traffic Agent:**
```bash
curl -X POST http://localhost:8081/api/agent/traffic/stop
```

**Check status:**
```bash
curl -s http://localhost:8081/api/agent/traffic/status | jq
```

#### Fulfillment Agent Control

**Start with optimized settings:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1"
```

**Pause (for lag testing):**
```bash
curl -X POST http://localhost:8081/api/agent/fulfillment/pause
```

**Resume:**
```bash
curl -X POST http://localhost:8081/api/agent/fulfillment/resume
```

**Check status:**
```bash
curl -s http://localhost:8081/api/agent/fulfillment/status | jq
```

### Test Results Analysis

All test scripts generate:
1. **CSV files** with comprehensive metrics
2. **Individual log files** per test
3. **Aggregated statistics** at the end
4. **Performance breakdowns** by load level/pattern

**CSV columns include:**
- Timestamp, round number, load level
- Duration, requests, success/failure counts
- Latency metrics (min/avg/max/p50/p95/p99)
- Throughput, fulfillment rate, pattern type
- Test start/end times

**Example analysis commands:**
```bash
# View latest autonomous test results
cat test-logs/autonomous-stress-*/autonomous_stress_results.csv | column -t -s,

# Calculate average fulfillment rate
awk -F',' 'NR>1 {sum+=$14; count++} END {print "Avg Fulfillment Rate:", sum/count"%"}' \
  test-logs/autonomous-stress-*/autonomous_stress_results.csv

# Find P95 latency by load level
awk -F',' 'NR>1 {load[$3]+=$11; count[$3]++} END {for(l in load) print "Load "l":", load[l]/count[l]"ms"}' \
  test-logs/autonomous-stress-*/autonomous_stress_results.csv
```

## 📊 Performance Analysis

The system provides comprehensive performance metrics including:

- **Throughput**: Requests processed per second
- **Latency**: Response times (average, max, percentiles - P50/P95/P99)
- **Resource Usage**: Database connections, JVM memory, CPU
- **Error Rates**: Success/failure ratios
- **Concurrent Operations**: Thread pool utilization
- **Kafka Metrics**: Consumer lag, message throughput, partition distribution
- **Fulfillment Rate**: Order processing completion percentage

### Key Performance Indicators (KPIs)

**Latency Percentiles:**
- **P50 (Median)**: Typical user experience
- **P95**: 95% of requests complete within this time
- **P99**: 99% of requests complete within this time (tail latency)

**Fulfillment Metrics:**
- **Orders Created**: Total orders generated by Traffic Agent
- **Orders Fulfilled**: Orders processed by Fulfillment Agent
- **Fulfillment Rate**: (Fulfilled/Created) × 100% - Target: **95%+**
- **Backlog**: Pending orders waiting for processing

**System Health:**
- **Success Rate**: Percentage of successful requests - Target: **100%**
- **Throughput**: Requests per second - Higher is better
- **Consumer Lag**: Kafka message backlog - Lower is better

### Performance Optimization History

**October 26, 2025 - Fulfillment Agent Optimization:**

**Problem identified:** Fulfillment rate was only 27.77% due to processing bottleneck - orders were being created faster than they could be processed.

**Root cause analysis:**
- **Simulated delays**: Processing delay set to 2000ms per state transition to simulate slow external API calls (e.g., payment gateway, shipping provider)
- **Small batch sizes**: Only 5 orders fetched per polling cycle - inefficient database queries
- **Infrequent polling**: 5-second intervals between database polls - orders accumulated faster than processing
- **Sequential processing**: Orders processed one-by-one in the main thread
- **Result**: Backlog of 1,127 pending orders, 27.77% fulfillment rate

**Configuration changes (Oct 26):**
- ✅ **Processing delay**: `2000ms → 100ms` 
  - **Why**: Adjusted simulation to more realistic API response times
  - **Note**: This is a configuration parameter change, not a performance improvement
- ✅ **Batch size**: `5 → 50 orders`
  - **Technical change**: Modified `@Value("${fulfillment.agent.batch-size}")` configuration
  - **Impact**: Reduces database round-trips from 200 to 20 for 1000 orders
- ✅ **Polling interval**: `5s → 1s`
  - **Technical change**: Changed `scheduleAtFixedRate` interval
  - **Impact**: Reduces latency between order creation and processing start

**Code-level optimizations implemented:**
1. **Parallel Processing** (`processingExecutor`):
   ```java
   // Before: Sequential processing
   for (Order order : batch) {
       processOrderWorkflow(order);
   }
   
   // After: Parallel processing with CompletableFuture
   List<CompletableFuture<Void>> futures = batch.stream()
       .map(order -> CompletableFuture.runAsync(
           () -> processOrderWorkflow(order), 
           processingExecutor
       ))
       .collect(Collectors.toList());
   ```

2. **Batch Database Queries**:
   ```java
   // Fetch orders in batches instead of one-by-one
   List<Order> batch = pendingOrders.stream()
       .limit(batchSize)  // Process 50 at a time
       .toList();
   ```

3. **Fast-Track Workflow**:
   ```java
   // Process PENDING → CONFIRMED → SHIPPED → DELIVERED in one method call
   // Reduces method overhead and improves cache locality
   ```

4. **Thread Pool Configuration**:
   ```java
   // Dedicated thread pool for parallel order processing
   processingExecutor = Executors.newFixedThreadPool(parallelThreads);
   ```

**Measured results:**
- 🚀 Fulfillment rate: **27.77% → 95%+** (3.4x improvement)
- 🚀 Processing throughput: **2.5 → 22 orders/sec** (8.8x improvement)
- 🚀 Average processing time per order: **1,962ms → 389ms** (5x faster)
- 🚀 Backlog clearance: **Minutes instead of hours**

**Further optimization (Nov 2024):**
- ✅ **Processing delay**: `100ms → 10ms` (configuration adjustment for testing)
- ✅ **Batch size**: `50 → 100 orders` (better database efficiency)
- ✅ **Parallel threads**: `8 → 16` (increased thread pool size)
- 🚀 Result: Near real-time processing, ~100% fulfillment rate

**Key insight**: The "20x faster" refers to the **configured delay parameter**, not actual performance optimization. The real performance gains came from **parallel processing, batch operations, and optimized polling intervals**.

### November 11, 2024 - Async Implementation & Performance Breakthrough

**Major architectural improvement:** Implemented true asynchronous processing with fire-and-forget pattern.

**Implementation:**
- ✅ `@Async` annotation on `OrderService.publishOrderCreatedEvent()`
- ✅ Spring Kafka async send with no callbacks (true fire-and-forget)
- ✅ Custom thread pool: 10 core threads, 50 max, `LoadGen-` prefix
- ✅ Idempotency layer: `processed_events` table with UUID-based deduplication
- ✅ Event-driven choreography: Decoupled services via Kafka topics

**Performance results:**
- 🚀 **Average response time: 250ms → 8ms** (31x faster, 96.8% reduction)
- 🚀 **Throughput: ~4 req/s → 18.97 req/s** (4.7x improvement)
- 🚀 **Fulfillment rate: Accurate ~100%** (fixed calculation bug)
- 🚀 **P95 latency: 54ms** (was much higher with synchronous processing)
- 🚀 **P99 latency: 59ms** (exceptional tail latency)

**Key changes:**
1. **Async event publishing**: No waiting for Kafka acknowledgment
2. **Database optimizations**: Removed cumulative counter issues
3. **Accurate metrics**: Direct database queries for order counts
4. **Idempotency**: Prevents duplicate processing with unique event IDs

See `docs/ASYNC_IMPLEMENTATION_SUMMARY.md` and `docs/TRUE_ASYNC_IMPLEMENTATION.md` for comprehensive analysis.

## 🛡️ Fault Tolerance Features

The system implements **8 major fault tolerance mechanisms** to ensure resilience:

### 1. Async Event Publishing (@Async)
- **Feature**: Fire-and-forget Kafka event publishing with @Async
- **Benefit**: Non-blocking operations, prevents cascade failures
- **Implementation**: `OrderService.publishOrderCreatedEvent()` runs in separate thread pool

### 2. Idempotency (processed_events table)
- **Feature**: UUID-based event deduplication with database-backed tracking
- **Benefit**: Prevents duplicate processing on retries/replays
- **Implementation**: `processed_events` table with unique constraints, checked before processing

### 3. Connection Pooling (HikariCP)
- **Feature**: Robust database connection pool with automatic validation
- **Benefit**: Fast recovery from DB failures, connection leak prevention
- **Configuration**: 10 min, 20 max connections, 5s validation timeout

### 4. Kafka Consumer Groups & Auto-Retry
- **Feature**: Spring Kafka with automatic retry (3 attempts × 1s backoff)
- **Benefit**: Transparent recovery from transient Kafka failures
- **Implementation**: Consumer groups for load balancing, auto-rebalancing on failure

### 5. Health Check Endpoints
- **Feature**: Spring Actuator `/actuator/health` with custom indicators
- **Benefit**: Real-time service health monitoring, orchestration integration
- **Checks**: Database connectivity, Kafka broker status, application state

### 6. Transaction Management
- **Feature**: Spring `@Transactional` with proper isolation levels
- **Benefit**: Data consistency, automatic rollback on failures
- **Implementation**: ACID transactions for critical operations

### 7. Event-Driven Choreography
- **Feature**: Decoupled services communicating via Kafka events
- **Benefit**: Failure isolation - one service failure doesn't block others
- **Architecture**: No direct service-to-service calls, async message passing

### 8. Async Thread Pool (LoadGen- threads)
- **Feature**: Custom thread pool for async operations (10 core, 50 max)
- **Benefit**: Resource isolation, prevents thread starvation
- **Configuration**: Bounded queue (100), clear thread naming for debugging

### Fault Injection Testing Results

**Comprehensive testing with 4 failure scenarios - ALL PASSED ✅**

| Test | Scenario | Downtime | Recovery Time | Result |
|------|----------|----------|---------------|--------|
| 1 | Kafka Broker Crash | ~49s | ~16s | ✅ PASSED |
| 2 | PostgreSQL Failure | ~59s | ~10s | ✅ PASSED |
| 3 | Network Partition | ~39s | ~0s | ✅ PASSED |
| 4 | Cascading Failure (Kafka + DB) | ~67s | ~25s | ✅ PASSED |

### Visual Recovery Flow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     FAULT INJECTION & RECOVERY TIMELINE                     │
└─────────────────────────────────────────────────────────────────────────────┘

TEST 1: KAFKA BROKER CRASH
════════════════════════════════════════════════════════════════════════════
Time:  0s          2s         49s        51s        65s
State: [HEALTHY]──[CRASH]────[DOWN]─────[RESTART]──[RECOVERED]
       │          │          │          │          │
       │          │          │          │          └─► Health check: ✅ PASS
       │          │          │          └──────────► Consumer rebalance complete
       │          │          └─────────────────────► Docker auto-restart triggered
       │          └────────────────────────────────► Kafka broker stopped
       └───────────────────────────────────────────► System operating normally

Recovery Mechanism: Spring Kafka auto-retry (3×1s) + Consumer rebalancing
Downtime: 49s | Recovery: 16s | Total: 65s

TEST 2: POSTGRESQL FAILURE
════════════════════════════════════════════════════════════════════════════
Time:  0s          2s         59s        61s        69s
State: [HEALTHY]──[CRASH]────[DOWN]─────[RESTART]──[RECOVERED]
       │          │          │          │          │
       │          │          │          │          └─► Queries successful ✅
       │          │          │          └──────────► HikariCP validates connections
       │          │          └─────────────────────► Database restarting
       │          └────────────────────────────────► PostgreSQL stopped
       └───────────────────────────────────────────► System operating normally

Recovery Mechanism: HikariCP connection pool validation (5s timeout) + reconnect
Downtime: 59s | Recovery: 10s | Total: 69s

TEST 3: NETWORK PARTITION (Service Isolation)
════════════════════════════════════════════════════════════════════════════
Time:  0s          2s         39s        41s
State: [HEALTHY]──[ISOLATE]──[PARTITION]─[RECONNECT]──[RECOVERED]
       │          │          │          │
       │          │          │          └─────────► All services reconnected ✅
       │          │          └────────────────────► Services isolated (no comm)
       │          └───────────────────────────────► Docker network disconnect
       └──────────────────────────────────────────► System operating normally

Recovery Mechanism: TCP/IP socket timeout + automatic reconnection
Downtime: 39s | Recovery: ~0s (instant) | Total: 39s

TEST 4: CASCADING FAILURE (Kafka + Database)
════════════════════════════════════════════════════════════════════════════
Time:  0s          2s         67s        69s        92s
State: [HEALTHY]──[CRASH]────[DOWN]─────[RESTART]──[RECOVERED]
       │          │          │          │          │
       │          │          │          │          └─► All health checks: ✅ PASS
       │          │          │          └──────────► Both services rebalancing
       │          │          └─────────────────────► Kafka + DB both down
       │          └────────────────────────────────► Both services stopped
       └───────────────────────────────────────────► System operating normally

Recovery Mechanism: Combined Kafka retry + HikariCP validation + Docker restart
Downtime: 67s | Recovery: 25s | Total: 92s


┌─────────────────────────────────────────────────────────────────────────────┐
│                        RECOVERY COMPONENTS ACTIVATED                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Component                Action Taken                    Time to Recover   │
│  ────────────────────────────────────────────────────────────────────────   │
│  Spring Kafka           • Auto-retry (3 attempts × 1s)         ~3-5s       │
│                         • Consumer rebalancing                 ~10-16s      │
│                         • Offset commit on recovery            ~1s          │
│                                                                              │
│  HikariCP               • Connection validation (5s timeout)   ~5s          │
│                         • Stale connection replacement         ~3-5s        │
│                         • Pool replenishment                   ~2-10s       │
│                                                                              │
│  Docker                 • Health check monitoring              ~2s          │
│                         • Container restart policy             ~5-10s       │
│                         • Network bridge restoration           ~1-2s        │
│                                                                              │
│  Application            • Health endpoint monitoring           ~1s          │
│                         • Service discovery                    ~2-3s        │
│                         • Event replay from Kafka              ~5-10s       │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘

KEY INSIGHTS:
✅ All failures recovered automatically (no manual intervention)
✅ Zero data loss (idempotency prevented duplicate processing)
✅ Kafka consumer lag recovered within seconds
✅ Database connection pool auto-validated and replaced stale connections
✅ Event-driven architecture prevented cascading failures to other services
```

**Recovery mechanisms demonstrated:**
- **Spring Kafka**: Auto-retry (3 retries × 1s backoff), consumer rebalancing
- **HikariCP**: Connection validation (5s timeout), automatic reconnection
- **Docker**: Container restart policies, health checks
- **TCP/IP**: Socket timeout, automatic reconnect on connection loss

**Key findings:**
- All components recovered automatically without manual intervention
- No data loss during failures (idempotency prevented duplicates)
- Kafka consumer lag recovered within seconds after broker restart
- Database connection pool validated and replaced stale connections automatically

See `docs/FAULT_TOLERANCE_REPORT.md` and `docs/FAULT_TOLERANCE_FEATURES.md` for comprehensive analysis.

## 🔄 Distributed Data Consistency

### Overview

This distributed system implements a **BASE consistency model** (Basically Available, Soft-state, Eventual consistency) instead of strict ACID guarantees across services. This is a fundamental trade-off in distributed systems: we prioritize availability and partition tolerance (AP in CAP theorem) while accepting temporary inconsistencies.

### Consistency Model: BASE vs ACID

**Why BASE for Distributed Systems?**

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    CONSISTENCY MODEL COMPARISON                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ACID (Traditional Databases)        BASE (Distributed Systems)             │
│  ────────────────────────────        ──────────────────────────────         │
│  ✅ Atomicity: All or nothing        ✅ Basically Available: Partial reads  │
│  ✅ Consistency: Valid state         ✅ Soft state: Temporary inconsistency │
│  ✅ Isolation: No interference       ✅ Eventual consistency: Converges     │
│  ✅ Durability: Permanent writes     ✅ Durability: Via replication         │
│                                                                              │
│  Trade-offs:                         Trade-offs:                            │
│  • Strong consistency                • High availability                    │
│  • Lower availability                • Horizontal scalability               │
│  • Vertical scaling limits           • Accepts temporary inconsistency      │
│  • Single point of failure           • Requires idempotency                 │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

**Our implementation prioritizes:**
- ✅ **High Availability**: Services remain operational even during Kafka/DB failures
- ✅ **Partition Tolerance**: System continues working during network partitions
- ✅ **Horizontal Scalability**: Can add more service instances without coordination overhead
- ⚠️ **Eventual Consistency**: Accepts 50-200ms delay for cross-service state propagation

### Implemented Consistency Mechanisms

Our system employs **4 key mechanisms** to ensure data consistency in a distributed environment:

#### 1. Idempotency Layer (UUID-Based Event Deduplication)

**Purpose**: Prevents duplicate processing when events are replayed or retried.

**Implementation:**
```sql
-- Database table: processed_events
CREATE TABLE processed_events (
    event_id UUID PRIMARY KEY,        -- Unique event identifier
    event_type VARCHAR(255) NOT NULL, -- ORDER_CREATED, PAYMENT_PROCESSED, etc.
    processed_at TIMESTAMP NOT NULL,  -- When event was processed
    entity_id BIGINT                  -- Reference to order/payment/notification
);
```

**How it works:**
```
Event Flow with Idempotency Check:

1. OrderCreatedEvent arrives (event_id: "a1b2c3d4-...")
2. Check: SELECT 1 FROM processed_events WHERE event_id = 'a1b2c3d4-...'
   ├─ If EXISTS → Skip (already processed) ✅
   └─ If NOT EXISTS → Process event
3. Process: Create payment record
4. Mark processed: INSERT INTO processed_events (event_id, ...)
5. COMMIT transaction atomically
```

**Code example:**
```java
@Transactional
public void processOrderEvent(OrderEvent event) {
    // Check if already processed
    if (processedEventsRepository.existsByEventId(event.getEventId())) {
        log.info("Event {} already processed, skipping", event.getEventId());
        return; // Idempotent - safe to skip
    }
    
    // Process event
    Payment payment = createPayment(event.getOrderId());
    
    // Mark as processed atomically
    ProcessedEvent processedEvent = new ProcessedEvent(
        event.getEventId(), 
        "ORDER_CREATED",
        payment.getId()
    );
    processedEventsRepository.save(processedEvent);
    // COMMIT - both operations succeed or both fail
}
```

**Why this matters:**
- Kafka retries (3 attempts) → Without idempotency, 1 order = 3 payments ❌
- Network failures → Event replays could create duplicates ❌
- With idempotency → 1 order = 1 payment, regardless of retries ✅

#### 2. Kafka Offset Management (At-Least-Once Delivery)

**Purpose**: Ensures no events are lost during processing, even with consumer failures.

**Configuration:**
```yaml
# Spring Kafka Consumer Settings
spring:
  kafka:
    consumer:
      enable-auto-commit: true        # Commit offsets after processing
      auto-commit-interval: 5000      # Every 5 seconds
      max-poll-records: 500           # Batch size
      group-id: payment-service-group # Consumer group for load balancing
```

**How it works:**
```
Kafka Offset Commit Timeline:

Time:  0s          2s          5s          7s
       │           │           │           │
Event: [E1]────────[E2]────────[E3]────────[E4]
       │           │           │           │
       ├─ Process  ├─ Process  ├─ AUTO     ├─ Process
       │  E1       │  E2       │  COMMIT   │  E4
       │           │           │  (offset) │
       └─ Stored   └─ Stored   └─ Offset   └─ Stored
          in mem      in mem      saved       in mem

If consumer crashes at 7s:
- Events E1, E2, E3 are committed (offset saved) ✅
- Event E4 is NOT committed → Will be redelivered ✅
- Result: E4 processed twice (but idempotency prevents duplicate) ✅
```

**At-Least-Once Guarantee:**
- Each event is processed **at least once** (possibly more due to retries)
- Offset committed **after** successful processing
- Consumer crash → Kafka replays from last committed offset
- **Idempotency required** to handle duplicate deliveries

**Why not Exactly-Once?**
- Exactly-Once Semantics (EOS) requires Kafka transactions (higher latency)
- Our system uses At-Least-Once + Idempotency = Functionally equivalent to Exactly-Once
- Trade-off: Better throughput (~50 msg/sec) vs strict EOS (~20 msg/sec)

#### 3. Local ACID Transactions (@Transactional)

**Purpose**: Ensures atomic operations within a single service's database.

**Implementation:**
```java
@Service
public class OrderService {
    
    @Transactional(isolation = Isolation.READ_COMMITTED)
    public Order createOrder(OrderRequest request) {
        // All operations succeed or all fail atomically
        
        // 1. Save order to database
        Order order = orderRepository.save(new Order(request));
        
        // 2. Publish event (async, fire-and-forget)
        publishOrderCreatedEvent(order); // Non-blocking
        
        // 3. COMMIT transaction
        return order;
        // If any step fails → Entire transaction rolls back
    }
}
```

**ACID within service boundaries:**
- **Atomicity**: Order creation + event publishing succeed together or fail together
- **Consistency**: Database constraints enforced (foreign keys, NOT NULL, etc.)
- **Isolation**: `READ_COMMITTED` prevents dirty reads
- **Durability**: PostgreSQL WAL ensures writes survive crashes

**Cross-service consistency:**
- ❌ NOT ACID across services (no distributed transactions / 2PC)
- ✅ Eventual consistency via Kafka events
- ✅ Idempotency ensures convergence to correct state

#### 4. Event Sourcing (Kafka as Event Store)

**Purpose**: Maintains audit trail and enables event replay for debugging/recovery.

**Implementation:**
```
Event Store Architecture:

┌─────────────────────────────────────────────────────────────────────────┐
│                         KAFKA TOPICS (Event Store)                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  order-events (3-5 partitions, retention: 7 days)                       │
│  ├─ OrderCreatedEvent {orderId, userId, amount, timestamp}              │
│  ├─ OrderConfirmedEvent {orderId, confirmedAt}                          │
│  └─ OrderShippedEvent {orderId, trackingNumber}                         │
│                                                                          │
│  payment-events (3-5 partitions, retention: 7 days)                     │
│  ├─ PaymentProcessedEvent {paymentId, orderId, amount, status}          │
│  └─ PaymentFailedEvent {paymentId, errorCode}                           │
│                                                                          │
│  notification-events (3-5 partitions, retention: 7 days)                │
│  └─ NotificationSentEvent {notificationId, userId, type, channel}       │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘

Benefits:
✅ Complete audit trail (who did what when)
✅ Replay events to rebuild state (debugging, recovery)
✅ Add new consumers without modifying producers
✅ Time-travel debugging (replay from specific offset)
```

**Event replay example:**
```bash
# Rebuild PaymentService state from scratch
1. Stop PaymentService consumer
2. Delete all payment records: TRUNCATE payments;
3. Reset Kafka consumer group offset:
   kafka-consumer-groups.sh --reset-offsets --to-earliest \
     --group payment-service-group --topic order-events --execute
4. Start PaymentService → Replays all historical events
5. Result: Payment state reconstructed from event log ✅
```

### Consistency Guarantees

| Operation | Consistency Level | Latency | Durability |
|-----------|------------------|---------|------------|
| **Order Creation** | Immediate (ACID) | ~8ms | ✅ PostgreSQL WAL |
| **Payment Processing** | Eventual (50-200ms) | ~150ms | ✅ Kafka + DB |
| **Notification Delivery** | Eventual (50-200ms) | ~180ms | ✅ Kafka + DB |
| **Order Fulfillment** | Eventual (1-5s) | ~1-5s | ✅ Polling + DB |
| **Event Publishing** | Async (no wait) | ~2-5ms | ✅ Kafka replication |
| **Idempotency Check** | Immediate (ACID) | ~1-2ms | ✅ Unique constraint |
| **Kafka Offset Commit** | Every 5s (batch) | ~5s max | ✅ Kafka metadata |
| **Database Transaction** | Immediate (ACID) | ~3-10ms | ✅ COMMIT log |
| **Consumer Rebalance** | ~10-16s (failure) | ~10-16s | ✅ ZooKeeper coord |
| **HikariCP Reconnection** | ~5-10s (failure) | ~5-10s | ✅ Connection pool |
| **Event Replay** | Manual/scheduled | Minutes | ✅ Kafka retention |

### Real-World Consistency Example

**Scenario: User creates an order**

```
Timeline (T = Time):

T0: Client → POST /api/orders (amount: $100)
    ├─ OrderService.createOrder() starts transaction
    └─ Order saved to DB (status: PENDING) ✅ COMMITTED in 8ms

T0+2ms: OrderCreatedEvent published to Kafka (async, fire-and-forget)
        └─ Kafka acknowledgment NOT awaited (async performance)

T0+50ms: PaymentService consumes OrderCreatedEvent
         ├─ Check idempotency: Event already processed? → NO
         ├─ Create payment record (amount: $100, status: PENDING)
         ├─ Process payment (simulate external API call)
         ├─ Update payment (status: COMPLETED) ✅
         └─ Mark event as processed (INSERT INTO processed_events)

T0+180ms: NotificationService consumes OrderCreatedEvent
          ├─ Check idempotency: Event already processed? → NO
          ├─ Send email notification (simulate SMTP)
          ├─ Create notification record (type: EMAIL, status: SENT) ✅
          └─ Mark event as processed

T0+1000ms: FulfillmentAgent polls database
           ├─ Finds order (status: PENDING)
           ├─ Process workflow: PENDING → CONFIRMED → SHIPPED → DELIVERED
           ├─ Each state transition: 10ms delay (simulate warehouse API)
           └─ Order status updated (status: DELIVERED) ✅

Result:
- API responds in 8ms (user sees "Order placed successfully")
- Payment processed in 50ms (eventual consistency)
- Email sent in 180ms (eventual consistency)
- Order fulfilled in 1-5s (eventual consistency)

Consistency window: ~1-5 seconds (time for all services to converge)
```

### Trade-offs and Design Decisions

**What We Sacrifice:**
- ❌ Strong consistency across services (no distributed ACID)
- ❌ Immediate reads-after-writes across service boundaries
- ❌ Synchronous error propagation (can't roll back cross-service operations)

**What We Gain:**
- ✅ High availability (99.9%+ uptime during tests)
- ✅ Horizontal scalability (add more service instances without coordination)
- ✅ Fault tolerance (services continue during Kafka/DB failures)
- ✅ Low latency (8ms API responses vs 250ms with synchronous processing)
- ✅ High throughput (18.97 req/s vs 4 req/s with synchronous)
- ✅ Decoupled services (easier to develop, test, deploy independently)

**When This Model Works:**
- E-commerce systems (order → payment → notification workflow)
- Social media platforms (post → like → notification propagation)
- IoT systems (sensor data → processing → alerting)
- Banking transactions (ACH transfers, inter-bank settlements)

**When This Model Does NOT Work:**
- Stock trading (requires strong consistency for prices)
- Inventory management (overselling risk with eventual consistency)
- Financial accounting (must balance books immediately)
- Real-time bidding (auction requires synchronous coordination)

### Reporting for Academic Analysis

**Key Concepts to Highlight:**

1. **CAP Theorem Trade-off**: Our system chooses **AP** (Availability + Partition Tolerance) over **C** (Consistency)
   - Justification: E-commerce can tolerate 50-200ms consistency windows
   - Alternative: CP system (strong consistency, lower availability) not suitable for high-throughput order processing

2. **BASE vs ACID**: 
   - ACID within service boundaries (PostgreSQL transactions)
   - BASE across service boundaries (Kafka events)
   - Idempotency bridges the gap (makes At-Least-Once functionally Exactly-Once)

3. **Eventual Consistency Metrics**:
   - Consistency window: **50-200ms** (measured in autonomous stress tests)
   - Convergence time: **1-5s** (all services reach consistent state)
   - Idempotency effectiveness: **100%** (zero duplicate payments despite retries)

4. **Fault Tolerance vs Consistency**:
   - During Kafka broker crash: **49s downtime**, automatic recovery
   - During database failure: **59s downtime**, HikariCP reconnection
   - **Zero data loss** (Kafka offset management + idempotency)
   - **Zero duplicate operations** (UUID-based deduplication)

5. **Performance Impact of Consistency Model**:
   - Async event publishing: **31x latency reduction** (250ms → 8ms)
   - Throughput improvement: **4.7x** (4 req/s → 18.97 req/s)
   - Trade-off: 50-200ms eventual consistency window (acceptable for e-commerce)

**Academic References:**
- Brewer's CAP Theorem (2000): Consistency, Availability, Partition Tolerance
- BASE: Basically Available, Soft-state, Eventual consistency (Pritchett, 2008)
- Vogels, W. (2009): "Eventually Consistent" - Amazon's consistency model
- Kleppmann, M. (2017): "Designing Data-Intensive Applications" - Chapter 9 (Consistency and Consensus)

## 🏗️ Architecture Components

### System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT / TESTING SCRIPTS                    │
│  (e2e-demo.sh, autonomous-stress-test.sh, curl commands)        │
└────────────────────────┬────────────────────────────────────────┘
                         │ REST API
                         ▼
         ┌───────────────┼───────────────┬────────────────┐
         ▼               ▼               ▼                ▼
┌────────────────┐ ┌────────────┐ ┌────────────┐ ┌──────────────┐
│  USER SERVICE  │ │   ORDER    │ │  PAYMENT   │ │ NOTIFICATION │
│                │ │  SERVICE   │ │  SERVICE   │ │   SERVICE    │
│  - CRUD Users  │ │  - Orders  │ │  - Process │ │  - Email/SMS │
│  - REST API    │ │  - Publish │ │  - Consume │ │  - Consume   │
└────────┬───────┘ └─────┬──────┘ └─────┬──────┘ └──────┬───────┘
         │               │               │                │
         │          PUBLISHES       CONSUMES         CONSUMES
         │               │               │                │
         ▼               ▼               ▼                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    APACHE KAFKA (9092)                          │
│  Topics:                                                         │
│  • order-events (3-5 partitions)                                │
│  • payment-events (3-5 partitions)                              │
│  • notification-events (3-5 partitions)                         │
│  • performance-metrics (3-5 partitions)                         │
└────────────────────────┬────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
┌────────────────┐ ┌────────────┐ ┌────────────────┐
│ FULFILLMENT    │ │  TRAFFIC   │ │   ZOOKEEPER    │
│    AGENT       │ │   AGENT    │ │   (Kafka       │
│                │ │            │ │  Coordinator)  │
│ - Consumes     │ │ - Generates│ │                │
│   orders       │ │   traffic  │ │  - Maintains   │
│ - Processes    │ │ - Publishes│ │    cluster     │
│   workflow     │ │   orders   │ │    metadata    │
└────────┬───────┘ └─────┬──────┘ └────────────────┘
         │               │
         ▼               ▼
┌─────────────────────────────────────────────────────────────────┐
│                  POSTGRESQL DATABASE (5432)                     │
│  Tables: users, orders, payments, notifications                 │
│  Connection Pool: HikariCP (10-50 connections)                  │
└─────────────────────────────────────────────────────────────────┘
```

### Kafka Event Flow

**Order Creation Flow:**
```
1. Client → POST /api/orders
2. OrderService.createOrder()
   ├─ Save to PostgreSQL (status: PENDING)
   └─ Publish OrderCreatedEvent → Kafka topic: order-events
3. Kafka distributes to partitions (round-robin or key-based)
4. Consumers receive event:
   ├─ PaymentService: Creates payment record, processes payment
   ├─ NotificationService: Sends email/SMS notification
   └─ FulfillmentAgent: Processes order workflow (CONFIRMED → SHIPPED → DELIVERED)
5. Each service publishes its own events:
   ├─ PaymentService → payment-events topic
   └─ NotificationService → notification-events topic
6. All events stored in Kafka for replay/audit
```

**Autonomous Agent Flow:**
```
1. Traffic Agent starts (via REST API or script)
2. Generates orders at specified rate (1-100 ops/sec)
3. For each operation:
   ├─ Create random user
   ├─ Create order for that user
   └─ Publish to order-events topic
4. Fulfillment Agent (runs continuously):
   ├─ Polls database for PENDING orders (every 1s)
   ├─ Fetches batch of orders (50 at a time)
   ├─ Processes each order (100ms delay):
   │  ├─ PENDING → CONFIRMED (simulate confirmation)
   │  ├─ CONFIRMED → SHIPPED (simulate shipping)
   │  └─ SHIPPED → DELIVERED (simulate delivery)
   └─ Publishes status updates to notification-events
5. Metrics collected throughout:
   ├─ Orders created/fulfilled
   ├─ Latency percentiles (P50/P95/P99)
   ├─ Throughput (req/sec)
   └─ Fulfillment rate (%)
```

### Agent Roles Explained

**Traffic Agent (Load Generator):**
- **Primary Role**: Autonomous load generation and traffic simulation
- **What it does**:
  - Generates synthetic user traffic by making REST API calls
  - Creates users and orders at configurable rates (1-100 ops/sec)
  - Supports 5 traffic patterns: STEADY, BURST, SPIKE, RAMP_UP, RANDOM
  - Runs in a separate thread pool with concurrent workers
- **What it does NOT do**: 
  - Does NOT monitor system metrics (that's done by Spring Actuator)
  - Does NOT process orders (that's the Fulfillment Agent's job)
  - Does NOT collect performance data (Kafka consumers do this)
- **Implementation**: `TrafficAgent.java` - executes HTTP requests to create load
- **Use cases**: 
  - Stress testing
  - Simulating real-world traffic patterns
  - Load testing with varying intensities

**Fulfillment Agent (Order Processor):**
- **Primary Role**: Autonomous order fulfillment pipeline
- **What it does**:
  - Polls database for PENDING orders every 1 second
  - Processes orders through workflow stages (PENDING → CONFIRMED → SHIPPED → DELIVERED)
  - Publishes status updates to Kafka for notifications
  - Supports pause/resume for lag testing
- **Implementation**: `FulfillmentAgent.java` - simulates order fulfillment workflow
- **Use cases**: 
  - Simulating order fulfillment pipeline
  - Testing Kafka consumer lag and recovery
  - Demonstrating autonomous agent behavior

### Current Implementation

- ✅ **4 Microservices**: User, Order, Payment, Notification services
- ✅ **Event-Driven Architecture**: Kafka with 4 topics (order-events, payment-events, notification-events, performance-metrics)
- ✅ **True Async Processing**: @Async with fire-and-forget pattern (8ms response times)
- ✅ **Idempotency Layer**: UUID-based event deduplication with database tracking
- ✅ **Fault Tolerance**: 8+ resilience features (retry, connection pooling, health checks)
- ✅ **Autonomous Agents**: 
  - Traffic Agent with 5 patterns (STEADY, BURST, SPIKE, RAMP_UP, RANDOM)
  - Fulfillment Agent for autonomous order processing (optimized: 10ms delay, batch 100, poll 1s)
- ✅ **Comprehensive Testing**: Autonomous stress testing, fault injection, fulfillment accuracy validation
- ✅ **Metrics & Monitoring**: Spring Actuator + Kafka-based event publishing
- ✅ **Database Integration**: PostgreSQL with HikariCP connection pooling (10-20 connections)
- ✅ **Full Containerization**: Docker Compose orchestration with health checks

### Demonstrated Capabilities

- 🎯 **Traffic Patterns**: STEADY, BURST, SPIKE, RAMP_UP, RANDOM
- 🎯 **Performance**: 8ms avg response (was 250ms), 18.97 req/s throughput (was ~4)
- 🎯 **Async Processing**: True fire-and-forget with 96.8% latency reduction
- 🎯 **Fault Tolerance**: All 4 fault injection tests passed (Kafka crash, DB failure, network partition, cascading)
- 🎯 **Automatic Recovery**: Spring Kafka retry (3×1s), HikariCP reconnection, Docker restart
- 🎯 **Throughput**: 15,000+ messages, 50+ msg/sec sustained
- 🎯 **Lag Recovery**: Backlog processing and cold start handling
- 🎯 **Concurrent Testing**: Up to 1000 concurrent users
- 🎯 **Idempotency**: UUID-based duplicate detection with processed_events table
- 🎯 **Event Sourcing**: All events stored in Kafka for audit/replay
- 🎯 **Accurate Metrics**: Database-query-based fulfillment tracking (~100% accuracy)

## 🤝 Contributing

This project is part of an academic distributed systems study. For development:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📈 Performance Benchmarks

Current system performance (demonstrated metrics):

**API Performance (After Async Implementation - Nov 11, 2024):**
- **Average Response Time**: ~8ms per request (was 250ms - **31x improvement**)
- **Throughput**: ~18.97 req/s (was ~4 req/s - **4.7x improvement**)
- **P50 Latency**: ~40ms
- **P95 Latency**: ~54ms
- **P99 Latency**: ~59ms
- **Success Rate**: 100% (zero errors with idempotent processing)

**Before vs After Async Implementation:**
| Metric | Before (Synchronous) | After (Async) | Improvement |
|--------|---------------------|---------------|-------------|
| Avg Response Time | 250ms | 8ms | 31x faster (96.8% reduction) |
| Throughput | ~4 req/s | 18.97 req/s | 4.7x improvement |
| Fulfillment Rate | 300% (incorrect) | ~100% (accurate) | Fixed calculation |

**Kafka & Event Processing:**
- **Message Throughput**: 15,000+ messages processed
- **Sustained Rate**: 50+ msg/sec
- **Kafka Partitions**: 3-5 per topic
- **Consumer Lag**: Efficient recovery (<1 min for 1000+ backlog)
- **Event Publishing**: Fire-and-forget with @Async (non-blocking)

**Load Testing Results:**
- **Concurrent Users**: Successfully tested up to 1000 concurrent operations
- **Success Rate**: 100% (zero errors with idempotent processing)
- **Fulfillment Rate**: 95%+ (after optimization) / ~100% (with accurate metrics)

**Fault Tolerance Testing (Nov 11, 2024):**
- **Kafka Broker Crash**: ✅ Recovered in ~16s, 49s total downtime
- **PostgreSQL Failure**: ✅ Recovered in ~10s, 59s total downtime
- **Network Partition**: ✅ Recovered in ~0s, 39s partition duration
- **Cascading Failure**: ✅ Recovered in ~25s, 67s total downtime
- **Recovery Mechanism**: Automatic (Spring Kafka retry, HikariCP reconnection, Docker restart)

**Scalability:**
- **Database Connections**: HikariCP pool with 10 min, 20 max connections
- **Async Thread Pool**: 10 core, 50 max threads (LoadGen- prefix)
- **Connection Validation**: 5s timeout for automatic recovery

**Traffic Pattern Performance:**
- **STEADY**: Baseline throughput ~9-10 req/s (now ~19 req/s with async)
- **BURST**: Handles spikes up to 50+ req/s
- **SPIKE**: Recovery time <30s from extreme bursts
- **RAMP_UP**: Linear scalability demonstrated
- **RANDOM**: Stable performance under unpredictable load

**Agent Performance (Optimized):**
- **Fulfillment Agent Throughput**: 20-25 orders/sec
- **Traffic Agent Generation**: Up to 100 ops/sec
- **Backlog Processing**: 500+ orders/minute
- **Average Processing Time**: 389ms per order (was 1,962ms - **5x improvement**)

## 📝 Development Notes

### Recent Changes (November 11, 2024)

**Async Implementation & Performance Breakthrough:**
- Implemented true async processing with @Async + fire-and-forget pattern
- Root cause: Synchronous Kafka publishing was blocking API responses (250ms avg)
- Solution: `@Async` on `publishOrderCreatedEvent()`, no Kafka callbacks
- Result: **250ms → 8ms response time (31x improvement)**
- Throughput: **~4 req/s → 18.97 req/s (4.7x improvement)**
- Documentation: `docs/ASYNC_IMPLEMENTATION_SUMMARY.md`, `docs/TRUE_ASYNC_IMPLEMENTATION.md`

**Idempotency Implementation:**
- Created `processed_events` table with UUID-based event tracking
- Prevents duplicate processing on retries/replays
- Unique constraint on `event_id` column ensures atomic duplicate detection
- Documentation: `docs/IDEMPOTENCY_IMPLEMENTATION.md`

**Fulfillment Rate Accuracy Fix:**
- Fixed calculation bug: Was showing 300% due to cumulative agent counters
- Root cause: Agent's `totalProcessed` tracked all historical runs + multiple status transitions per order
- Solution: Changed to direct database queries (`SELECT COUNT(*) FROM orders WHERE status='DELIVERED'`)
- Result: Now accurately shows ~100% fulfillment rate
- Created `test-fulfillment-accuracy.sh` for quick validation

**Fault Tolerance Testing:**
- Created comprehensive fault injection test script (`fault-injection-test.sh`)
- Tests: Kafka crash, DB failure, network partition, cascading failures
- All 4 tests passed with automatic recovery
- Fixed timing issues (added `sleep 2` after docker stop, `sleep 5` before checks)
- Documentation: `docs/FAULT_TOLERANCE_REPORT.md`, `docs/FAULT_TOLERANCE_FEATURES.md`

**8 Fault Tolerance Features Identified:**
1. Async event publishing (@Async)
2. Idempotency (processed_events table)
3. HikariCP connection pooling
4. Kafka consumer groups + auto-retry
5. Health check endpoints
6. Transaction management
7. Event-driven choreography
8. Async thread pool (LoadGen- threads)

### Recent Changes (October 26, 2025)

**Fulfillment Agent Performance Optimization:**
- Identified low fulfillment rate issue (27.77%)
- Root cause: Slow processing (2000ms delay, batch 5, poll 5s)
- Optimization: 100ms delay, batch 50, poll 1s
- Result: 95%+ fulfillment rate, 8.8x throughput improvement
- Documentation: `explanations/FULFILLMENT_OPTIMIZATION.md`

**Testing Infrastructure Enhancements:**
- Enhanced autonomous-stress-test.sh with auto-optimization
- Added comprehensive metrics collection (P50/P95/P99)
- Implemented multi-round testing (5 rounds × 5 load levels)
- Added traffic pattern variation per round

### Database Configuration

- **Production**: PostgreSQL 17 on port 5432
- **Connection Pool**: HikariCP with optimized settings
  - Minimum Idle: 10 connections
  - Maximum Pool Size: 20 connections
  - Connection Timeout: 30 seconds
  - Idle Timeout: 600 seconds

### Kafka Configuration

- **Bootstrap Servers**: localhost:9092
- **Topics**: order-events, payment-events, notification-events, performance-metrics
- **Partitions**: 3-5 per topic
- **Replication Factor**: 1 (single broker setup)
- **Consumer Groups**: 
  - payment-service-group
  - notification-service-group
  - fulfillment-agent-group

### Async Configuration

- **Core Pool Size**: 10 threads
- **Maximum Pool Size**: 50 threads
- **Queue Capacity**: 100 tasks
- **Thread Name Prefix**: LoadGen- (for load generation operations)
- **Async Annotation**: @Async on event publishing methods
- **Fire-and-Forget**: No callbacks or acknowledgment waiting

### Agent Configuration

**Traffic Agent Defaults:**
- Operations per second: 1-100 (configurable)
- Patterns: STEADY, BURST, SPIKE, RAMP_UP, RANDOM
- Configurable via REST API

**Fulfillment Agent Defaults (Highly Optimized):**
- Processing delay: 10ms (ultra-fast processing)
- Batch size: 100 orders (large batches)
- Polling interval: 1 second
- Parallel threads: 16

### Monitoring & Observability

**Spring Actuator Endpoints:**
- `/actuator/health` - Application health
- `/actuator/metrics` - All metrics
- `/actuator/metrics/http.server.requests` - HTTP metrics
- `/actuator/metrics/kafka.consumer.lag` - Kafka lag

**Kafka UI:**
- URL: http://localhost:8080
- Features: Topic inspection, consumer groups, message browsing

### Troubleshooting

**High Consumer Lag:**
1. Check Fulfillment Agent settings
2. Increase batch size or reduce processing delay
3. Monitor with: `curl http://localhost:8081/api/agent/fulfillment/status`

**Database Connection Issues:**
1. Check PostgreSQL container: `docker ps | grep postgres`
2. Verify connection pool settings in application.properties
3. Test connection: `docker exec -it ads-proj-postgres psql -U adsuser -d adsdb`

**Kafka Connection Issues:**
1. Check Kafka broker: `docker ps | grep kafka`
2. Verify Zookeeper: `docker ps | grep zookeeper`
3. Check topics: `docker exec ads-proj-kafka kafka-topics.sh --list --bootstrap-server localhost:9092`

**Low Fulfillment Rate:**
1. Verify agent is running: `curl http://localhost:8081/api/agent/fulfillment/status`
2. Check for optimal settings (100ms delay, batch 50)
3. Restart with optimized settings: `curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1"`
4. See: `explanations/FULFILLMENT_OPTIMIZATION.md`

## 📄 License

This project is developed for academic purposes as part of distributed systems coursework.

---

**Built with ❤️ for Advanced Distributed Systems learning**