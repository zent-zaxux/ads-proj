# Fulfillment Agent - Restart and Test Guide

## Current Status

✅ **FulfillmentAgent** and **FulfillmentAgentController** have been created and compiled.

⚠️ **Application needs restart** to load the new classes.

---

## Step 1: Restart the Application

The application needs to be restarted to load the FulfillmentAgent. Here are your options:

### Option A: Using Docker Compose (Recommended)

```bash
# Stop all services
docker compose down

# Rebuild and start (this will pick up the new JAR)
docker compose up --build -d

# Check logs to confirm startup
docker compose logs -f app
```

### Option B: If Running Locally with Maven

```bash
# Stop the currently running application (Ctrl+C in the terminal where it's running)

# Then restart with:
./mvnw spring-boot:run
```

### Option C: Using the JAR directly

```bash
# Stop the current application

# Run the newly built JAR
java -jar target/ads_proj-0.0.1-SNAPSHOT.jar
```

---

## Step 2: Verify Fulfillment Agent is Loaded

Once the application restarts, verify the Fulfillment Agent controller is available:

```bash
# Check health endpoint
curl http://localhost:8081/api/agent/fulfillment/health | jq

# Expected response:
# {
#   "service": "fulfillment-agent",
#   "status": "UP",
#   "agentId": "FULFILLMENT-AGENT-...",
#   "running": false,
#   "paused": false
# }
```

---

## Step 3: Run the Integrated Test

After confirming the Fulfillment Agent is loaded, run the comprehensive test:

```bash
./test-agents-integrated.sh
```

### What the Test Does:

1. **Test 1: Basic Integration** - Starts both agents, verifies orders are created and delivered
2. **Test 2: Lag Testing** - Pauses fulfillment, creates backlog
3. **Test 3: Catch-up Testing** - Resumes fulfillment, processes backlog
4. **Test 4: Performance Test** - High-load scenario with optimization
5. **Test 5: Metrics Validation** - Verifies all metrics are being collected

### Expected Duration: ~2-3 minutes

---

## Step 4: Manual Testing (Optional)

You can also test manually to explore the agents:

### Start Both Agents

```bash
# Start Traffic Agent (creates orders)
curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=5&pattern=STEADY"

# Start Fulfillment Agent (processes orders)
curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=1000&batchSize=5"
```

### Monitor Status

```bash
# Check Traffic Agent
curl http://localhost:8081/api/agent/traffic/status | jq '{status, totalOps: .totalOperations, ordersCreated: .ordersCreated}'

# Check Fulfillment Agent
curl http://localhost:8081/api/agent/fulfillment/status | jq '{status, processed: .totalProcessed, backlog: .currentBacklog, delivered: .ordersDelivered}'

# Check Order Distribution
curl http://localhost:8081/api/orders | jq 'group_by(.status) | map({status: .[0].status, count: length})'
```

### Test Pause/Resume (Lag Scenario)

```bash
# Pause fulfillment (orders accumulate)
curl -X POST "http://localhost:8081/api/agent/fulfillment/pause"

# Wait 20 seconds while backlog grows
sleep 20

# Check backlog
curl http://localhost:8081/api/agent/fulfillment/status | jq '.currentBacklog'

# Resume and watch catch-up
curl -X POST "http://localhost:8081/api/agent/fulfillment/resume"

# Monitor backlog decrease
watch -n 2 "curl -s http://localhost:8081/api/agent/fulfillment/status | jq '{backlog: .currentBacklog, processed: .totalProcessed}'"
```

### Stop Both Agents

```bash
curl -X POST "http://localhost:8081/api/agent/traffic/stop"
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"
```

---

## Step 5: View Results in Kafka UI

Open **Kafka UI** at http://localhost:8090 to see the events:

- **order-events** topic - Order lifecycle events
- **performance-events** topic - Agent metrics (every 15 seconds)
- **notification-events** topic - Notification delivery events

---

## Troubleshooting

### Problem: Fulfillment Agent health endpoint returns nothing

**Cause:** Application hasn't been restarted with new code

**Solution:** Restart the application (see Step 1)

---

### Problem: Agent won't start

**Symptom:**
```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/start"
# Returns error or nothing
```

**Solution:**
```bash
# Check if already running
curl http://localhost:8081/api/agent/fulfillment/status | jq '.status'

# If RUNNING, stop it first
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"

# Then start again
curl -X POST "http://localhost:8081/api/agent/fulfillment/start"
```

---

### Problem: No orders being processed

**Check:**
1. Are there pending orders?
   ```bash
   curl "http://localhost:8081/api/orders?status=PENDING" | jq 'length'
   ```

2. Is fulfillment agent running?
   ```bash
   curl http://localhost:8081/api/agent/fulfillment/status | jq '{status, isPaused}'
   ```

3. Is traffic agent creating orders?
   ```bash
   curl http://localhost:8081/api/agent/traffic/status | jq '.ordersCreated'
   ```

**Solution:**
- Start Traffic Agent if needed
- Ensure Fulfillment Agent is running and not paused
- Check application logs for errors

---

### Problem: Backlog not clearing

**Check:**
```bash
# Is fulfillment paused?
curl http://localhost:8081/api/agent/fulfillment/status | jq '.isPaused'
```

**Solution:**
```bash
# Resume if paused
curl -X POST "http://localhost:8081/api/agent/fulfillment/resume"

# Or speed up processing
curl -X POST "http://localhost:8081/api/agent/fulfillment/config/delay?delayMs=500"
curl -X POST "http://localhost:8081/api/agent/fulfillment/config/batch?batchSize=10"
```

---

## Quick Commands Reference

```bash
# HEALTH CHECKS
curl http://localhost:8081/api/agent/traffic/health | jq
curl http://localhost:8081/api/agent/fulfillment/health | jq

# START AGENTS
curl -X POST "http://localhost:8081/api/agent/traffic/start?opsPerSecond=5"
curl -X POST "http://localhost:8081/api/agent/fulfillment/start"

# STATUS
curl http://localhost:8081/api/agent/traffic/status | jq
curl http://localhost:8081/api/agent/fulfillment/status | jq

# PAUSE/RESUME
curl -X POST "http://localhost:8081/api/agent/fulfillment/pause"
curl -X POST "http://localhost:8081/api/agent/fulfillment/resume"

# STOP AGENTS
curl -X POST "http://localhost:8081/api/agent/traffic/stop"
curl -X POST "http://localhost:8081/api/agent/fulfillment/stop"

# VIEW ORDERS
curl "http://localhost:8081/api/orders?status=PENDING" | jq 'length'
curl "http://localhost:8081/api/orders?status=DELIVERED" | jq 'length'

# RUN INTEGRATED TEST
./test-agents-integrated.sh
```

---

## Next Steps After Testing

Once both agents are tested and working:

1. ✅ Document test results (screenshots, logs)
2. ✅ Update PROJECT_STATUS.md
3. 🔄 Move to Deliverable 4: Partition scaling and multi-instance deployment
4. 📊 Add Prometheus/Grafana monitoring (optional enhancement)

---

**Ready to proceed?** Start with Step 1 (restart the application), then run the integrated test!
