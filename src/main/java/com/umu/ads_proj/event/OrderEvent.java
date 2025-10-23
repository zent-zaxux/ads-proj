package com.umu.ads_proj.event;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;
import java.math.BigDecimal;

/**
 * Event published when an order is created, updated, or cancelled
 */
public class OrderEvent extends BaseEvent {
    
    public enum OrderAction {
        CREATED, CONFIRMED, SHIPPED, DELIVERED, CANCELLED, UPDATED
    }
    
    private Long orderId;
    private Long userId;
    private String productName;
    private Integer quantity;
    private BigDecimal totalAmount;
    private String orderStatus;
    private OrderAction action;
    private String details;
    
    // Default constructor for JSON deserialization
    public OrderEvent() {
        super();
    }
    
    @JsonCreator
    public OrderEvent(
            @JsonProperty("orderId") Long orderId,
            @JsonProperty("userId") Long userId,
            @JsonProperty("productName") String productName,
            @JsonProperty("quantity") Integer quantity,
            @JsonProperty("totalAmount") BigDecimal totalAmount,
            @JsonProperty("orderStatus") String orderStatus,
            @JsonProperty("action") OrderAction action,
            @JsonProperty("details") String details) {
        super("ORDER_EVENT", "order-service");
        this.orderId = orderId;
        this.userId = userId;
        this.productName = productName;
        this.quantity = quantity;
        this.totalAmount = totalAmount;
        this.orderStatus = orderStatus;
        this.action = action;
        this.details = details;
    }
    
    // Static factory methods for easier creation
    public static OrderEvent orderCreated(Long orderId, Long userId, String productName, 
                                         Integer quantity, BigDecimal totalAmount) {
        return new OrderEvent(orderId, userId, productName, quantity, totalAmount, 
                            "PENDING", OrderAction.CREATED, 
                            "Order created successfully");
    }
    
    public static OrderEvent orderConfirmed(Long orderId, Long userId, String productName, 
                                          Integer quantity, BigDecimal totalAmount) {
        return new OrderEvent(orderId, userId, productName, quantity, totalAmount, 
                            "CONFIRMED", OrderAction.CONFIRMED, 
                            "Order confirmed and ready for processing");
    }
    
    public static OrderEvent orderShipped(Long orderId, Long userId, String productName, 
                                        Integer quantity, BigDecimal totalAmount) {
        return new OrderEvent(orderId, userId, productName, quantity, totalAmount, 
                            "SHIPPED", OrderAction.SHIPPED, 
                            "Order shipped to customer");
    }
    
    public static OrderEvent orderDelivered(Long orderId, Long userId, String productName, 
                                          Integer quantity, BigDecimal totalAmount) {
        return new OrderEvent(orderId, userId, productName, quantity, totalAmount, 
                            "DELIVERED", OrderAction.DELIVERED, 
                            "Order delivered successfully");
    }
    
    public static OrderEvent orderCancelled(Long orderId, Long userId, String productName, 
                                          Integer quantity, BigDecimal totalAmount) {
        return new OrderEvent(orderId, userId, productName, quantity, totalAmount, 
                            "CANCELLED", OrderAction.CANCELLED, 
                            "Order cancelled by user or system");
    }
    
    public static OrderEvent orderUpdated(Long orderId, Long userId, String productName, 
                                        Integer quantity, BigDecimal totalAmount, String status) {
        return new OrderEvent(orderId, userId, productName, quantity, totalAmount, 
                            status, OrderAction.UPDATED, 
                            "Order details updated");
    }
    
    // Getters and Setters
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
    
    public String getProductName() {
        return productName;
    }
    
    public void setProductName(String productName) {
        this.productName = productName;
    }
    
    public Integer getQuantity() {
        return quantity;
    }
    
    public void setQuantity(Integer quantity) {
        this.quantity = quantity;
    }
    
    public BigDecimal getTotalAmount() {
        return totalAmount;
    }
    
    public void setTotalAmount(BigDecimal totalAmount) {
        this.totalAmount = totalAmount;
    }
    
    public String getOrderStatus() {
        return orderStatus;
    }
    
    public void setOrderStatus(String orderStatus) {
        this.orderStatus = orderStatus;
    }
    
    public OrderAction getAction() {
        return action;
    }
    
    public void setAction(OrderAction action) {
        this.action = action;
    }
    
    public String getDetails() {
        return details;
    }
    
    public void setDetails(String details) {
        this.details = details;
    }
    
    @Override
    public String toString() {
        return "OrderEvent{" +
                "orderId=" + orderId +
                ", userId=" + userId +
                ", productName='" + productName + '\'' +
                ", quantity=" + quantity +
                ", totalAmount=" + totalAmount +
                ", orderStatus='" + orderStatus + '\'' +
                ", action=" + action +
                ", details='" + details + '\'' +
                ", " + super.toString() +
                '}';
    }
}