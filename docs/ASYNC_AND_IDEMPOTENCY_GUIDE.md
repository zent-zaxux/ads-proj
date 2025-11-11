# Asynchronous Event Publishing & Idempotency - Quick Reference Guide

## Overview
This guide explains the asynchronous event publishing and idempotency mechanisms implemented in the ADS Project.

---

## 1. Asynchronous Event Publishing

### Why Async?
**Problem:** Synchronous Kafka publishing blocks HTTP response threads, increasing latency.

**Solution:** `@Async` methods publish events in background thread pool, returning HTTP responses immediately.

### Implementation

#### EventPublisherService.java
```java
@Service
public class EventPublisherService {
    
    @Async  // <-- Key annotation
    public void publishOrderEventAsync(OrderEvent event) {
        kafkaTemplate.send("order-events", event.getOrderId().toString(), event);
    }
    
    @Async
    public void publishPaymentEventAsync(PaymentEvent event) {
        kafkaTemplate.send("payment-events", event.getPaymentId().toString(), event);
    }
    
    @Async
    public void publishUserEventAsync(UserEvent event) {
        kafkaTemplate.send("user-events", event.getUserId().toString(), event);
    }
}
```

#### Usage in Services
**OrderService.java:**
```java
// ✅ CORRECT - Async (non-blocking)
eventPublisher.publishOrderEventAsync(orderEvent);

// ❌ INCORRECT - Sync (blocking)
eventPublisher.publishOrderEvent(orderEvent);
```

### Thread Pool Configuration
**AsyncConfig.java:**
```java
@Configuration
@EnableAsync
public class AsyncConfig implements AsyncConfigurer {
    
    @Override
    public Executor getAsyncExecutor() {
        ThreadPoolTaskExecutor executor = new ThreadPoolTaskExecutor();
        executor.setCorePoolSize(10);      // Always 10 threads ready
        executor.setMaxPoolSize(50);       // Can grow to 50 threads
        executor.setQueueCapacity(100);    // Queue up to 100 tasks
        executor.setThreadNamePrefix("async-");
        executor.initialize();
        return executor;
    }
}
```

---

## 2. Idempotency System

### Why Idempotency?
**Problem:** Kafka may redeliver messages due to:
- Network failures
- Consumer restarts
- Rebalancing
- Manual offset reset

**Without Idempotency:**
- Duplicate notifications sent to users
- Duplicate payment processing
- Data corruption

**With Idempotency:**
- Each event has unique UUID
- System checks if event already processed
- Duplicates automatically skipped

### How It Works

#### Step 1: Event ID Generation
**BaseEvent.java:**
```java
public abstract class BaseEvent {
    private String eventId;  // UUID generated automatically
    
    protected BaseEvent(String eventType, String serviceSource) {
        this.eventId = UUID.randomUUID().toString();  // <-- Unique ID
        this.eventType = eventType;
        this.serviceSource = serviceSource;
        this.timestamp = LocalDateTime.now();
    }
}
```

**Example Event ID:** `efbbfd2f-b54f-44ae-866d-f4115d92ffe4`

#### Step 2: Database Tracking
**ProcessedEvent.java:**
```java
@Entity
@Table(name = "processed_events")
public class ProcessedEvent {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false)  // <-- Unique constraint
    private String eventId;
    
    @Column(nullable = false)
    private String eventType;
    
    private String consumerGroup;
    private String aggregateId;
    
    @Column(nullable = false)
    private LocalDateTime processedAt;
}
```

**Database Schema:**
```sql
CREATE TABLE processed_events (
    id             BIGINT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
    event_id       VARCHAR(255) NOT NULL UNIQUE,  -- Prevents duplicates
    event_type     VARCHAR(100) NOT NULL,
    consumer_group VARCHAR(100),
    aggregate_id   VARCHAR(500),
    processed_at   TIMESTAMP NOT NULL
);

CREATE UNIQUE INDEX idx_event_id ON processed_events(event_id);
```

#### Step 3: Consumer Idempotency Check
**NotificationConsumer.java:**
```java
@KafkaListener(topics = "order-events", groupId = "notification-group")
@Transactional
public void consumeOrderEvent(OrderEvent event, ...) {
    try {
        logger.info("Received event: {}", event.getEventId());
        
        // ✅ IDEMPOTENCY CHECK
        if (processedEventRepository.existsByEventId(event.getEventId())) {
            logger.info("⚠️ DUPLICATE EVENT DETECTED - Skipping");
            return;  // Exit early - don't reprocess
        }
        
        // Process the event...
        Notification notification = notificationService.processOrderEvent(event);
        
        // ✅ MARK AS PROCESSED (within same transaction)
        if (event.getEventId() != null) {
            ProcessedEvent processed = new ProcessedEvent(
                event.getEventId(),
                "ORDER_" + event.getAction(),
                "notification-group",
                event.getOrderId().toString()
            );
            processedEventRepository.save(processed);
            logger.info("✓ Event marked as processed: {}", event.getEventId());
        }
        
    } catch (Exception e) {
        logger.error("❌ ERROR processing event", e);
        throw e;  // Rethrow to trigger Kafka redelivery
    }
}
```

### Idempotency Flow Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                     Kafka Delivers Event                     │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  Consumer Receives: eventId = "efbbfd2f-b54f-44ae-..."      │
└──────────────────┬───────────────────────────────────────────┘
                   │
                   ▼
┌──────────────────────────────────────────────────────────────┐
│  Query: SELECT EXISTS(event_id = "efbbfd2f-...")            │
└──────────────────┬───────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
   ┌─────────┐          ┌─────────┐
   │  TRUE   │          │  FALSE  │
   │ (Dupe)  │          │  (New)  │
   └────┬────┘          └────┬────┘
        │                    │
        ▼                    ▼
   ┌─────────────────┐  ┌────────────────────┐
   │  Skip Process   │  │  Process Event     │
   │  Log Warning    │  │  Send Notification │
   │  Return Early   │  │  INSERT eventId    │
   └─────────────────┘  └────────────────────┘
```

---

## 3. Payment Event Choreography

### Architecture

```
┌───────────────┐
│ PaymentService│
│  .processPayment()
└───────┬───────┘
        │
        │ Publishes to Kafka
        ▼
┌─────────────────────────────┐
│   payment-events topic      │
└─────────────┬───────────────┘
              │
              │ Consumed by
              ▼
┌─────────────────────────────┐
│  NotificationConsumer       │
│  (notification-group)       │
└─────────────┬───────────────┘
              │
              ▼
┌─────────────────────────────────────────────┐
│  Process Payment Event:                     │
│  - PAYMENT_COMPLETED → Success notification │
│  - PAYMENT_FAILED → Failure notification    │
└─────────────────────────────────────────────┘
```

### Payment Event Handling

**NotificationConsumer.java:**
```java
@KafkaListener(
    topics = "${app.kafka.topics.payment-events}",
    groupId = "notification-group"
)
@Transactional
public void consumePaymentEvent(PaymentEvent event, ...) {
    
    // Idempotency check
    if (processedEventRepository.existsByEventId(event.getEventId())) {
        logger.info("⚠️ DUPLICATE - Skipping");
        return;
    }
    
    // Process payment event
    Notification notification = notificationService.processPaymentEvent(event);
    
    // Mark as processed
    processedEventRepository.save(new ProcessedEvent(...));
}
```

**NotificationService.java:**
```java
public Notification processPaymentEvent(PaymentEvent paymentEvent) {
    
    // Only process COMPLETED and FAILED
    if (paymentEvent.getAction() != PAYMENT_COMPLETED && 
        paymentEvent.getAction() != PAYMENT_FAILED) {
        return null;
    }
    
    // Determine notification type
    NotificationType type = (paymentEvent.getAction() == PAYMENT_COMPLETED) 
        ? NotificationType.PAYMENT_COMPLETED 
        : NotificationType.PAYMENT_FAILED;
    
    // Create and send notification
    Notification notification = createPaymentNotification(type, order, user);
    return sendNotification(notification);
}
```

---

## 4. Testing & Verification

### 4.1 Run E2E Demo
```bash
./e2e-demo.sh
```

**What it tests:**
1. Service health checks
2. User creation
3. Order creation → Kafka event
4. Payment processing
5. Notification delivery
6. **Idempotency verification** (queries `processed_events`)
7. Autonomous agents
8. Complete flow summary

### 4.2 Check Processed Events
```bash
docker exec postgres psql -U adsuser -d adsdb -c \
  "SELECT COUNT(*) as total, 
          COUNT(DISTINCT event_type) as types,
          COUNT(DISTINCT consumer_group) as groups 
   FROM processed_events 
   WHERE processed_at > NOW() - INTERVAL '5 minutes';"
```

**Expected Output:**
```
 total | types | groups 
-------+-------+--------
   266 |     4 |      2
```

### 4.3 View Event Breakdown
```bash
docker exec postgres psql -U adsuser -d adsdb -c \
  "SELECT event_type, consumer_group, COUNT(*) as count 
   FROM processed_events 
   GROUP BY event_type, consumer_group 
   ORDER BY count DESC LIMIT 10;"
```

**Example Output:**
```
   event_type    |     consumer_group     | count 
-----------------+------------------------+-------
 ORDER_CREATED   | notification-group     |    63
 ORDER_CONFIRMED | notification-group     |    43
 ORDER_DELIVERED | event-consumer-service |    38
```

### 4.4 Check Payment Events
```bash
docker exec postgres psql -U adsuser -d adsdb -c \
  "SELECT event_type, COUNT(*) 
   FROM processed_events 
   WHERE event_type LIKE 'PAYMENT%' 
   GROUP BY event_type;"
```

### 4.5 View Application Logs
```bash
tail -f /tmp/app.log | grep -i "duplicate\|idempotency"
```

**Expected Log:**
```
⚠️  DUPLICATE EVENT DETECTED - Already processed
   EventID: efbbfd2f-b54f-44ae-866d-f4115d92ffe4
   Skipping notification to prevent duplicates
```

---

## 5. Troubleshooting

### Issue: Events Not Being Processed

**Check Kafka Consumer Groups:**
```bash
docker exec kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --list
```

**Expected Groups:**
- `notification-group`
- `event-consumer-service`

**Check Consumer Lag:**
```bash
docker exec kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group notification-group
```

### Issue: Duplicate Events Still Processing

**Check Database Constraints:**
```bash
docker exec postgres psql -U adsuser -d adsdb -c \
  "\d processed_events"
```

**Verify unique index exists:**
```
Indexes:
    "processed_events_pkey" PRIMARY KEY, btree (id)
    "idx_event_id" UNIQUE CONSTRAINT, btree (event_id)
```

**Check for duplicates:**
```bash
docker exec postgres psql -U adsuser -d adsdb -c \
  "SELECT event_id, COUNT(*) 
   FROM processed_events 
   GROUP BY event_id 
   HAVING COUNT(*) > 1;"
```

**Expected:** 0 rows (no duplicates)

### Issue: Async Events Not Publishing

**Check Thread Pool:**
```bash
# Look for async thread logs
tail -f /tmp/app.log | grep "async-"
```

**Verify @EnableAsync:**
```java
@Configuration
@EnableAsync  // <-- Must be present
public class AsyncConfig implements AsyncConfigurer {
    ...
}
```

**Check Service Uses Async Methods:**
```java
// ✅ Correct
eventPublisher.publishOrderEventAsync(event);

// ❌ Wrong
eventPublisher.publishOrderEvent(event);
```

---

## 6. Performance Considerations

### Thread Pool Tuning

**Current Settings:**
- Core Pool: 10 threads
- Max Pool: 50 threads
- Queue: 100 tasks

**Recommendations:**
- **Low Traffic (<100 ops/sec):** Current settings sufficient
- **Medium Traffic (100-500 ops/sec):** Increase max to 100 threads
- **High Traffic (>500 ops/sec):** Increase max to 200 threads, queue to 500

**Monitor Thread Usage:**
```bash
# Check application metrics
curl -s http://localhost:8081/actuator/metrics/executor.active | jq .
```

### Database Performance

**Processed Events Table Growth:**
- Each event = 1 row
- 1000 events/sec = 86.4M rows/day
- Consider archiving old events (>7 days)

**Archiving Script:**
```sql
DELETE FROM processed_events 
WHERE processed_at < NOW() - INTERVAL '7 days';
```

**Index Maintenance:**
```sql
REINDEX INDEX idx_event_id;
VACUUM ANALYZE processed_events;
```

---

## 7. Best Practices

### ✅ DO:
- Always use `publishXxxEventAsync()` methods
- Check idempotency before processing events
- Use `@Transactional` on consumer methods
- Log event IDs for debugging
- Monitor `processed_events` table growth

### ❌ DON'T:
- Don't use synchronous `publishXxxEvent()` methods
- Don't skip idempotency checks
- Don't process events outside transactions
- Don't delete from `processed_events` table manually
- Don't reuse event IDs

---

## 8. Monitoring & Metrics

### Key Metrics to Track:
1. **Async Thread Pool Utilization**
2. **Kafka Consumer Lag**
3. **Processed Events Table Size**
4. **Duplicate Event Detection Rate**
5. **Event Processing Time**

### Grafana Dashboard Queries:
```promql
# Async thread pool active threads
executor_active{name="async"}

# Kafka consumer lag
kafka_consumer_lag{group="notification-group"}

# Processed events count
rate(processed_events_total[5m])

# Duplicate events rate
rate(duplicate_events_total[5m])
```

---

## 9. Related Documentation

- **Implementation Details:** `ASYNC_IMPLEMENTATION_SUMMARY.md`
- **Idempotency Implementation:** `IDEMPOTENCY_IMPLEMENTATION.md`
- **E2E Testing:** `e2e-demo.sh`
- **Architecture Diagrams:** `README.md`

---

## 10. Quick Commands Reference

```bash
# Start application
./mvnw spring-boot:run

# Run E2E demo
./e2e-demo.sh

# Check processed events
docker exec postgres psql -U adsuser -d adsdb -c \
  "SELECT COUNT(*) FROM processed_events;"

# View recent logs
tail -f /tmp/app.log

# Check Kafka topics
docker exec kafka kafka-topics.sh \
  --bootstrap-server localhost:9092 --list

# Check consumer groups
docker exec kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 --list

# Monitor Kafka UI
open http://localhost:8080

# Check application health
curl http://localhost:8081/actuator/health | jq .
```

---

**Last Updated:** November 11, 2025  
**Version:** 1.0  
**Status:** ✅ Production Ready
