# Observability Examples for Report

**Document**: Concrete examples demonstrating system observability  
**Date**: November 25, 2025  
**Purpose**: Show how operators monitor system health, detect issues, and validate recovery

---

## Table of Contents

1. [Overview](#overview)
2. [Spring Actuator Health Endpoints](#1-spring-actuator-health-endpoints)
3. [Autonomous Agent Metrics](#2-autonomous-agent-metrics)
4. [Kafka Performance Metrics](#3-kafka-performance-metrics-via-events)
5. [Kafka UI for Consumer Lag Monitoring](#4-kafka-ui-for-consumer-lag-monitoring)
6. [Real-World Monitoring Scenario](#5-real-world-monitoring-scenario-fault-recovery)
7. [Complete Monitoring Dashboard Example](#6-complete-monitoring-dashboard-example)

---

## Overview

The system provides observability through **multiple complementary channels**:

1. **Spring Actuator** - Health status, DB connectivity, Kafka availability
2. **Agent Status APIs** - Throughput, latency, fulfillment rates
3. **Kafka Events** - Performance metrics published to dedicated topic
4. **Kafka UI** - Consumer lag, backlog monitoring

Together, these allow operators to:
- ✅ Monitor real-time system health
- ✅ Detect performance degradation
- ✅ Verify fault recovery mechanisms
- ✅ Validate return to steady state after incidents

---

## 1. Spring Actuator Health Endpoints

### 1.1 Health Check Endpoint

**Endpoint**: `GET /actuator/health`

**Example Request**:
```bash
curl http://localhost:8081/actuator/health
```

**Example Response** (System Healthy):
```json
{
  "status": "UP",
  "components": {
    "db": {
      "status": "UP",
      "details": {
        "database": "PostgreSQL",
        "validationQuery": "isValid()"
      }
    },
    "diskSpace": {
      "status": "UP",
      "details": {
        "total": 994662584320,
        "free": 443871612928,
        "threshold": 10485760,
        "exists": true
      }
    },
    "kafka": {
      "status": "UP",
      "details": {
        "clusterId": "MkU3OEVBNTcwNTJENDM2Qk",
        "brokerId": 1001
      }
    },
    "ping": {
      "status": "UP"
    }
  }
}
```

**Example Response** (Kafka Down - During Fault Injection):
```json
{
  "status": "DOWN",
  "components": {
    "db": {
      "status": "UP"
    },
    "kafka": {
      "status": "DOWN",
      "details": {
        "error": "org.apache.kafka.common.errors.TimeoutException: Failed to get offsets by times in 30000ms"
      }
    },
    "ping": {
      "status": "UP"
    }
  }
}
```

### 1.2 Metrics Endpoint

**Endpoint**: `GET /actuator/metrics`

**Example Request**:
```bash
# List all available metrics
curl http://localhost:8081/actuator/metrics

# Get specific metric (JVM memory)
curl http://localhost:8081/actuator/metrics/jvm.memory.used

# Get database connection pool metrics
curl http://localhost:8081/actuator/metrics/hikaricp.connections.active
```

**Example Response** (Database Connection Pool):
```json
{
  "name": "hikaricp.connections.active",
  "description": "Active connections",
  "baseUnit": "connections",
  "measurements": [
    {
      "statistic": "VALUE",
      "value": 3.0
    }
  ],
  "availableTags": [
    {
      "tag": "pool",
      "values": ["HikariPool-1"]
    }
  ]
}
```

**Use Case**: Monitor connection pool saturation during high load
- Normal: 2-5 active connections
- High load: 15-20 active connections (pool size = 20)
- **Alert**: If consistently at max (20), need to increase pool size

---

## 2. Autonomous Agent Metrics

### 2.1 Traffic Agent Status

**Endpoint**: `GET /api/agent/traffic/status`

**Code Implementation**:
```java
@GetMapping("/status")
public ResponseEntity<AgentStats> getStatus() {
    AgentStats stats = trafficAgent.getStats();
    return ResponseEntity.ok(stats);
}

// TrafficAgent.java
public AgentStats getStats() {
    return new AgentStats(
        agentId,                                    // "traffic-agent-1"
        running.get() ? "RUNNING" : "STOPPED",      // Current state
        currentPattern,                             // STEADY/SPIKE/WAVE
        operationsPerSecond,                        // Target ops/sec
        totalOperations.get(),                      // Total operations
        successfulOperations.get(),                 // Success count
        failedOperations.get(),                     // Failure count
        startTime,                                  // Agent start time
        pauseTime,                                  // Last pause time
        paused.get()                               // Paused flag
    );
}
```

**Example Request**:
```bash
curl http://localhost:8081/api/agent/traffic/status | jq
```

**Example Response**:
```json
{
  "agentId": "traffic-agent-1",
  "status": "RUNNING",
  "pattern": "STEADY",
  "operationsPerSecond": 10,
  "totalOperations": 5428,
  "successfulOperations": 5426,
  "failedOperations": 2,
  "startTime": "2025-11-25T10:30:15.234",
  "uptime": "PT8M32S",
  "successRate": 99.96,
  "throughput": 10.6
}
```

**Key Metrics**:
- `successRate`: 99.96% (nearly all operations succeed)
- `throughput`: 10.6 ops/sec (actual vs 10 target = healthy)
- `failedOperations`: 2 (minimal failures acceptable)

### 2.2 Fulfillment Agent Status

**Endpoint**: `GET /api/agent/fulfillment/status`

**Code Implementation**:
```java
@GetMapping("/status")
public ResponseEntity<AgentStats> getStatus() {
    AgentStats stats = fulfillmentAgent.getStats();
    return ResponseEntity.ok(stats);
}

// FulfillmentAgent.java
public AgentStats getStats() {
    return new AgentStats(
        agentId,                                         // "fulfillment-agent-1"
        running.get() ? "RUNNING" : "STOPPED",           // Current state
        paused.get(),                                    // Paused flag
        startTime,                                       // Start timestamp
        pauseTime,                                       // Pause timestamp
        processingDelayMs,                               // Configured delay
        batchSize,                                       // Batch size
        pollingIntervalSeconds,                          // Polling interval
        ordersProcessed.get(),                           // Total processed
        ordersConfirmed.get(),                           // CONFIRMED count
        ordersShipped.get(),                             // SHIPPED count
        ordersDelivered.get(),                           // DELIVERED count
        ordersFailed.get(),                              // Failed count
        getBacklogCount(),                               // Current backlog
        ordersProcessed.get() > 0 ? 
            totalProcessingTimeMs.get() / ordersProcessed.get() : 0,  // Avg latency
        getUptimeSeconds()                               // Uptime
    );
}
```

**Example Request**:
```bash
curl http://localhost:8081/api/agent/fulfillment/status | jq
```

**Example Response** (Healthy System):
```json
{
  "agentId": "fulfillment-agent-1",
  "status": "RUNNING",
  "paused": false,
  "startTime": "2025-11-25T10:30:20.123",
  "uptime": "PT8M27S",
  "configuration": {
    "processingDelayMs": 100,
    "batchSize": 50,
    "pollingIntervalSeconds": 1
  },
  "metrics": {
    "ordersProcessed": 5142,
    "ordersConfirmed": 5140,
    "ordersShipped": 5138,
    "ordersDelivered": 5135,
    "ordersFailed": 7,
    "backlogCount": 12,
    "avgProcessingTimeMs": 389,
    "fulfillmentRate": 99.86,
    "throughput": 21.8
  }
}
```

**Example Response** (Performance Degradation - Backlog Building):
```json
{
  "agentId": "fulfillment-agent-1",
  "status": "RUNNING",
  "paused": false,
  "startTime": "2025-11-25T14:15:30.456",
  "uptime": "PT12M18S",
  "configuration": {
    "processingDelayMs": 100,
    "batchSize": 50,
    "pollingIntervalSeconds": 1
  },
  "metrics": {
    "ordersProcessed": 3842,
    "ordersConfirmed": 3840,
    "ordersShipped": 3835,
    "ordersDelivered": 3830,
    "ordersFailed": 12,
    "backlogCount": 1547,     // ⚠️ BACKLOG GROWING!
    "avgProcessingTimeMs": 892,  // ⚠️ LATENCY INCREASING!
    "fulfillmentRate": 71.24,    // ⚠️ RATE DROPPED!
    "throughput": 8.3            // ⚠️ THROUGHPUT DEGRADED!
  }
}
```

**Key Indicators**:
- ✅ **Healthy**: backlog < 50, fulfillmentRate > 95%, throughput ~22 ops/sec
- ⚠️ **Degraded**: backlog 100-1000, fulfillmentRate 70-90%, throughput < 15 ops/sec
- 🚨 **Critical**: backlog > 1000, fulfillmentRate < 50%, throughput < 5 ops/sec

---

## 3. Kafka Performance Metrics (via Events)

### 3.1 Performance Event Publishing

**Code Implementation**:
```java
// TrafficAgent.java - Publishes metrics every cycle
private void publishMetricsEvent(long total, long success, long failed) {
    double successRate = total > 0 ? (success * 100.0 / total) : 0.0;
    String details = String.format(
        "Agent %s: Total=%d, Success=%d (%.1f%%), Failed=%d",
        agentId, total, success, successRate, failed
    );
    
    PerformanceEvent event = new PerformanceEvent();
    event.setEventType("AGENT_METRICS");
    event.setServiceSource("traffic-agent");
    event.setTestType(agentId);
    event.setNumberOfOperations((int) total);
    event.setAction(PerformanceEvent.PerformanceAction.SYSTEM_HEALTHY);
    event.setDetails(details);
    
    // Publish to performance-metrics topic
    eventPublisherService.publishPerformanceEvent(event);
}
```

**PerformanceEvent Structure**:
```java
public class PerformanceEvent extends BaseEvent {
    private String testType;                  // "traffic-agent-1"
    private PerformanceAction action;         // SYSTEM_HEALTHY, PERFORMANCE_DEGRADATION
    private Integer numberOfOperations;       // Total operations
    private Integer concurrencyLevel;         // Concurrency
    private Long durationMs;                  // Test duration
    private Double throughput;                // Ops/sec
    private String details;                   // Human-readable summary
}
```

### 3.2 Consuming Performance Metrics

**Consumer Example** (for monitoring dashboard):
```java
@KafkaListener(topics = "performance-metrics", groupId = "monitoring-dashboard")
public void consumePerformanceMetric(PerformanceEvent event) {
    log.info("Performance Metric: {}", event.getDetails());
    
    // Example: Agent traffic-agent-1: Total=5428, Success=5426 (99.96%), Failed=2
    
    // Parse metrics
    double successRate = calculateSuccessRate(event);
    
    // Check for performance degradation
    if (successRate < 95.0) {
        log.warn("⚠️ Performance degradation detected: {}%", successRate);
        alertService.sendAlert(
            "Performance Degradation",
            "Success rate dropped to " + successRate + "%"
        );
    }
    
    // Store in time-series database for dashboards (e.g., Prometheus, InfluxDB)
    metricsStore.record(event.getTestType(), successRate, event.getThroughput());
}
```

**Example Kafka Event** (published to `performance-metrics` topic):
```json
{
  "eventId": "550e8400-e29b-41d4-a716-446655440000",
  "eventType": "AGENT_METRICS",
  "timestamp": "2025-11-25T10:38:47.234Z",
  "serviceSource": "traffic-agent",
  "testType": "traffic-agent-1",
  "action": "SYSTEM_HEALTHY",
  "numberOfOperations": 5428,
  "throughput": 10.6,
  "details": "Agent traffic-agent-1: Total=5428, Success=5426 (99.96%), Failed=2"
}
```

---

## 4. Kafka UI for Consumer Lag Monitoring

### 4.1 Kafka UI Access

**URL**: http://localhost:8080

**What You Can See**:
1. **Topics** - All Kafka topics with partition counts
2. **Consumer Groups** - Active consumers and their lag
3. **Messages** - Browse messages in topics
4. **Brokers** - Kafka cluster health

### 4.2 Consumer Lag Example

**Screenshot Description** (for your report):

```
Kafka UI - Consumer Groups Tab

┌─────────────────────────────────────────────────────────────────┐
│ Consumer Group: fulfillment-agent-group                         │
├─────────────────────────────────────────────────────────────────┤
│ Topic              Partition  Offset  Lag   Status              │
├─────────────────────────────────────────────────────────────────┤
│ order-events       0          15,234  0     ✓ Healthy           │
│ order-events       1          15,189  0     ✓ Healthy           │
│ order-events       2          15,210  0     ✓ Healthy           │
├─────────────────────────────────────────────────────────────────┤
│ Total Lag: 0 messages                                           │
└─────────────────────────────────────────────────────────────────┘

Consumer Group: notification-group
┌─────────────────────────────────────────────────────────────────┐
│ Topic              Partition  Offset  Lag   Status              │
├─────────────────────────────────────────────────────────────────┤
│ order-events       0          15,234  0     ✓ Healthy           │
│ order-events       1          15,189  0     ✓ Healthy           │
│ order-events       2          15,210  0     ✓ Healthy           │
├─────────────────────────────────────────────────────────────────┤
│ Total Lag: 0 messages                                           │
└─────────────────────────────────────────────────────────────────┘
```

**Interpretation**:
- **Lag = 0**: Consumers are keeping up with producers (healthy)
- **Lag > 0 but stable**: Temporary burst, but consumers catching up
- **Lag growing**: Performance degradation, need investigation

### 4.3 During Fault Injection (Kafka Crash)

**Before Kafka Crash**:
```
Consumer Group: fulfillment-agent-group
Lag: 0 messages (healthy)
```

**During Kafka Downtime** (49 seconds):
```
Consumer Group: fulfillment-agent-group
Status: DISCONNECTED
Last Offset: 15,234
Messages accumulated during outage: ~490 (10 ops/sec × 49s)
```

**After Kafka Recovery** (16 seconds later):
```
Consumer Group: fulfillment-agent-group
Partition 0: Offset 15,234 → 15,398, Lag: 164
Partition 1: Offset 15,189 → 15,352, Lag: 163
Partition 2: Offset 15,210 → 15,373, Lag: 163
Total Lag: 490 messages (processing backlog...)

[10 seconds later]
Total Lag: 0 messages (✓ RECOVERED)
```

**Operators Can See**:
1. ✅ Consumer reconnected after Kafka restart
2. ✅ Backlog being processed (lag decreasing)
3. ✅ Full recovery achieved (lag = 0)

---

## 5. Real-World Monitoring Scenario: Fault Recovery

### Scenario: Kafka Broker Crash During Production Load

**Timeline**: Show how operators use observability to monitor recovery

#### T+0s: Normal Operation

```bash
# Check system health
$ curl http://localhost:8081/actuator/health | jq .status
"UP"

# Check traffic agent
$ curl http://localhost:8081/api/agent/traffic/status | jq .successRate
99.96

# Check fulfillment agent
$ curl http://localhost:8081/api/agent/fulfillment/status | jq .metrics.backlogCount
12

# Check Kafka lag
Kafka UI shows: Total Lag = 0 messages
```

**Observation**: System healthy, all metrics normal

---

#### T+10s: Kafka Crash (Fault Injection)

```bash
# Kafka stops responding
$ curl http://localhost:8081/actuator/health | jq
{
  "status": "DOWN",
  "components": {
    "kafka": {
      "status": "DOWN",
      "details": {
        "error": "TimeoutException"
      }
    }
  }
}

# Traffic agent continues (async pattern)
$ curl http://localhost:8081/api/agent/traffic/status | jq
{
  "status": "RUNNING",
  "successRate": 100.0,  # ✓ API still works!
  "totalOperations": 5528
}

# Fulfillment agent can't process (Kafka down)
$ curl http://localhost:8081/api/agent/fulfillment/status | jq
{
  "status": "RUNNING",
  "metrics": {
    "backlogCount": 112,  # ⚠️ Backlog growing
    "throughput": 0.0     # ⚠️ No processing
  }
}
```

**Observation**: 
- ✅ Application still accepting requests (async event publishing)
- ⚠️ Fulfillment stopped (no Kafka to consume from)
- ⚠️ Backlog accumulating

---

#### T+49s: Kafka Restarted

```bash
# Kafka recovers
$ curl http://localhost:8081/actuator/health | jq .status
"UP"  # ✓ System detects Kafka is back

# Check Kafka UI
Consumer Group: fulfillment-agent-group
Total Lag: 490 messages  # ⚠️ Backlog to process
Status: ACTIVE (reconnected)
```

**Observation**: Kafka recovered, consumers reconnecting

---

#### T+59s: Recovery in Progress (10 seconds after restart)

```bash
# Fulfillment agent processing backlog
$ curl http://localhost:8081/api/agent/fulfillment/status | jq
{
  "status": "RUNNING",
  "metrics": {
    "backlogCount": 212,     # Still elevated
    "throughput": 18.5,      # ✓ Processing resumed!
    "fulfillmentRate": 85.3  # ⚠️ Recovering
  }
}

# Kafka UI shows lag decreasing
Total Lag: 245 messages (↓ from 490)
```

**Observation**: System recovering, processing backlog

---

#### T+79s: Full Recovery (30 seconds after restart)

```bash
# System returned to steady state
$ curl http://localhost:8081/actuator/health | jq .status
"UP"

$ curl http://localhost:8081/api/agent/fulfillment/status | jq
{
  "status": "RUNNING",
  "metrics": {
    "backlogCount": 8,       # ✓ Back to normal
    "throughput": 22.1,      # ✓ Normal throughput
    "fulfillmentRate": 98.5  # ✓ Healthy rate
  }
}

# Kafka UI
Total Lag: 0 messages  # ✓ FULLY RECOVERED
```

**Observation**: 
- ✅ System returned to healthy steady state
- ✅ All backlogs cleared
- ✅ Performance metrics normal

---

### Key Observability Signals Used

| Signal | Source | What It Shows |
|--------|--------|---------------|
| `actuator/health` | Spring Actuator | Kafka/DB connectivity |
| `agent/traffic/status` | Traffic Agent API | Request success rate |
| `agent/fulfillment/status` | Fulfillment Agent API | Backlog, throughput, latency |
| `performance-metrics` topic | Kafka Events | Time-series metrics |
| Kafka UI Consumer Lag | Kafka Admin | Message backlog |

**Operator Actions**:
1. ✅ Detected failure via health endpoint (status: DOWN)
2. ✅ Verified async pattern working (traffic agent still succeeds)
3. ✅ Monitored backlog growth via fulfillment agent API
4. ✅ Confirmed recovery via Kafka UI (lag decreasing)
5. ✅ Validated steady state via all metrics returning to normal

---

## 6. Complete Monitoring Dashboard Example

### Dashboard Layout (for your report diagram)

```
┌────────────────────────────────────────────────────────────────────┐
│                     SYSTEM HEALTH DASHBOARD                        │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  System Status: ● UP                    Last Updated: 10:38:47    │
│                                                                    │
│  ┌─────────────────────┐  ┌─────────────────────┐                │
│  │ Database            │  │ Kafka               │                │
│  │ Status: ● UP        │  │ Status: ● UP        │                │
│  │ Connections: 3/20   │  │ Broker: healthy     │                │
│  └─────────────────────┘  └─────────────────────┘                │
│                                                                    │
├────────────────────────────────────────────────────────────────────┤
│                    AGENT PERFORMANCE METRICS                       │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  Traffic Agent                                                    │
│  ├─ Status: RUNNING                                               │
│  ├─ Operations: 5,428 total (5,426 success, 2 failed)            │
│  ├─ Success Rate: 99.96%     Throughput: 10.6 ops/sec           │
│  └─ Pattern: STEADY @ 10 ops/sec                                 │
│                                                                    │
│  Fulfillment Agent                                                │
│  ├─ Status: RUNNING                                               │
│  ├─ Processed: 5,142 orders (5,135 delivered)                    │
│  ├─ Fulfillment Rate: 99.86%                                     │
│  ├─ Throughput: 21.8 orders/sec                                  │
│  ├─ Avg Latency: 389ms/order                                     │
│  └─ Backlog: 12 pending orders                                   │
│                                                                    │
├────────────────────────────────────────────────────────────────────┤
│                    KAFKA CONSUMER LAG                              │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  fulfillment-agent-group                                          │
│  ├─ order-events [0]: Lag = 0                                    │
│  ├─ order-events [1]: Lag = 0                                    │
│  └─ order-events [2]: Lag = 0                                    │
│                                                                    │
│  notification-group                                               │
│  ├─ order-events [0]: Lag = 0                                    │
│  ├─ order-events [1]: Lag = 0                                    │
│  └─ order-events [2]: Lag = 0                                    │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘

All systems healthy ✓
```

---

## 7. Code Snippets for Report

### Example 1: Health Check Monitoring Code

```java
// Operators can programmatically monitor health
@Service
public class HealthMonitoringService {
    
    @Autowired
    private RestTemplate restTemplate;
    
    @Scheduled(fixedRate = 5000) // Check every 5 seconds
    public void monitorHealth() {
        try {
            ResponseEntity<Map> response = restTemplate.getForEntity(
                "http://localhost:8081/actuator/health",
                Map.class
            );
            
            String status = (String) response.getBody().get("status");
            
            if ("DOWN".equals(status)) {
                log.error("🚨 ALERT: System health is DOWN");
                alertService.sendCriticalAlert("System Down");
            } else {
                log.info("✓ System healthy: {}", status);
            }
            
        } catch (Exception e) {
            log.error("🚨 ALERT: Cannot reach health endpoint", e);
        }
    }
}
```

### Example 2: Agent Metrics Monitoring Code

```java
// Monitor agent performance and detect degradation
@Service
public class AgentMonitoringService {
    
    @Autowired
    private RestTemplate restTemplate;
    
    @Scheduled(fixedRate = 10000) // Check every 10 seconds
    public void monitorFulfillmentAgent() {
        try {
            ResponseEntity<AgentStats> response = restTemplate.getForEntity(
                "http://localhost:8081/api/agent/fulfillment/status",
                AgentStats.class
            );
            
            AgentStats stats = response.getBody();
            
            // Check for backlog growth
            if (stats.getMetrics().getBacklogCount() > 1000) {
                log.warn("⚠️ ALERT: Large backlog detected: {} orders",
                        stats.getMetrics().getBacklogCount());
                alertService.sendWarning("Backlog Growing", 
                    "Current backlog: " + stats.getMetrics().getBacklogCount());
            }
            
            // Check fulfillment rate
            if (stats.getMetrics().getFulfillmentRate() < 90.0) {
                log.error("🚨 ALERT: Fulfillment rate dropped to {}%",
                         stats.getMetrics().getFulfillmentRate());
                alertService.sendCriticalAlert("Low Fulfillment Rate");
            }
            
            // Check throughput
            if (stats.getMetrics().getThroughput() < 15.0) {
                log.warn("⚠️ ALERT: Throughput degraded to {} ops/sec",
                        stats.getMetrics().getThroughput());
            }
            
            log.info("Fulfillment Agent: backlog={}, rate={}%, throughput={} ops/sec",
                    stats.getMetrics().getBacklogCount(),
                    stats.getMetrics().getFulfillmentRate(),
                    stats.getMetrics().getThroughput());
            
        } catch (Exception e) {
            log.error("Failed to monitor fulfillment agent", e);
        }
    }
}
```

### Example 3: Kafka Performance Event Consumer

```java
// Consume and analyze performance metrics from Kafka
@Service
public class PerformanceMetricsConsumer {
    
    @KafkaListener(
        topics = "performance-metrics",
        groupId = "monitoring-dashboard"
    )
    public void consumePerformanceMetric(PerformanceEvent event) {
        log.info("📊 Performance Metric: {}", event.getDetails());
        
        // Extract metrics
        double successRate = calculateSuccessRate(event);
        double throughput = event.getThroughput();
        
        // Store in time-series database for visualization
        metricsDatabase.record(
            event.getTestType(),
            event.getTimestamp(),
            successRate,
            throughput
        );
        
        // Detect performance degradation
        if (successRate < 95.0) {
            log.warn("⚠️ Performance degradation: success rate = {}%", 
                    successRate);
            
            alertService.sendWarning(
                "Performance Degradation",
                String.format("Success rate dropped to %.2f%%", successRate)
            );
        }
        
        // Detect healthy recovery
        if (event.getAction() == PerformanceAction.SYSTEM_HEALTHY) {
            log.info("✓ System healthy: {}", event.getDetails());
        }
    }
}
```

---

## Summary: What to Show in Your Report

### 1. **Diagram**: Observability Architecture
```
┌──────────────┐      ┌──────────────┐      ┌──────────────┐
│   Traffic    │─────▶│   Kafka      │─────▶│  Monitoring  │
│   Agent      │      │   Topics     │      │  Dashboard   │
└──────────────┘      └──────────────┘      └──────────────┘
       │                                            ▲
       │ Publish metrics                            │
       ▼                                            │
┌──────────────┐                                   │
│ Performance  │───────────────────────────────────┘
│ Metrics      │         Consume events
│ Topic        │
└──────────────┘

┌──────────────┐      ┌──────────────┐
│ Fulfillment  │      │   Spring     │
│ Agent        │─────▶│   Actuator   │
└──────────────┘      │   /health    │
       │              └──────────────┘
       │ REST API            ▲
       ▼                     │ HTTP GET
┌──────────────┐            │
│ Agent Status │────────────┘
│ Endpoints    │    Poll status
└──────────────┘
```

### 2. **Screenshot**: Kafka UI Consumer Lag (Healthy vs During Fault)

### 3. **Code Snippet**: Agent Status API Response
```json
{
  "fulfillmentRate": 99.86,
  "backlogCount": 12,
  "throughput": 21.8
}
```

### 4. **Table**: Monitoring Timeline During Fault Recovery
| Time | Health | Backlog | Kafka Lag | Status |
|------|--------|---------|-----------|--------|
| T+0s | UP | 12 | 0 | ✓ Healthy |
| T+10s | DOWN | 112 | N/A | ⚠️ Kafka crashed |
| T+49s | UP | 490 | 490 | ⚠️ Recovering |
| T+79s | UP | 8 | 0 | ✓ Recovered |

### 5. **Narrative**: "Operators use Spring Actuator's `/actuator/health` endpoint to detect the Kafka broker failure (status: DOWN), then monitor the fulfillment agent's backlog growth via `/api/agent/fulfillment/status`. After Kafka recovery, they verify the system returned to steady state by observing: (1) health status returns to UP, (2) Kafka consumer lag drops to 0 in Kafka UI, and (3) fulfillment rate climbs back above 95%."

---

**Document Generated**: November 25, 2025  
**Related Files**: 
- `TrafficAgent.java` (line 540: `publishMetricsEvent()`)
- `FulfillmentAgent.java` (line 500: `getStats()`)
- `PerformanceEvent.java` (event structure)
- `application.properties` (actuator configuration)
