package com.umu.ads_proj.loadtest;

import com.umu.ads_proj.event.*;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.clients.producer.RecordMetadata;
import org.apache.kafka.common.serialization.StringSerializer;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.support.serializer.JsonSerializer;

import java.math.BigDecimal;
import java.time.Duration;
import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Concurrent Load Test Runner
 * Simulates 10-1000 concurrent users performing random actions
 * Features:
 * - Gradual load increase
 * - Variable message rates
 * - Random delays and failures
 * - Comprehensive metrics logging
 */
public class ConcurrentLoadTestRunner {
    
    private static final Logger logger = LoggerFactory.getLogger(ConcurrentLoadTestRunner.class);
    
    private final KafkaProducer<String, Object> producer;
    private final LoadTestMetrics metrics;
    private final Random random;
    
    // Configuration
    private final String bootstrapServers;
    private final List<String> topics;
    
    // Metrics counters
    private final AtomicInteger successCount = new AtomicInteger(0);
    private final AtomicInteger failureCount = new AtomicInteger(0);
    private final AtomicLong totalLatency = new AtomicLong(0);
    private final AtomicInteger activeUsers = new AtomicInteger(0);
    
    public ConcurrentLoadTestRunner(String bootstrapServers) {
        this.bootstrapServers = bootstrapServers;
        this.producer = createKafkaProducer();
        this.metrics = new LoadTestMetrics();
        this.random = new Random();
        this.topics = Arrays.asList("user-events", "order-events", "payment-events", "notification-events");
    }
    
    private KafkaProducer<String, Object> createKafkaProducer() {
        Properties props = new Properties();
        props.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, JsonSerializer.class.getName());
        props.put(ProducerConfig.ACKS_CONFIG, "1");
        props.put(ProducerConfig.RETRIES_CONFIG, 3);
        props.put(ProducerConfig.BATCH_SIZE_CONFIG, 16384);
        props.put(ProducerConfig.LINGER_MS_CONFIG, 10);
        props.put(ProducerConfig.BUFFER_MEMORY_CONFIG, 33554432);
        props.put(JsonSerializer.ADD_TYPE_INFO_HEADERS, false);
        
        return new KafkaProducer<>(props);
    }
    
    /**
     * Run load test with gradual ramp-up
     */
    public void runGradualLoadTest(int minUsers, int maxUsers, int durationSeconds, 
                                   int rampUpSeconds) {
        logger.info("Starting gradual load test: {} to {} users over {} seconds", 
                   minUsers, maxUsers, durationSeconds);
        
        ExecutorService executor = Executors.newCachedThreadPool();
        ScheduledExecutorService metricsLogger = Executors.newSingleThreadScheduledExecutor();
        ScheduledExecutorService userRampUp = Executors.newSingleThreadScheduledExecutor();
        
        // Start metrics logging
        metricsLogger.scheduleAtFixedRate(this::logCurrentMetrics, 0, 5, TimeUnit.SECONDS);
        
        long startTime = System.currentTimeMillis();
        long endTime = startTime + (durationSeconds * 1000L);
        
        // Calculate user increment
        int userIncrement = (maxUsers - minUsers) / rampUpSeconds;
        if (userIncrement < 1) userIncrement = 1;
        
        // Gradual ramp-up
        final int finalUserIncrement = userIncrement;
        final int finalMaxUsers = maxUsers;
        AtomicInteger currentMaxUsers = new AtomicInteger(minUsers);
        userRampUp.scheduleAtFixedRate(() -> {
            int current = currentMaxUsers.get();
            if (current < finalMaxUsers) {
                currentMaxUsers.addAndGet(finalUserIncrement);
                logger.info("Ramping up to {} concurrent users", Math.min(current + finalUserIncrement, finalMaxUsers));
            }
        }, 1, 1, TimeUnit.SECONDS);
        
        // Main test loop
        final long finalEndTime = endTime;
        while (System.currentTimeMillis() < endTime) {
            int currentUsers = Math.min(activeUsers.get(), currentMaxUsers.get());
            
            if (currentUsers < currentMaxUsers.get()) {
                // Add new user
                executor.submit(() -> simulateUser(finalEndTime));
            }
            
            try {
                Thread.sleep(50); // Check every 50ms
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                break;
            }
        }
        
        // Shutdown
        logger.info("Load test duration complete. Shutting down...");
        userRampUp.shutdown();
        executor.shutdown();
        
        try {
            executor.awaitTermination(30, TimeUnit.SECONDS);
        } catch (InterruptedException e) {
            executor.shutdownNow();
        }
        
        metricsLogger.shutdown();
        
        // Final metrics
        logFinalMetrics();
    }
    
    /**
     * Simulate a single user performing random actions
     */
    private void simulateUser(long endTime) {
        activeUsers.incrementAndGet();
        long userId = random.nextInt(10000) + 1L;
        
        try {
            while (System.currentTimeMillis() < endTime) {
                // Random action selection
                String action = selectRandomAction();
                
                // Variable delay between actions (100ms to 2s)
                int delay = 100 + random.nextInt(1900);
                Thread.sleep(delay);
                
                // Introduce occasional failures (5% chance)
                boolean shouldFail = random.nextDouble() < 0.05;
                
                if (shouldFail) {
                    // Simulate failure scenario
                    simulateFailure(action, userId);
                } else {
                    // Normal operation
                    performAction(action, userId);
                }
                
                // Vary message rate - occasionally burst messages
                if (random.nextDouble() < 0.1) {
                    // Burst: send 3-5 messages quickly
                    int burstSize = 3 + random.nextInt(3);
                    for (int i = 0; i < burstSize; i++) {
                        performAction(selectRandomAction(), userId);
                        Thread.sleep(50);
                    }
                }
            }
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        } finally {
            activeUsers.decrementAndGet();
        }
    }
    
    /**
     * Select random action with weighted distribution
     */
    private String selectRandomAction() {
        double rand = random.nextDouble();
        
        if (rand < 0.30) return "CREATE_USER";
        if (rand < 0.50) return "CREATE_ORDER";
        if (rand < 0.70) return "PROCESS_PAYMENT";
        if (rand < 0.85) return "UPDATE_ORDER";
        if (rand < 0.95) return "SEND_NOTIFICATION";
        return "CANCEL_ORDER";
    }
    
    /**
     * Perform the selected action
     */
    private void performAction(String action, long userId) {
        long startTime = System.nanoTime();
        
        try {
            Object event;
            String topic;
            
            switch (action) {
                case "CREATE_USER":
                    event = createUserEvent(userId);
                    topic = "user-events";
                    break;
                case "CREATE_ORDER":
                    event = createOrderEvent(userId);
                    topic = "order-events";
                    break;
                case "PROCESS_PAYMENT":
                    event = createPaymentEvent(userId);
                    topic = "payment-events";
                    break;
                case "UPDATE_ORDER":
                    event = updateOrderEvent(userId);
                    topic = "order-events";
                    break;
                case "SEND_NOTIFICATION":
                    event = createNotificationEvent(userId);
                    topic = "notification-events";
                    break;
                case "CANCEL_ORDER":
                    event = cancelOrderEvent(userId);
                    topic = "order-events";
                    break;
                default:
                    return;
            }
            
            // Send to Kafka
            ProducerRecord<String, Object> record = new ProducerRecord<>(topic, String.valueOf(userId), event);
            
            producer.send(record, (RecordMetadata metadata, Exception exception) -> {
                long latency = System.nanoTime() - startTime;
                totalLatency.addAndGet(latency);
                
                if (exception == null) {
                    successCount.incrementAndGet();
                    metrics.recordSuccess(action, latency / 1_000_000); // Convert to ms
                } else {
                    failureCount.incrementAndGet();
                    metrics.recordFailure(action, exception.getMessage());
                    logger.warn("Failed to send {} event: {}", action, exception.getMessage());
                }
            });
            
        } catch (Exception e) {
            failureCount.incrementAndGet();
            metrics.recordFailure(action, e.getMessage());
        }
    }
    
    /**
     * Simulate failure scenarios
     */
    private void simulateFailure(String action, long userId) {
        failureCount.incrementAndGet();
        metrics.recordFailure(action, "Simulated failure");
        
        // Add delay to simulate timeout or network issue
        try {
            Thread.sleep(random.nextInt(500) + 500); // 500-1000ms delay
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
        }
    }
    
    /**
     * Create user event
     */
    private UserEvent createUserEvent(long userId) {
        return UserEvent.userCreated(
            userId,
            "user_" + userId,
            "user" + userId + "@test.com"
        );
    }
    
    /**
     * Create order event
     */
    private OrderEvent createOrderEvent(long userId) {
        long orderId = random.nextInt(100000) + 1L;
        return OrderEvent.orderCreated(
            orderId,
            userId,
            "Product_" + random.nextInt(100),
            random.nextInt(10) + 1,
            BigDecimal.valueOf(random.nextDouble() * 1000 + 10)
        );
    }
    
    /**
     * Update order event
     */
    private OrderEvent updateOrderEvent(long userId) {
        long orderId = random.nextInt(100000) + 1L;
        String[] statuses = {"CONFIRMED", "SHIPPED", "DELIVERED"};
        return OrderEvent.orderUpdated(
            orderId,
            userId,
            "Product_" + random.nextInt(100),
            random.nextInt(10) + 1,
            BigDecimal.valueOf(random.nextDouble() * 1000 + 10),
            statuses[random.nextInt(statuses.length)]
        );
    }
    
    /**
     * Cancel order event
     */
    private OrderEvent cancelOrderEvent(long userId) {
        long orderId = random.nextInt(100000) + 1L;
        return OrderEvent.orderCancelled(
            orderId,
            userId,
            "Product_" + random.nextInt(100),
            random.nextInt(10) + 1,
            BigDecimal.valueOf(random.nextDouble() * 1000 + 10)
        );
    }
    
    /**
     * Create payment event
     */
    private PaymentEvent createPaymentEvent(long userId) {
        long paymentId = random.nextInt(100000) + 1L;
        long orderId = random.nextInt(100000) + 1L;
        return PaymentEvent.paymentCreated(
            paymentId,
            orderId,
            userId,
            BigDecimal.valueOf(random.nextDouble() * 1000 + 10),
            random.nextBoolean() ? "CREDIT_CARD" : "PAYPAL"
        );
    }
    
    /**
     * Create notification event
     */
    private NotificationEvent createNotificationEvent(long userId) {
        long notificationId = random.nextInt(100000) + 1L;
        long orderId = random.nextInt(100000) + 1L;
        return NotificationEvent.notificationSent(
            notificationId,
            orderId,
            userId,
            "ORDER_UPDATE",
            "EMAIL",
            "user" + userId + "@test.com"
        );
    }
    
    /**
     * Log current metrics
     */
    private void logCurrentMetrics() {
        int success = successCount.get();
        int failure = failureCount.get();
        int total = success + failure;
        
        double successRate = total > 0 ? (success * 100.0 / total) : 0;
        long avgLatency = success > 0 ? (totalLatency.get() / success / 1_000_000) : 0; // Convert to ms
        
        logger.info("═══════════════════════════════════════════════════════════");
        logger.info("LOAD TEST METRICS [{}]", LocalDateTime.now());
        logger.info("───────────────────────────────────────────────────────────");
        logger.info("Active Users:     {}", activeUsers.get());
        logger.info("Total Requests:   {}", total);
        logger.info("Successful:       {} ({:.2f}%)", success, successRate);
        logger.info("Failed:           {} ({:.2f}%)", failure, 100 - successRate);
        logger.info("Avg Latency:      {} ms", avgLatency);
        logger.info("Throughput:       {:.2f} req/sec", metrics.getThroughput());
        logger.info("───────────────────────────────────────────────────────────");
        metrics.logActionBreakdown();
        logger.info("═══════════════════════════════════════════════════════════\n");
    }
    
    /**
     * Log final metrics
     */
    private void logFinalMetrics() {
        int success = successCount.get();
        int failure = failureCount.get();
        int total = success + failure;
        
        double successRate = total > 0 ? (success * 100.0 / total) : 0;
        long avgLatency = success > 0 ? (totalLatency.get() / success / 1_000_000) : 0;
        
        logger.info("\n");
        logger.info("╔═══════════════════════════════════════════════════════════╗");
        logger.info("║           FINAL LOAD TEST RESULTS                         ║");
        logger.info("╠═══════════════════════════════════════════════════════════╣");
        logger.info("║ Total Requests:      {:>10}                         ║", total);
        logger.info("║ Successful:          {:>10} ({:>6.2f}%)              ║", success, successRate);
        logger.info("║ Failed:              {:>10} ({:>6.2f}%)              ║", failure, 100 - successRate);
        logger.info("║ Average Latency:     {:>10} ms                       ║", avgLatency);
        logger.info("║ Peak Users:          {:>10}                         ║", activeUsers.get());
        logger.info("╠═══════════════════════════════════════════════════════════╣");
        logger.info("║ Action Breakdown:                                         ║");
        logger.info("╠═══════════════════════════════════════════════════════════╣");
        metrics.logFinalBreakdown();
        logger.info("╚═══════════════════════════════════════════════════════════╝\n");
    }
    
    /**
     * Close resources
     */
    public void close() {
        if (producer != null) {
            producer.close();
        }
    }
    
    /**
     * Main entry point for standalone execution
     */
    public static void main(String[] args) {
        String bootstrapServers = args.length > 0 ? args[0] : "localhost:9092";
        int minUsers = args.length > 1 ? Integer.parseInt(args[1]) : 10;
        int maxUsers = args.length > 2 ? Integer.parseInt(args[2]) : 1000;
        int durationSeconds = args.length > 3 ? Integer.parseInt(args[3]) : 300; // 5 minutes
        int rampUpSeconds = args.length > 4 ? Integer.parseInt(args[4]) : 60; // 1 minute
        
        logger.info("Concurrent Load Test Configuration:");
        logger.info("  Bootstrap Servers: {}", bootstrapServers);
        logger.info("  User Range: {} - {}", minUsers, maxUsers);
        logger.info("  Duration: {} seconds", durationSeconds);
        logger.info("  Ramp-up Time: {} seconds", rampUpSeconds);
        
        ConcurrentLoadTestRunner runner = new ConcurrentLoadTestRunner(bootstrapServers);
        
        try {
            runner.runGradualLoadTest(minUsers, maxUsers, durationSeconds, rampUpSeconds);
        } finally {
            runner.close();
        }
    }
}
