package com.umu.ads_proj.controller;

import com.umu.ads_proj.entity.User;
import com.umu.ads_proj.service.UserService;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Optional;

@RestController
@RequestMapping("/api/users")
@CrossOrigin(origins = "*")
public class UserController {
    
    private static final Logger logger = LoggerFactory.getLogger(UserController.class);
    
    @Autowired
    private UserService userService;
    
    /**
     * Create a new user
     */
    @PostMapping
    @Timed(value = "user.create", description = "Time taken to create a user")
    public ResponseEntity<User> createUser(@RequestBody User user) {
        logger.info("REST: Creating user with email: {}", user.getEmail());
        try {
            User createdUser = userService.createUser(user);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdUser);
        } catch (IllegalArgumentException e) {
            logger.error("Error creating user: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(null);
        }
    }
    
    /**
     * Get user by ID
     */
    @GetMapping("/{id}")
    @Timed(value = "user.get", description = "Time taken to get a user by ID")
    public ResponseEntity<User> getUserById(@PathVariable Long id) {
        logger.info("REST: Fetching user with ID: {}", id);
        Optional<User> user = userService.getUserById(id);
        
        if (user.isPresent()) {
            return ResponseEntity.ok(user.get());
        } else {
            logger.warn("User with ID {} not found", id);
            return ResponseEntity.notFound().build();
        }
    }
    
    /**
     * Get all users with pagination
     */
    @GetMapping
    @Timed(value = "user.getAll", description = "Time taken to get all users")
    public ResponseEntity<Page<User>> getAllUsers(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        
        logger.info("REST: Fetching all users - page: {}, size: {}", page, size);
        Pageable pageable = PageRequest.of(page, size);
        Page<User> users = userService.getAllUsers(pageable);
        return ResponseEntity.ok(users);
    }
    
    /**
     * Search users by name
     */
    @GetMapping("/search")
    @Timed(value = "user.search", description = "Time taken to search users by name")
    public ResponseEntity<List<User>> searchUsers(@RequestParam String name) {
        logger.info("REST: Searching users by name: {}", name);
        List<User> users = userService.searchUsersByName(name);
        return ResponseEntity.ok(users);
    }
    
    /**
     * Get user by email
     */
    @GetMapping("/email/{email}")
    @Timed(value = "user.getByEmail", description = "Time taken to get user by email")
    public ResponseEntity<User> getUserByEmail(@PathVariable String email) {
        logger.info("REST: Fetching user with email: {}", email);
        Optional<User> user = userService.getUserByEmail(email);
        
        if (user.isPresent()) {
            return ResponseEntity.ok(user.get());
        } else {
            logger.warn("User with email {} not found", email);
            return ResponseEntity.notFound().build();
        }
    }
    
    /**
     * Update user
     */
    @PutMapping("/{id}")
    @Timed(value = "user.update", description = "Time taken to update a user")
    public ResponseEntity<User> updateUser(@PathVariable Long id, @RequestBody User user) {
        logger.info("REST: Updating user with ID: {}", id);
        try {
            User updatedUser = userService.updateUser(id, user);
            return ResponseEntity.ok(updatedUser);
        } catch (IllegalArgumentException e) {
            logger.error("Error updating user: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        }
    }
    
    /**
     * Delete user
     */
    @DeleteMapping("/{id}")
    @Timed(value = "user.delete", description = "Time taken to delete a user")
    public ResponseEntity<Void> deleteUser(@PathVariable Long id) {
        logger.info("REST: Deleting user with ID: {}", id);
        try {
            userService.deleteUser(id);
            return ResponseEntity.noContent().build();
        } catch (IllegalArgumentException e) {
            logger.error("Error deleting user: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        }
    }
    
    /**
     * Get user count (useful for performance testing)
     */
    @GetMapping("/count")
    @Timed(value = "user.count", description = "Time taken to count users")
    public ResponseEntity<Long> getUserCount() {
        logger.info("REST: Getting total user count");
        long count = userService.getTotalUserCount();
        return ResponseEntity.ok(count);
    }
    
    /**
     * Bulk create users (useful for performance testing)
     */
    @PostMapping("/bulk")
    @Timed(value = "user.bulkCreate", description = "Time taken to bulk create users")
    public ResponseEntity<List<User>> createBulkUsers(@RequestBody List<User> users) {
        logger.info("REST: Creating {} users in bulk", users.size());
        try {
            List<User> createdUsers = userService.createBulkUsers(users);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdUsers);
        } catch (Exception e) {
            logger.error("Error in bulk user creation: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.BAD_REQUEST).body(null);
        }
    }
    
    /**
     * Health check endpoint
     */
    @GetMapping("/health")
    public ResponseEntity<String> healthCheck() {
        return ResponseEntity.ok("User Service is healthy");
    }
}