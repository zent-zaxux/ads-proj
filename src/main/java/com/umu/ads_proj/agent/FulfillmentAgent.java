package com.umu.ads_proj.agent;

import com.umu.ads_proj.entity.Order;
import com.umu.ads_proj.event.PerformanceEvent;
import com.umu.ads_proj.repository.OrderRepository;
import com.umu.ads_proj.service.EventPublisherService;
import com.umu.ads_proj.service.OrderService;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.config.KafkaListenerEndpointRegistry;
import org.springframework.kafka.listener.MessageListenerContainer;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

import jakarta.annotation.PostConstruct;
import jakarta.annotation.PreDestroy;
import java.time.LocalDateTime;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;
import java.util.stream.Collectors;

/**
 * Autonomous Fulfillment Agent
 * 
 * This agent:
 * - Consumes PENDING orders from the database
 * - Processes orders through workflow: PENDING → CONFIRMED → SHIPPED → DELIVERED
 * - Supports pause/resume for lag testing (pauses Kafka consumer)
 * - Reports metrics to Kafka performance-events topic
 * - Configurable processing speed
 * 
 * Use Cases:
 * - Simulate order fulfillment pipeline
 * - Test Kafka consumer lag and catch-up
 * - Demonstrate autonomous agent behavior
 * - Load testing with Traffic Agent
 */
@Component
public class FulfillmentAgent {
    
    private static final Logger logger = LoggerFactory.getLogger(FulfillmentAgent.class);
    
    @Autowired
    private OrderRepository orderRepository;
    
    @Autowired
    private OrderService orderService;
    
    @Autowired
    private EventPublisherService eventPublisherService;
    
    @Autowired
    private KafkaListenerEndpointRegistry kafkaListenerEndpointRegistry;
    
    // Agent identification
    private final String agentId;
    
    // Control flags
    private final AtomicBoolean running = new AtomicBoolean(false);
    private final AtomicBoolean paused = new AtomicBoolean(false);
    
    // Thread pools
    private ScheduledExecutorService schedulerExecutor;
    private ExecutorService workerExecutor;
    private ExecutorService processingExecutor; // NEW: For parallel order processing
    
    // Configuration - HIGHLY OPTIMIZED for maximum performance
    @Value("${fulfillment.agent.processing-delay-ms:100}")
    private int processingDelayMs;
    
    @Value("${fulfillment.agent.batch-size:50}")
    private int batchSize;
    
    @Value("${fulfillment.agent.polling-interval-seconds:1}")
    private int pollingIntervalSeconds;
    
    @Value("${fulfillment.agent.parallel-threads:8}")
    private int parallelThreads;
    
    // Metrics
    private final AtomicLong ordersProcessed = new AtomicLong(0);
    private final AtomicLong ordersConfirmed = new AtomicLong(0);
    private final AtomicLong ordersShipped = new AtomicLong(0);
    private final AtomicLong ordersDelivered = new AtomicLong(0);
    private final AtomicLong ordersFailed = new AtomicLong(0);
    private final AtomicLong totalProcessingTimeMs = new AtomicLong(0);
    
    private LocalDateTime startTime;
    private LocalDateTime pauseTime;
    
    // Kafka consumer control
    private static final String ORDER_LISTENER_ID = "org.springframework.kafka.KafkaListenerEndpointContainer#2-0";
    
    public FulfillmentAgent() {
        this.agentId = "FULFILLMENT-AGENT-" + UUID.randomUUID().toString().substring(0, 8);
    }
    
    @PostConstruct
    public void init() {
        logger.info("🏭 Fulfillment Agent initialized: {}", agentId);
    }
    
    /**
     * Start the fulfillment agent
     */
    public synchronized void start() {
        if (running.get()) {
            logger.warn("Fulfillment agent is already running");
            return;
        }
        
        logger.info("🚀 STARTING FULFILLMENT AGENT: {}", agentId);
        logger.info("   Processing Delay: {}ms per transition", processingDelayMs);
        logger.info("   Batch Size: {} orders", batchSize);
        logger.info("   Polling Interval: {}s", pollingIntervalSeconds);
        logger.info("   Parallel Threads: {}", parallelThreads);
        logger.info("═══════════════════════════════════════════════════════════");
        
        running.set(true);
        paused.set(false);
        startTime = LocalDateTime.now();
        pauseTime = null;
        
        // Initialize thread pools - OPTIMIZED with parallel processing
        schedulerExecutor = Executors.newScheduledThreadPool(2);
        workerExecutor = Executors.newFixedThreadPool(10);
        processingExecutor = Executors.newFixedThreadPool(parallelThreads); // NEW: Parallel processing pool
        
        // Start order processing loop
        schedulerExecutor.scheduleAtFixedRate(
            this::processOrders,
            0,
            pollingIntervalSeconds,
            TimeUnit.SECONDS
        );
        
        // Start metrics reporting (every 15 seconds)
        schedulerExecutor.scheduleAtFixedRate(
            this::reportMetrics,
            15,
            15,
            TimeUnit.SECONDS
        );
        
        // Publish start event
        publishAgentEvent("STARTED", "Fulfillment agent started. Polling every " + pollingIntervalSeconds + "s");
        
        logger.info("✅ Fulfillment agent {} started successfully", agentId);
    }
    
    /**
     * Stop the fulfillment agent
     */
    public synchronized void stop() {
        if (!running.get()) {
            logger.warn("Fulfillment agent is not running");
            return;
        }
        
        logger.info("🛑 STOPPING FULFILLMENT AGENT: {}", agentId);
        
        running.set(false);
        
        // Shutdown thread pools
        if (schedulerExecutor != null) {
            schedulerExecutor.shutdown();
            try {
                if (!schedulerExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                    schedulerExecutor.shutdownNow();
                }
            } catch (InterruptedException e) {
                schedulerExecutor.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
        
        if (workerExecutor != null) {
            workerExecutor.shutdown();
            try {
                if (!workerExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                    workerExecutor.shutdownNow();
                }
            } catch (InterruptedException e) {
                workerExecutor.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
        
        // NEW: Shutdown processing executor
        if (processingExecutor != null) {
            processingExecutor.shutdown();
            try {
                if (!processingExecutor.awaitTermination(5, TimeUnit.SECONDS)) {
                    processingExecutor.shutdownNow();
                }
            } catch (InterruptedException e) {
                processingExecutor.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
        
        // Publish stop event
        publishAgentEvent("STOPPED", "Fulfillment agent stopped. Total orders processed: " + ordersProcessed.get());
        
        logger.info("✅ Fulfillment agent {} stopped", agentId);
        printFinalStats();
    }
    
    /**
     * Pause the fulfillment agent
     * This pauses the Kafka consumer to simulate lag
     */
    public synchronized void pause() {
        if (!running.get()) {
            logger.warn("Cannot pause: agent is not running");
            return;
        }
        
        if (paused.get()) {
            logger.warn("Agent is already paused");
            return;
        }
        
        logger.info("⏸️  PAUSING FULFILLMENT AGENT: {}", agentId);
        paused.set(true);
        pauseTime = LocalDateTime.now();
        
        // Pause Kafka consumer to create lag
        pauseKafkaConsumer();
        
        publishAgentEvent("PAUSED", "Fulfillment agent paused. Orders will accumulate (lag simulation)");
        
        logger.info("✅ Fulfillment agent paused. Orders will queue up.");
    }
    
    /**
     * Resume the fulfillment agent
     * This resumes the Kafka consumer to catch up on lag
     */
    public synchronized void resume() {
        if (!running.get()) {
            logger.warn("Cannot resume: agent is not running");
            return;
        }
        
        if (!paused.get()) {
            logger.warn("Agent is not paused");
            return;
        }
        
        logger.info("▶️  RESUMING FULFILLMENT AGENT: {}", agentId);
        
        long pauseDuration = pauseTime != null ? 
            ChronoUnit.SECONDS.between(pauseTime, LocalDateTime.now()) : 0;
        
        paused.set(false);
        pauseTime = null;
        
        // Resume Kafka consumer to catch up on backlog
        resumeKafkaConsumer();
        
        publishAgentEvent("RESUMED", "Fulfillment agent resumed after " + pauseDuration + "s. Catching up on backlog");
        
        logger.info("✅ Fulfillment agent resumed. Processing backlog...");
    }
    
    /**
     * Main order processing loop - OPTIMIZED with parallel batch processing
     * FAST TRACK MODE: Processes orders through all stages in one go
     */
    @Async
    @Timed(value = "fulfillment.agent.processing", description = "Time to process orders")
    private void processOrders() {
        if (!running.get() || paused.get()) {
            return;
        }
        
        try {
            // Find pending orders only (we process them through all stages)
            List<Order> pendingOrders = orderRepository.findByStatusOrderByCreatedAtAsc(
                Order.OrderStatus.PENDING
            );
            
            if (!pendingOrders.isEmpty()) {
                logger.info("📦 Found {} PENDING orders to process (FAST TRACK)", pendingOrders.size());
                
                // Process in batches with parallel execution - OPTIMIZED
                List<Order> batch = pendingOrders.stream()
                    .limit(batchSize)
                    .toList();
                
                // Process all orders in batch in parallel using CompletableFuture
                List<CompletableFuture<Void>> futures = batch.stream()
                    .map(order -> CompletableFuture.runAsync(
                        () -> processOrderWorkflow(order), 
                        processingExecutor
                    ))
                    .collect(Collectors.toList());
                
                // Wait for all to complete
                CompletableFuture.allOf(futures.toArray(new CompletableFuture[0])).join();
            }
            
        } catch (Exception e) {
            logger.error("Error in order processing loop: {}", e.getMessage(), e);
        }
    }
    
    /**
     * Process a single order through the COMPLETE workflow - FAST TRACK MODE
     * Processes PENDING → CONFIRMED → SHIPPED → DELIVERED in one go
     */
    private void processOrderWorkflow(Order order) {
        long startTime = System.currentTimeMillis();
        
        try {
            logger.info("🔄 Processing order #{} (Status: {})", order.getId(), order.getStatus());
            
            // FAST TRACK: Process through all stages immediately
            if (order.getStatus() == Order.OrderStatus.PENDING) {
                // PENDING → CONFIRMED
                Thread.sleep(processingDelayMs);
                orderService.updateOrderStatus(order.getId(), Order.OrderStatus.CONFIRMED);
                ordersConfirmed.incrementAndGet();
                ordersProcessed.incrementAndGet();
                logger.debug("✅ Order #{} → CONFIRMED", order.getId());
                
                // CONFIRMED → SHIPPED
                Thread.sleep(processingDelayMs);
                orderService.updateOrderStatus(order.getId(), Order.OrderStatus.SHIPPED);
                ordersShipped.incrementAndGet();
                ordersProcessed.incrementAndGet();
                logger.debug("✅ Order #{} → SHIPPED", order.getId());
                
                // SHIPPED → DELIVERED
                Thread.sleep(processingDelayMs);
                orderService.updateOrderStatus(order.getId(), Order.OrderStatus.DELIVERED);
                ordersDelivered.incrementAndGet();
                ordersProcessed.incrementAndGet();
                logger.info("✅ Order #{} → DELIVERED (FAST TRACK)", order.getId());
            }
            
            long processingTime = System.currentTimeMillis() - startTime;
            totalProcessingTimeMs.addAndGet(processingTime);
            
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            logger.warn("Order processing interrupted for order #{}", order.getId());
        } catch (Exception e) {
            logger.error("Failed to process order #{}: {}", order.getId(), e.getMessage());
            ordersFailed.incrementAndGet();
        }
    }
    
    /**
     * Report metrics to Kafka
     */
    private void reportMetrics() {
        if (!running.get()) {
            return;
        }
        
        long totalOrders = ordersProcessed.get();
        long avgProcessingTime = totalOrders > 0 ? 
            totalProcessingTimeMs.get() / totalOrders : 0;
        
        long backlogCount = getBacklogCount();
        long uptime = getUptimeSeconds();
        
        double throughput = uptime > 0 ? (double) totalOrders / uptime : 0.0;
        
        logger.info("📊 FULFILLMENT METRICS [{}]: Processed={}, Confirmed={}, Shipped={}, Delivered={}, Failed={}, Backlog={}, Avg={}ms, Throughput={:.2f}/s",
            agentId, totalOrders, ordersConfirmed.get(), ordersShipped.get(), 
            ordersDelivered.get(), ordersFailed.get(), backlogCount, avgProcessingTime, throughput);
        
        String details = String.format(
            "Agent %s: Processed=%d, Confirmed=%d, Shipped=%d, Delivered=%d, Failed=%d, Backlog=%d, AvgTime=%dms, Throughput=%.2f/s",
            agentId, totalOrders, ordersConfirmed.get(), ordersShipped.get(),
            ordersDelivered.get(), ordersFailed.get(), backlogCount, avgProcessingTime, throughput
        );
        
        PerformanceEvent event = new PerformanceEvent();
        event.setTestType(agentId);
        event.setAction(PerformanceEvent.PerformanceAction.SYSTEM_HEALTHY);
        event.setNumberOfOperations((int) totalOrders);
        event.setThroughput(throughput);
        event.setDetails(details);
        
        eventPublisherService.publishPerformanceEvent(event);
    }
    
    /**
     * Pause Kafka consumer
     */
    private void pauseKafkaConsumer() {
        try {
            MessageListenerContainer container = kafkaListenerEndpointRegistry
                .getListenerContainer(ORDER_LISTENER_ID);
            
            if (container != null) {
                container.pause();
                logger.info("⏸️  Kafka consumer paused: {}", ORDER_LISTENER_ID);
            } else {
                logger.warn("Kafka consumer not found: {}", ORDER_LISTENER_ID);
            }
        } catch (Exception e) {
            logger.error("Failed to pause Kafka consumer: {}", e.getMessage());
        }
    }
    
    /**
     * Resume Kafka consumer
     */
    private void resumeKafkaConsumer() {
        try {
            MessageListenerContainer container = kafkaListenerEndpointRegistry
                .getListenerContainer(ORDER_LISTENER_ID);
            
            if (container != null) {
                container.resume();
                logger.info("▶️  Kafka consumer resumed: {}", ORDER_LISTENER_ID);
            } else {
                logger.warn("Kafka consumer not found: {}", ORDER_LISTENER_ID);
            }
        } catch (Exception e) {
            logger.error("Failed to resume Kafka consumer: {}", e.getMessage());
        }
    }
    
    /**
     * Publish agent lifecycle event
     */
    private void publishAgentEvent(String action, String details) {
        try {
            PerformanceEvent event = new PerformanceEvent();
            event.setTestType(agentId);
            event.setAction(PerformanceEvent.PerformanceAction.SYSTEM_HEALTHY);
            event.setDetails(action + ": " + details);
            
            eventPublisherService.publishPerformanceEvent(event);
        } catch (Exception e) {
            logger.error("Failed to publish agent event: {}", e.getMessage());
        }
    }
    
    /**
     * Get current backlog count
     */
    private long getBacklogCount() {
        try {
            long pending = orderRepository.countByStatus(Order.OrderStatus.PENDING);
            long confirmed = orderRepository.countByStatus(Order.OrderStatus.CONFIRMED);
            long shipped = orderRepository.countByStatus(Order.OrderStatus.SHIPPED);
            return pending + confirmed + shipped;
        } catch (Exception e) {
            logger.error("Failed to get backlog count: {}", e.getMessage());
            return 0;
        }
    }
    
    /**
     * Get agent uptime in seconds
     */
    private long getUptimeSeconds() {
        if (startTime == null) {
            return 0;
        }
        return ChronoUnit.SECONDS.between(startTime, LocalDateTime.now());
    }
    
    /**
     * Print final statistics
     */
    private void printFinalStats() {
        logger.info("═══════════════════════════════════════════════════════════");
        logger.info("📈 FULFILLMENT AGENT FINAL STATS: {}", agentId);
        logger.info("   Total Processed: {}", ordersProcessed.get());
        logger.info("   Confirmed: {}", ordersConfirmed.get());
        logger.info("   Shipped: {}", ordersShipped.get());
        logger.info("   Delivered: {}", ordersDelivered.get());
        logger.info("   Failed: {}", ordersFailed.get());
        logger.info("   Uptime: {}s", getUptimeSeconds());
        
        long avgTime = ordersProcessed.get() > 0 ? 
            totalProcessingTimeMs.get() / ordersProcessed.get() : 0;
        logger.info("   Avg Processing Time: {}ms", avgTime);
        
        logger.info("═══════════════════════════════════════════════════════════");
    }
    
    /**
     * Get agent statistics
     */
    public AgentStats getStats() {
        return new AgentStats(
            agentId,
            running.get() ? "RUNNING" : "STOPPED",
            paused.get(),
            startTime,
            pauseTime,
            processingDelayMs,
            batchSize,
            pollingIntervalSeconds,
            ordersProcessed.get(),
            ordersConfirmed.get(),
            ordersShipped.get(),
            ordersDelivered.get(),
            ordersFailed.get(),
            getBacklogCount(),
            ordersProcessed.get() > 0 ? totalProcessingTimeMs.get() / ordersProcessed.get() : 0,
            getUptimeSeconds()
        );
    }
    
    // Getters and setters
    public String getAgentId() {
        return agentId;
    }
    
    public boolean isRunning() {
        return running.get();
    }
    
    public boolean isPaused() {
        return paused.get();
    }
    
    public void setProcessingDelayMs(int processingDelayMs) {
        this.processingDelayMs = processingDelayMs;
        logger.info("Processing delay changed to: {}ms", processingDelayMs);
    }
    
    public void setBatchSize(int batchSize) {
        this.batchSize = batchSize;
        logger.info("Batch size changed to: {}", batchSize);
    }
    
    public void setPollingIntervalSeconds(int pollingIntervalSeconds) {
        this.pollingIntervalSeconds = pollingIntervalSeconds;
        logger.info("Polling interval changed to: {}s (restart agent to apply)", pollingIntervalSeconds);
    }
    
    @PreDestroy
    public void cleanup() {
        if (running.get()) {
            stop();
        }
    }
    
    /**
     * Agent statistics class
     */
    public static class AgentStats {
        private final String agentId;
        private final String status;
        private final boolean isPaused;
        private final LocalDateTime startTime;
        private final LocalDateTime pauseTime;
        private final int processingDelayMs;
        private final int batchSize;
        private final int pollingIntervalSeconds;
        private final long totalProcessed;
        private final long ordersConfirmed;
        private final long ordersShipped;
        private final long ordersDelivered;
        private final long ordersFailed;
        private final long currentBacklog;
        private final long avgProcessingTimeMs;
        private final long uptimeSeconds;
        
        public AgentStats(String agentId, String status, boolean isPaused,
                         LocalDateTime startTime, LocalDateTime pauseTime,
                         int processingDelayMs, int batchSize, int pollingIntervalSeconds,
                         long totalProcessed, long ordersConfirmed, long ordersShipped,
                         long ordersDelivered, long ordersFailed, long currentBacklog,
                         long avgProcessingTimeMs, long uptimeSeconds) {
            this.agentId = agentId;
            this.status = status;
            this.isPaused = isPaused;
            this.startTime = startTime;
            this.pauseTime = pauseTime;
            this.processingDelayMs = processingDelayMs;
            this.batchSize = batchSize;
            this.pollingIntervalSeconds = pollingIntervalSeconds;
            this.totalProcessed = totalProcessed;
            this.ordersConfirmed = ordersConfirmed;
            this.ordersShipped = ordersShipped;
            this.ordersDelivered = ordersDelivered;
            this.ordersFailed = ordersFailed;
            this.currentBacklog = currentBacklog;
            this.avgProcessingTimeMs = avgProcessingTimeMs;
            this.uptimeSeconds = uptimeSeconds;
        }
        
        // Getters
        public String getAgentId() { return agentId; }
        public String getStatus() { return status; }
        public boolean isPaused() { return isPaused; }
        public LocalDateTime getStartTime() { return startTime; }
        public LocalDateTime getPauseTime() { return pauseTime; }
        public int getProcessingDelayMs() { return processingDelayMs; }
        public int getBatchSize() { return batchSize; }
        public int getPollingIntervalSeconds() { return pollingIntervalSeconds; }
        public long getTotalProcessed() { return totalProcessed; }
        public long getOrdersConfirmed() { return ordersConfirmed; }
        public long getOrdersShipped() { return ordersShipped; }
        public long getOrdersDelivered() { return ordersDelivered; }
        public long getOrdersFailed() { return ordersFailed; }
        public long getCurrentBacklog() { return currentBacklog; }
        public long getAvgProcessingTimeMs() { return avgProcessingTimeMs; }
        public long getUptimeSeconds() { return uptimeSeconds; }
    }
}
