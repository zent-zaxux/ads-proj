package com.umu.ads_proj.controller;

import com.umu.ads_proj.service.LoadGenerationService;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.concurrent.CompletableFuture;
import java.util.Map;
import java.util.HashMap;

/**
 * Controller for triggering load generation and performance testing
 */
@RestController
@RequestMapping("/api/load")
@CrossOrigin(origins = "*")
public class LoadGenerationController {
    
    private static final Logger logger = LoggerFactory.getLogger(LoadGenerationController.class);
    
    @Autowired
    private LoadGenerationService loadGenerationService;
    
    /**
     * Health check for load generation service
     */
    @GetMapping("/health")
    @Timed(value = "load.generation.health", description = "Time taken for load generation health check")
    public ResponseEntity<String> health() {
        return ResponseEntity.ok("Load Generation Service is healthy");
    }
    
    /**
     * Generate load by creating multiple users
     */
    @PostMapping("/users")
    @Timed(value = "load.generation.users", description = "Time taken to generate user creation load")
    public ResponseEntity<Map<String, Object>> generateUserLoad(
            @RequestParam(defaultValue = "100") int numberOfUsers,
            @RequestParam(defaultValue = "10") int concurrencyLevel) {
        
        logger.info("Load generation request: {} users, concurrency {}", numberOfUsers, concurrencyLevel);
        
        // Start async load generation
        CompletableFuture<String> futureResult = loadGenerationService.generateCreateUserLoad(numberOfUsers, concurrencyLevel);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("numberOfUsers", numberOfUsers);
        response.put("concurrencyLevel", concurrencyLevel);
        response.put("message", "Load generation started asynchronously");
        
        // Log when it completes (non-blocking)
        futureResult.thenAccept(result -> {
            logger.info("Load generation completed: {}", result);
        });
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Generate mixed load (create, read, update operations)
     */
    @PostMapping("/mixed")
    @Timed(value = "load.generation.mixed", description = "Time taken to generate mixed operation load")
    public ResponseEntity<Map<String, Object>> generateMixedLoad(
            @RequestParam(defaultValue = "200") int operations,
            @RequestParam(defaultValue = "0.4") double createRatio,
            @RequestParam(defaultValue = "0.5") double readRatio,
            @RequestParam(defaultValue = "0.1") double updateRatio) {
        
        logger.info("Mixed load generation: {} ops, ratios: create={}, read={}, update={}", 
                   operations, createRatio, readRatio, updateRatio);
        
        // Validate ratios sum to 1.0
        double totalRatio = createRatio + readRatio + updateRatio;
        if (Math.abs(totalRatio - 1.0) > 0.01) {
            Map<String, Object> errorResponse = new HashMap<>();
            errorResponse.put("error", "Ratios must sum to 1.0");
            errorResponse.put("currentSum", totalRatio);
            return ResponseEntity.badRequest().body(errorResponse);
        }
        
        // Start async mixed load generation
        CompletableFuture<String> futureResult = loadGenerationService.generateMixedLoad(
            operations, createRatio, readRatio, updateRatio);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("operations", operations);
        response.put("createRatio", createRatio);
        response.put("readRatio", readRatio);
        response.put("updateRatio", updateRatio);
        response.put("message", "Mixed load generation started asynchronously");
        
        // Log when it completes (non-blocking)
        futureResult.thenAccept(result -> {
            logger.info("Mixed load generation completed: {}", result);
        });
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Quick performance test - creates 50 users rapidly
     */
    @PostMapping("/quick-test")
    @Timed(value = "load.generation.quick", description = "Time taken for quick performance test")
    public ResponseEntity<Map<String, Object>> quickPerformanceTest() {
        logger.info("Starting quick performance test");
        
        CompletableFuture<String> futureResult = loadGenerationService.generateCreateUserLoad(50, 20);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "quick");
        response.put("numberOfUsers", 50);
        response.put("concurrencyLevel", 20);
        response.put("message", "Quick performance test started");
        
        futureResult.thenAccept(result -> {
            logger.info("Quick test completed: {}", result);
        });
        
        return ResponseEntity.ok(response);
    }
}