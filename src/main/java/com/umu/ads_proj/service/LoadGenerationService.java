package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.User;
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

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ThreadLocalRandom;
import java.util.List;
import java.util.ArrayList;

/**
 * Service for generating load against the User Service for performance testing
 */
@Service
public class LoadGenerationService {
    
    private static final Logger logger = LoggerFactory.getLogger(LoadGenerationService.class);
    private static final String USER_SERVICE_URL = "http://localhost:8081/api/users";
    
    @Autowired
    private RestTemplate restTemplate;
    
    /**
     * Generate concurrent load by creating multiple users
     */
    @Async
    public CompletableFuture<String> generateCreateUserLoad(int numberOfUsers, int concurrencyLevel) {
        logger.info("Starting load generation: {} users with concurrency {}", numberOfUsers, concurrencyLevel);
        
        List<CompletableFuture<Void>> tasks = new ArrayList<>();
        long startTime = System.currentTimeMillis();
        
        for (int i = 0; i < numberOfUsers; i++) {
            CompletableFuture<Void> task = CompletableFuture.runAsync(() -> {
                try {
                    User user = generateRandomUser();
                    createUser(user);
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
        
        String result = String.format("Load generation completed: %d users created in %d ms (%.2f users/sec)", 
                                    numberOfUsers, duration, (numberOfUsers * 1000.0) / duration);
        logger.info(result);
        
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
                    createUser(user);
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
    
    private void createUser(User user) {
        try {
            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            HttpEntity<User> request = new HttpEntity<>(user, headers);
            
            ResponseEntity<User> response = restTemplate.postForEntity(USER_SERVICE_URL, request, User.class);
            logger.debug("Created user: {}", response.getBody().getId());
        } catch (Exception e) {
            logger.error("Failed to create user: {}", user.getEmail(), e);
        }
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
}