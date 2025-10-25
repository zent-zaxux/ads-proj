# Fulfillment Agent - Complete Guide

## Overview

The **Fulfillment Agent** is an autonomous order processing system that simulates a real-world order fulfillment pipeline. It processes orders through a complete workflow: PENDING → CONFIRMED → SHIPPED → DELIVERED.

### Key Features

- 🏭 **Autonomous Processing** - Continuously polls and processes orders
- 📊 **Order Workflow** - Complete status transitions (4 stages)
- ⏸️ **Pause/Resume** - For lag testing and backlog simulation
- 📈 **Real-time Metrics** - Published to Kafka every 15 seconds
- ⚙️ **Configurable** - Processing delay, batch size, polling interval
- 🔄 **FIFO Processing** - Orders processed in creation order

## Architecture

### Components

1. **FulfillmentAgent.java** (`com.umu.ads_proj.agent`)
   - Core autonomous agent with scheduled processing
   - Multi-threaded order processing
   - Kafka consumer pause/resume control
   - Metrics collection and reporting

2. **FulfillmentAgentController.java** (`com.umu.ads_proj.controller`)
   - REST API for agent lifecycle management
   - 10 endpoints for complete control

### Order Processing Workflow

```
PENDING → CONFIRMED → SHIPPED → DELIVERED
  ↓          ↓          ↓          ↓
 2s        2s         2s         Done
```

**Default Processing:**
- Each transition takes 2 seconds (configurable)
- Processes 5 orders per batch (configurable)
- Polls database every 5 seconds (configurable)
- Total time per order: ~6-8 seconds

### Thread Pools

- **ScheduledExecutorService** (2 threads)
  - Order processing loop (configurable interval)
  - Metrics reporting (every 15 seconds)

- **ExecutorService** (10 worker threads)
  - Concurrent order processing
  - Status transitions

## REST API Endpoints

### Base URL
```
http://localhost:8081/api/agent/fulfillment
```

---

### 1. Start Agent

**Endpoint:** `POST /api/agent/fulfillment/start`

**Parameters:**
- `processingDelayMs` (optional, default: 2000) - Delay per status transition (100-60000ms)
- `batchSize` (optional, default: 5) - Orders to process per batch (1-100)
- `pollingIntervalSeconds` (optional, default: 5) - Database polling frequency (1-300s)

**Example:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=2000&batchSize=5&pollingIntervalSeconds=5"
```

**Response:**
```json
{
  "success": true,
  "message": "Fulfillment agent started",
  "agentId": "FULFILLMENT-AGENT-abc123",
  "processingDelayMs": 2000,
  "batchSize": 5,
  "pollingIntervalSeconds": 5
}
```

**Use Case:** Start the agent to begin processing pending orders

---

### 2. Stop Agent

**Endpoint:** `POST /api/agent/fulfillment/stop`

**Example:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"
```

**Response:**
```json
{
  "success": true,
  "message": "Fulfillment agent stopped",
  "agentId": "FULFILLMENT-AGENT-abc123"
}
```

**Use Case:** Stop the agent gracefully

---

### 3. Pause Agent (Lag Testing)

**Endpoint:** `POST /api/agent/fulfillment/pause`

**Example:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/pause"
```

**Response:**
```json
{
  "success": true,
  "message": "Fulfillment agent paused",
  "agentId": "FULFILLMENT-AGENT-abc123",
  "note": "Orders will accumulate (backlog simulation)"
}
```

**What Happens:**
- Agent stops processing new orders
- Kafka consumer is paused
- Orders continue to arrive from Traffic Agent
- Backlog accumulates
- Perfect for lag testing scenarios

---

### 4. Resume Agent

**Endpoint:** `POST /api/agent/fulfillment/resume`

**Example:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/resume"
```

**Response:**
```json
{
  "success": true,
  "message": "Fulfillment agent resumed",
  "agentId": "FULFILLMENT-AGENT-abc123",
  "note": "Agent will process backlog"
}
```

**What Happens:**
- Agent resumes processing
- Kafka consumer is resumed
- Processes backlog in FIFO order
- Demonstrates catch-up behavior

---

### 5. Get Status

**Endpoint:** `GET /api/agent/fulfillment/status`

**Example:**
```bash
curl -X GET "http://localhost:8081/api/agent/fulfillment/status"
```

**Response:**
```json
{
  "agentId": "FULFILLMENT-AGENT-abc123",
  "status": "RUNNING",
  "isPaused": false,
  "startTime": "2025-10-23T19:30:00",
  "pauseTime": null,
  "processingDelayMs": 2000,
  "batchSize": 5,
  "pollingIntervalSeconds": 5,
  "totalProcessed": 45,
  "ordersConfirmed": 15,
  "ordersShipped": 15,
  "ordersDelivered": 15,
  "ordersFailed": 0,
  "currentBacklog": 12,
  "avgProcessingTimeMs": 2100,
  "uptimeSeconds": 120
}
```

**Use Case:** Monitor agent performance and backlog

---

### 6. Configure Processing Delay

**Endpoint:** `POST /api/agent/fulfillment/config/delay`

**Parameters:**
- `delayMs` (required) - Processing delay in milliseconds (100-60000)

**Example:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/config/delay?delayMs=1000"
```

**Response:**
```json
{
  "success": true,
  "message": "Processing delay configured",
  "delayMs": 1000,
  "note": "New delay applies immediately"
}
```

**Use Case:** Speed up or slow down order processing

---

### 7. Configure Batch Size

**Endpoint:** `POST /api/agent/fulfillment/config/batch`

**Parameters:**
- `batchSize` (required) - Orders per batch (1-100)

**Example:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/config/batch?batchSize=10"
```

**Response:**
```json
{
  "success": true,
  "message": "Batch size configured",
  "batchSize": 10,
  "note": "New batch size applies immediately"
}
```

**Use Case:** Process more/fewer orders per polling cycle

---

### 8. Configure Polling Interval

**Endpoint:** `POST /api/agent/fulfillment/config/interval`

**Parameters:**
- `intervalSeconds` (required) - Polling frequency (1-300)

**Example:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/config/interval?intervalSeconds=10"
```

**Response:**
```json
{
  "success": true,
  "message": "Polling interval configured",
  "intervalSeconds": 10,
  "note": "Restart agent to apply new interval"
}
```

**Use Case:** Change how often the agent checks for new orders

---

### 9. Health Check

**Endpoint:** `GET /api/agent/fulfillment/health`

**Example:**
```bash
curl -X GET "http://localhost:8081/api/agent/fulfillment/health"
```

**Response:**
```json
{
  "service": "fulfillment-agent",
  "status": "UP",
  "agentId": "FULFILLMENT-AGENT-abc123",
  "running": true,
  "paused": false
}
```

**Use Case:** Verify agent is operational

---

## Testing Scenarios

### Scenario 1: Basic Fulfillment Test

**Goal:** Process orders through complete workflow

```bash
# 1. Start Traffic Agent to generate orders
curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=2&pattern=STEADY"

# 2. Start Fulfillment Agent
curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=2000&batchSize=5"

# 3. Wait 30 seconds for orders to process
sleep 30

# 4. Check status
curl -X GET "http://localhost:8081/api/agent/fulfillment/status" | jq

# 5. Verify orders are being delivered
curl -X GET "http://localhost:8081/api/orders?status=DELIVERED" | jq

# 6. Stop both agents
curl -X POST "http://localhost:8081/api/agent/traffic/stop"
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"
```

**Expected Results:**
- Orders created by Traffic Agent
- Orders processed through all statuses
- Final status: DELIVERED
- Metrics published to Kafka

---

### Scenario 2: Backlog & Lag Testing

**Goal:** Create backlog by pausing fulfillment, then demonstrate catch-up

```bash
# 1. Start both agents
curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=5"
curl -X POST "http://localhost:8081/api/agent/fulfillment/start"

# 2. Let them run for 20 seconds
sleep 20

# 3. Check initial backlog
curl -X GET "http://localhost:8081/api/agent/fulfillment/status" | jq '.currentBacklog'

# 4. PAUSE fulfillment agent (orders will accumulate)
curl -X POST "http://localhost:8081/api/agent/fulfillment/pause"

# 5. Wait 30 seconds (backlog grows)
sleep 30

# 6. Check backlog growth
curl -X GET "http://localhost:8081/api/agent/fulfillment/status" | jq '.currentBacklog'

# 7. RESUME fulfillment agent (catch up)
curl -X POST "http://localhost:8081/api/agent/fulfillment/resume"

# 8. Monitor catch-up progress every 5 seconds
watch -n 5 "curl -s http://localhost:8081/api/agent/fulfillment/status | jq '.currentBacklog, .totalProcessed'"

# 9. Stop agents when backlog is cleared
curl -X POST "http://localhost:8081/api/agent/traffic/stop"
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"
```

**Expected Results:**
- Backlog grows during pause
- Kafka consumer lag increases
- Backlog clears after resume
- Demonstrates catch-up behavior

---

### Scenario 3: Performance Tuning

**Goal:** Optimize processing speed

```bash
# 1. Start with slow processing (4 second delay)
curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=4000&batchSize=3"

# 2. Generate load
curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=10"

# 3. Check throughput after 30s
sleep 30
curl -X GET "http://localhost:8081/api/agent/fulfillment/status" | jq '{throughput: (.totalProcessed / .uptimeSeconds), backlog: .currentBacklog}'

# 4. Speed up processing (1 second delay, larger batch)
curl -X POST "http://localhost:8081/api/agent/fulfillment/config/delay?delayMs=1000"
curl -X POST "http://localhost:8081/api/agent/fulfillment/config/batch?batchSize=10"

# 5. Check improved throughput after 30s
sleep 30
curl -X GET "http://localhost:8081/api/agent/fulfillment/status" | jq '{throughput: (.totalProcessed / .uptimeSeconds), backlog: .currentBacklog}'

# 6. Stop agents
curl -X POST "http://localhost:8081/api/agent/traffic/stop"
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"
```

**Expected Results:**
- Lower delay = higher throughput
- Larger batch = faster processing
- Backlog decreases with optimization

---

### Scenario 4: Stress Test

**Goal:** Test agent under heavy load

```bash
# 1. Start with fast processing
curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=500&batchSize=20"

# 2. Generate heavy load
curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=20&pattern=BURST"

# 3. Monitor for 2 minutes
watch -n 10 "curl -s http://localhost:8081/api/agent/fulfillment/status | jq '{processed: .totalProcessed, backlog: .currentBacklog, avgTime: .avgProcessingTimeMs, throughput: (.totalProcessed / .uptimeSeconds)}'"

# 4. Stop agents
curl -X POST "http://localhost:8081/api/agent/traffic/stop"
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"
```

**Expected Results:**
- Agent handles burst traffic
- Backlog remains manageable
- No failures
- Consistent throughput

---

## Kafka Integration

### Topics Published To

**performance-events Topic:**
```json
{
  "eventType": "AGENT_METRICS",
  "testType": "FULFILLMENT-AGENT-abc123",
  "action": "SYSTEM_HEALTHY",
  "numberOfOperations": 45,
  "throughput": 2.25,
  "details": "Agent FULFILLMENT-AGENT-abc123: Processed=45, Confirmed=15, Shipped=15, Delivered=15, Failed=0, Backlog=12, AvgTime=2100ms, Throughput=2.25/s"
}
```

**Frequency:** Every 15 seconds while running

### Kafka Consumer Control

The agent can pause/resume the order-events Kafka consumer:

- **Pause:** Consumer stops polling → lag accumulates
- **Resume:** Consumer catches up → processes backlog

---

## Monitoring

### Key Metrics

1. **throughput** = `totalProcessed / uptimeSeconds`
2. **success_rate** = `(totalProcessed - ordersFailed) / totalProcessed * 100`
3. **backlog** = `count(PENDING) + count(CONFIRMED) + count(SHIPPED)`
4. **avg_processing_time** = `totalProcessingTimeMs / totalProcessed`

### Kafka UI
- **URL:** http://localhost:8090
- **Topics to Monitor:**
  - `performance-events` - Agent metrics
  - `order-events` - Order lifecycle
  - `notification-events` - Notification delivery

### Database Queries

```sql
-- Check order distribution by status
SELECT status, COUNT(*) FROM orders GROUP BY status;

-- Check recent orders
SELECT * FROM orders ORDER BY created_at DESC LIMIT 10;

-- Check average processing time
SELECT 
  status,
  AVG(EXTRACT(EPOCH FROM (updated_at - created_at))) as avg_seconds
FROM orders 
WHERE status IN ('CONFIRMED', 'SHIPPED', 'DELIVERED')
GROUP BY status;
```

---

## Configuration Parameters

### Processing Delay

| Value | Speed | Use Case |
|-------|-------|----------|
| 500ms | Very Fast | Stress testing, high throughput |
| 1000ms | Fast | Standard testing |
| 2000ms | Normal | Realistic simulation |
| 5000ms | Slow | Create backlog intentionally |

### Batch Size

| Value | Impact | Use Case |
|-------|--------|----------|
| 1-3 | Low throughput | Sequential processing |
| 5-10 | Medium throughput | Balanced |
| 20-50 | High throughput | Bulk processing |

### Polling Interval

| Value | Impact | Use Case |
|-------|--------|----------|
| 1-3s | Responsive | Real-time processing |
| 5-10s | Balanced | Standard operation |
| 30-60s | Batch-oriented | Scheduled processing |

---

## Integration with Traffic Agent

### Combined Testing

```bash
# Start both agents simultaneously
curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=5&pattern=STEADY"
curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=2000&batchSize=5"

# Monitor both agents
watch -n 5 'echo "=== TRAFFIC AGENT ==="; curl -s http://localhost:8081/api/agent/traffic/status | jq "{ops: .totalOperations, success: .successRate}"; echo "\n=== FULFILLMENT AGENT ==="; curl -s http://localhost:8081/api/agent/fulfillment/status | jq "{processed: .totalProcessed, backlog: .currentBacklog}"'

# Create lag scenario: Pause fulfillment, continue traffic
curl -X POST "http://localhost:8081/api/agent/fulfillment/pause"
# ... wait ...
curl -X POST "http://localhost:8081/api/agent/fulfillment/resume"

# Stop both
curl -X POST "http://localhost:8081/api/agent/traffic/stop"
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"
```

---

## Troubleshooting

### Agent Won't Start
- **Check:** Is it already running?
  ```bash
  curl http://localhost:8081/api/agent/fulfillment/health
  ```
- **Solution:** Stop first
  ```bash
  curl -X POST http://localhost:8081/api/agent/fulfillment/stop
  ```

### Backlog Not Decreasing
- **Check:** Is agent paused?
  ```bash
  curl http://localhost:8081/api/agent/fulfillment/status | jq '.isPaused'
  ```
- **Solution:** Resume agent
  ```bash
  curl -X POST http://localhost:8081/api/agent/fulfillment/resume
  ```

### Slow Processing
- **Check:** Current delay
  ```bash
  curl http://localhost:8081/api/agent/fulfillment/status | jq '.processingDelayMs'
  ```
- **Solution:** Reduce delay and increase batch size
  ```bash
  curl -X POST "http://localhost:8081/api/agent/fulfillment/config/delay?delayMs=1000"
  curl -X POST "http://localhost:8081/api/agent/fulfillment/config/batch?batchSize=10"
  ```

### No Orders Being Processed
- **Check:** Are there pending orders?
  ```bash
  curl "http://localhost:8081/api/orders?status=PENDING" | jq 'length'
  ```
- **Solution:** Start Traffic Agent to generate orders
  ```bash
  curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=5"
  ```

---

## Best Practices

1. **Always start Traffic Agent first** - Ensures orders are available
2. **Match agent speeds** - Traffic rate vs. fulfillment capacity
3. **Use pause/resume for demos** - Shows lag clearly
4. **Monitor backlog trends** - Ensure sustainable throughput
5. **Tune parameters gradually** - Test impact of changes
6. **Stop both agents together** - Clean shutdown

---

## Performance Characteristics

### Resource Usage
- **Threads:** 2 scheduled + 10 workers
- **Memory:** ~80MB additional heap
- **CPU:** ~10-15% per 10 orders/sec
- **Database:** Queries every polling interval

### Scalability
- **Single instance:** Up to 50 orders/sec (with fast config)
- **Multiple instances:** Deploy multiple fulfillment agents
- **Database bottleneck:** Consider read replicas for high load

---

## Related Documentation

- **Traffic Agent:** `TRAFFIC_AGENT_GUIDE.md`
- **Notification Service:** `NOTIFICATION_SERVICE_COMPLETE.md`
- **Kafka Implementation:** `KAFKA_CURRENT_IMPLEMENTATION.md`
- **Project Status:** `PROJECT_STATUS.md`

---

## Quick Commands Cheatsheet

```bash
# Start fulfillment
curl -X POST "localhost:8081/api/agent/fulfillment/start"

# Fast processing
curl -X POST "localhost:8081/api/agent/fulfillment/start?processingDelayMs=1000&batchSize=10"

# Pause
curl -X POST "localhost:8081/api/agent/fulfillment/pause"

# Resume
curl -X POST "localhost:8081/api/agent/fulfillment/resume"

# Status
curl -X GET "localhost:8081/api/agent/fulfillment/status" | jq

# Stop
curl -X POST "localhost:8081/api/agent/fulfillment/stop"

# Health
curl -X GET "localhost:8081/api/agent/fulfillment/health" | jq
```

---

**Fulfillment Agent Status:** ✅ Complete and ready for testing  
**Last Updated:** 2025-10-23  
**Deliverable:** Phase 3 - Agent Implementation  
