package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.Notification;
import com.umu.ads_proj.entity.Notification.NotificationChannel;
import com.umu.ads_proj.entity.Notification.NotificationStatus;
import com.umu.ads_proj.entity.Notification.NotificationType;
import com.umu.ads_proj.entity.Order;
import com.umu.ads_proj.entity.User;
import com.umu.ads_proj.event.NotificationEvent;
import com.umu.ads_proj.event.OrderEvent;
import com.umu.ads_proj.repository.NotificationRepository;
import com.umu.ads_proj.repository.OrderRepository;
import com.umu.ads_proj.repository.UserRepository;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.LocalDateTime;
import java.util.*;

/**
 * Service for processing notifications with idempotency support
 * Prevents duplicate notifications from being sent
 */
@Service
public class NotificationService {
    
    private static final Logger logger = LoggerFactory.getLogger(NotificationService.class);
    
    @Autowired
    private NotificationRepository notificationRepository;
    
    @Autowired
    private OrderRepository orderRepository;
    
    @Autowired
    private UserRepository userRepository;
    
    @Autowired
    private EventPublisherService eventPublisherService;
    
    /**
     * Process order event and send notification with idempotency check
     * THIS IS THE CORE IDEMPOTENCY IMPLEMENTATION
     * 
     * @param orderEvent The order event from Kafka
     * @return Notification if sent, null if duplicate
     */
    @Transactional
    @Timed(value = "notification.process.order.event", description = "Time taken to process order event")
    public Notification processOrderEvent(OrderEvent orderEvent) {
        String eventId = orderEvent.getEventId();
        
        logger.info("Processing order event: {} (EventID: {})", orderEvent.getAction(), eventId);
        
        // ========================================
        // IDEMPOTENCY CHECK: Has this event been processed before?
        // ========================================
        if (notificationRepository.existsByProcessedEventId(eventId)) {
            logger.warn("IDEMPOTENCY: Event {} already processed. Skipping notification.", eventId);
            
            // Publish skipped event
            NotificationEvent skippedEvent = NotificationEvent.notificationSkipped(
                    orderEvent.getOrderId(),
                    orderEvent.getUserId(),
                    orderEvent.getAction().name(),
                    eventId
            );
            eventPublisherService.publishNotificationEvent(skippedEvent);
            
            return null;  // Return null to indicate duplicate
        }
        
        // Determine if this order action should trigger a notification
        NotificationType notificationType = mapOrderActionToNotificationType(orderEvent.getAction());
        if (notificationType == null) {
            logger.debug("Order action {} does not require notification", orderEvent.getAction());
            return null;
        }
        
        // Get order and user details
        Optional<Order> orderOpt = orderRepository.findById(orderEvent.getOrderId());
        Optional<User> userOpt = userRepository.findById(orderEvent.getUserId());
        
        if (orderOpt.isEmpty() || userOpt.isEmpty()) {
            logger.error("Order {} or User {} not found. Cannot send notification.",
                    orderEvent.getOrderId(), orderEvent.getUserId());
            return null;
        }
        
        Order order = orderOpt.get();
        User user = userOpt.get();
        
        // Create notification with event ID for idempotency
        Notification notification = createNotification(
                eventId,
                order,
                user,
                notificationType,
                orderEvent
        );
        
        // Save notification (this also saves the processed_event_id for idempotency)
        notification = notificationRepository.save(notification);
        logger.info("Notification created with ID: {} for event: {}", notification.getId(), eventId);
        
        // Send the notification
        boolean success = sendNotification(notification);
        
        // Update notification status
        if (success) {
            notification.setStatus(NotificationStatus.SENT);
            notification.setSentAt(LocalDateTime.now());
            logger.info("Notification {} sent successfully", notification.getId());
            
            // Publish success event
            NotificationEvent successEvent = NotificationEvent.notificationSent(
                    notification.getId(),
                    order.getId(),
                    user.getId(),
                    notificationType.name(),
                    notification.getChannel().name(),
                    user.getEmail()
            );
            eventPublisherService.publishNotificationEvent(successEvent);
        } else {
            notification.setStatus(NotificationStatus.FAILED);
            notification.setRetryCount(notification.getRetryCount() + 1);
            logger.error("Notification {} failed to send", notification.getId());
            
            // Publish failure event
            NotificationEvent failureEvent = NotificationEvent.notificationFailed(
                    notification.getId(),
                    order.getId(),
                    user.getId(),
                    notificationType.name(),
                    notification.getChannel().name(),
                    notification.getErrorMessage()
            );
            eventPublisherService.publishNotificationEvent(failureEvent);
        }
        
        notification = notificationRepository.save(notification);
        
        return notification;
    }
    
    /**
     * Create a notification object
     */
    private Notification createNotification(String eventId, Order order, User user,
                                           NotificationType type, OrderEvent orderEvent) {
        Notification notification = new Notification();
        notification.setProcessedEventId(eventId);  // IDEMPOTENCY KEY
        notification.setOrderId(order.getId());
        notification.setUserId(user.getId());
        notification.setType(type);
        notification.setChannel(NotificationChannel.EMAIL);  // Default to email
        notification.setRecipientEmail(user.getEmail());
        notification.setStatus(NotificationStatus.PENDING);
        
        // Generate subject and message based on notification type
        Map<String, String> content = generateNotificationContent(type, order, user);
        notification.setSubject(content.get("subject"));
        notification.setMessage(content.get("message"));
        
        return notification;
    }
    
    /**
     * Generate notification content based on type
     */
    private Map<String, String> generateNotificationContent(NotificationType type, Order order, User user) {
        Map<String, String> content = new HashMap<>();
        String userName = user.getName();
        Long orderId = order.getId();
        String productName = order.getProductName();
        
        switch (type) {
            case ORDER_CREATED:
                content.put("subject", "Order Confirmation - Order #" + orderId);
                content.put("message", String.format(
                        "Dear %s,\n\nThank you for your order!\n\nOrder Details:\n" +
                        "Order ID: #%d\nProduct: %s\nQuantity: %d\nTotal: $%.2f\n\n" +
                        "We'll send you another email when your order is confirmed.\n\n" +
                        "Best regards,\nADS Proj Team",
                        userName, orderId, productName, order.getQuantity(), order.getTotalAmount()
                ));
                break;
                
            case ORDER_CONFIRMED:
                content.put("subject", "Order Confirmed - Order #" + orderId);
                content.put("message", String.format(
                        "Dear %s,\n\nGreat news! Your order has been confirmed and is being prepared for shipment.\n\n" +
                        "Order ID: #%d\nProduct: %s\n\n" +
                        "You'll receive a shipping notification once your order is on its way.\n\n" +
                        "Best regards,\nADS Proj Team",
                        userName, orderId, productName
                ));
                break;
                
            case ORDER_SHIPPED:
                content.put("subject", "Order Shipped - Order #" + orderId);
                content.put("message", String.format(
                        "Dear %s,\n\nYour order has been shipped!\n\n" +
                        "Order ID: #%d\nProduct: %s\n" +
                        "Tracking Number: TRK-%d-%d\n\n" +
                        "Estimated delivery: 3-5 business days\n\n" +
                        "Best regards,\nADS Proj Team",
                        userName, orderId, productName, orderId, System.currentTimeMillis()
                ));
                break;
                
            case ORDER_DELIVERED:
                content.put("subject", "Order Delivered - Order #" + orderId);
                content.put("message", String.format(
                        "Dear %s,\n\nYour order has been delivered!\n\n" +
                        "Order ID: #%d\nProduct: %s\n\n" +
                        "We hope you enjoy your purchase. Please rate your experience!\n\n" +
                        "Best regards,\nADS Proj Team",
                        userName, orderId, productName
                ));
                break;
                
            case ORDER_CANCELLED:
                content.put("subject", "Order Cancelled - Order #" + orderId);
                content.put("message", String.format(
                        "Dear %s,\n\nYour order has been cancelled as requested.\n\n" +
                        "Order ID: #%d\nProduct: %s\n\n" +
                        "If you have any questions, please contact our support team.\n\n" +
                        "Best regards,\nADS Proj Team",
                        userName, orderId, productName
                ));
                break;
                
            default:
                content.put("subject", "Order Update - Order #" + orderId);
                content.put("message", String.format(
                        "Dear %s,\n\nYour order #%d has been updated.\n\n" +
                        "Best regards,\nADS Proj Team",
                        userName, orderId
                ));
        }
        
        return content;
    }
    
    /**
     * Simulate sending notification (EMAIL/SMS/PUSH)
     * In production, this would call actual email/SMS APIs
     * 
     * @return true if sent successfully, false otherwise
     */
    private boolean sendNotification(Notification notification) {
        try {
            logger.info("SENDING NOTIFICATION: {} to {} via {}",
                    notification.getType(),
                    notification.getRecipientEmail(),
                    notification.getChannel());
            
            // Simulate network delay
            Thread.sleep(100);
            
            // Simulate 95% success rate (5% failure for testing)
            boolean success = Math.random() > 0.05;
            
            if (success) {
                logger.info("✅ NOTIFICATION SENT: {} (ID: {})", notification.getSubject(), notification.getId());
                logger.debug("Message: {}", notification.getMessage());
            } else {
                String errorMsg = "Simulated notification delivery failure (network error)";
                notification.setErrorMessage(errorMsg);
                logger.error("❌ NOTIFICATION FAILED: {}", errorMsg);
            }
            
            return success;
            
        } catch (InterruptedException e) {
            logger.error("Error sending notification: {}", e.getMessage());
            notification.setErrorMessage("Interrupted: " + e.getMessage());
            Thread.currentThread().interrupt();
            return false;
        } catch (Exception e) {
            logger.error("Error sending notification: {}", e.getMessage(), e);
            notification.setErrorMessage("Error: " + e.getMessage());
            return false;
        }
    }
    
    /**
     * Map order action to notification type
     */
    private NotificationType mapOrderActionToNotificationType(OrderEvent.OrderAction action) {
        switch (action) {
            case CREATED:
                return NotificationType.ORDER_CREATED;
            case CONFIRMED:
                return NotificationType.ORDER_CONFIRMED;
            case SHIPPED:
                return NotificationType.ORDER_SHIPPED;
            case DELIVERED:
                return NotificationType.ORDER_DELIVERED;
            case CANCELLED:
                return NotificationType.ORDER_CANCELLED;
            case UPDATED:
                // Don't send notifications for simple updates
                return null;
            default:
                return null;
        }
    }
    
    // ========================================
    // Additional Service Methods
    // ========================================
    
    /**
     * Get notification by ID
     */
    @Timed(value = "notification.get.by.id", description = "Time to get notification by ID")
    public Optional<Notification> getNotificationById(Long id) {
        return notificationRepository.findById(id);
    }
    
    /**
     * Get all notifications for an order
     */
    @Timed(value = "notification.get.by.order", description = "Time to get notifications by order")
    public List<Notification> getNotificationsByOrderId(Long orderId) {
        return notificationRepository.findByOrderId(orderId);
    }
    
    /**
     * Get all notifications for a user
     */
    @Timed(value = "notification.get.by.user", description = "Time to get notifications by user")
    public Page<Notification> getNotificationsByUserId(Long userId, Pageable pageable) {
        return notificationRepository.findByUserId(userId, pageable);
    }
    
    /**
     * Get notifications by status
     */
    public Page<Notification> getNotificationsByStatus(NotificationStatus status, Pageable pageable) {
        return notificationRepository.findByStatus(status, pageable);
    }
    
    /**
     * Get notification statistics
     */
    @Timed(value = "notification.get.stats", description = "Time to get notification stats")
    public Map<String, Object> getNotificationStats() {
        Map<String, Object> stats = new HashMap<>();
        
        stats.put("total", notificationRepository.count());
        stats.put("sent", notificationRepository.countByStatus(NotificationStatus.SENT));
        stats.put("failed", notificationRepository.countByStatus(NotificationStatus.FAILED));
        stats.put("pending", notificationRepository.countByStatus(NotificationStatus.PENDING));
        stats.put("skipped", notificationRepository.countByStatus(NotificationStatus.SKIPPED));
        
        // Get stats by type
        Map<String, Long> byType = new HashMap<>();
        for (NotificationType type : NotificationType.values()) {
            byType.put(type.name(), notificationRepository.countByType(type));
        }
        stats.put("byType", byType);
        
        // Get recent notifications (last 24 hours)
        LocalDateTime since = LocalDateTime.now().minusDays(1);
        List<Notification> recent = notificationRepository.findRecentNotifications(since);
        stats.put("last24Hours", recent.size());
        
        return stats;
    }
    
    /**
     * Retry failed notifications
     */
    @Transactional
    @Timed(value = "notification.retry.failed", description = "Time to retry failed notifications")
    public int retryFailedNotifications(int maxRetries) {
        List<Notification> failedNotifications = notificationRepository.findFailedNotificationsForRetry(maxRetries);
        int retried = 0;
        
        for (Notification notification : failedNotifications) {
            logger.info("Retrying notification ID: {} (attempt {})", 
                    notification.getId(), notification.getRetryCount() + 1);
            
            boolean success = sendNotification(notification);
            
            if (success) {
                notification.setStatus(NotificationStatus.SENT);
                notification.setSentAt(LocalDateTime.now());
                retried++;
            } else {
                notification.setRetryCount(notification.getRetryCount() + 1);
            }
            
            notificationRepository.save(notification);
        }
        
        logger.info("Retried {} failed notifications", retried);
        return retried;
    }
    
    /**
     * Check if event was already processed (for testing/debugging)
     */
    public boolean isEventProcessed(String eventId) {
        return notificationRepository.existsByProcessedEventId(eventId);
    }
}
