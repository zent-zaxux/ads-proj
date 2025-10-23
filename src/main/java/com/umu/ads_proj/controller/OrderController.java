package com.umu.ads_proj.controller;

import com.umu.ads_proj.entity.Order;
import com.umu.ads_proj.service.OrderService;
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

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;
import java.util.Optional;

/**
 * REST Controller for Order Management
 */
@RestController
@RequestMapping("/api/orders")
public class OrderController {
    
    private static final Logger logger = LoggerFactory.getLogger(OrderController.class);
    
    @Autowired
    private OrderService orderService;
    
    /**
     * Create a new order
     */
    @PostMapping
    @Timed(value = "order.create", description = "Time taken to create order")
    public ResponseEntity<Order> createOrder(@RequestBody Order order) {
        logger.info("Received request to create order for user: {}", order.getUserId());
        
        try {
            Order createdOrder = orderService.createOrder(order);
            return ResponseEntity.status(HttpStatus.CREATED).body(createdOrder);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid order data: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            logger.error("Error creating order: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Get order by ID
     */
    @GetMapping("/{id}")
    @Timed(value = "order.get", description = "Time taken to get order by ID")
    public ResponseEntity<Order> getOrder(@PathVariable Long id) {
        logger.debug("Received request to get order with ID: {}", id);
        
        try {
            Optional<Order> order = orderService.getOrderById(id);
            return order.map(o -> ResponseEntity.ok(o))
                       .orElse(ResponseEntity.notFound().build());
        } catch (Exception e) {
            logger.error("Error retrieving order with ID {}: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Get all orders with pagination
     */
    @GetMapping
    @Timed(value = "order.list", description = "Time taken to list orders")
    public ResponseEntity<Page<Order>> getAllOrders(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        
        logger.debug("Received request to get all orders - page: {}, size: {}, sortBy: {}, sortDir: {}", 
                    page, size, sortBy, sortDir);
        
        try {
            Sort sort = sortDir.equalsIgnoreCase("desc") ? 
                       Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
            Pageable pageable = PageRequest.of(page, size, sort);
            
            Page<Order> orders = orderService.getAllOrders(pageable);
            return ResponseEntity.ok(orders);
        } catch (Exception e) {
            logger.error("Error retrieving orders: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Get orders by user ID
     */
    @GetMapping("/user/{userId}")
    @Timed(value = "order.user", description = "Time taken to get orders by user")
    public ResponseEntity<List<Order>> getOrdersByUser(@PathVariable Long userId) {
        logger.debug("Received request to get orders for user: {}", userId);
        
        try {
            List<Order> orders = orderService.getOrdersByUserId(userId);
            return ResponseEntity.ok(orders);
        } catch (Exception e) {
            logger.error("Error retrieving orders for user {}: {}", userId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Get orders by user ID with pagination
     */
    @GetMapping("/user/{userId}/paginated")
    @Timed(value = "order.user.paginated", description = "Time taken to get paginated orders by user")
    public ResponseEntity<Page<Order>> getOrdersByUserPaginated(
            @PathVariable Long userId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "desc") String sortDir) {
        
        logger.debug("Received request to get paginated orders for user: {}", userId);
        
        try {
            Sort sort = sortDir.equalsIgnoreCase("desc") ? 
                       Sort.by(sortBy).descending() : Sort.by(sortBy).ascending();
            Pageable pageable = PageRequest.of(page, size, sort);
            
            Page<Order> orders = orderService.getOrdersByUserId(userId, pageable);
            return ResponseEntity.ok(orders);
        } catch (Exception e) {
            logger.error("Error retrieving paginated orders for user {}: {}", userId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Get orders by status
     */
    @GetMapping("/status/{status}")
    @Timed(value = "order.status", description = "Time taken to get orders by status")
    public ResponseEntity<List<Order>> getOrdersByStatus(@PathVariable String status) {
        logger.debug("Received request to get orders with status: {}", status);
        
        try {
            Order.OrderStatus orderStatus = Order.OrderStatus.valueOf(status.toUpperCase());
            List<Order> orders = orderService.getOrdersByStatus(orderStatus);
            return ResponseEntity.ok(orders);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid order status: {}", status);
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            logger.error("Error retrieving orders with status {}: {}", status, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Update order
     */
    @PutMapping("/{id}")
    @Timed(value = "order.update", description = "Time taken to update order")
    public ResponseEntity<Order> updateOrder(@PathVariable Long id, @RequestBody Order order) {
        logger.info("Received request to update order with ID: {}", id);
        
        try {
            Order updatedOrder = orderService.updateOrder(id, order);
            return ResponseEntity.ok(updatedOrder);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid order data for update: {}", e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (Exception e) {
            logger.error("Error updating order with ID {}: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Update order status
     */
    @PatchMapping("/{id}/status")
    @Timed(value = "order.update.status", description = "Time taken to update order status")
    public ResponseEntity<Order> updateOrderStatus(
            @PathVariable Long id, 
            @RequestBody Map<String, String> statusUpdate) {
        
        logger.info("Received request to update status for order ID: {}", id);
        
        try {
            String statusStr = statusUpdate.get("status");
            if (statusStr == null) {
                return ResponseEntity.badRequest().build();
            }
            
            Order.OrderStatus newStatus = Order.OrderStatus.valueOf(statusStr.toUpperCase());
            Order updatedOrder = orderService.updateOrderStatus(id, newStatus);
            return ResponseEntity.ok(updatedOrder);
        } catch (IllegalArgumentException e) {
            logger.warn("Invalid status update for order {}: {}", id, e.getMessage());
            return ResponseEntity.badRequest().build();
        } catch (IllegalStateException e) {
            logger.warn("Invalid status transition for order {}: {}", id, e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT).build();
        } catch (Exception e) {
            logger.error("Error updating status for order {}: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Cancel order
     */
    @PostMapping("/{id}/cancel")
    @Timed(value = "order.cancel", description = "Time taken to cancel order")
    public ResponseEntity<Order> cancelOrder(@PathVariable Long id) {
        logger.info("Received request to cancel order with ID: {}", id);
        
        try {
            Order cancelledOrder = orderService.cancelOrder(id);
            return ResponseEntity.ok(cancelledOrder);
        } catch (IllegalArgumentException e) {
            logger.warn("Order not found for cancellation: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (IllegalStateException e) {
            logger.warn("Cannot cancel order: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT).build();
        } catch (Exception e) {
            logger.error("Error cancelling order with ID {}: {}", id, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Get order statistics
     */
    @GetMapping("/stats")
    @Timed(value = "order.stats", description = "Time taken to get order statistics")
    public ResponseEntity<Map<String, Object>> getOrderStats() {
        logger.debug("Received request to get order statistics");
        
        try {
            long totalOrders = orderService.getTotalOrderCount();
            long pendingOrders = orderService.getOrderCountByStatus(Order.OrderStatus.PENDING);
            long confirmedOrders = orderService.getOrderCountByStatus(Order.OrderStatus.CONFIRMED);
            long shippedOrders = orderService.getOrderCountByStatus(Order.OrderStatus.SHIPPED);
            long deliveredOrders = orderService.getOrderCountByStatus(Order.OrderStatus.DELIVERED);
            long cancelledOrders = orderService.getOrderCountByStatus(Order.OrderStatus.CANCELLED);
            BigDecimal totalRevenue = orderService.calculateTotalRevenue();
            
            Map<String, Object> stats = Map.of(
                "totalOrders", totalOrders,
                "pendingOrders", pendingOrders,
                "confirmedOrders", confirmedOrders,
                "shippedOrders", shippedOrders,
                "deliveredOrders", deliveredOrders,
                "cancelledOrders", cancelledOrders,
                "totalRevenue", totalRevenue != null ? totalRevenue : BigDecimal.ZERO
            );
            
            return ResponseEntity.ok(stats);
        } catch (Exception e) {
            logger.error("Error retrieving order statistics: {}", e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
    
    /**
     * Get user's total order amount
     */
    @GetMapping("/user/{userId}/total")
    @Timed(value = "order.user.total", description = "Time taken to get user's total order amount")
    public ResponseEntity<Map<String, BigDecimal>> getUserTotalAmount(@PathVariable Long userId) {
        logger.debug("Received request to get total amount for user: {}", userId);
        
        try {
            BigDecimal totalAmount = orderService.calculateUserTotalAmount(userId);
            Map<String, BigDecimal> result = Map.of(
                "totalAmount", totalAmount != null ? totalAmount : BigDecimal.ZERO
            );
            return ResponseEntity.ok(result);
        } catch (Exception e) {
            logger.error("Error retrieving total amount for user {}: {}", userId, e.getMessage(), e);
            return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).build();
        }
    }
}