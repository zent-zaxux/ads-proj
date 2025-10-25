package com.umu.ads_proj.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * Notification entity for tracking sent notifications
 * Includes idempotency tracking via processed_event_id
 */
@Entity
@Table(name = "notifications", indexes = {
    @Index(name = "idx_notification_order_id", columnList = "order_id"),
    @Index(name = "idx_notification_user_id", columnList = "user_id"),
    @Index(name = "idx_notification_processed_event_id", columnList = "processed_event_id", unique = true),
    @Index(name = "idx_notification_status", columnList = "status"),
    @Index(name = "idx_notification_created_at", columnList = "created_at")
})
public class Notification {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    /**
     * Idempotency key - stores the Kafka event ID
     * Ensures we don't process the same event twice
     */
    @Column(name = "processed_event_id", nullable = false, unique = true, length = 255)
    private String processedEventId;
    
    @Column(name = "order_id", nullable = false)
    private Long orderId;
    
    @Column(name = "user_id", nullable = false)
    private Long userId;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private NotificationType type;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private NotificationChannel channel;
    
    @Column(nullable = false, length = 500)
    private String subject;
    
    @Column(columnDefinition = "TEXT")
    private String message;
    
    @Column(name = "recipient_email", length = 255)
    private String recipientEmail;
    
    @Column(name = "recipient_phone", length = 50)
    private String recipientPhone;
    
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 50)
    private NotificationStatus status;
    
    @Column(name = "sent_at")
    private LocalDateTime sentAt;
    
    @Column(name = "created_at", nullable = false, updatable = false)
    private LocalDateTime createdAt;
    
    @Column(name = "updated_at")
    private LocalDateTime updatedAt;
    
    @Column(name = "retry_count")
    private Integer retryCount = 0;
    
    @Column(name = "error_message", length = 1000)
    private String errorMessage;
    
    /**
     * Notification types based on order events
     */
    public enum NotificationType {
        ORDER_CREATED,
        ORDER_CONFIRMED,
        ORDER_SHIPPED,
        ORDER_DELIVERED,
        ORDER_CANCELLED,
        PAYMENT_COMPLETED,
        PAYMENT_FAILED
    }
    
    /**
     * Notification delivery channels
     */
    public enum NotificationChannel {
        EMAIL,
        SMS,
        PUSH,
        IN_APP
    }
    
    /**
     * Notification status
     */
    public enum NotificationStatus {
        PENDING,
        SENT,
        FAILED,
        SKIPPED  // For duplicate events (idempotency)
    }
    
    @PrePersist
    protected void onCreate() {
        createdAt = LocalDateTime.now();
        updatedAt = LocalDateTime.now();
        if (retryCount == null) {
            retryCount = 0;
        }
    }
    
    @PreUpdate
    protected void onUpdate() {
        updatedAt = LocalDateTime.now();
    }
    
    // Constructors
    public Notification() {
    }
    
    public Notification(String processedEventId, Long orderId, Long userId, 
                       NotificationType type, NotificationChannel channel,
                       String subject, String message) {
        this.processedEventId = processedEventId;
        this.orderId = orderId;
        this.userId = userId;
        this.type = type;
        this.channel = channel;
        this.subject = subject;
        this.message = message;
        this.status = NotificationStatus.PENDING;
    }
    
    // Getters and Setters
    public Long getId() {
        return id;
    }
    
    public void setId(Long id) {
        this.id = id;
    }
    
    public String getProcessedEventId() {
        return processedEventId;
    }
    
    public void setProcessedEventId(String processedEventId) {
        this.processedEventId = processedEventId;
    }
    
    public Long getOrderId() {
        return orderId;
    }
    
    public void setOrderId(Long orderId) {
        this.orderId = orderId;
    }
    
    public Long getUserId() {
        return userId;
    }
    
    public void setUserId(Long userId) {
        this.userId = userId;
    }
    
    public NotificationType getType() {
        return type;
    }
    
    public void setType(NotificationType type) {
        this.type = type;
    }
    
    public NotificationChannel getChannel() {
        return channel;
    }
    
    public void setChannel(NotificationChannel channel) {
        this.channel = channel;
    }
    
    public String getSubject() {
        return subject;
    }
    
    public void setSubject(String subject) {
        this.subject = subject;
    }
    
    public String getMessage() {
        return message;
    }
    
    public void setMessage(String message) {
        this.message = message;
    }
    
    public String getRecipientEmail() {
        return recipientEmail;
    }
    
    public void setRecipientEmail(String recipientEmail) {
        this.recipientEmail = recipientEmail;
    }
    
    public String getRecipientPhone() {
        return recipientPhone;
    }
    
    public void setRecipientPhone(String recipientPhone) {
        this.recipientPhone = recipientPhone;
    }
    
    public NotificationStatus getStatus() {
        return status;
    }
    
    public void setStatus(NotificationStatus status) {
        this.status = status;
    }
    
    public LocalDateTime getSentAt() {
        return sentAt;
    }
    
    public void setSentAt(LocalDateTime sentAt) {
        this.sentAt = sentAt;
    }
    
    public LocalDateTime getCreatedAt() {
        return createdAt;
    }
    
    public void setCreatedAt(LocalDateTime createdAt) {
        this.createdAt = createdAt;
    }
    
    public LocalDateTime getUpdatedAt() {
        return updatedAt;
    }
    
    public void setUpdatedAt(LocalDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
    
    public Integer getRetryCount() {
        return retryCount;
    }
    
    public void setRetryCount(Integer retryCount) {
        this.retryCount = retryCount;
    }
    
    public String getErrorMessage() {
        return errorMessage;
    }
    
    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }
    
    @Override
    public String toString() {
        return "Notification{" +
                "id=" + id +
                ", processedEventId='" + processedEventId + '\'' +
                ", orderId=" + orderId +
                ", userId=" + userId +
                ", type=" + type +
                ", channel=" + channel +
                ", subject='" + subject + '\'' +
                ", status=" + status +
                ", sentAt=" + sentAt +
                ", createdAt=" + createdAt +
                '}';
    }
}
