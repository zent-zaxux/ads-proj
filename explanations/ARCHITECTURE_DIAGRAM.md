# Concurrent Load Testing System Architecture

```
╔══════════════════════════════════════════════════════════════════════════════════╗
║                    CONCURRENT LOAD TESTING SYSTEM                                ║
║                    Simulates 10-1000 Concurrent Users                           ║
╚══════════════════════════════════════════════════════════════════════════════════╝

┌─────────────────────────────────────────────────────────────────────────────────┐
│                              ENTRY POINTS                                        │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Shell Scripts                    REST API Endpoints                            │
│  ┌─────────────────────┐         ┌──────────────────────────────────┐          │
│  │ quick-start.sh      │         │ POST /api/concurrent-load/gradual│          │
│  │ run-concurrent.sh   │────────▶│ POST /api/concurrent-load/spike  │          │
│  │ test-all-scenarios  │         │ POST /api/concurrent-load/stress │          │
│  │ demo-load-testing   │         │ POST /api/concurrent-load/quick  │          │
│  └─────────────────────┘         └──────────────────────────────────┘          │
│                                             │                                    │
└─────────────────────────────────────────────┼────────────────────────────────────┘
                                              │
                                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         SPRING SERVICE LAYER                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────┐        │
│  │           ConcurrentLoadTestController                              │        │
│  │  • Parameter validation                                             │        │
│  │  • Request handling                                                 │        │
│  │  • Response formatting                                              │        │
│  └───────────────────────────┬────────────────────────────────────────┘        │
│                              │                                                   │
│                              ▼                                                   │
│  ┌────────────────────────────────────────────────────────────────────┐        │
│  │           ConcurrentLoadTestService                                 │        │
│  │  • @Async execution                                                 │        │
│  │  • Predefined scenarios (stress, spike, sustained)                 │        │
│  │  • Test orchestration                                               │        │
│  └───────────────────────────┬────────────────────────────────────────┘        │
│                              │                                                   │
└──────────────────────────────┼───────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         CORE LOAD TEST ENGINE                                    │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────┐        │
│  │           ConcurrentLoadTestRunner                                  │        │
│  │                                                                      │        │
│  │  Configuration:                  User Simulation:                   │        │
│  │  • Min/Max Users: 10-1000       • Multi-threaded execution         │        │
│  │  • Duration: configurable        • Random action selection         │        │
│  │  • Ramp-up: configurable         • Variable delays (100-2000ms)    │        │
│  │  • Kafka bootstrap servers       • Burst mode (10% probability)    │        │
│  │                                   • 5% failure simulation           │        │
│  │                                                                      │        │
│  │  ┌─────────────────────────────────────────────────────────┐       │        │
│  │  │         Thread Pool (ExecutorService)                    │       │        │
│  │  │  ┌────────┐  ┌────────┐  ┌────────┐      ┌────────┐   │       │        │
│  │  │  │ User 1 │  │ User 2 │  │ User 3 │ ... │User 1000│   │       │        │
│  │  │  └───┬────┘  └───┬────┘  └───┬────┘      └───┬────┘   │       │        │
│  │  │      │           │           │               │          │       │        │
│  │  │      └───────────┴───────────┴───────────────┘          │       │        │
│  │  │                     │                                    │       │        │
│  │  │                     ▼                                    │       │        │
│  │  │         ┌─────────────────────────┐                     │       │        │
│  │  │         │  Action Selection       │                     │       │        │
│  │  │         │  (Weighted Random)      │                     │       │        │
│  │  │         └──────────┬──────────────┘                     │       │        │
│  │  │                    │                                     │       │        │
│  │  │         ┌──────────┴──────────────────────────┐         │       │        │
│  │  │         │                                      │         │       │        │
│  │  │         ▼          ▼          ▼          ▼    ▼         │       │        │
│  │  │    CREATE_USER  CREATE_   PROCESS_  UPDATE_ CANCEL_    │       │        │
│  │  │      (30%)     ORDER(20%) PAYMENT   ORDER   ORDER       │       │        │
│  │  │                          (20%)     (15%)   (5%)         │       │        │
│  │  │                                                          │       │        │
│  │  └──────────────────────────────────────────────────────────┘       │        │
│  │                                                                      │        │
│  └────────────────────────────┬─────────────────────────────────────────┘        │
│                               │                                                   │
└───────────────────────────────┼───────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         KAFKA PRODUCER LAYER                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────┐        │
│  │           KafkaProducer<String, Object>                             │        │
│  │                                                                      │        │
│  │  Configuration:                                                     │        │
│  │  • Batch Size: 16384 bytes                                          │        │
│  │  • Linger MS: 10ms                                                  │        │
│  │  • Buffer Memory: 32MB                                              │        │
│  │  • Acks: 1 (leader acknowledgment)                                 │        │
│  │  • Retries: 3                                                       │        │
│  │  • JSON Serialization                                               │        │
│  │                                                                      │        │
│  └────────────────────────────┬───────────────────────────────────────┘        │
│                               │                                                  │
└───────────────────────────────┼──────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         KAFKA TOPICS                                             │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │  user-events    │  │  order-events   │  │ payment-events  │                │
│  │   (30% weight)  │  │   (35% weight)  │  │  (20% weight)   │                │
│  │  3 partitions   │  │  3 partitions   │  │  3 partitions   │                │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
│                                                                                  │
│  ┌─────────────────────┐                                                        │
│  │ notification-events │                                                        │
│  │    (15% weight)     │                                                        │
│  │   3 partitions      │                                                        │
│  └─────────────────────┘                                                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         METRICS COLLECTION                                       │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌────────────────────────────────────────────────────────────────────┐        │
│  │           LoadTestMetrics                                           │        │
│  │                                                                      │        │
│  │  Real-time Tracking (every 5s):                                     │        │
│  │  • Active Users                  • Per-Action Metrics:              │        │
│  │  • Total Requests                  - Success count                  │        │
│  │  • Success Rate                    - Failure count                  │        │
│  │  • Failure Rate                    - Average latency                │        │
│  │  • Average Latency                 - Failure reasons                │        │
│  │  • Throughput (req/sec)                                             │        │
│  │                                                                      │        │
│  │  Final Summary:                                                     │        │
│  │  • Detailed breakdown by action type                                │        │
│  │  • Success/failure percentages                                      │        │
│  │  • Latency statistics                                               │        │
│  │  • Peak concurrent users                                            │        │
│  │                                                                      │        │
│  └──────────────────────────────────────────────────────────────────────┘        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         MONITORING & LOGGING                                     │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  Console Output (every 5s):          Shell Scripts:                             │
│  ═══════════════════════════         ┌──────────────────────────┐              │
│  LOAD TEST METRICS                   │ monitor-kafka-metrics.sh │              │
│  ───────────────────────────         │ • Topic message counts    │              │
│  Active Users:     450                │ • Consumer group lag     │              │
│  Total Requests:   12,580             │ • Real-time updates      │              │
│  Successful:       95.00%             └──────────────────────────┘              │
│  Failed:           5.00%                                                         │
│  Avg Latency:      125 ms                                                       │
│  Throughput:       75.48 req/sec                                                │
│  ───────────────────────────                                                    │
│  Action Breakdown:                                                              │
│  CREATE_USER - 3,585 (118ms)                                                    │
│  CREATE_ORDER - 4,183 (128ms)                                                   │
│  ...                                                                             │
│  ═══════════════════════════                                                    │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                         TEST SCENARIOS                                           │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                  │
│  ┌────────────────┐  ┌────────────────┐  ┌────────────────┐                   │
│  │  Quick Test    │  │  Gradual Test  │  │  Spike Test    │                   │
│  │  10-50 users   │  │  10-1000 users │  │  10-1000 users │                   │
│  │  60s duration  │  │  300s duration │  │  120s duration │                   │
│  │  10s ramp-up   │  │  60s ramp-up   │  │  5s ramp-up    │                   │
│  └────────────────┘  └────────────────┘  └────────────────┘                   │
│                                                                                  │
│  ┌────────────────┐  ┌────────────────┐                                        │
│  │  Stress Test   │  │  Sustained     │                                        │
│  │  10-500 users  │  │  Constant users│                                        │
│  │  180s duration │  │  Configurable  │                                        │
│  │  30s ramp-up   │  │  duration      │                                        │
│  └────────────────┘  └────────────────┘                                        │
│                                                                                  │
└─────────────────────────────────────────────────────────────────────────────────┘

KEY FEATURES:
✅ 10-1000 concurrent users simulation
✅ Gradual load increase with configurable ramp-up
✅ Variable message rates (100-2000ms + bursts)
✅ Random delays and 5% failure simulation
✅ Real-time metrics (success rate, latency, throughput)
✅ Comprehensive logging every 5 seconds
✅ Multiple Kafka topics with weighted distribution
✅ REST API and shell script interfaces
✅ Predefined and custom test scenarios
```
