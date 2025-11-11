# Traffic Agent - Quick Reference Guide

## Overview

The **Traffic Agent** is an autonomous load generator that simulates realistic user traffic patterns. It's designed for:
- **Continuous load generation** with configurable rates
- **Lag testing** via pause/resume functionality
- **Performance monitoring** with real-time metrics
- **Multiple traffic patterns** for different testing scenarios

## Architecture

### Components

1. **TrafficAgent.java** (`com.umu.ads_proj.agent`)
   - Core autonomous agent with scheduling and execution
   - 5 operation types with weighted probabilities
   - Thread pools for concurrent execution
   - Metrics reporting to Kafka

2. **TrafficAgentController.java** (`com.umu.ads_proj.controller`)
   - REST API for agent lifecycle management
   - 9 endpoints for control and monitoring

### Operation Types (Weighted Probabilities)

- **CREATE_USER** (30%) - Create new users
- **CREATE_ORDER** (40%) - Place new orders
- **CREATE_PAYMENT** (10%) - Process payments
- **UPDATE_ORDER_STATUS** (15%) - Update order statuses
- **CANCEL_ORDER** (5%) - Cancel orders

### Traffic Patterns

- **STEADY** - Constant rate of operations
- **BURST** - Periodic bursts of traffic (5x normal every 60s)
- **RAMP_UP** - Gradually increasing load (doubles every 30s)
- **SPIKE** - Sudden spike then back to normal (10x for 10s)
- **RANDOM** - Random fluctuations (50%-150% of target rate)

## REST API Endpoints

### Start Agent
```bash
curl -X POST "http://localhost:8080/api/agent/traffic/start?opsPerSecond=5&pattern=STEADY"
```

**Parameters:**
- `opsPerSecond` (optional, default: 5) - Operations per second (1-100)
- `pattern` (optional, default: STEADY) - Traffic pattern

**Response:**
```json
{
  "success": true,
  "message": "Traffic agent started",
  "agentId": "traffic-agent-1234567890",
  "opsPerSecond": 5,
  "pattern": "STEADY"
}
```

### Stop Agent
```bash
curl -X POST "http://localhost:8080/api/agent/traffic/stop"
```

### Pause Agent (for Lag Testing)
```bash
curl -X POST "http://localhost:8080/api/agent/traffic/pause"
```

**Use Case:** 
- Pauses the agent while continuing to publish events
- Allows Kafka consumer lag to accumulate
- Perfect for demonstrating catch-up behavior

### Resume Agent
```bash
curl -X POST "http://localhost:8080/api/agent/traffic/resume"
```

**Use Case:**
- Resumes after pause
- Agent catches up on accumulated messages
- Demonstrates lag recovery

### Get Status
```bash
curl -X GET "http://localhost:8080/api/agent/traffic/status"
```

**Response:**
```json
{
  "agentId": "traffic-agent-1234567890",
  "running": true,
  "paused": false,
  "currentPattern": "STEADY",
  "operationsPerSecond": 5,
  "totalOperations": 150,
  "successfulOperations": 145,
  "failedOperations": 5,
  "successRate": 96.67,
  "uptimeSeconds": 30,
  "lastOperationTimestamp": "2025-01-23T19:15:00"
}
```

### Change Pattern
```bash
curl -X POST "http://localhost:8080/api/agent/traffic/pattern?pattern=BURST"
```

**Available Patterns:** STEADY, BURST, RAMP_UP, SPIKE, RANDOM

### Change Rate
```bash
curl -X POST "http://localhost:8080/api/agent/traffic/rate?opsPerSecond=10"
```

**Range:** 1-100 operations per second

### Health Check
```bash
curl -X GET "http://localhost:8080/api/agent/traffic/health"
```

### List Available Patterns
```bash
curl -X GET "http://localhost:8080/api/agent/traffic/patterns"
```

## Testing Scenarios

### Scenario 1: Basic Load Test
```bash
# Start with steady traffic
curl -X POST "http://localhost:8080/api/agent/traffic/start?opsPerSecond=5&pattern=STEADY"

# Monitor for 30 seconds
sleep 30

# Check statistics
curl -X GET "http://localhost:8080/api/agent/traffic/status"

# Stop
curl -X POST "http://localhost:8080/api/agent/traffic/stop"
```

### Scenario 2: Lag Simulation & Recovery
```bash
# Start agent
curl -X POST "http://localhost:8080/api/agent/traffic/start?opsPerSecond=10&pattern=STEADY"

# Run for 20 seconds
sleep 20

# Pause (lag accumulates)
curl -X POST "http://localhost:8080/api/agent/traffic/pause"

# Wait 30 seconds (200+ messages accumulate)
sleep 30

# Check Kafka lag (use Kafka UI or CLI)
# Topic: order-events, user-events, payment-events

# Resume and observe catch-up
curl -X POST "http://localhost:8080/api/agent/traffic/resume"

# Monitor status during catch-up
watch -n 2 "curl -s http://localhost:8080/api/agent/traffic/status | jq"
```

### Scenario 3: Burst Traffic
```bash
# Start with burst pattern
curl -X POST "http://localhost:8080/api/agent/traffic/start?opsPerSecond=5&pattern=BURST"

# Every 60 seconds, traffic spikes 5x
# Monitor system behavior during bursts

# Check status
curl -X GET "http://localhost:8080/api/agent/traffic/status"
```

### Scenario 4: Spike Test
```bash
# Start with spike pattern
curl -X POST "http://localhost:8080/api/agent/traffic/start?opsPerSecond=5&pattern=SPIKE"

# After 10 seconds, 10x spike for 10 seconds
# Tests system resilience to sudden load

# Monitor metrics
curl -X GET "http://localhost:8080/api/agent/traffic/status"
```

### Scenario 5: Ramp Up Load
```bash
# Start with ramp-up pattern
curl -X POST "http://localhost:8080/api/agent/traffic/start?opsPerSecond=2&pattern=RAMP_UP"

# Load doubles every 30 seconds: 2→4→8→16→32
# Tests scalability and breaking points
```

## Monitoring

### Kafka Metrics
The agent publishes metrics to `performance-events` topic every 10 seconds:

```json
{
  "eventType": "PERFORMANCE_METRICS",
  "eventId": "PERF_EVENT-...",
  "timestamp": "2025-01-23T19:15:00",
  "details": "ops=150, success=145, failed=5, rate=96.67%, uptime=30s"
}
```

### View Metrics
- **Kafka UI:** http://localhost:8090
- **Topic:** performance-events
- **Consumer Groups:** ads-proj-group, notification-group

### Database Monitoring
```bash
# Check notification processing
curl -X GET "http://localhost:8080/api/notifications/stats"

# Check orders
curl -X GET "http://localhost:8080/api/orders"

# Check payments
curl -X GET "http://localhost:8080/api/payments"
```

## Configuration

### Modify Agent Behavior
Located in `TrafficAgent.java`:
- **Default rate:** 5 ops/sec
- **Thread pool size:** 10 workers
- **Metrics interval:** 10 seconds
- **Operation weights:** CREATE_USER 30%, CREATE_ORDER 40%, etc.

### Rate Limits
- **Minimum:** 1 ops/sec
- **Maximum:** 100 ops/sec
- **Recommended:** 5-20 ops/sec for local testing

## Integration with Kafka

### Topics Published To
- `user-events` - User creation events
- `order-events` - Order creation, updates, cancellations
- `payment-events` - Payment processing events
- `performance-events` - Agent metrics

### Consumer Groups
- `ads-proj-group` - Main application consumers
- `notification-group` - Notification service

## Troubleshooting

### Agent Won't Start
- Check if already running: `curl http://localhost:8080/api/agent/traffic/status`
- Stop first: `curl -X POST http://localhost:8080/api/agent/traffic/stop`
- Check application logs

### High Failure Rate
- Check if services are running (User, Order, Payment controllers)
- Verify database connectivity
- Check application logs for errors

### Pause/Resume Not Working
- Verify agent is running first
- Check if already paused/resumed
- Monitor logs for state transitions

### No Metrics in Kafka
- Verify Kafka is running: `docker ps`
- Check performance-events topic exists
- Verify Kafka configuration in `application.properties`

## Development Notes

### Adding New Operation Types
1. Add enum to `OperationType` in `TrafficAgent.java`
2. Update `executeOperation()` method with new case
3. Adjust probability weights

### Custom Traffic Patterns
1. Add enum to `TrafficPattern`
2. Implement logic in `applyTrafficPattern()` method
3. Update controller documentation

### Extending Metrics
1. Modify `AgentStats` inner class
2. Update `reportMetrics()` method
3. Adjust Kafka event structure

## Performance Characteristics

### Resource Usage
- **Threads:** 2 scheduled + 10 workers
- **Memory:** ~50MB additional heap
- **CPU:** ~5-10% per 10 ops/sec
- **Network:** ~100KB/sec at 10 ops/sec

### Scalability
- **Single instance:** Up to 100 ops/sec
- **Multiple instances:** Deploy multiple agents with different IDs
- **Kafka throughput:** Supports 1000+ ops/sec per topic

## Related Documentation

- **Notification Service:** `NOTIFICATION_SERVICE_COMPLETE.md`
- **Kafka Implementation:** `KAFKA_CURRENT_IMPLEMENTATION.md`
- **Project Status:** `PROJECT_STATUS.md`
- **Phase 4 Reference:** `PHASE4_QUICK_REFERENCE.md`

## Quick Commands Cheatsheet

```bash
# Start with default settings
curl -X POST "localhost:8080/api/agent/traffic/start"

# Start with custom settings
curl -X POST "localhost:8080/api/agent/traffic/start?opsPerSecond=10&pattern=BURST"

# Pause for lag test
curl -X POST "localhost:8080/api/agent/traffic/pause"

# Resume
curl -X POST "localhost:8080/api/agent/traffic/resume"

# Check status
curl -X GET "localhost:8080/api/agent/traffic/status" | jq

# Stop
curl -X POST "localhost:8080/api/agent/traffic/stop"

# Health check
curl -X GET "localhost:8080/api/agent/traffic/health" | jq
```

## Next Steps

1. **FulfillmentAgent** - Create order processing agent
2. **Multi-instance deployment** - Scale horizontally
3. **Advanced metrics** - Prometheus/Grafana integration
4. **E2E testing** - Automated test scenarios
5. **Load testing** - Performance benchmarks

---

**Traffic Agent Status:** ✅ Complete and ready for testing
**Last Updated:** 2025-01-23
**Deliverable:** Phase 3 - Agent Implementation
