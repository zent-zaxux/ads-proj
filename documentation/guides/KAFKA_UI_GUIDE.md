# Kafka UI Setup Guide

## Quick Start: Opening Kafka UI

### Option 1: If Kafka UI is already running

**Simply open your browser and navigate to:**
```
http://localhost:8080
```

### Option 2: If Kafka UI is not running

**Start all services including Kafka UI:**
```bash
docker-compose up -d
```

This will start:
- Kafka broker
- Zookeeper
- PostgreSQL
- Kafka UI (accessible at http://localhost:8080)

---

## Verifying Kafka UI is Running

### Check if Kafka UI is accessible:
```bash
curl http://localhost:8080
```

If you see HTML output, Kafka UI is running!

### Check Docker containers:
```bash
docker ps | grep kafka-ui
```

You should see a container running with `provectuslabs/kafka-ui` image.

---

## Using Kafka UI for Observability

### 1. Access Kafka UI
Open browser: http://localhost:8080

### 2. Navigate to Consumer Groups
Click on **"Consumers"** tab in the left sidebar

### 3. View Consumer Lag
You'll see a list of consumer groups:
- `ads-proj-group`
- `notification-group`

### 4. Key Metrics to Monitor

**For each consumer group, check:**

| Metric | What It Means | Healthy State |
|--------|---------------|---------------|
| **Lag** | Messages waiting to be consumed | 0 or < 100 |
| **Members** | Active consumers in the group | 1 or more |
| **Topics** | Topics this group consumes from | order-events, etc. |
| **State** | Consumer group state | STABLE |

### 5. During Normal Operation

**Expected state:**
```
Consumer Group: ads-proj-group
├─ Topic: order-events
│  ├─ Partition 0: Lag = 0
│  ├─ Partition 1: Lag = 0
│  └─ Partition 2: Lag = 0
└─ State: STABLE, Members: 20
```

### 6. During High Load or Fault

**What you might see:**
```
Consumer Group: ads-proj-group
├─ Topic: order-events
│  ├─ Partition 0: Lag = 245  ⚠️ Backlog!
│  ├─ Partition 1: Lag = 238
│  └─ Partition 2: Lag = 251
└─ State: STABLE, Members: 20
```

**This indicates:**
- Messages are being produced faster than consumed
- System is under load or experiencing degradation
- Monitor to see if lag decreases (system recovering) or increases (system overwhelmed)

---

## Kafka UI Features for Your Report

### Topics Tab
- View all Kafka topics
- See message count per topic
- Browse messages in real-time

### Consumers Tab
- Monitor consumer lag (key observability metric)
- View consumer group status
- Check partition assignments

### Brokers Tab
- Kafka cluster health
- Broker configurations
- Resource usage

---

## Troubleshooting Kafka UI

### If Kafka UI doesn't open:

**1. Check if Docker is running:**
```bash
docker ps
```

**2. Check if Kafka UI container is running:**
```bash
docker ps | grep kafka-ui
```

**3. If not running, start it:**
```bash
docker-compose up -d kafka-ui
```

**4. Check logs if there are issues:**
```bash
docker logs kafka-ui
```

### If port 8080 is already in use:

**Option A: Stop the conflicting service**

**Option B: Change Kafka UI port in docker-compose.yaml:**
```yaml
kafka-ui:
  ports:
    - "8081:8080"  # Change to different port
```

Then access at: http://localhost:8081

---

## Integration with Observability Demo

The observability demo script (`observability-demo.sh`) will:
1. Check if Kafka UI is accessible
2. Provide instructions on how to access it
3. Automatically open it in your browser (if possible)

**During the demo:**
- Keep Kafka UI open in a browser tab
- Watch consumer lag change in real-time
- Refresh the page to see updates
- Use it alongside API metrics for complete observability

---

## Screenshots for Your Report

### Recommended Screenshots:

1. **Healthy System** - Consumer Groups tab showing Lag = 0
2. **Topics Overview** - All topics with message counts
3. **Consumer Details** - Expanded view of one consumer group
4. **During Load** - Consumer lag during traffic generation
5. **After Recovery** - Lag returning to 0 after incident

---

## Quick Reference

| Action | Command/URL |
|--------|-------------|
| Open Kafka UI | http://localhost:8080 |
| Start Kafka UI | `docker-compose up -d kafka-ui` |
| Stop Kafka UI | `docker-compose stop kafka-ui` |
| View logs | `docker logs kafka-ui` |
| Restart Kafka UI | `docker-compose restart kafka-ui` |

---

**Next Step**: Run `./observability-demo.sh` to see all observability features in action!
