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
    
    // ==================== ORDER LOAD GENERATION ENDPOINTS ====================
    
    /**
     * Generate order creation load
     */
    @PostMapping("/orders")
    @Timed(value = "load.generation.orders", description = "Time taken to generate order creation load")
    public ResponseEntity<Map<String, Object>> generateOrderLoad(
            @RequestParam(defaultValue = "100") int numberOfOrders,
            @RequestParam(defaultValue = "10") int concurrencyLevel) {
        
        logger.info("Order load generation request: {} orders, concurrency {}", numberOfOrders, concurrencyLevel);
        
        CompletableFuture<String> futureResult = loadGenerationService.generateOrderLoad(numberOfOrders, concurrencyLevel);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("numberOfOrders", numberOfOrders);
        response.put("concurrencyLevel", concurrencyLevel);
        response.put("message", "Order load generation started asynchronously");
        
        futureResult.thenAccept(result -> logger.info("Order load completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Generate mixed order operations load
     */
    @PostMapping("/orders/mixed")
    @Timed(value = "load.generation.orders.mixed", description = "Time taken to generate mixed order operations")
    public ResponseEntity<Map<String, Object>> generateMixedOrderLoad(
            @RequestParam(defaultValue = "200") int operations) {
        
        logger.info("Mixed order load generation: {} operations", operations);
        
        CompletableFuture<String> futureResult = loadGenerationService.generateMixedOrderLoad(operations);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("operations", operations);
        response.put("message", "Mixed order load generation started asynchronously");
        
        futureResult.thenAccept(result -> logger.info("Mixed order load completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    // ==================== PAYMENT LOAD GENERATION ENDPOINTS ====================
    
    /**
     * Generate payment processing load
     */
    @PostMapping("/payments")
    @Timed(value = "load.generation.payments", description = "Time taken to generate payment processing load")
    public ResponseEntity<Map<String, Object>> generatePaymentLoad(
            @RequestParam(defaultValue = "50") int numberOfPayments,
            @RequestParam(defaultValue = "5") int concurrencyLevel) {
        
        logger.info("Payment load generation request: {} payments, concurrency {}", numberOfPayments, concurrencyLevel);
        
        CompletableFuture<String> futureResult = loadGenerationService.generatePaymentLoad(numberOfPayments, concurrencyLevel);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("numberOfPayments", numberOfPayments);
        response.put("concurrencyLevel", concurrencyLevel);
        response.put("message", "Payment load generation started asynchronously");
        
        futureResult.thenAccept(result -> logger.info("Payment load completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    // ==================== COMPLETE JOURNEY ENDPOINTS ====================
    
    /**
     * Generate complete user journey load (User -> Order -> Payment)
     */
    @PostMapping("/journey")
    @Timed(value = "load.generation.journey", description = "Time taken to generate complete journey load")
    public ResponseEntity<Map<String, Object>> generateCompleteJourneyLoad(
            @RequestParam(defaultValue = "25") int numberOfJourneys,
            @RequestParam(defaultValue = "5") int concurrencyLevel) {
        
        logger.info("Complete journey load generation: {} journeys, concurrency {}", numberOfJourneys, concurrencyLevel);
        
        CompletableFuture<String> futureResult = loadGenerationService.generateCompleteJourneyLoad(numberOfJourneys, concurrencyLevel);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("numberOfJourneys", numberOfJourneys);
        response.put("concurrencyLevel", concurrencyLevel);
        response.put("message", "Complete journey load generation started asynchronously");
        
        futureResult.thenAccept(result -> logger.info("Complete journey load completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    // ==================== PERFORMANCE TEST SCENARIOS ====================
    
    /**
     * Ramp-up load test: gradually increase load
     */
    @PostMapping("/test/ramp-up")
    @Timed(value = "load.test.rampup", description = "Time taken for ramp-up load test")
    public ResponseEntity<Map<String, Object>> rampUpLoadTest(
            @RequestParam(defaultValue = "100") int maxOperations,
            @RequestParam(defaultValue = "5") int rampUpSteps) {
        
        logger.info("Ramp-up load test: max {} operations in {} steps", maxOperations, rampUpSteps);
        
        CompletableFuture<String> futureResult = loadGenerationService.rampUpLoadTest(maxOperations, rampUpSteps);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "ramp-up");
        response.put("maxOperations", maxOperations);
        response.put("rampUpSteps", rampUpSteps);
        response.put("message", "Ramp-up load test started asynchronously");
        
        futureResult.thenAccept(result -> logger.info("Ramp-up test completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Sustained load test: constant load for duration
     */
    @PostMapping("/test/sustained")
    @Timed(value = "load.test.sustained", description = "Time taken for sustained load test")
    public ResponseEntity<Map<String, Object>> sustainedLoadTest(
            @RequestParam(defaultValue = "10") int operationsPerSecond,
            @RequestParam(defaultValue = "30") int durationSeconds) {
        
        logger.info("Sustained load test: {} ops/sec for {} seconds", operationsPerSecond, durationSeconds);
        
        CompletableFuture<String> futureResult = loadGenerationService.sustainedLoadTest(operationsPerSecond, durationSeconds);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "sustained");
        response.put("operationsPerSecond", operationsPerSecond);
        response.put("durationSeconds", durationSeconds);
        response.put("expectedTotalOperations", operationsPerSecond * durationSeconds);
        response.put("message", "Sustained load test started asynchronously");
        
        futureResult.thenAccept(result -> logger.info("Sustained test completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Spike test: sudden increase in load
     */
    @PostMapping("/test/spike")
    @Timed(value = "load.test.spike", description = "Time taken for spike load test")
    public ResponseEntity<Map<String, Object>> spikeLoadTest(
            @RequestParam(defaultValue = "10") int baselineOps,
            @RequestParam(defaultValue = "100") int spikeOps) {
        
        logger.info("Spike load test: baseline {} ops, spike {} ops", baselineOps, spikeOps);
        
        CompletableFuture<String> futureResult = loadGenerationService.spikeLoadTest(baselineOps, spikeOps);
        
        Map<String, Object> response = new HashMap<>();
        response.put("status", "started");
        response.put("testType", "spike");
        response.put("baselineOperations", baselineOps);
        response.put("spikeOperations", spikeOps);
        response.put("message", "Spike load test started asynchronously");
        
        futureResult.thenAccept(result -> logger.info("Spike test completed: {}", result));
        
        return ResponseEntity.ok(response);
    }
}