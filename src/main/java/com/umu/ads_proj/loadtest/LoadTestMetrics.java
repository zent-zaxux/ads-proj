package com.umu.ads_proj.loadtest;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.time.Duration;
import java.time.LocalDateTime;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;

/**
 * Metrics collector for load testing
 * Tracks success/failure rates, latencies, and throughput per action type
 */
public class LoadTestMetrics {
    
    private static final Logger logger = LoggerFactory.getLogger(LoadTestMetrics.class);
    
    private final ConcurrentHashMap<String, ActionMetrics> actionMetrics;
    private final LocalDateTime startTime;
    private final AtomicLong totalRequests;
    private final AtomicLong totalLatency;
    
    public LoadTestMetrics() {
        this.actionMetrics = new ConcurrentHashMap<>();
        this.startTime = LocalDateTime.now();
        this.totalRequests = new AtomicLong(0);
        this.totalLatency = new AtomicLong(0);
    }
    
    /**
     * Record a successful action
     */
    public void recordSuccess(String action, long latencyMs) {
        ActionMetrics metrics = actionMetrics.computeIfAbsent(action, k -> new ActionMetrics(action));
        metrics.recordSuccess(latencyMs);
        totalRequests.incrementAndGet();
        totalLatency.addAndGet(latencyMs);
    }
    
    /**
     * Record a failed action
     */
    public void recordFailure(String action, String reason) {
        ActionMetrics metrics = actionMetrics.computeIfAbsent(action, k -> new ActionMetrics(action));
        metrics.recordFailure(reason);
        totalRequests.incrementAndGet();
    }
    
    /**
     * Get overall throughput in requests per second
     */
    public double getThroughput() {
        long seconds = Duration.between(startTime, LocalDateTime.now()).getSeconds();
        if (seconds == 0) return 0;
        return totalRequests.get() / (double) seconds;
    }
    
    /**
     * Get average latency across all actions
     */
    public long getAverageLatency() {
        long total = totalRequests.get();
        if (total == 0) return 0;
        return totalLatency.get() / total;
    }
    
    /**
     * Log breakdown by action type
     */
    public void logActionBreakdown() {
        logger.info("Action Breakdown:");
        actionMetrics.forEach((action, metrics) -> {
            logger.info("  {} - Success: {}, Failed: {}, Avg Latency: {} ms",
                action,
                metrics.getSuccessCount(),
                metrics.getFailureCount(),
                metrics.getAverageLatency()
            );
        });
    }
    
    /**
     * Log final detailed breakdown
     */
    public void logFinalBreakdown() {
        actionMetrics.forEach((action, metrics) -> {
            double successRate = metrics.getSuccessRate();
            logger.info("║ {:20} Success: {:>6} ({:>6.2f}%)            ║",
                action,
                metrics.getSuccessCount(),
                successRate
            );
            logger.info("║                      Failed:  {:>6}  Avg: {:>6} ms    ║",
                metrics.getFailureCount(),
                metrics.getAverageLatency()
            );
        });
    }
    
    /**
     * Get metrics for a specific action
     */
    public ActionMetrics getActionMetrics(String action) {
        return actionMetrics.get(action);
    }
    
    /**
     * Get all action names
     */
    public java.util.Set<String> getActionNames() {
        return actionMetrics.keySet();
    }
    
    /**
     * Reset all metrics
     */
    public void reset() {
        actionMetrics.clear();
        totalRequests.set(0);
        totalLatency.set(0);
    }
    
    /**
     * Inner class to track metrics per action type
     */
    public static class ActionMetrics {
        private final String actionName;
        private final AtomicInteger successCount;
        private final AtomicInteger failureCount;
        private final AtomicLong totalLatency;
        private final ConcurrentHashMap<String, AtomicInteger> failureReasons;
        
        public ActionMetrics(String actionName) {
            this.actionName = actionName;
            this.successCount = new AtomicInteger(0);
            this.failureCount = new AtomicInteger(0);
            this.totalLatency = new AtomicLong(0);
            this.failureReasons = new ConcurrentHashMap<>();
        }
        
        public void recordSuccess(long latencyMs) {
            successCount.incrementAndGet();
            totalLatency.addAndGet(latencyMs);
        }
        
        public void recordFailure(String reason) {
            failureCount.incrementAndGet();
            failureReasons.computeIfAbsent(reason, k -> new AtomicInteger(0)).incrementAndGet();
        }
        
        public int getSuccessCount() {
            return successCount.get();
        }
        
        public int getFailureCount() {
            return failureCount.get();
        }
        
        public long getAverageLatency() {
            int count = successCount.get();
            if (count == 0) return 0;
            return totalLatency.get() / count;
        }
        
        public double getSuccessRate() {
            int total = successCount.get() + failureCount.get();
            if (total == 0) return 0;
            return (successCount.get() * 100.0) / total;
        }
        
        public String getActionName() {
            return actionName;
        }
        
        public ConcurrentHashMap<String, AtomicInteger> getFailureReasons() {
            return failureReasons;
        }
    }
}
