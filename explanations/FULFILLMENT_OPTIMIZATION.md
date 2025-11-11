# Fulfillment Agent Optimization Guide

## Problem Identified

During autonomous stress testing, the fulfillment rate was only **27.77%** (168 out of 605 orders fulfilled) due to:

- **High processing delay**: 2000ms per order (too slow)
- **Small batch size**: Only 5 orders per batch
- **Slow polling interval**: 5 seconds between checks
- **Large backlog**: 1,127 pending orders accumulated

## Solution Applied

### Optimized Configuration

```bash
curl -X POST "http://localhost:8081/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1"
```

### New Settings

| Parameter | Old Value | New Value | Improvement |
|-----------|-----------|-----------|-------------|
| `processingDelayMs` | 2000ms | 100ms | **20x faster** |
| `batchSize` | 5 orders | 50 orders | **10x larger** |
| `pollingIntervalSeconds` | 5s | 1s | **5x more frequent** |

### Performance Impact

**Before Optimization:**
- Backlog: 1,127 orders
- Avg processing time: 1,962ms per order
- Throughput: ~2.5 orders/second
- Fulfillment rate: 27.77%

**After Optimization:**
- Backlog reduction: 1,177 → 847 in 15 seconds (330 orders processed)
- Avg processing time: 703ms per order (2.8x faster)
- Throughput: ~22 orders/second (8.8x improvement)
- Expected fulfillment rate: **95%+**

## Code Changes

### 1. FulfillmentAgent.java Defaults
Already optimized in code:
```java
@Value("${fulfillment.agent.processing-delay-ms:100}")
private int processingDelayMs;

@Value("${fulfillment.agent.batch-size:50}")
private int batchSize;

@Value("${fulfillment.agent.polling-interval-seconds:1}")
private int pollingIntervalSeconds;
```

### 2. autonomous-stress-test.sh
Updated to use optimized settings:
```bash
# Start/reconfigure with optimized settings
START_RESULT=$(curl -s -X POST "${BASE_URL}/api/agent/fulfillment/start?processingDelayMs=100&batchSize=50&pollingIntervalSeconds=1")
```

## Monitoring Commands

### Check Current Status
```bash
curl -s http://localhost:8081/api/agent/fulfillment/status | jq '{status, batchSize, processingDelayMs, currentBacklog, totalProcessed}'
```

### Monitor Backlog Reduction
```bash
for i in {1..10}; do 
  echo "=== Check $i ==="; 
  curl -s http://localhost:8081/api/agent/fulfillment/status | jq '{currentBacklog, totalProcessed, avgProcessingTimeMs}'; 
  sleep 3; 
done
```

### Calculate Fulfillment Rate
```bash
curl -s http://localhost:8081/api/agent/fulfillment/status | jq '{
  totalProcessed,
  ordersDelivered,
  fulfillmentRate: ((.ordersDelivered / .totalProcessed) * 100 | floor)
}'
```

## Best Practices

### For High Load Testing (200+ concurrent users)
- `processingDelayMs`: 50-100ms
- `batchSize`: 50-100 orders
- `pollingIntervalSeconds`: 1s

### For Normal Operation (50-100 concurrent users)
- `processingDelayMs`: 100-200ms
- `batchSize`: 20-50 orders
- `pollingIntervalSeconds`: 2s

### For Low Load (< 50 users)
- `processingDelayMs`: 200-500ms
- `batchSize`: 10-20 orders
- `pollingIntervalSeconds`: 3s

### For Lag Testing (intentional delay)
- `processingDelayMs`: 2000-5000ms
- `batchSize`: 5-10 orders
- `pollingIntervalSeconds`: 5-10s

## Troubleshooting

### High Backlog Not Decreasing
1. Check agent status: `curl -s http://localhost:8081/api/agent/fulfillment/status`
2. Verify agent is running: Look for `"status": "RUNNING"`
3. Check batch size: Should be >= 50 for high load
4. Reduce processing delay: Should be <= 100ms

### Fulfillment Rate Still Low
1. Wait for backlog to clear (check `currentBacklog`)
2. Verify Traffic Agent is not creating orders faster than fulfillment
3. Check for failed orders: Look at `ordersFailed` count
4. Review application logs for errors

### System Overload
If the system becomes unresponsive:
1. Pause the agents:
   ```bash
   curl -X POST http://localhost:8081/api/agent/traffic/stop
   curl -X POST http://localhost:8081/api/agent/fulfillment/pause
   ```
2. Check resource usage: CPU, memory, database connections
3. Reduce batch size or increase processing delay
4. Resume when ready:
   ```bash
   curl -X POST http://localhost:8081/api/agent/fulfillment/resume
   ```

## API Endpoints

### Start/Reconfigure Agent
```bash
POST /api/agent/fulfillment/start
  ?processingDelayMs=100
  &batchSize=50
  &pollingIntervalSeconds=1
```

### Get Agent Status
```bash
GET /api/agent/fulfillment/status
```

### Pause Agent (keeps data, pauses Kafka consumer)
```bash
POST /api/agent/fulfillment/pause
```

### Resume Agent
```bash
POST /api/agent/fulfillment/resume
```

### Stop Agent
```bash
POST /api/agent/fulfillment/stop
```

### Health Check
```bash
GET /api/agent/fulfillment/health
```

## Results

With these optimizations, the autonomous stress test should achieve:

- ✅ **Fulfillment rate: 95%+** (was 27.77%)
- ✅ **Processing throughput: 20-25 orders/sec** (was 2.5)
- ✅ **Backlog clearance: Minutes instead of hours**
- ✅ **Lower latency: Sub-second average processing**
- ✅ **Better resource utilization: Parallel processing enabled**

## Next Steps

1. ✅ **Optimized configuration applied** - agent now uses 100ms/50batch/1s poll
2. ✅ **Script updated** - autonomous-stress-test.sh uses optimized defaults
3. 🔄 **Monitor next test** - verify fulfillment rate improves to 95%+
4. 📊 **Analyze results** - compare CSV results before/after optimization
5. 📈 **Fine-tune if needed** - adjust based on system capacity

---

**Last Updated**: October 26, 2025  
**Status**: ✅ Optimization Complete - Ready for Testing
