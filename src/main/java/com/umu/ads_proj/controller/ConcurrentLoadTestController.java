package com.umu.ads_proj.controller;

import com.umu.ads_proj.service.ConcurrentLoadTestService;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;
import java.util.concurrent.CompletableFuture;

/**
 * REST Controller for concurrent load testing
 */
@RestController
@RequestMapping("/api/concurrent-load")
@CrossOrigin(origins = "*")
public class ConcurrentLoadTestController {
    
    private static final Logger logger = LoggerFactory.getLogger(ConcurrentLoadTestController.class);
    
    @Autowired
    private ConcurrentLoadTestService loadTestService;
    
    /**
     * Health check
     */
    @GetMapping("/health")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Concurrent Load Test Service is healthy");
    }
    
    /**
     * Start a gradual load test with custom parameters
     */
    @PostMapping("/gradual")
    @Timed(value = "concurrent.load.test.gradual", description = "Gradual load test execution time")
    public ResponseEntity<Map<String, Object>> startGradualLoadTest(
            @RequestParam(defaultValue = "10") int minUsers,
            @RequestParam(defaultValue = "1000") int maxUsers,
            @RequestParam(defaultValue = "300") int durationSeconds,
            @RequestParam(defaultValue = "60") int rampUpSeconds) {
        
        logger.info("Received gradual load test request: {}-{} users, {}s duration, {}s ramp-up",
                   minUsers, maxUsers, durationSeconds, rampUpSeconds);
        
        // Validate parameters
        if (minUsers < 1 || maxUsers < minUsers) {
            return ResponseEntity.badRequest().body(createErrorResponse(
                "Invalid user range. minUsers must be >= 1 and maxUsers must be >= minUsers"
            ));
        }
        
        if (durationSeconds < 10) {
            return ResponseEntity.badRequest().body(createErrorResponse(
                "Duration must be at least 10 seconds"
            ));
        }
        
        if (rampUpSeconds < 1 || rampUpSeconds > durationSeconds) {
            return ResponseEntity.badRequest().body(createErrorResponse(
                "Ramp-up time must be between 1 and duration seconds"
            ));
        }
        
        // Start async test
        CompletableFuture<String> futureResult = loadTestService.startGradualLoadTest(
            minUsers, maxUsers, durationSeconds, rampUpSeconds
        );
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "gradual");
        response.put("minUsers", minUsers);
        response.put("maxUsers", maxUsers);
        response.put("durationSeconds", durationSeconds);
        response.put("rampUpSeconds", rampUpSeconds);
        response.put("message", "Concurrent load test started. Check logs for real-time metrics.");
        
        // Log completion (non-blocking)
        futureResult.thenAccept(result -> logger.info("Gradual load test completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Run a predefined stress test
     */
    @PostMapping("/stress-test")
    @Timed(value = "concurrent.load.test.stress", description = "Stress test execution time")
    public ResponseEntity<Map<String, Object>> runStressTest() {
        logger.info("Starting stress test scenario");
        
        CompletableFuture<String> futureResult = loadTestService.runStressTest();
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "stress");
        response.put("description", "Stress test: 10-500 users, 3 minutes, 30s ramp-up");
        response.put("message", "Stress test started. Monitor logs for metrics.");
        
        futureResult.thenAccept(result -> logger.info("Stress test completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Run a sustained load test
     */
    @PostMapping("/sustained")
    @Timed(value = "concurrent.load.test.sustained", description = "Sustained load test execution time")
    public ResponseEntity<Map<String, Object>> runSustainedLoadTest(
            @RequestParam(defaultValue = "100") int users,
            @RequestParam(defaultValue = "300") int durationSeconds) {
        
        logger.info("Starting sustained load test: {} users for {}s", users, durationSeconds);
        
        if (users < 1 || users > 10000) {
            return ResponseEntity.badRequest().body(createErrorResponse(
                "Users must be between 1 and 10000"
            ));
        }
        
        CompletableFuture<String> futureResult = loadTestService.runSustainedLoadTest(
            users, durationSeconds
        );
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "sustained");
        response.put("users", users);
        response.put("durationSeconds", durationSeconds);
        response.put("message", "Sustained load test started with constant user count");
        
        futureResult.thenAccept(result -> logger.info("Sustained load test completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Run a spike test (sudden load increase)
     */
    @PostMapping("/spike-test")
    @Timed(value = "concurrent.load.test.spike", description = "Spike test execution time")
    public ResponseEntity<Map<String, Object>> runSpikeTest() {
        logger.info("Starting spike test scenario");
        
        CompletableFuture<String> futureResult = loadTestService.runSpikeTest();
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "spike");
        response.put("description", "Spike test: 10-1000 users, 2 minutes, 5s ramp-up");
        response.put("message", "Spike test started to test sudden load increases");
        
        futureResult.thenAccept(result -> logger.info("Spike test completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Quick smoke test
     */
    @PostMapping("/quick-test")
    @Timed(value = "concurrent.load.test.quick", description = "Quick test execution time")
    public ResponseEntity<Map<String, Object>> runQuickTest() {
        logger.info("Starting quick smoke test");
        
        CompletableFuture<String> futureResult = loadTestService.startGradualLoadTest(
            10, 50, 60, 10 // 10-50 users, 1 minute, 10s ramp-up
        );
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "quick");
        response.put("description", "Quick test: 10-50 users, 1 minute");
        response.put("message", "Quick smoke test started");
        
        futureResult.thenAccept(result -> logger.info("Quick test completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Helper method to create error response
     */
    private Map<String, Object> createErrorResponse(String message) {
        Map<String, Object> response = new HashMap<>();
        response.put("status", "error");
        response.put("error", message);
        return response;
    }
}
