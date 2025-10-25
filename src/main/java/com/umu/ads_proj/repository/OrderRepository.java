package com.umu.ads_proj.repository;

import com.umu.ads_proj.entity.Order;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;

/**
 * Repository interface for Order entity operations
 */
@Repository
public interface OrderRepository extends JpaRepository<Order, Long> {
    
    /**
     * Find orders by user ID
     */
    List<Order> findByUserId(Long userId);
    
    /**
     * Find orders by user ID with pagination
     */
    Page<Order> findByUserId(Long userId, Pageable pageable);
    
    /**
     * Find orders by status
     */
    List<Order> findByStatus(Order.OrderStatus status);
    
    /**
     * Find orders by status with pagination
     */
    Page<Order> findByStatus(Order.OrderStatus status, Pageable pageable);
    
    /**
     * Find orders by user ID and status
     */
    List<Order> findByUserIdAndStatus(Long userId, Order.OrderStatus status);
    
    /**
     * Find orders by product name (case insensitive)
     */
    List<Order> findByProductNameContainingIgnoreCase(String productName);
    
    /**
     * Find orders with total amount greater than specified value
     */
    @Query("SELECT o FROM Order o WHERE o.totalAmount > :minAmount")
    List<Order> findOrdersWithAmountGreaterThan(@Param("minAmount") BigDecimal minAmount);
    
    /**
     * Find orders by user ID with total amount greater than specified value
     */
    @Query("SELECT o FROM Order o WHERE o.userId = :userId AND o.totalAmount > :minAmount")
    List<Order> findUserOrdersWithAmountGreaterThan(@Param("userId") Long userId, 
                                                   @Param("minAmount") BigDecimal minAmount);
    
    /**
     * Count orders by status
     */
    long countByStatus(Order.OrderStatus status);
    
    /**
     * Count orders by user ID
     */
    long countByUserId(Long userId);
    
    /**
     * Check if user has any orders
     */
    boolean existsByUserId(Long userId);
    
    /**
     * Calculate total amount for user's orders
     */
    @Query("SELECT COALESCE(SUM(o.totalAmount), 0) FROM Order o WHERE o.userId = :userId")
    BigDecimal calculateTotalAmountForUser(@Param("userId") Long userId);
    
    /**
     * Calculate total amount for orders with specific status
     */
    @Query("SELECT COALESCE(SUM(o.totalAmount), 0) FROM Order o WHERE o.status = :status")
    BigDecimal calculateTotalAmountByStatus(@Param("status") Order.OrderStatus status);
    
    /**
     * Find recent orders (last N orders)
     */
    @Query("SELECT o FROM Order o ORDER BY o.createdAt DESC")
    List<Order> findRecentOrders(Pageable pageable);
    
    /**
     * Find orders by status ordered by creation date (ascending)
     * Used by FulfillmentAgent to process orders in FIFO order
     */
    List<Order> findByStatusOrderByCreatedAtAsc(Order.OrderStatus status);
}