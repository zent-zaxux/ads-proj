package com.umu.ads_proj.event;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Event published when a notification is sent or fails
 */
public class NotificationEvent extends BaseEvent {
    
    public enum NotificationAction {
        NOTIFICATION_SENT,
        NOTIFICATION_FAILED,
        NOTIFICATION_SKIPPED  // Duplicate event detected (idempotency)
    }
    
    private Long notificationId;
    private Long orderId;
    private Long userId;
    private String notificationType;  // ORDER_CREATED, ORDER_CONFIRMED, etc.
    private String channel;  // EMAIL, SMS, PUSH
    private String recipientEmail;
    private String recipientPhone;
    private NotificationAction action;
    private String details;
    private String errorMessage;
    
    // Default constructor for JSON deserialization
    public NotificationEvent() {
        super();
    }
    
    @JsonCreator
    public NotificationEvent(
            @JsonProperty("notificationId") Long notificationId,
            @JsonProperty("orderId") Long orderId,
            @JsonProperty("userId") Long userId,
            @JsonProperty("notificationType") String notificationType,
            @JsonProperty("channel") String channel,
            @JsonProperty("recipientEmail") String recipientEmail,
            @JsonProperty("recipientPhone") String recipientPhone,
            @JsonProperty("action") NotificationAction action,
            @JsonProperty("details") String details,
            @JsonProperty("errorMessage") String errorMessage) {
        super("NOTIFICATION_EVENT", "notification-service");
        this.notificationId = notificationId;
        this.orderId = orderId;
        this.userId = userId;
        this.notificationType = notificationType;
        this.channel = channel;
        this.recipientEmail = recipientEmail;
        this.recipientPhone = recipientPhone;
        this.action = action;
        this.details = details;
        this.errorMessage = errorMessage;
    }
    
    // Static factory methods for easier creation
    public static NotificationEvent notificationSent(Long notificationId, Long orderId, Long userId,
                                                    String notificationType, String channel,
                                                    String recipientEmail) {
        return new NotificationEvent(notificationId, orderId, userId, notificationType, channel,
                recipientEmail, null, NotificationAction.NOTIFICATION_SENT,
                "Notification sent successfully", null);
    }
    
    public static NotificationEvent notificationFailed(Long notificationId, Long orderId, Long userId,
                                                      String notificationType, String channel,
                                                      String errorMessage) {
        return new NotificationEvent(notificationId, orderId, userId, notificationType, channel,
                null, null, NotificationAction.NOTIFICATION_FAILED,
                "Notification failed", errorMessage);
    }
    
    public static NotificationEvent notificationSkipped(Long orderId, Long userId,
                                                       String notificationType, String eventId) {
        return new NotificationEvent(null, orderId, userId, notificationType, "NONE",
                null, null, NotificationAction.NOTIFICATION_SKIPPED,
                "Duplicate event detected - notification skipped (idempotency): " + eventId, null);
    }
    
    // Getters and Setters
    public Long getNotificationId() {
        return notificationId;
    }
    
    public void setNotificationId(Long notificationId) {
        this.notificationId = notificationId;
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
    
    public String getNotificationType() {
        return notificationType;
    }
    
    public void setNotificationType(String notificationType) {
        this.notificationType = notificationType;
    }
    
    public String getChannel() {
        return channel;
    }
    
    public void setChannel(String channel) {
        this.channel = channel;
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
    
    public NotificationAction getAction() {
        return action;
    }
    
    public void setAction(NotificationAction action) {
        this.action = action;
    }
    
    public String getDetails() {
        return details;
    }
    
    public void setDetails(String details) {
        this.details = details;
    }
    
    public String getErrorMessage() {
        return errorMessage;
    }
    
    public void setErrorMessage(String errorMessage) {
        this.errorMessage = errorMessage;
    }
    
    @Override
    public String toString() {
        return "NotificationEvent{" +
                "notificationId=" + notificationId +
                ", orderId=" + orderId +
                ", userId=" + userId +
                ", notificationType='" + notificationType + '\'' +
                ", channel='" + channel + '\'' +
                ", recipientEmail='" + recipientEmail + '\'' +
                ", action=" + action +
                ", details='" + details + '\'' +
                ", " + super.toString() +
                '}';
    }
}
