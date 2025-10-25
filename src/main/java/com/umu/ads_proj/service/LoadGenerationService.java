package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.Order;
import com.umu.ads_proj.entity.Payment;
import com.umu.ads_proj.entity.User;
import com.umu.ads_proj.event.PerformanceEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

import java.math.BigDecimal;
import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ThreadLocalRandom;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.List;
import java.util.ArrayList;
import java.util.Map;
import java.util.HashMap;

/**
 * Service for generating load against microservices for performance testing
 */
@Service
public class LoadGenerationService {
    
    private static final Logger logger = LoggerFactory.getLogger(LoadGenerationService.class);
    private static final String USER_SERVICE_URL = "http://localhost:8081/api/users";
    private static final String ORDER_SERVICE_URL = "http://localhost:8081/api/orders";
    private static final String PAYMENT_SERVICE_URL = "http://localhost:8081/api/payments";
    
    @Autowired
    private RestTemplate restTemplate;
    
    @Autowired
    private EventPublisherService eventPublisher;
    
    /**
     * Generate concurrent load by creating multiple users
     */
    @Async
    public CompletableFuture<String> generateCreateUserLoad(int numberOfUsers, int concurrencyLevel) {
        logger.info("Starting load generation: {} users with concurrency {}", numberOfUsers, concurrencyLevel);
        
        // Publish load test start event
        PerformanceEvent startEvent = PerformanceEvent.loadTestStarted("USER_CREATION", numberOfUsers, concurrencyLevel);
        eventPublisher.publishPerformanceEvent(startEvent);
        
        List<CompletableFuture<Void>> tasks = new ArrayList<>();
        long startTime = System.currentTimeMillis();
        
        for (int i = 0; i < numberOfUsers; i++) {
            CompletableFuture<Void> task = CompletableFuture.runAsync(() -> {
                try {
                    User user = generateRandomUser();
                    ResponseEntity<User> response = createUser(user);
                    if (response == null) {
                        logger.error("Failed to create user");
                    }
                } catch (Exception e) {
                    logger.error("Error creating user during load test", e);
                }
            });
            tasks.add(task);
            
            // Control concurrency by waiting after every 'concurrencyLevel' tasks
            if ((i + 1) % concurrencyLevel == 0) {
                try {
                    Thread.sleep(100); // Small delay to control load
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        }
        
        // Wait for all tasks to complete
        CompletableFuture.allOf(tasks.toArray(new CompletableFuture[0])).join();
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        
        double throughput = (numberOfUsers * 1000.0) / duration;
        String result = String.format("Load generation completed: %d users created in %d ms (%.2f users/sec)", 
                                    numberOfUsers, duration, throughput);
        logger.info(result);
        
        // Publish load test completion event
        PerformanceEvent completionEvent = PerformanceEvent.loadTestCompleted("USER_CREATION", numberOfUsers, duration, throughput);
        eventPublisher.publishPerformanceEvent(completionEvent);
        
        return CompletableFuture.completedFuture(result);
    }
    
    /**
     * Generate mixed load (create, read, update operations)
     */
    @Async
    public CompletableFuture<String> generateMixedLoad(int operations, double createRatio, double readRatio, double updateRatio) {
        logger.info("Starting mixed load generation: {} operations", operations);
        
        long startTime = System.currentTimeMillis();
        
        for (int i = 0; i < operations; i++) {
            double random = Math.random();
            
            try {
                if (random < createRatio) {
                    // Create operation
                    User user = generateRandomUser();
                    ResponseEntity<User> response = createUser(user);
                    if (response == null) {
                        logger.debug("Failed to create user");
                    }
                } else if (random < createRatio + readRatio) {
                    // Read operation
                    getAllUsers();
                } else if (random < createRatio + readRatio + updateRatio) {
                    // Update operation (simplified - just get by ID)
                    int userId = ThreadLocalRandom.current().nextInt(1, 10);
                    getUserById(userId);
                }
                
                // Small delay between operations
                Thread.sleep(ThreadLocalRandom.current().nextInt(10, 100));
                
            } catch (Exception e) {
                logger.error("Error during mixed load operation", e);
            }
        }
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        
        String result = String.format("Mixed load completed: %d operations in %d ms (%.2f ops/sec)", 
                                    operations, duration, (operations * 1000.0) / duration);
        logger.info(result);
        
        return CompletableFuture.completedFuture(result);
    }
    
    private User generateRandomUser() {
        String[] firstNames = {"John", "Jane", "Bob", "Alice", "Charlie", "Diana", "Eve", "Frank"};
        String[] lastNames = {"Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis"};
        
        String firstName = firstNames[ThreadLocalRandom.current().nextInt(firstNames.length)];
        String lastName = lastNames[ThreadLocalRandom.current().nextInt(lastNames.length)];
        int number = ThreadLocalRandom.current().nextInt(1000, 9999);
        
        User user = new User();
        user.setName(firstName + " " + lastName);
        user.setEmail(firstName.toLowerCase() + "." + lastName.toLowerCase() + number + "@test.com");
        user.setPhoneNumber("+1" + ThreadLocalRandom.current().nextInt(100, 999) + 
                           ThreadLocalRandom.current().nextInt(100, 999) + 
                           ThreadLocalRandom.current().nextInt(1000, 9999));
        user.setAddress(ThreadLocalRandom.current().nextInt(100, 9999) + " Test St, Test City, USA");
        
        return user;
    }
    
    private void getAllUsers() {
        try {
            ResponseEntity<String> response = restTemplate.getForEntity(USER_SERVICE_URL, String.class);
            logger.debug("Retrieved users, response length: {}", response.getBody().length());
        } catch (Exception e) {
            logger.error("Failed to get all users", e);
        }
    }
    
    private void getUserById(int userId) {
        try {
            restTemplate.getForEntity(USER_SERVICE_URL + "/" + userId, User.class);
            logger.debug("Retrieved user by ID: {}", userId);
        } catch (Exception e) {
            logger.debug("User not found: {}", userId); // This is expected for non-existent users
        }
    }
    
    // ==================== ORDER LOAD GENERATION ====================
    
    /**
     * Generate load by creating orders
     */
    @Async
    public CompletableFuture<String> generateOrderLoad(int numberOfOrders, int concurrencyLevel) {
        logger.info("Starting order load generation: {} orders with concurrency {}", numberOfOrders, concurrencyLevel);
        
        // Publish load test start event
        PerformanceEvent startEvent = PerformanceEvent.loadTestStarted("ORDER_CREATION", numberOfOrders, concurrencyLevel);
        eventPublisher.publishPerformanceEvent(startEvent);
        
        List<CompletableFuture<Void>> tasks = new ArrayList<>();
        long startTime = System.currentTimeMillis();
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failureCount = new AtomicInteger(0);
        
        for (int i = 0; i < numberOfOrders; i++) {
            CompletableFuture<Void> task = CompletableFuture.runAsync(() -> {
                try {
                    // Get random user ID (assuming users 1-10 exist)
                    Long userId = (long) ThreadLocalRandom.current().nextInt(1, 11);
                    Map<String, Object> order = generateRandomOrder(userId);
                    createOrder(order);
                    successCount.incrementAndGet();
                } catch (Exception e) {
                    logger.error("Error creating order during load test", e);
                    failureCount.incrementAndGet();
                }
            });
            tasks.add(task);
            
            // Control concurrency
            if ((i + 1) % concurrencyLevel == 0) {
                try {
                    Thread.sleep(50);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        }
        
        // Wait for all tasks to complete
        CompletableFuture.allOf(tasks.toArray(new CompletableFuture[0])).join();
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        double throughput = (numberOfOrders * 1000.0) / duration;
        
        String result = String.format("Order load completed: %d orders (%d success, %d failed) in %d ms (%.2f orders/sec)", 
                                    numberOfOrders, successCount.get(), failureCount.get(), duration, throughput);
        logger.info(result);
        
        // Publish load test completion event
        PerformanceEvent completionEvent = PerformanceEvent.loadTestCompleted("ORDER_CREATION", numberOfOrders, duration, throughput);
        eventPublisher.publishPerformanceEvent(completionEvent);
        
        return CompletableFuture.completedFuture(result);
    }
    
    /**
     * Generate mixed order operations (create, read, update status, cancel)
     */
    @Async
    public CompletableFuture<String> generateMixedOrderLoad(int operations) {
        logger.info("Starting mixed order load generation: {} operations", operations);
        
        long startTime = System.currentTimeMillis();
        AtomicInteger createOps = new AtomicInteger(0);
        AtomicInteger readOps = new AtomicInteger(0);
        AtomicInteger updateOps = new AtomicInteger(0);
        AtomicInteger cancelOps = new AtomicInteger(0);
        
        for (int i = 0; i < operations; i++) {
            double random = Math.random();
            
            try {
                if (random < 0.4) {
                    // 40% Create operations
                    Long userId = (long) ThreadLocalRandom.current().nextInt(1, 11);
                    Map<String, Object> order = generateRandomOrder(userId);
                    createOrder(order);
                    createOps.incrementAndGet();
                } else if (random < 0.7) {
                    // 30% Read operations
                    int orderId = ThreadLocalRandom.current().nextInt(1, 20);
                    getOrderById(orderId);
                    readOps.incrementAndGet();
                } else if (random < 0.9) {
                    // 20% Update status operations
                    int orderId = ThreadLocalRandom.current().nextInt(1, 20);
                    updateOrderStatus(orderId);
                    updateOps.incrementAndGet();
                } else {
                    // 10% Cancel operations
                    int orderId = ThreadLocalRandom.current().nextInt(1, 20);
                    cancelOrder(orderId);
                    cancelOps.incrementAndGet();
                }
                
                Thread.sleep(ThreadLocalRandom.current().nextInt(10, 50));
            } catch (Exception e) {
                logger.debug("Error during mixed order operation", e);
            }
        }
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        
        String result = String.format("Mixed order load completed: %d ops (Create:%d, Read:%d, Update:%d, Cancel:%d) in %d ms (%.2f ops/sec)", 
                                    operations, createOps.get(), readOps.get(), updateOps.get(), cancelOps.get(),
                                    duration, (operations * 1000.0) / duration);
        logger.info(result);
        
        return CompletableFuture.completedFuture(result);
    }
    
    // ==================== PAYMENT LOAD GENERATION ====================
    
    /**
     * Generate payment load (create and process payments)
     */
    @Async
    public CompletableFuture<String> generatePaymentLoad(int numberOfPayments, int concurrencyLevel) {
        logger.info("Starting payment load generation: {} payments with concurrency {}", numberOfPayments, concurrencyLevel);
        
        // Publish load test start event
        PerformanceEvent startEvent = PerformanceEvent.loadTestStarted("PAYMENT_PROCESSING", numberOfPayments, concurrencyLevel);
        eventPublisher.publishPerformanceEvent(startEvent);
        
        List<CompletableFuture<Void>> tasks = new ArrayList<>();
        long startTime = System.currentTimeMillis();
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failureCount = new AtomicInteger(0);
        
        for (int i = 0; i < numberOfPayments; i++) {
            CompletableFuture<Void> task = CompletableFuture.runAsync(() -> {
                try {
                    // Create user and order first
                    User user = generateRandomUser();
                    ResponseEntity<User> userResponse = createUser(user);
                    if (userResponse != null && userResponse.getBody() != null) {
                        Long userId = userResponse.getBody().getId();
                        
                        // Create order
                        Map<String, Object> orderData = generateRandomOrder(userId);
                        ResponseEntity<Order> orderResponse = createOrder(orderData);
                        
                        if (orderResponse != null && orderResponse.getBody() != null) {
                            Order order = orderResponse.getBody();
                            
                            // Create payment
                            Map<String, Object> paymentData = generateRandomPayment(order.getId(), userId, order.getTotalAmount());
                            ResponseEntity<Payment> paymentResponse = createPayment(paymentData);
                            
                            if (paymentResponse != null && paymentResponse.getBody() != null) {
                                // Process payment
                                Long paymentId = paymentResponse.getBody().getId();
                                processPayment(paymentId);
                                successCount.incrementAndGet();
                            }
                        }
                    }
                } catch (Exception e) {
                    logger.error("Error during payment load test", e);
                    failureCount.incrementAndGet();
                }
            });
            tasks.add(task);
            
            // Control concurrency
            if ((i + 1) % concurrencyLevel == 0) {
                try {
                    Thread.sleep(100);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        }
        
        // Wait for all tasks to complete
        CompletableFuture.allOf(tasks.toArray(new CompletableFuture[0])).join();
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        double throughput = (numberOfPayments * 1000.0) / duration;
        
        String result = String.format("Payment load completed: %d payments (%d success, %d failed) in %d ms (%.2f payments/sec)", 
                                    numberOfPayments, successCount.get(), failureCount.get(), duration, throughput);
        logger.info(result);
        
        // Publish load test completion event
        PerformanceEvent completionEvent = PerformanceEvent.loadTestCompleted("PAYMENT_PROCESSING", numberOfPayments, duration, throughput);
        eventPublisher.publishPerformanceEvent(completionEvent);
        
        return CompletableFuture.completedFuture(result);
    }
    
    // ==================== COMPLETE JOURNEY LOAD GENERATION ====================
    
    /**
     * Generate complete user journey load (User -> Order -> Payment flow)
     */
    @Async
    public CompletableFuture<String> generateCompleteJourneyLoad(int numberOfJourneys, int concurrencyLevel) {
        logger.info("Starting complete journey load generation: {} journeys with concurrency {}", numberOfJourneys, concurrencyLevel);
        
        // Publish load test start event
        PerformanceEvent startEvent = PerformanceEvent.loadTestStarted("COMPLETE_JOURNEY", numberOfJourneys, concurrencyLevel);
        eventPublisher.publishPerformanceEvent(startEvent);
        
        List<CompletableFuture<Void>> tasks = new ArrayList<>();
        long startTime = System.currentTimeMillis();
        AtomicInteger successCount = new AtomicInteger(0);
        AtomicInteger failureCount = new AtomicInteger(0);
        
        for (int i = 0; i < numberOfJourneys; i++) {
            CompletableFuture<Void> task = CompletableFuture.runAsync(() -> {
                try {
                    // Step 1: Create user
                    User user = generateRandomUser();
                    ResponseEntity<User> userResponse = createUser(user);
                    if (userResponse == null || userResponse.getBody() == null) {
                        failureCount.incrementAndGet();
                        return;
                    }
                    Long userId = userResponse.getBody().getId();
                    logger.debug("Journey: Created user {}", userId);
                    
                    // Step 2: Create order
                    Map<String, Object> orderData = generateRandomOrder(userId);
                    ResponseEntity<Order> orderResponse = createOrder(orderData);
                    if (orderResponse == null || orderResponse.getBody() == null) {
                        failureCount.incrementAndGet();
                        return;
                    }
                    Order order = orderResponse.getBody();
                    logger.debug("Journey: Created order {} for user {}", order.getId(), userId);
                    
                    // Step 3: Create payment
                    Map<String, Object> paymentData = generateRandomPayment(order.getId(), userId, order.getTotalAmount());
                    ResponseEntity<Payment> paymentResponse = createPayment(paymentData);
                    if (paymentResponse == null || paymentResponse.getBody() == null) {
                        failureCount.incrementAndGet();
                        return;
                    }
                    Long paymentId = paymentResponse.getBody().getId();
                    logger.debug("Journey: Created payment {} for order {}", paymentId, order.getId());
                    
                    // Step 4: Process payment
                    ResponseEntity<Payment> processedPayment = processPayment(paymentId);
                    if (processedPayment != null && processedPayment.getBody() != null) {
                        String status = processedPayment.getBody().getStatus().toString();
                        logger.debug("Journey: Payment {} processed with status {}", paymentId, status);
                        
                        if ("COMPLETED".equals(status)) {
                            successCount.incrementAndGet();
                        } else {
                            failureCount.incrementAndGet();
                        }
                    } else {
                        failureCount.incrementAndGet();
                    }
                    
                } catch (Exception e) {
                    logger.error("Error during complete journey", e);
                    failureCount.incrementAndGet();
                }
            });
            tasks.add(task);
            
            // Control concurrency
            if ((i + 1) % concurrencyLevel == 0) {
                try {
                    Thread.sleep(200);
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            }
        }
        
        // Wait for all tasks to complete
        CompletableFuture.allOf(tasks.toArray(new CompletableFuture[0])).join();
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        double throughput = (numberOfJourneys * 1000.0) / duration;
        
        String result = String.format("Complete journey load completed: %d journeys (%d success, %d failed) in %d ms (%.2f journeys/sec)", 
                                    numberOfJourneys, successCount.get(), failureCount.get(), duration, throughput);
        logger.info(result);
        
        // Publish load test completion event
        PerformanceEvent completionEvent = PerformanceEvent.loadTestCompleted("COMPLETE_JOURNEY", numberOfJourneys, duration, throughput);
        eventPublisher.publishPerformanceEvent(completionEvent);
        
        return CompletableFuture.completedFuture(result);
    }
    
    // ==================== PERFORMANCE TEST SCENARIOS ====================
    
    /**
     * Ramp-up load test: gradually increase load
     */
    @Async
    public CompletableFuture<String> rampUpLoadTest(int maxOperations, int rampUpSteps) {
        logger.info("Starting ramp-up load test: {} max operations in {} steps", maxOperations, rampUpSteps);
        
        long startTime = System.currentTimeMillis();
        int operationsPerStep = maxOperations / rampUpSteps;
        
        for (int step = 1; step <= rampUpSteps; step++) {
            int operationsInStep = operationsPerStep * step;
            logger.info("Ramp-up step {}/{}: {} operations", step, rampUpSteps, operationsInStep);
            
            try {
                generateCompleteJourneyLoad(operationsInStep, 10).get();
                Thread.sleep(5000); // Wait between steps
            } catch (Exception e) {
                logger.error("Error in ramp-up step {}", step, e);
            }
        }
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        
        String result = String.format("Ramp-up test completed: %d total operations in %d steps, duration: %d ms", 
                                    maxOperations, rampUpSteps, duration);
        logger.info(result);
        
        return CompletableFuture.completedFuture(result);
    }
    
    /**
     * Sustained load test: constant load for duration
     */
    @Async
    public CompletableFuture<String> sustainedLoadTest(int operationsPerSecond, int durationSeconds) {
        logger.info("Starting sustained load test: {} ops/sec for {} seconds", operationsPerSecond, durationSeconds);
        
        long startTime = System.currentTimeMillis();
        int totalOperations = 0;
        
        for (int second = 0; second < durationSeconds; second++) {
            long secondStart = System.currentTimeMillis();
            
            try {
                generateCompleteJourneyLoad(operationsPerSecond, operationsPerSecond).get();
                totalOperations += operationsPerSecond;
                
                // Wait to maintain rate
                long elapsed = System.currentTimeMillis() - secondStart;
                if (elapsed < 1000) {
                    Thread.sleep(1000 - elapsed);
                }
            } catch (Exception e) {
                logger.error("Error in sustained load second {}", second, e);
            }
        }
        
        long endTime = System.currentTimeMillis();
        long duration = endTime - startTime;
        
        String result = String.format("Sustained load test completed: %d operations in %d seconds, actual duration: %d ms", 
                                    totalOperations, durationSeconds, duration);
        logger.info(result);
        
        return CompletableFuture.completedFuture(result);
    }
    
    /**
     * Spike test: sudden increase in load
     */
    @Async
    public CompletableFuture<String> spikeLoadTest(int baselineOps, int spikeOps) {
        logger.info("Starting spike load test: baseline {} ops, spike {} ops", baselineOps, spikeOps);
        
        long startTime = System.currentTimeMillis();
        
        try {
            // Baseline load
            logger.info("Running baseline load: {} operations", baselineOps);
            generateCompleteJourneyLoad(baselineOps, 5).get();
            
            // Spike
            logger.info("Running spike load: {} operations", spikeOps);
            long spikeStart = System.currentTimeMillis();
            generateCompleteJourneyLoad(spikeOps, 50).get();
            long spikeDuration = System.currentTimeMillis() - spikeStart;
            
            // Return to baseline
            logger.info("Returning to baseline load: {} operations", baselineOps);
            generateCompleteJourneyLoad(baselineOps, 5).get();
            
            long endTime = System.currentTimeMillis();
            long duration = endTime - startTime;
            
            String result = String.format("Spike test completed: Spike of %d ops completed in %d ms, total duration: %d ms", 
                                        spikeOps, spikeDuration, duration);
            logger.info(result);
            
            return CompletableFuture.completedFuture(result);
        } catch (Exception e) {
            logger.error("Error during spike test", e);
            return CompletableFuture.completedFuture("Spike test failed: " + e.getMessage());
        }
    }
    
    // ==================== HELPER METHODS ====================
    
    private Map<String, Object> generateRandomOrder(Long userId) {
        String[] products = {"Laptop", "Smartphone", "Tablet", "Headphones", "Monitor", "Keyboard", "Mouse", "Webcam"};
        
        Map<String, Object> order = new HashMap<>();
        order.put("userId", userId);
        order.put("productName", products[ThreadLocalRandom.current().nextInt(products.length)]);
        order.put("quantity", ThreadLocalRandom.current().nextInt(1, 5));
        order.put("unitPrice", ThreadLocalRandom.current().nextDouble(99.99, 999.99));
        
        return order;
    }
    
    private Map<String, Object> generateRandomPayment(Long orderId, Long userId, BigDecimal amount) {
        String[] paymentMethods = {"CREDIT_CARD", "DEBIT_CARD", "PAYPAL", "BANK_TRANSFER"};
        
        Map<String, Object> payment = new HashMap<>();
        payment.put("orderId", orderId);
        payment.put("userId", userId);
        payment.put("amount", amount);
        payment.put("paymentMethod", paymentMethods[ThreadLocalRandom.current().nextInt(paymentMethods.length)]);
        
        return payment;
    }
    
    private ResponseEntity<User> createUser(User user) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<User> request = new HttpEntity<>(user, headers);
            
            ResponseEntity<User> response = restTemplate.postForEntity(USER_SERVICE_URL, request, User.class);
            logger.debug("Created user: {}", response.getBody().getId());
            return response;
        } catch (Exception e) {
            logger.error("Failed to create user: {}", user.getEmail(), e);
            return null;
        }
    }
    
    private ResponseEntity<Order> createOrder(Map<String, Object> orderData) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(orderData, headers);
            
            ResponseEntity<Order> response = restTemplate.postForEntity(ORDER_SERVICE_URL, request, Order.class);
            logger.debug("Created order: {}", response.getBody().getId());
            return response;
        } catch (Exception e) {
            logger.error("Failed to create order", e);
            return null;
        }
    }
    
    private ResponseEntity<Payment> createPayment(Map<String, Object> paymentData) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, Object>> request = new HttpEntity<>(paymentData, headers);
            
            ResponseEntity<Payment> response = restTemplate.postForEntity(PAYMENT_SERVICE_URL, request, Payment.class);
            logger.debug("Created payment: {}", response.getBody().getId());
            return response;
        } catch (Exception e) {
            logger.error("Failed to create payment", e);
            return null;
        }
    }
    
    private ResponseEntity<Payment> processPayment(Long paymentId) {
        try {
            ResponseEntity<Payment> response = restTemplate.postForEntity(
                PAYMENT_SERVICE_URL + "/" + paymentId + "/process", 
                null, 
                Payment.class
            );
            logger.debug("Processed payment: {}", paymentId);
            return response;
        } catch (Exception e) {
            logger.error("Failed to process payment: {}", paymentId, e);
            return null;
        }
    }
    
    private void getOrderById(int orderId) {
        try {
            restTemplate.getForEntity(ORDER_SERVICE_URL + "/" + orderId, Order.class);
            logger.debug("Retrieved order: {}", orderId);
        } catch (Exception e) {
            logger.debug("Order not found: {}", orderId);
        }
    }
    
    private void updateOrderStatus(int orderId) {
        try {
            String[] statuses = {"CONFIRMED", "SHIPPED", "DELIVERED"};
            String status = statuses[ThreadLocalRandom.current().nextInt(statuses.length)];
            
            Map<String, String> statusUpdate = new HashMap<>();
            statusUpdate.put("status", status);
            
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<Map<String, String>> request = new HttpEntity<>(statusUpdate, headers);
            
            restTemplate.patchForObject(ORDER_SERVICE_URL + "/" + orderId + "/status?status=" + status, request, Order.class);
            logger.debug("Updated order {} status to {}", orderId, status);
        } catch (Exception e) {
            logger.debug("Failed to update order status: {}", orderId);
        }
    }
    
    private void cancelOrder(int orderId) {
        try {
            restTemplate.postForEntity(ORDER_SERVICE_URL + "/" + orderId + "/cancel", null, Order.class);
            logger.debug("Cancelled order: {}", orderId);
        } catch (Exception e) {
            logger.debug("Failed to cancel order: {}", orderId);
        }
    }
}