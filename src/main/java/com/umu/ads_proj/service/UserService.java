package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.User;
import com.umu.ads_proj.event.UserEvent;
import com.umu.ads_proj.repository.UserRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.util.List;
import java.util.Optional;

@Service
@Transactional
public class UserService {
    
    private static final Logger logger = LoggerFactory.getLogger(UserService.class);
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private EventPublisherService eventPublisher;
    
    /**
     * Create a new user
     */
    public User createUser(User user) {
        logger.info("Creating new user with email: {}", user.getEmail());
        
        // Validation
        if (userRepository.existsByEmail(user.getEmail())) {
            logger.warn("User with email {} already exists", user.getEmail());
            throw new IllegalArgumentException("User with email " + user.getEmail() + " already exists");
        }
        
        if (userRepository.existsByPhoneNumber(user.getPhoneNumber())) {
            logger.warn("User with phone number {} already exists", user.getPhoneNumber());
            throw new IllegalArgumentException("User with phone number " + user.getPhoneNumber() + " already exists");
        }
        
        User savedUser = userRepository.save(user);
        logger.info("User created successfully with ID: {}", savedUser.getId());
        
        // Publish user creation event to Kafka
        UserEvent userEvent = UserEvent.userCreated(savedUser.getId(), savedUser.getName(), savedUser.getEmail());
        eventPublisher.publishUserEvent(userEvent);
        
        return savedUser;
    }
    
    /**
     * Get user by ID
     */
    @Transactional(readOnly = true)
    public Optional<User> getUserById(Long id) {
        logger.debug("Fetching user with ID: {}", id);
        return userRepository.findById(id);
    }
    
    /**
     * Get user by email
     */
    @Transactional(readOnly = true)
    public Optional<User> getUserByEmail(String email) {
        logger.debug("Fetching user with email: {}", email);
        return userRepository.findByEmail(email);
    }
    
    /**
     * Get all users with pagination (useful for performance testing)
     */
    @Transactional(readOnly = true)
    public Page<User> getAllUsers(Pageable pageable) {
        logger.debug("Fetching all users with pagination: {}", pageable);
        return userRepository.findAll(pageable);
    }
    
    /**
     * Search users by name
     */
    @Transactional(readOnly = true)
    public List<User> searchUsersByName(String name) {
        logger.debug("Searching users by name: {}", name);
        return userRepository.findByNameContainingIgnoreCase(name);
    }
    
    /**
     * Update user
     */
    public User updateUser(Long id, User updatedUser) {
        logger.info("Updating user with ID: {}", id);
        
        Optional<User> existingUserOpt = userRepository.findById(id);
        if (existingUserOpt.isEmpty()) {
            logger.warn("User with ID {} not found for update", id);
            throw new IllegalArgumentException("User with ID " + id + " not found");
        }
        
        User existingUser = existingUserOpt.get();
        
        // Update fields
        existingUser.setName(updatedUser.getName());
        existingUser.setEmail(updatedUser.getEmail());
        existingUser.setPhoneNumber(updatedUser.getPhoneNumber());
        existingUser.setAddress(updatedUser.getAddress());
        
        User savedUser = userRepository.save(existingUser);
        logger.info("User updated successfully with ID: {}", savedUser.getId());
        
        // Publish user update event to Kafka
        UserEvent userEvent = UserEvent.userUpdated(savedUser.getId(), savedUser.getName(), savedUser.getEmail());
        eventPublisher.publishUserEvent(userEvent);
        
        return savedUser;
    }
    
    /**
     * Delete user
     */
    public void deleteUser(Long id) {
        logger.info("Deleting user with ID: {}", id);
        
        // Get user info before deletion for event publishing
        Optional<User> userToDelete = userRepository.findById(id);
        if (userToDelete.isEmpty()) {
            logger.warn("User with ID {} not found for deletion", id);
            throw new IllegalArgumentException("User with ID " + id + " not found");
        }
        
        User user = userToDelete.get();
        userRepository.deleteById(id);
        logger.info("User deleted successfully with ID: {}", id);
        
        // Publish user deletion event to Kafka
        UserEvent userEvent = UserEvent.userDeleted(user.getId(), user.getName(), user.getEmail());
        eventPublisher.publishUserEvent(userEvent);
    }
    
    /**
     * Get total user count (useful for performance metrics)
     */
    @Transactional(readOnly = true)
    public long getTotalUserCount() {
        long count = userRepository.countTotalUsers();
        logger.debug("Total user count: {}", count);
        return count;
    }
    
    /**
     * Bulk create users (useful for performance testing data setup)
     */
    public List<User> createBulkUsers(List<User> users) {
        logger.info("Creating {} users in bulk", users.size());
        List<User> savedUsers = userRepository.saveAll(users);
        logger.info("Bulk user creation completed. Created {} users", savedUsers.size());
        return savedUsers;
    }
}