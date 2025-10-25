package com.umu.ads_proj.event;

import java.math.BigDecimal;

/**
 * Payment event for Kafka messaging
 */
public class PaymentEvent extends BaseEvent {
    
    private Long paymentId;
    private Long orderId;
    private Long userId;
    private BigDecimal amount;
    private String paymentMethod;
    private String status;
    private PaymentAction action;
    private String transactionId;
    private String failureReason;
    
    // Payment Action Enum
    public enum PaymentAction {
        PAYMENT_CREATED,
        PAYMENT_PROCESSING,
        PAYMENT_COMPLETED,
        PAYMENT_FAILED,
        PAYMENT_REFUNDED,
        PAYMENT_CANCELLED
    }
    
    // Constructors
    public PaymentEvent() {
        super();
    }
    
    public PaymentEvent(String eventType, String serviceSource, Long paymentId, Long orderId, 
                       Long userId, BigDecimal amount, String paymentMethod, String status,
                       PaymentAction action) {
        super(eventType, serviceSource);
        this.paymentId = paymentId;
        this.orderId = orderId;
        this.userId = userId;
        this.amount = amount;
        this.paymentMethod = paymentMethod;
        this.status = status;
        this.action = action;
    }
    
    // Factory methods for different payment actions
    public static PaymentEvent paymentCreated(Long paymentId, Long orderId, Long userId, 
                                             BigDecimal amount, String paymentMethod) {
        PaymentEvent event = new PaymentEvent();
        event.setEventId(java.util.UUID.randomUUID().toString());
        event.setEventType("PAYMENT_CREATED");
        event.setPaymentId(paymentId);
        event.setOrderId(orderId);
        event.setUserId(userId);
        event.setAmount(amount);
        event.setPaymentMethod(paymentMethod);
        event.setStatus("PENDING");
        event.setAction(PaymentAction.PAYMENT_CREATED);
        event.setTimestamp(java.time.LocalDateTime.now());
        return event;
    }
    
    public static PaymentEvent paymentProcessing(Long paymentId, Long orderId, String transactionId) {
        PaymentEvent event = new PaymentEvent();
        event.setEventId(java.util.UUID.randomUUID().toString());
        event.setEventType("PAYMENT_PROCESSING");
        event.setPaymentId(paymentId);
        event.setOrderId(orderId);
        event.setStatus("PROCESSING");
        event.setAction(PaymentAction.PAYMENT_PROCESSING);
        event.setTransactionId(transactionId);
        event.setTimestamp(java.time.LocalDateTime.now());
        return event;
    }
    
    public static PaymentEvent paymentCompleted(Long paymentId, Long orderId, Long userId, 
                                               BigDecimal amount, String transactionId) {
        PaymentEvent event = new PaymentEvent();
        event.setEventId(java.util.UUID.randomUUID().toString());
        event.setEventType("PAYMENT_COMPLETED");
        event.setPaymentId(paymentId);
        event.setOrderId(orderId);
        event.setUserId(userId);
        event.setAmount(amount);
        event.setStatus("COMPLETED");
        event.setAction(PaymentAction.PAYMENT_COMPLETED);
        event.setTransactionId(transactionId);
        event.setTimestamp(java.time.LocalDateTime.now());
        return event;
    }
    
    public static PaymentEvent paymentFailed(Long paymentId, Long orderId, String failureReason) {
        PaymentEvent event = new PaymentEvent();
        event.setEventId(java.util.UUID.randomUUID().toString());
        event.setEventType("PAYMENT_FAILED");
        event.setPaymentId(paymentId);
        event.setOrderId(orderId);
        event.setStatus("FAILED");
        event.setAction(PaymentAction.PAYMENT_FAILED);
        event.setFailureReason(failureReason);
        event.setTimestamp(java.time.LocalDateTime.now());
        return event;
    }
    
    public static PaymentEvent paymentRefunded(Long paymentId, Long orderId, BigDecimal amount, String reason) {
        PaymentEvent event = new PaymentEvent();
        event.setEventId(java.util.UUID.randomUUID().toString());
        event.setEventType("PAYMENT_REFUNDED");
        event.setPaymentId(paymentId);
        event.setOrderId(orderId);
        event.setAmount(amount);
        event.setStatus("REFUNDED");
        event.setAction(PaymentAction.PAYMENT_REFUNDED);
        event.setFailureReason(reason);
        event.setTimestamp(java.time.LocalDateTime.now());
        return event;
    }
    
    public static PaymentEvent paymentCancelled(Long paymentId, Long orderId, String reason) {
        PaymentEvent event = new PaymentEvent();
        event.setEventId(java.util.UUID.randomUUID().toString());
        event.setEventType("PAYMENT_CANCELLED");
        event.setPaymentId(paymentId);
        event.setOrderId(orderId);
        event.setStatus("CANCELLED");
        event.setAction(PaymentAction.PAYMENT_CANCELLED);
        event.setFailureReason(reason);
        event.setTimestamp(java.time.LocalDateTime.now());
        return event;
    }
    
    // Getters and Setters
    public Long getPaymentId() {
        return paymentId;
    }
    
    public void setPaymentId(Long paymentId) {
        this.paymentId = paymentId;
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
    
    public BigDecimal getAmount() {
        return amount;
    }
    
    public void setAmount(BigDecimal amount) {
        this.amount = amount;
    }
    
    public String getPaymentMethod() {
        return paymentMethod;
    }
    
    public void setPaymentMethod(String paymentMethod) {
        this.paymentMethod = paymentMethod;
    }
    
    public String getStatus() {
        return status;
    }
    
    public void setStatus(String status) {
        this.status = status;
    }
    
    public PaymentAction getAction() {
        return action;
    }
    
    public void setAction(PaymentAction action) {
        this.action = action;
    }
    
    public String getTransactionId() {
        return transactionId;
    }
    
    public void setTransactionId(String transactionId) {
        this.transactionId = transactionId;
    }
    
    public String getFailureReason() {
        return failureReason;
    }
    
    public void setFailureReason(String failureReason) {
        this.failureReason = failureReason;
    }
    
    @Override
    public String toString() {
        return "PaymentEvent{" +
                "eventId='" + getEventId() + '\'' +
                ", paymentId=" + paymentId +
                ", orderId=" + orderId +
                ", userId=" + userId +
                ", amount=" + amount +
                ", paymentMethod='" + paymentMethod + '\'' +
                ", status='" + status + '\'' +
                ", action=" + action +
                ", transactionId='" + transactionId + '\'' +
                ", timestamp=" + getTimestamp() +
                '}';
    }
}
