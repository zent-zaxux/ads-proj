# 🎬 Live Demo Scripts

Complete set of scripts for demonstrating the event-driven order fulfillment system.

## 📋 Quick Start

### Option 1: Run Complete Demo (Recommended)

```bash
./scripts/run-demo.sh
```

Select demo mode:
- **Full Automated** - Runs all parts with 5-second pauses
- **Interactive** - Pause between each part (best for live presentation)
- **Quick Demo** - Essential parts only (~5 minutes)
- **Custom** - Select specific parts to run

### Option 2: Run Individual Parts

```bash
# 1. Setup environment (required first)
./scripts/demo-setup.sh

# 2. User registration + Kafka events
./scripts/demo-1-users.sh

# 3. Order creation + workflow
./scripts/demo-2-orders.sh

# 4. Notification system
./scripts/demo-3-notifications.sh

# 5. Concurrent traffic simulation
./scripts/demo-4-traffic.sh

# 6. Fulfillment agent demo
./scripts/demo-5-fulfillment.sh

# 7. Generate summary report
./scripts/demo-summary.sh

# 8. Cleanup (when done)
./scripts/demo-cleanup.sh
```

---

## 🎯 Demo Flow

### Part 0: Setup (5 min)
- Cleans environment
- Starts Docker services (PostgreSQL, Kafka, Zookeeper)
- Launches Spring Boot in background
- Verifies system health

### Part 1: User Registration (2 min)
**Focus**: Event-driven architecture
- Create 2 users (Alice, Bob)
- Watch USER_REGISTERED events in Kafka
- Test idempotency (duplicate user creation)

**Terminal Setup**:
```bash
# Terminal 2 - Monitor user-events
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic user-events \
  --from-beginning \
  --property print.timestamp=true
```

### Part 2: Order Creation (3 min)
**Focus**: Order workflow + state transitions
- Create order for Alice ($2,578)
- Watch status: PENDING → PROCESSING → PAYMENT_COMPLETED → SHIPPED → DELIVERED
- See events published at each stage

**Terminal Setup**:
```bash
# Terminal 2 - Monitor order-events
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic order-events \
  --from-beginning

# Terminal 3 - Watch fulfillment logs
tail -f app.log | grep -E 'FulfillmentAgent|PENDING|PROCESSING|SHIPPED|DELIVERED'
```

### Part 3: Notifications (1 min)
**Focus**: Cross-topic event consumption
- Check notifications for both users
- Show notification timeline (5+ notifications per order)
- Verify idempotency (no duplicates)

### Part 4: Traffic Simulation (3 min)
**Focus**: Concurrent processing + scalability
- Create 10 orders simultaneously
- Monitor Kafka consumer lag
- Verify 100% delivery rate
- Show performance metrics

**Terminal Setup**:
```bash
# Terminal 2 - Watch consumer lag
watch -n 1 'docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group ads-proj-group \
  --describe | grep order-events'
```

### Part 5: Fulfillment Agent (2 min)
**Focus**: Fault tolerance + recovery
- Pause fulfillment agent (simulate outage)
- Create order during "downtime"
- Resume agent and watch recovery
- Verify zero data loss

### Part 6: Summary Report (1 min)
**Focus**: Final metrics
- Total users/orders/notifications
- Success rate (should be 100%)
- Kafka throughput
- System health
- Processing times

---

## 🖥️ Recommended Terminal Layout

```
┌─────────────────────┬─────────────────────┐
│                     │                     │
│   Terminal 1        │   Terminal 2        │
│   (Main Demo)       │   (Kafka Events)    │
│                     │                     │
├─────────────────────┼─────────────────────┤
│                     │                     │
│   Terminal 3        │   Terminal 4        │
│   (App Logs)        │   (Extra/Optional)  │
│                     │                     │
└─────────────────────┴─────────────────────┘
```

### Terminal Commands:

**Terminal 1** (Main):
```bash
./scripts/run-demo.sh
# Or run individual parts
```

**Terminal 2** (Kafka Monitoring - switch topics as needed):
```bash
# For user events
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic user-events \
  --from-beginning

# For order events  
docker exec -it kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic order-events \
  --from-beginning
```

**Terminal 3** (Application Logs):
```bash
tail -f app.log | grep -E 'ORDER|USER|PAYMENT|NOTIF|Fulfillment'
```

**Terminal 4** (Optional - Database queries):
```bash
docker exec -it postgres psql -U adsuser -d adsdb
```

---

## 🎤 Presentation Tips

### Key Talking Points:

1. **Event-Driven Architecture**
   - "All state changes publish events to Kafka for asynchronous processing"
   - "Services are decoupled through message queues"

2. **Idempotency**
   - "Duplicate requests return existing resources, preventing database conflicts"
   - "Unique event IDs prevent duplicate notifications"

3. **Scalability**
   - "Kafka partitioning enables parallel consumption (5 partitions × 5 threads)"
   - "Batch processing handles 50 orders per batch"

4. **Fault Tolerance**
   - "Events persist in Kafka during service outages"
   - "Automatic catch-up processing after recovery"
   - "Zero data loss demonstrated"

### What to Highlight:

✅ **Real-time event flow** - Show Kafka events appearing as operations complete  
✅ **Zero consumer lag** - Demonstrate consumers keeping up with producers  
✅ **100% success rate** - All orders delivered successfully  
✅ **Concurrent processing** - 10 orders created simultaneously  
✅ **Recovery** - System catches up after simulated failure  

---

## 📊 Expected Results

| Metric | Expected Value |
|--------|---------------|
| Total Users | 2 |
| Total Orders | 11-12 |
| Success Rate | 100% |
| Avg Processing Time | 10-15 seconds |
| Kafka Consumer Lag | 0 messages |
| Notifications | 5+ per order |

---

## 🐛 Troubleshooting

### Application won't start
```bash
# Check logs
tail -f app.log

# Verify Docker services
docker ps

# Restart setup
./scripts/demo-cleanup.sh
./scripts/demo-setup.sh
```

### Kafka events not appearing
```bash
# Check Kafka is running
docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092

# List topics
docker exec kafka kafka-topics --list --bootstrap-server localhost:9092

# Check from beginning
--from-beginning flag
```

### Orders stuck in PENDING
```bash
# Check fulfillment agent
curl http://localhost:8081/api/admin/fulfillment/status

# Resume if paused
curl -X POST http://localhost:8081/api/admin/resume-fulfillment

# Check logs
grep "FulfillmentAgent" app.log
```

### Consumer lag not zero
```bash
# Wait longer (system catching up)
sleep 10

# Check consumer group
docker exec kafka kafka-consumer-groups \
  --bootstrap-server localhost:9092 \
  --group ads-proj-group \
  --describe
```

---

## 🧹 Cleanup

After demo:
```bash
./scripts/demo-cleanup.sh
```

This will:
- Stop Spring Boot application
- Stop Docker containers
- Clean Docker volumes
- Remove temp files
- Archive logs to `demo_archive_YYYYMMDD_HHMMSS/`

---

## 📝 Notes

- **Spring Boot runs in background** - Check `app.log` for real-time logs
- **PID saved** - Application PID stored in `app.pid` for easy stopping
- **Temp files** - User/order IDs saved to `/tmp/demo_*.env` for script coordination
- **Non-destructive** - Cleanup creates backups before removing files

---

## ⏱️ Demo Timeline

| Part | Duration | Key Activity |
|------|----------|--------------|
| Setup | 5 min | Environment preparation |
| Part 1 | 2 min | User registration |
| Part 2 | 3 min | Order workflow |
| Part 3 | 1 min | Notifications |
| Part 4 | 3 min | Traffic simulation |
| Part 5 | 2 min | Fault tolerance |
| Summary | 1 min | Final report |
| **Total** | **~17 min** | Complete demo |

---

**Good luck with your presentation! 🚀**
