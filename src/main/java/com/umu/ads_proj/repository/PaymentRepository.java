package com.umu.ads_proj.repository;

import com.umu.ads_proj.entity.Payment;
import com.umu.ads_proj.entity.Payment.PaymentStatus;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;

import java.math.BigDecimal;
import java.util.List;
import java.util.Optional;

/**
 * Repository interface for Payment entity
 */
@Repository
public interface PaymentRepository extends JpaRepository<Payment, Long> {
    
    /**
     * Find all payments by user ID
     */
    List<Payment> findByUserId(Long userId);
    
    /**
     * Find all payments by user ID with pagination
     */
    Page<Payment> findByUserId(Long userId, Pageable pageable);
    
    /**
     * Find all payments by order ID
     */
    List<Payment> findByOrderId(Long orderId);
    
    /**
     * Find payment by order ID (assuming one payment per order)
     */
    Optional<Payment> findFirstByOrderIdOrderByCreatedAtDesc(Long orderId);
    
    /**
     * Find all payments by status
     */
    List<Payment> findByStatus(PaymentStatus status);
    
    /**
     * Find all payments by status with pagination
     */
    Page<Payment> findByStatus(PaymentStatus status, Pageable pageable);
    
    /**
     * Find payments by user and status
     */
    List<Payment> findByUserIdAndStatus(Long userId, PaymentStatus status);
    
    /**
     * Find payment by transaction ID
     */
    Optional<Payment> findByTransactionId(String transactionId);
    
    /**
     * Count payments by status
     */
    long countByStatus(PaymentStatus status);
    
    /**
     * Count payments by user
     */
    long countByUserId(Long userId);
    
    /**
     * Calculate total amount by status
     */
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.status = :status")
    BigDecimal calculateTotalAmountByStatus(@Param("status") PaymentStatus status);
    
    /**
     * Calculate total amount by user
     */
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.userId = :userId")
    BigDecimal calculateTotalAmountByUser(@Param("userId") Long userId);
    
    /**
     * Calculate total amount by user and status
     */
    @Query("SELECT COALESCE(SUM(p.amount), 0) FROM Payment p WHERE p.userId = :userId AND p.status = :status")
    BigDecimal calculateTotalAmountByUserAndStatus(@Param("userId") Long userId, @Param("status") PaymentStatus status);
    
    /**
     * Find recent payments
     */
    @Query("SELECT p FROM Payment p ORDER BY p.createdAt DESC")
    Page<Payment> findRecentPayments(Pageable pageable);
    
    /**
     * Find failed payments
     */
    @Query("SELECT p FROM Payment p WHERE p.status = 'FAILED' ORDER BY p.createdAt DESC")
    List<Payment> findFailedPayments();
    
    /**
     * Check if payment exists for order
     */
    boolean existsByOrderId(Long orderId);
}
