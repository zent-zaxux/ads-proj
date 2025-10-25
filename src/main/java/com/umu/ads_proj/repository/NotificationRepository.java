package com.umu.ads_proj.repository;

import com.umu.ads_proj.entity.Notification;
import com.umu.ads_proj.entity.Notification.NotificationStatus;
import com.umu.ads_proj.entity.Notification.NotificationType;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;

/**
 * Repository for Notification entity with idempotency support
 */
@Repository
public interface NotificationRepository extends JpaRepository<Notification, Long> {
    
    /**
     * IDEMPOTENCY CHECK: Check if event has already been processed
     * This is the key method for preventing duplicate notifications
     * 
     * @param processedEventId The Kafka event ID
     * @return true if event was already processed, false otherwise
     */
    boolean existsByProcessedEventId(String processedEventId);
    
    /**
     * IDEMPOTENCY: Get notification by processed event ID
     * 
     * @param processedEventId The Kafka event ID
     * @return Optional containing the notification if found
     */
    Optional<Notification> findByProcessedEventId(String processedEventId);
    
    /**
     * Find all notifications for a specific order
     */
    List<Notification> findByOrderId(Long orderId);
    
    /**
     * Find all notifications for a specific order (paginated)
     */
    Page<Notification> findByOrderId(Long orderId, Pageable pageable);
    
    /**
     * Find all notifications for a specific user
     */
    List<Notification> findByUserId(Long userId);
    
    /**
     * Find all notifications for a specific user (paginated)
     */
    Page<Notification> findByUserId(Long userId, Pageable pageable);
    
    /**
     * Find notifications by status
     */
    List<Notification> findByStatus(NotificationStatus status);
    
    /**
     * Find notifications by status (paginated)
     */
    Page<Notification> findByStatus(NotificationStatus status, Pageable pageable);
    
    /**
     * Find notifications by type
     */
    List<Notification> findByType(NotificationType type);
    
    /**
     * Find failed notifications that need retry
     */
    @Query("SELECT n FROM Notification n WHERE n.status = 'FAILED' AND n.retryCount < :maxRetries")
    List<Notification> findFailedNotificationsForRetry(@Param("maxRetries") int maxRetries);
    
    /**
     * Find pending notifications
     */
    List<Notification> findByStatusOrderByCreatedAtAsc(NotificationStatus status);
    
    /**
     * Find notifications created within a date range
     */
    @Query("SELECT n FROM Notification n WHERE n.createdAt BETWEEN :startDate AND :endDate")
    List<Notification> findByCreatedAtBetween(@Param("startDate") LocalDateTime startDate,
                                               @Param("endDate") LocalDateTime endDate);
    
    /**
     * Count notifications by status
     */
    long countByStatus(NotificationStatus status);
    
    /**
     * Count notifications by type
     */
    long countByType(NotificationType type);
    
    /**
     * Count total notifications for a user
     */
    long countByUserId(Long userId);
    
    /**
     * Count notifications for an order
     */
    long countByOrderId(Long orderId);
    
    /**
     * Get notification statistics
     */
    @Query("SELECT n.status as status, COUNT(n) as count FROM Notification n GROUP BY n.status")
    List<Object[]> getNotificationStatsByStatus();
    
    /**
     * Get notification statistics by type
     */
    @Query("SELECT n.type as type, COUNT(n) as count FROM Notification n GROUP BY n.type")
    List<Object[]> getNotificationStatsByType();
    
    /**
     * Find recent notifications (last N days)
     */
    @Query("SELECT n FROM Notification n WHERE n.createdAt >= :since ORDER BY n.createdAt DESC")
    List<Notification> findRecentNotifications(@Param("since") LocalDateTime since);
    
    /**
     * Delete old notifications (cleanup)
     */
    @Query("DELETE FROM Notification n WHERE n.createdAt < :before AND n.status = 'SENT'")
    void deleteOldSentNotifications(@Param("before") LocalDateTime before);
}
