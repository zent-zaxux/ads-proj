package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.Order;
import com.umu.ads_proj.event.OrderEvent;
import com.umu.ads_proj.repository.OrderRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * Service class for Order operations with Kafka event publishing
 */
@Service
@Transactional
public class OrderService {
    
    private static final Logger logger = LoggerFactory.getLogger(OrderService.class);
    
    @Autowired
    private OrderRepository orderRepository;
    
    @Autowired
    private EventPublisherService eventPublisher;
    
    /**
     * Create a new order
     */
    public Order createOrder(Order order) {
        logger.info("Creating new order for user: {} - Product: {}", 
                   order.getUserId(), order.getProductName());
        
        // Validate order data
        validateOrder(order);
        
        Order savedOrder = orderRepository.save(order);
        logger.info("Order created successfully with ID: {}", savedOrder.getId());
        
        // Publish order creation event to Kafka asynchronously (non-blocking)
        OrderEvent orderEvent = OrderEvent.orderCreated(
            savedOrder.getId(), 
            savedOrder.getUserId(), 
            savedOrder.getProductName(),
            savedOrder.getQuantity(), 
            savedOrder.getTotalAmount()
        );
        eventPublisher.publishOrderEventAsync(orderEvent);
        
        return savedOrder;
    }
    
    /**
     * Get order by ID
     */
    @Transactional(readOnly = true)
    public Optional<Order> getOrderById(Long id) {
        logger.debug("Retrieving order with ID: {}", id);
        return orderRepository.findById(id);
    }
    
    /**
     * Get all orders with pagination
     */
    @Transactional(readOnly = true)
    public Page<Order> getAllOrders(Pageable pageable) {
        logger.debug("Retrieving all orders with pagination: {}", pageable);
        return orderRepository.findAll(pageable);
    }
    
    /**
     * Get orders by user ID
     */
    @Transactional(readOnly = true)
    public List<Order> getOrdersByUserId(Long userId) {
        logger.debug("Retrieving orders for user: {}", userId);
        return orderRepository.findByUserId(userId);
    }
    
    /**
     * Get orders by user ID with pagination
     */
    @Transactional(readOnly = true)
    public Page<Order> getOrdersByUserId(Long userId, Pageable pageable) {
        logger.debug("Retrieving orders for user: {} with pagination", userId);
        return orderRepository.findByUserId(userId, pageable);
    }
    
    /**
     * Get orders by status
     */
    @Transactional(readOnly = true)
    public List<Order> getOrdersByStatus(Order.OrderStatus status) {
        logger.debug("Retrieving orders with status: {}", status);
        return orderRepository.findByStatus(status);
    }
    
    /**
     * Update order status
     */
    public Order updateOrderStatus(Long orderId, Order.OrderStatus newStatus) {
        logger.info("Updating order {} status to: {}", orderId, newStatus);
        
        Optional<Order> orderOpt = orderRepository.findById(orderId);
        if (orderOpt.isEmpty()) {
            logger.warn("Order with ID {} not found for status update", orderId);
            throw new IllegalArgumentException("Order with ID " + orderId + " not found");
        }
        
        Order order = orderOpt.get();
        Order.OrderStatus oldStatus = order.getStatus();
        order.setStatus(newStatus);
        
        Order updatedOrder = orderRepository.save(order);
        logger.info("Order {} status updated from {} to {}", orderId, oldStatus, newStatus);
        
        // Publish appropriate event based on new status
        OrderEvent orderEvent = createStatusChangeEvent(updatedOrder, newStatus);
        eventPublisher.publishOrderEvent(orderEvent);
        
        return updatedOrder;
    }
    
    /**
     * Update order details
     */
    public Order updateOrder(Long orderId, Order updatedOrder) {
        logger.info("Updating order with ID: {}", orderId);
        
        Optional<Order> existingOrderOpt = orderRepository.findById(orderId);
        if (existingOrderOpt.isEmpty()) {
            logger.warn("Order with ID {} not found for update", orderId);
            throw new IllegalArgumentException("Order with ID " + orderId + " not found");
        }
        
        Order existingOrder = existingOrderOpt.get();
        
        // Update fields
        existingOrder.setProductName(updatedOrder.getProductName());
        existingOrder.setQuantity(updatedOrder.getQuantity());
        existingOrder.setUnitPrice(updatedOrder.getUnitPrice());
        // Total amount is recalculated automatically in the entity
        
        Order savedOrder = orderRepository.save(existingOrder);
        logger.info("Order updated successfully with ID: {}", savedOrder.getId());
        
        // Publish order update event
        OrderEvent orderEvent = OrderEvent.orderUpdated(
            savedOrder.getId(),
            savedOrder.getUserId(),
            savedOrder.getProductName(),
            savedOrder.getQuantity(),
            savedOrder.getTotalAmount(),
            savedOrder.getStatus().toString()
        );
        eventPublisher.publishOrderEvent(orderEvent);
        
        return savedOrder;
    }
    
    /**
     * Cancel order
     */
    public Order cancelOrder(Long orderId) {
        logger.info("Cancelling order with ID: {}", orderId);
        
        Optional<Order> orderOpt = orderRepository.findById(orderId);
        if (orderOpt.isEmpty()) {
            logger.warn("Order with ID {} not found for cancellation", orderId);
            throw new IllegalArgumentException("Order with ID " + orderId + " not found");
        }
        
        Order order = orderOpt.get();
        
        // Check if order can be cancelled
        if (order.getStatus() == Order.OrderStatus.DELIVERED) {
            throw new IllegalStateException("Cannot cancel delivered order");
        }
        
        order.setStatus(Order.OrderStatus.CANCELLED);
        Order cancelledOrder = orderRepository.save(order);
        logger.info("Order cancelled successfully with ID: {}", cancelledOrder.getId());
        
        // Publish order cancellation event
        OrderEvent orderEvent = OrderEvent.orderCancelled(
            cancelledOrder.getId(),
            cancelledOrder.getUserId(),
            cancelledOrder.getProductName(),
            cancelledOrder.getQuantity(),
            cancelledOrder.getTotalAmount()
        );
        eventPublisher.publishOrderEvent(orderEvent);
        
        return cancelledOrder;
    }
    
    /**
     * Get total order count
     */
    @Transactional(readOnly = true)
    public long getTotalOrderCount() {
        return orderRepository.count();
    }
    
    /**
     * Get order count by status
     */
    @Transactional(readOnly = true)
    public long getOrderCountByStatus(Order.OrderStatus status) {
        return orderRepository.countByStatus(status);
    }
    
    /**
     * Calculate total revenue
     */
    @Transactional(readOnly = true)
    public BigDecimal calculateTotalRevenue() {
        return orderRepository.calculateTotalAmountByStatus(Order.OrderStatus.DELIVERED);
    }
    
    /**
     * Calculate user's total order amount
     */
    @Transactional(readOnly = true)
    public BigDecimal calculateUserTotalAmount(Long userId) {
        return orderRepository.calculateTotalAmountForUser(userId);
    }
    
    /**
     * Validate order data
     */
    private void validateOrder(Order order) {
        if (order.getUserId() == null) {
            throw new IllegalArgumentException("User ID cannot be null");
        }
        if (order.getProductName() == null || order.getProductName().trim().isEmpty()) {
            throw new IllegalArgumentException("Product name cannot be null or empty");
        }
        if (order.getQuantity() == null || order.getQuantity() <= 0) {
            throw new IllegalArgumentException("Quantity must be greater than 0");
        }
        if (order.getUnitPrice() == null || order.getUnitPrice().compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Unit price must be greater than 0");
        }
    }
    
    /**
     * Create appropriate event based on status change
     */
    private OrderEvent createStatusChangeEvent(Order order, Order.OrderStatus newStatus) {
        switch (newStatus) {
            case CONFIRMED:
                return OrderEvent.orderConfirmed(order.getId(), order.getUserId(), 
                    order.getProductName(), order.getQuantity(), order.getTotalAmount());
            case SHIPPED:
                return OrderEvent.orderShipped(order.getId(), order.getUserId(), 
                    order.getProductName(), order.getQuantity(), order.getTotalAmount());
            case DELIVERED:
                return OrderEvent.orderDelivered(order.getId(), order.getUserId(), 
                    order.getProductName(), order.getQuantity(), order.getTotalAmount());
            case CANCELLED:
                return OrderEvent.orderCancelled(order.getId(), order.getUserId(), 
                    order.getProductName(), order.getQuantity(), order.getTotalAmount());
            default:
                return OrderEvent.orderUpdated(order.getId(), order.getUserId(), 
                    order.getProductName(), order.getQuantity(), order.getTotalAmount(), 
                    newStatus.toString());
        }
    }
}