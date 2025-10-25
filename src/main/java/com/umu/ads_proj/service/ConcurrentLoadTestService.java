package com.umu.ads_proj.service;

import com.umu.ads_proj.loadtest.ConcurrentLoadTestRunner;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

/**
 * Service for running concurrent load tests
 */
@Service
public class ConcurrentLoadTestService {
    
    private static final Logger logger = LoggerFactory.getLogger(ConcurrentLoadTestService.class);
    
    @Value("${spring.kafka.bootstrap-servers}")
    private String bootstrapServers;
    
    private ConcurrentLoadTestRunner currentRunner;
    
    /**
     * Start a gradual load test asynchronously
     */
    @Async
    public CompletableFuture<String> startGradualLoadTest(
            int minUsers, int maxUsers, int durationSeconds, int rampUpSeconds) {
        
        logger.info("Starting concurrent load test: {}-{} users, duration: {}s, ramp-up: {}s",
                   minUsers, maxUsers, durationSeconds, rampUpSeconds);
        
        try {
            currentRunner = new ConcurrentLoadTestRunner(bootstrapServers);
            currentRunner.runGradualLoadTest(minUsers, maxUsers, durationSeconds, rampUpSeconds);
            
            String result = String.format(
                "Load test completed successfully. Users: %d-%d, Duration: %ds",
                minUsers, maxUsers, durationSeconds
            );
            
            logger.info(result);
            return CompletableFuture.completedFuture(result);
            
        } catch (Exception e) {
            logger.error("Load test failed", e);
            return CompletableFuture.completedFuture("Load test failed: " + e.getMessage());
        } finally {
            if (currentRunner != null) {
                currentRunner.close();
            }
        }
    }
    
    /**
     * Run a predefined stress test scenario
     */
    @Async
    public CompletableFuture<String> runStressTest() {
        logger.info("Starting predefined stress test scenario");
        return startGradualLoadTest(10, 500, 180, 30); // 10-500 users, 3 min test, 30s ramp-up
    }
    
    /**
     * Run a sustained load test
     */
    @Async
    public CompletableFuture<String> runSustainedLoadTest(int users, int durationSeconds) {
        logger.info("Starting sustained load test: {} users for {}s", users, durationSeconds);
        return startGradualLoadTest(users, users, durationSeconds, 5); // Fixed user count
    }
    
    /**
     * Run a spike test (sudden load increase)
     */
    @Async
    public CompletableFuture<String> runSpikeTest() {
        logger.info("Starting spike test scenario");
        return startGradualLoadTest(10, 1000, 120, 5); // 10-1000 users, 2 min test, 5s ramp-up (fast spike)
    }
}
