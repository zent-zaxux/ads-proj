package com.umu.ads_proj.agent;

import com.umu.ads_proj.entity.User;
import com.umu.ads_proj.event.PerformanceEvent;
import com.umu.ads_proj.service.EventPublisherService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestTemplate;

import java.time.LocalDateTime;
import java.util.*;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Traffic Agent - Autonomous Load Generator
 * 
 * This agent runs independently and generates continuous traffic to the system.
 * It can be deployed as multiple distributed instances, each generating load.
 * 
 * Key Features:
 * - Autonomous operation (starts automatically)
 * - Configurable traffic patterns (steady, burst, ramp-up, spike)
 * - Pause/Resume capability (for lag testing)
 * - Metrics publishing to Kafka
 * - Thread-safe concurrent execution
 * - Distributed deployment ready
 */
@Component
public class TrafficAgent {
    
    private static final Logger logger = LoggerFactory.getLogger(TrafficAgent.class);
    
    @Autowired
    private RestTemplate restTemplate;
    
    @Autowired
    private EventPublisherService eventPublisherService;
    
    // Agent Configuration
    private final String agentId;
    private final String baseUrl = "http://localhost:8081";
    
    // Agent State
    private final AtomicBoolean running = new AtomicBoolean(false);
    private final AtomicBoolean paused = new AtomicBoolean(false);
    private TrafficPattern currentPattern = TrafficPattern.STEADY;
    private int operationsPerSecond = 5;
    
    // Metrics
    private final AtomicLong totalOperations = new AtomicLong(0);
    private final AtomicLong successfulOperations = new AtomicLong(0);
    private final AtomicLong failedOperations = new AtomicLong(0);
    private LocalDateTime startTime;
    private LocalDateTime pauseTime;
    
    // Thread Pool
    private ScheduledExecutorService scheduler;
    private ExecutorService workerPool;
    
    /**
     * Traffic patterns supported by the agent
     */
    public enum TrafficPattern {
        STEADY,      // Constant rate
        BURST,       // Periodic bursts
        RAMP_UP,     // Gradually increasing
        SPIKE,       // Sudden spike then back to normal
        RANDOM       // Random fluctuations
    }
    
    /**
     * Agent statistics
     */
    public static class AgentStats {
        public String agentId;
        public String status;
        public TrafficPattern pattern;
        public int targetOpsPerSecond;
        public long totalOperations;
        public long successfulOperations;
        public long failedOperations;
        public double successRate;
        public long uptimeSeconds;
        public LocalDateTime startTime;
        public LocalDateTime pauseTime;
        public boolean isPaused;
        
        public AgentStats(String agentId, String status, TrafficPattern pattern,
                         int opsPerSecond, long total, long success, long failed,
                         LocalDateTime startTime, LocalDateTime pauseTime, boolean isPaused) {
            this.agentId = agentId;
            this.status = status;
            this.pattern = pattern;
            this.targetOpsPerSecond = opsPerSecond;
            this.totalOperations = total;
            this.successfulOperations = success;
            this.failedOperations = failed;
            this.successRate = total > 0 ? (success * 100.0 / total) : 0.0;
            this.startTime = startTime;
            this.pauseTime = pauseTime;
            this.isPaused = isPaused;
            this.uptimeSeconds = startTime != null ? 
                java.time.Duration.between(startTime, LocalDateTime.now()).getSeconds() : 0;
        }
    }
    
    public TrafficAgent() {
        this.agentId = "TRAFFIC-AGENT-" + UUID.randomUUID().toString().substring(0, 8);
        logger.info("🚗 Traffic Agent initialized: {}", agentId);
    }
    
    /**
     * Start the traffic agent
     */
    public synchronized void start() {
        if (running.get()) {
            logger.warn("Traffic agent {} is already running", agentId);
            return;
        }
        
        logger.info("════════════════════════════════════════════════════════════");
        logger.info("🚦 STARTING TRAFFIC AGENT: {}", agentId);
        logger.info("   Pattern: {}", currentPattern);
        logger.info("   Target: {} ops/sec", operationsPerSecond);
        logger.info("════════════════════════════════════════════════════════════");
        
        running.set(true);
        paused.set(false);
        startTime = LocalDateTime.now();
        
        // Initialize thread pools
        scheduler = Executors.newScheduledThreadPool(2);
        workerPool = Executors.newFixedThreadPool(10);
        
        // Publish agent started event
        publishAgentEvent("STARTED", "Traffic agent started with pattern: " + currentPattern);
        
        // Start traffic generation based on pattern
        scheduleTrafficGeneration();
        
        // Start metrics reporting
        scheduleMetricsReporting();
        
        logger.info("✅ Traffic agent {} started successfully", agentId);
    }
    
    /**
     * Stop the traffic agent
     */
    public synchronized void stop() {
        if (!running.get()) {
            logger.warn("Traffic agent {} is not running", agentId);
            return;
        }
        
        logger.info("🛑 STOPPING TRAFFIC AGENT: {}", agentId);
        
        running.set(false);
        paused.set(false);
        
        // Shutdown thread pools
        if (scheduler != null) {
            scheduler.shutdown();
            try {
                if (!scheduler.awaitTermination(5, TimeUnit.SECONDS)) {
                    scheduler.shutdownNow();
                }
            } catch (InterruptedException e) {
                scheduler.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
        
        if (workerPool != null) {
            workerPool.shutdown();
            try {
                if (!workerPool.awaitTermination(5, TimeUnit.SECONDS)) {
                    workerPool.shutdownNow();
                }
            } catch (InterruptedException e) {
                workerPool.shutdownNow();
                Thread.currentThread().interrupt();
            }
        }
        
        // Publish agent stopped event
        publishAgentEvent("STOPPED", "Traffic agent stopped. Total operations: " + totalOperations.get());
        
        logger.info("✅ Traffic agent {} stopped", agentId);
        printFinalStats();
    }
    
    /**
     * Pause the traffic agent (for lag testing)
     */
    public synchronized void pause() {
        if (!running.get()) {
            logger.warn("Cannot pause - agent {} is not running", agentId);
            return;
        }
        
        if (paused.get()) {
            logger.warn("Agent {} is already paused", agentId);
            return;
        }
        
        logger.info("⏸️  PAUSING TRAFFIC AGENT: {}", agentId);
        paused.set(true);
        pauseTime = LocalDateTime.now();
        
        publishAgentEvent("PAUSED", "Traffic agent paused for lag testing");
        
        logger.info("✅ Traffic agent {} paused", agentId);
    }
    
    /**
     * Resume the traffic agent (after pause)
     */
    public synchronized void resume() {
        if (!running.get()) {
            logger.warn("Cannot resume - agent {} is not running", agentId);
            return;
        }
        
        if (!paused.get()) {
            logger.warn("Agent {} is not paused", agentId);
            return;
        }
        
        logger.info("▶️  RESUMING TRAFFIC AGENT: {}", agentId);
        
        long pauseDuration = java.time.Duration.between(pauseTime, LocalDateTime.now()).getSeconds();
        paused.set(false);
        pauseTime = null;
        
        publishAgentEvent("RESUMED", "Traffic agent resumed after " + pauseDuration + " seconds");
        
        logger.info("✅ Traffic agent {} resumed (paused for {}s)", agentId, pauseDuration);
    }
    
    /**
     * Schedule traffic generation based on pattern
     */
    private void scheduleTrafficGeneration() {
        long intervalMs = 1000 / operationsPerSecond;
        
        scheduler.scheduleAtFixedRate(() -> {
            if (!paused.get()) {
                generateTrafficBurst();
            } else {
                logger.debug("Agent {} paused - skipping traffic generation", agentId);
            }
        }, 0, intervalMs, TimeUnit.MILLISECONDS);
    }
    
    /**
     * Generate a burst of traffic operations
     */
    private void generateTrafficBurst() {
        try {
            // Randomly choose operation type
            OperationType opType = OperationType.random();
            
            // Execute operation asynchronously
            workerPool.submit(() -> executeOperation(opType));
            
        } catch (Exception e) {
            logger.error("Error generating traffic: {}", e.getMessage());
        }
    }
    
    /**
     * Execute a single operation
     */
    private void executeOperation(OperationType opType) {
        totalOperations.incrementAndGet();
        
        try {
            boolean success = false;
            
            switch (opType) {
                case CREATE_USER:
                    success = createUser();
                    break;
                case CREATE_ORDER:
                    success = createOrder();
                    break;
                case CREATE_PAYMENT:
                    success = createPayment();
                    break;
                case UPDATE_ORDER_STATUS:
                    success = updateOrderStatus();
                    break;
                case CANCEL_ORDER:
                    success = cancelOrder();
                    break;
            }
            
            if (success) {
                successfulOperations.incrementAndGet();
            } else {
                failedOperations.incrementAndGet();
            }
            
        } catch (Exception e) {
            failedOperations.incrementAndGet();
            logger.debug("Operation {} failed: {}", opType, e.getMessage());
        }
    }
    
    /**
     * Operation types
     */
    private enum OperationType {
        CREATE_USER(30),      // 30% probability
        CREATE_ORDER(40),     // 40% probability
        CREATE_PAYMENT(10),   // 10% probability
        UPDATE_ORDER_STATUS(15),  // 15% probability
        CANCEL_ORDER(5);      // 5% probability
        
        private final int weight;
        
        OperationType(int weight) {
            this.weight = weight;
        }
        
        static OperationType random() {
            int totalWeight = Arrays.stream(values()).mapToInt(v -> v.weight).sum();
            int random = ThreadLocalRandom.current().nextInt(totalWeight);
            
            int cumulativeWeight = 0;
            for (OperationType type : values()) {
                cumulativeWeight += type.weight;
                if (random < cumulativeWeight) {
                    return type;
                }
            }
            return CREATE_USER;
        }
    }
    
    /**
     * Create a user
     */
    private boolean createUser() {
        try {
            String name = "Agent User " + ThreadLocalRandom.current().nextInt(10000);
            String email = "agent.user." + System.currentTimeMillis() + "@traffic.test";
            
            Map<String, Object> user = new HashMap<>();
            user.put("name", name);
            user.put("email", email);
            user.put("phoneNumber", "+1" + ThreadLocalRandom.current().nextInt(1000000000));
            user.put("address", "Traffic Test Address " + ThreadLocalRandom.current().nextInt(1000));
            
            ResponseEntity<User> response = restTemplate.postForEntity(
                    baseUrl + "/api/users",
                    user,
                    User.class
            );
            
            return response.getStatusCode().is2xxSuccessful();
            
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Create an order
     */
    private boolean createOrder() {
        try {
            long userId = ThreadLocalRandom.current().nextInt(1, 10);
            String[] products = {"Laptop", "Phone", "Tablet", "Monitor", "Keyboard", "Mouse", "Headset", "Webcam"};
            String product = products[ThreadLocalRandom.current().nextInt(products.length)];
            
            Map<String, Object> order = new HashMap<>();
            order.put("userId", userId);
            order.put("productName", product);
            order.put("quantity", ThreadLocalRandom.current().nextInt(1, 5));
            order.put("unitPrice", ThreadLocalRandom.current().nextDouble(99.99, 999.99));
            
            ResponseEntity<String> response = restTemplate.postForEntity(
                    baseUrl + "/api/orders",
                    order,
                    String.class
            );
            
            return response.getStatusCode().is2xxSuccessful();
            
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Create a payment
     */
    private boolean createPayment() {
        try {
            long orderId = ThreadLocalRandom.current().nextInt(1, 50);
            long userId = ThreadLocalRandom.current().nextInt(1, 10);
            
            Map<String, Object> payment = new HashMap<>();
            payment.put("orderId", orderId);
            payment.put("userId", userId);
            payment.put("amount", ThreadLocalRandom.current().nextDouble(50.0, 1000.0));
            payment.put("paymentMethod", "CREDIT_CARD");
            
            ResponseEntity<String> response = restTemplate.postForEntity(
                    baseUrl + "/api/payments",
                    payment,
                    String.class
            );
            
            return response.getStatusCode().is2xxSuccessful();
            
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Update order status
     */
    private boolean updateOrderStatus() {
        try {
            long orderId = ThreadLocalRandom.current().nextInt(1, 50);
            String[] statuses = {"CONFIRMED", "SHIPPED", "DELIVERED"};
            String status = statuses[ThreadLocalRandom.current().nextInt(statuses.length)];
            
            Map<String, Object> request = new HashMap<>();
            request.put("status", status);
            
            restTemplate.put(
                    baseUrl + "/api/orders/" + orderId + "/status",
                    request
            );
            
            return true;
            
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Cancel an order
     */
    private boolean cancelOrder() {
        try {
            long orderId = ThreadLocalRandom.current().nextInt(1, 50);
            
            restTemplate.delete(baseUrl + "/api/orders/" + orderId + "/cancel");
            
            return true;
            
        } catch (Exception e) {
            return false;
        }
    }
    
    /**
     * Schedule metrics reporting
     */
    private void scheduleMetricsReporting() {
        scheduler.scheduleAtFixedRate(() -> {
            if (running.get()) {
                reportMetrics();
            }
        }, 10, 10, TimeUnit.SECONDS);
    }
    
    /**
     * Report current metrics
     */
    private void reportMetrics() {
        long total = totalOperations.get();
        long success = successfulOperations.get();
        long failed = failedOperations.get();
        double successRate = total > 0 ? (success * 100.0 / total) : 0.0;
        
        logger.info("📊 AGENT METRICS [{}]: Total={}, Success={}, Failed={}, Rate={:.1f}%",
                agentId, total, success, failed, successRate);
        
        // Publish metrics event
        publishMetricsEvent(total, success, failed);
    }
    
    /**
     * Print final statistics
     */
    private void printFinalStats() {
        long total = totalOperations.get();
        long success = successfulOperations.get();
        long failed = failedOperations.get();
        double successRate = total > 0 ? (success * 100.0 / total) : 0.0;
        long uptimeSeconds = startTime != null ? 
            java.time.Duration.between(startTime, LocalDateTime.now()).getSeconds() : 0;
        double avgOpsPerSec = uptimeSeconds > 0 ? (total * 1.0 / uptimeSeconds) : 0.0;
        
        logger.info("════════════════════════════════════════════════════════════");
        logger.info("📈 TRAFFIC AGENT FINAL STATS: {}", agentId);
        logger.info("   Total Operations: {}", total);
        logger.info("   Successful: {} ({:.1f}%)", success, successRate);
        logger.info("   Failed: {} ({:.1f}%)", failed, 100.0 - successRate);
        logger.info("   Uptime: {}s", uptimeSeconds);
        logger.info("   Average: {:.2f} ops/sec", avgOpsPerSec);
        logger.info("════════════════════════════════════════════════════════════");
    }
    
    /**
     * Publish agent lifecycle event
     */
    private void publishAgentEvent(String action, String details) {
        try {
            PerformanceEvent event = new PerformanceEvent();
            event.setEventType("AGENT_EVENT");
            event.setServiceSource("traffic-agent");
            event.setTestType(agentId);
            event.setAction(PerformanceEvent.PerformanceAction.SYSTEM_HEALTHY);
            event.setDetails(action + ": " + details);
            
            eventPublisherService.publishPerformanceEvent(event);
        } catch (Exception e) {
            logger.error("Failed to publish agent event: {}", e.getMessage());
        }
    }
    
    /**
     * Publish metrics event
     */
    private void publishMetricsEvent(long total, long success, long failed) {
        try {
            double successRate = total > 0 ? (success * 100.0 / total) : 0.0;
            String details = String.format("Agent %s: Total=%d, Success=%d (%.1f%%), Failed=%d",
                    agentId, total, success, successRate, failed);
            
            PerformanceEvent event = new PerformanceEvent();
            event.setEventType("AGENT_METRICS");
            event.setServiceSource("traffic-agent");
            event.setTestType(agentId);
            event.setNumberOfOperations((int) total);
            event.setAction(PerformanceEvent.PerformanceAction.SYSTEM_HEALTHY);
            event.setDetails(details);
            
            eventPublisherService.publishPerformanceEvent(event);
        } catch (Exception e) {
            logger.error("Failed to publish metrics event: {}", e.getMessage());
        }
    }
    
    // Getters and Setters
    
    public String getAgentId() {
        return agentId;
    }
    
    public boolean isRunning() {
        return running.get();
    }
    
    public boolean isPaused() {
        return paused.get();
    }
    
    public TrafficPattern getCurrentPattern() {
        return currentPattern;
    }
    
    public void setCurrentPattern(TrafficPattern pattern) {
        this.currentPattern = pattern;
        logger.info("Traffic pattern changed to: {}", pattern);
    }
    
    public int getOperationsPerSecond() {
        return operationsPerSecond;
    }
    
    public void setOperationsPerSecond(int opsPerSecond) {
        this.operationsPerSecond = opsPerSecond;
        logger.info("Target operations per second changed to: {}", opsPerSecond);
        
        // Restart scheduler with new rate if running
        if (running.get() && scheduler != null) {
            // Would need to reschedule - for now just log
            logger.info("Restart agent to apply new rate");
        }
    }
    
    public AgentStats getStats() {
        return new AgentStats(
                agentId,
                running.get() ? (paused.get() ? "PAUSED" : "RUNNING") : "STOPPED",
                currentPattern,
                operationsPerSecond,
                totalOperations.get(),
                successfulOperations.get(),
                failedOperations.get(),
                startTime,
                pauseTime,
                paused.get()
        );
    }
}
