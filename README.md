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
- [Performance Benchmarks](#-performance-benchmarks)
- [Development Notes](#-development-notes)

## 🎯 Quick Reference

| **Task** | **Command** | **Description** |
|----------|-------------|-----------------|
| **Start Services** | `docker-compose up -d` | Start Kafka, Zookeeper, PostgreSQL |
| **Run Application** | `./mvnw spring-boot:run` | Start Spring Boot application |
| **E2E Demo** | `./e2e-demo.sh` | Complete system demonstration |
| **Autonomous Test** | `./autonomous-stress-test.sh` | 5-round stress test (25 tests) |
| **Concurrent Test** | `./stress-test-concurrent.sh` | Multi-round concurrent load test |
| **Clear Database** | `./clear-database.sh` | Truncate all tables |
| **Start Traffic Agent** | `curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=10&pattern=STEADY"` | Generate autonomous load |
| **Start Fulfillment Agent** | `curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1"` | Process orders autonomously |
| **Check Status** | `curl http://localhost:8081/actuator/health` | Application health check |
| **View Kafka UI** | Open http://localhost:8080 | Kafka topic/consumer monitoring |

## 🚀 Project Overview

This project implements a microservices-based distributed system designed for performance testing and analysis. It features autonomous load generation agents, real-time metrics collection, and comprehensive performance monitoring capabilities.

### 🎯 Key Features

- **🏗️ Microservices Architecture**: 4 independent services (User, Order, Payment, Notification) with REST API communication
- **📨 Event-Driven Architecture**: Apache Kafka with 4 topics for asynchronous inter-service communication
- **🤖 Autonomous Agents**: Traffic Agent (5 patterns) + Fulfillment Agent for autonomous load generation and order processing
- **⚡ Performance Testing**: Concurrent load testing system supporting 10-1000 users with comprehensive metrics
- **📊 Real-time Metrics**: Comprehensive performance monitoring with Spring Actuator + Kafka event publishing
- **🔄 Horizontal Scaling**: Multi-instance deployment with Nginx load balancing (1-5 instances)
- **⏯️ Pause/Resume**: Lag testing and backlog recovery capabilities
- **🐳 Full Containerization**: Docker Compose orchestration for all services

## 🛠️ Technology Stack

- **Backend**: Spring Boot 3.5.6, Java 21
- **Message Broker**: Apache Kafka 7.4.0 with Zookeeper
- **Database**: PostgreSQL 15 (Production), H2 (Testing)
- **Build Tool**: Maven
- **Metrics**: Micrometer + Spring Actuator
- **Load Balancing**: Nginx
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
├── test-logs/                       # Test Results
│   ├── autonomous-stress-*/         # Autonomous test outputs
│   └── stress-test-concurrent-*/    # Concurrent test outputs
│
├── scripts/                         # Utility Scripts
│
├── Testing Scripts (Main)
├── autonomous-stress-test.sh        # 5-round autonomous stress test
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

**Single Instance:**
```bash
./mvnw spring-boot:run
```

**Multiple Instances (with scaling):**
```bash
# Start with 3 order-service instances + Nginx load balancer
docker-compose -f docker-compose-scale.yaml up --scale order-service=3 -d
```

The application will be available at:
- **Single instance**: `http://localhost:8081`
- **Load balanced**: `http://localhost:8081` (Nginx distributes to all instances)
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

5-round stress test using Traffic Agent and Fulfillment Agent:

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
- Orders created/fulfilled per test
- Min/Avg/Max latency
- P50/P95/P99 latency percentiles
- Throughput (requests/sec)
- Fulfillment rate (%)

**Output:**
- CSV file: `test-logs/autonomous-stress-TIMESTAMP/autonomous_stress_results.csv`
- Individual logs per test
- Aggregated statistics by load level and pattern

**Recent optimizations (Oct 26, 2025):**
- 🚀 Fulfillment Agent optimized: 100ms delay (was 2000ms) - **20x faster**
- 🚀 Batch size increased: 50 orders (was 5) - **10x larger**
- 🚀 Polling interval: 1s (was 5s) - **5x more frequent**
- 🚀 Result: Fulfillment rate improved from **27.77%** to **95%+**

### 3. Concurrent Stress Test (`stress-test-concurrent.sh`)

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

**Problem identified:** Fulfillment rate was only 27.77% due to slow processing.

**Root cause:**
- Processing delay: 2000ms per order (too slow)
- Batch size: 5 orders (too small)
- Polling interval: 5 seconds (too infrequent)
- Backlog: 1,127 pending orders

**Solution applied:**
- ✅ Processing delay: **100ms** (20x faster)
- ✅ Batch size: **50 orders** (10x larger)
- ✅ Polling interval: **1 second** (5x more frequent)

**Results:**
- 🚀 Fulfillment rate: **27.77% → 95%+** (3.4x improvement)
- 🚀 Processing throughput: **2.5 → 22 orders/sec** (8.8x improvement)
- 🚀 Average processing time: **1,962ms → 389ms** (5x faster)
- 🚀 Backlog clearance: **Minutes instead of hours**

See `explanations/FULFILLMENT_OPTIMIZATION.md` for detailed analysis.

## 🏗️ Architecture Components

### System Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT / TESTING SCRIPTS                    │
│  (e2e-demo.sh, autonomous-stress-test.sh, curl commands)        │
└────────────────────────┬────────────────────────────────────────┘
                         │ REST API
                         ▼
┌─────────────────────────────────────────────────────────────────┐
│                    NGINX LOAD BALANCER (8081)                   │
│                   (For multi-instance scaling)                   │
└────────────────────────┬────────────────────────────────────────┘
                         │
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

### Current Implementation

- ✅ **4 Microservices**: User, Order, Payment, Notification services
- ✅ **Event-Driven Architecture**: Kafka with 4 topics (order-events, payment-events, notification-events, performance-metrics)
- ✅ **Autonomous Agents**: 
  - Traffic Agent with 5 patterns (STEADY, BURST, SPIKE, RAMP_UP, RANDOM)
  - Fulfillment Agent for autonomous order processing (optimized: 100ms delay, batch 50, poll 1s)
- ✅ **Concurrent Load Testing**: Sophisticated testing system (10-1000 concurrent users)
- ✅ **Horizontal Scaling**: Multi-instance deployment with Nginx load balancer
- ✅ **Metrics & Monitoring**: Spring Actuator + Kafka-based event publishing
- ✅ **Fault Tolerance**: Pause/Resume, cold start recovery, backlog processing
- ✅ **Database Integration**: PostgreSQL with optimized connection pooling
- ✅ **Full Containerization**: Docker Compose orchestration

### Demonstrated Capabilities

- 🎯 **Traffic Patterns**: STEADY, BURST, SPIKE, RAMP_UP, RANDOM
- 🎯 **Scalability**: 1-5 instances with Kafka partition distribution
- 🎯 **Throughput**: 15,000+ messages, 50+ msg/sec sustained
- 🎯 **Lag Recovery**: Backlog processing and cold start handling
- 🎯 **Concurrent Testing**: Up to 1000 concurrent users
- 🎯 **Idempotency**: Duplicate detection and handling
- 🎯 **Event Sourcing**: All events stored in Kafka for audit/replay
- 🎯 **Asynchronous Processing**: Decoupled services via message broker

## 🤝 Contributing

This project is part of an academic distributed systems study. For development:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📈 Performance Benchmarks

Current system performance (demonstrated metrics):

**API Performance:**
- **Average Response Time**: ~15.9ms per request
- **Maximum Response Time**: <100ms
- **P50 Latency**: ~40ms
- **P95 Latency**: ~54ms
- **P99 Latency**: ~59ms

**Kafka & Event Processing:**
- **Message Throughput**: 15,000+ messages processed
- **Sustained Rate**: 50+ msg/sec
- **Kafka Partitions**: 3-5 per topic
- **Consumer Lag**: Efficient recovery (<1 min for 1000+ backlog)

**Load Testing Results:**
- **Concurrent Users**: Successfully tested up to 1000 concurrent operations
- **Success Rate**: 100% (zero errors with idempotent processing)
- **Fulfillment Rate**: 95%+ (after optimization)

**Scalability:**
- **Horizontal Scaling**: 1-5 instances with Nginx load balancing
- **Database Connections**: HikariCP pool with 10-50 connections
- **Async Thread Pool**: 10 core, 50 max threads

**Traffic Pattern Performance:**
- **STEADY**: Baseline throughput ~9-10 req/s
- **BURST**: Handles spikes up to 50+ req/s
- **SPIKE**: Recovery time <30s from extreme bursts
- **RAMP_UP**: Linear scalability demonstrated
- **RANDOM**: Stable performance under unpredictable load

**Agent Performance (Optimized):**
- **Fulfillment Agent Throughput**: 20-25 orders/sec
- **Traffic Agent Generation**: Up to 100 ops/sec
- **Backlog Processing**: 500+ orders/minute
- **Average Processing Time**: 389ms per order

## 📝 Development Notes

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

- **Production**: PostgreSQL 15 on port 5432
- **Testing**: H2 in-memory database
- **Connection Pool**: HikariCP with optimized settings
  - Minimum Idle: 10 connections
  - Maximum Pool Size: 50 connections
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
- **Thread Name Prefix**: async-executor-

### Agent Configuration

**Traffic Agent Defaults:**
- Operations per second: 1-100 (configurable)
- Patterns: STEADY, BURST, SPIKE, RAMP_UP, RANDOM
- Configurable via REST API

**Fulfillment Agent Defaults (Optimized):**
- Processing delay: 100ms
- Batch size: 50 orders
- Polling interval: 1 second
- Parallel threads: 8

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