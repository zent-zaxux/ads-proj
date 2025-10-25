package com.umu.ads_proj.controller;

import com.umu.ads_proj.entity.Notification;
import com.umu.ads_proj.entity.Notification.NotificationStatus;
import com.umu.ads_proj.service.NotificationService;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * REST Controller for Notification Service
 */
@RestController
@RequestMapping("/api/notifications")
public class NotificationController {
    
    private static final Logger logger = LoggerFactory.getLogger(NotificationController.class);
    
    @Autowired
    private NotificationService notificationService;
    
    /**
     * Get notification by ID
     * 
     * GET /api/notifications/1
     */
    @GetMapping("/{id}")
    @Timed(value = "notification.get", description = "Get notification by ID")
    public ResponseEntity<Notification> getNotificationById(@PathVariable Long id) {
        logger.info("Getting notification by ID: {}", id);
        
        Optional<Notification> notification = notificationService.getNotificationById(id);
        
        return notification
                .map(ResponseEntity::ok)
                .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Get all notifications for an order
     * 
     * GET /api/notifications/order/123
     */
    @GetMapping("/order/{orderId}")
    @Timed(value = "notification.get.by.order", description = "Get notifications by order")
    public ResponseEntity<List<Notification>> getNotificationsByOrderId(@PathVariable Long orderId) {
        logger.info("Getting notifications for order: {}", orderId);
        
        List<Notification> notifications = notificationService.getNotificationsByOrderId(orderId);
        
        return ResponseEntity.ok(notifications);
    }
    
    /**
     * Get all notifications for a user (paginated)
     * 
     * GET /api/notifications/user/123?page=0&size=10
     */
    @GetMapping("/user/{userId}")
    @Timed(value = "notification.get.by.user", description = "Get notifications by user")
    public ResponseEntity<Page<Notification>> getNotificationsByUserId(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "DESC") String sortDirection) {
        
        logger.info("Getting notifications for user: {} (page={}, size={})", userId, page, size);
        
        Sort sort = sortDirection.equalsIgnoreCase("ASC") ? 
                    Sort.by(sortBy).ascending() : 
                    Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        
        Page<Notification> notifications = notificationService.getNotificationsByUserId(userId, pageable);
        
        return ResponseEntity.ok(notifications);
    }
    
    /**
     * Get notifications by status (paginated)
     * 
     * GET /api/notifications/status/SENT?page=0&size=20
     */
    @GetMapping("/status/{status}")
    @Timed(value = "notification.get.by.status", description = "Get notifications by status")
    public ResponseEntity<Page<Notification>> getNotificationsByStatus(
            @PathVariable NotificationStatus status,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size) {
        
        logger.info("Getting notifications with status: {} (page={}, size={})", status, page, size);
        
        Pageable pageable = PageRequest.of(page, size, Sort.by("createdAt").descending());
        Page<Notification> notifications = notificationService.getNotificationsByStatus(status, pageable);
        
        return ResponseEntity.ok(notifications);
    }
    
    /**
     * Get notification statistics
     * 
     * GET /api/notifications/stats
     */
    @GetMapping("/stats")
    @Timed(value = "notification.get.stats", description = "Get notification statistics")
    public ResponseEntity<Map<String, Object>> getNotificationStats() {
        logger.info("Getting notification statistics");
        
        Map<String, Object> stats = notificationService.getNotificationStats();
        
        return ResponseEntity.ok(stats);
    }
    
    /**
     * Retry failed notifications
     * 
     * POST /api/notifications/retry?maxRetries=3
     */
    @PostMapping("/retry")
    @Timed(value = "notification.retry", description = "Retry failed notifications")
    public ResponseEntity<Map<String, Object>> retryFailedNotifications(
            @RequestParam(defaultValue = "3") int maxRetries) {
        
        logger.info("Retrying failed notifications (maxRetries={})", maxRetries);
        
        int retriedCount = notificationService.retryFailedNotifications(maxRetries);
        
        Map<String, Object> response = Map.of(
                "message", "Failed notifications retried",
                "retriedCount", retriedCount,
                "maxRetries", maxRetries
        );
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Check if an event was already processed (for testing idempotency)
     * 
     * GET /api/notifications/idempotency/check/event-12345
     */
    @GetMapping("/idempotency/check/{eventId}")
    @Timed(value = "notification.idempotency.check", description = "Check if event processed")
    public ResponseEntity<Map<String, Object>> checkEventProcessed(@PathVariable String eventId) {
        logger.info("Checking if event was processed: {}", eventId);
        
        boolean processed = notificationService.isEventProcessed(eventId);
        
        Map<String, Object> response = Map.of(
                "eventId", eventId,
                "processed", processed,
                "message", processed ? "Event already processed" : "Event not yet processed"
        );
        
        return ResponseEntity.ok(response);
    }
    
    /**
     * Health check endpoint
     * 
     * GET /api/notifications/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        Map<String, String> health = Map.of(
                "status", "UP",
                "service", "notification-service",
                "consumerGroup", "notification-group"
        );
        
        return ResponseEntity.ok(health);
    }
    
    /**
     * Get all notifications (paginated) - Admin endpoint
     * 
     * GET /api/notifications?page=0&size=20
     */
    @GetMapping
    @Timed(value = "notification.get.all", description = "Get all notifications")
    public ResponseEntity<Page<Notification>> getAllNotifications(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "DESC") String sortDirection) {
        
        logger.info("Getting all notifications (page={}, size={})", page, size);
        
        Sort sort = sortDirection.equalsIgnoreCase("ASC") ? 
                    Sort.by(sortBy).ascending() : 
                    Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        
        // Use status endpoint with null to get all
        Page<Notification> notifications = notificationService.getNotificationsByStatus(
                NotificationStatus.SENT, pageable);  // TODO: Add getAllNotifications method
        
        return ResponseEntity.ok(notifications);
    }
}
