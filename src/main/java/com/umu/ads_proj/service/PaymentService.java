package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.Order;
import com.umu.ads_proj.entity.Payment;
import com.umu.ads_proj.entity.Payment.PaymentMethod;
import com.umu.ads_proj.entity.Payment.PaymentStatus;
import com.umu.ads_proj.event.PaymentEvent;
import com.umu.ads_proj.repository.PaymentRepository;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.ThreadLocalRandom;

/**
 * Service for payment processing and management
 */
@Service
@Transactional
public class PaymentService {
    
    private static final Logger logger = LoggerFactory.getLogger(PaymentService.class);
    
    @Autowired
    private PaymentRepository paymentRepository;
    
    @Autowired
    private EventPublisherService eventPublisher;
    
    @Autowired
    private OrderService orderService;
    
    /**
     * Create a new payment for an order
     */
    @Timed(value = "payment.create", description = "Time taken to create payment")
    public Payment createPayment(Long orderId, Long userId, BigDecimal amount, PaymentMethod paymentMethod) {
        logger.info("Creating payment for order: {}, user: {}, amount: {}", orderId, userId, amount);
        
        // Validate order exists
        Optional<Order> orderOpt = orderService.getOrderById(orderId);
        if (orderOpt.isEmpty()) {
            throw new IllegalArgumentException("Order not found with ID: " + orderId);
        }
        
        Order order = orderOpt.get();
        
        // Validate order belongs to user
        if (!order.getUserId().equals(userId)) {
            throw new IllegalArgumentException("Order does not belong to user");
        }
        
        // Check if payment already exists for this order
        if (paymentRepository.existsByOrderId(orderId)) {
            throw new IllegalStateException("Payment already exists for this order");
        }
        
        // Validate amount matches order total
        if (amount.compareTo(order.getTotalAmount()) != 0) {
            throw new IllegalArgumentException("Payment amount does not match order total");
        }
        
        // Create payment
        Payment payment = new Payment(orderId, userId, amount, paymentMethod);
        payment.setPaymentGateway(determinePaymentGateway(paymentMethod));
        Payment savedPayment = paymentRepository.save(payment);
        
        // Publish payment created event
        PaymentEvent event = PaymentEvent.paymentCreated(
            savedPayment.getId(),
            orderId,
            userId,
            amount,
            paymentMethod.toString()
        );
        eventPublisher.publishPaymentEventAsync(event);
        
        logger.info("Payment created successfully: {}", savedPayment.getId());
        return savedPayment;
    }
    
    /**
     * Process a payment (simulate payment gateway processing)
     */
    @Timed(value = "payment.process", description = "Time taken to process payment")
    public Payment processPayment(Long paymentId) {
        logger.info("Processing payment: {}", paymentId);
        
        Payment payment = paymentRepository.findById(paymentId)
            .orElseThrow(() -> new IllegalArgumentException("Payment not found with ID: " + paymentId));
        
        if (payment.getStatus() != PaymentStatus.PENDING) {
            throw new IllegalStateException("Payment is not in PENDING status. Current status: " + payment.getStatus());
        }
        
        // Update to processing
        payment.setStatus(PaymentStatus.PROCESSING);
        String transactionId = generateTransactionId();
        payment.setTransactionId(transactionId);
        payment = paymentRepository.save(payment);
        
        // Publish processing event
        PaymentEvent processingEvent = PaymentEvent.paymentProcessing(
            payment.getId(),
            payment.getOrderId(),
            transactionId
        );
        eventPublisher.publishPaymentEventAsync(processingEvent);
        
        // Simulate payment gateway processing (90% success rate)
        boolean paymentSuccess = simulatePaymentGateway();
        
        if (paymentSuccess) {
            // Payment succeeded
            payment.setStatus(PaymentStatus.COMPLETED);
            payment.setProcessedAt(LocalDateTime.now());
            payment = paymentRepository.save(payment);
            
            // Publish success event
            PaymentEvent successEvent = PaymentEvent.paymentCompleted(
                payment.getId(),
                payment.getOrderId(),
                payment.getUserId(),
                payment.getAmount(),
                transactionId
            );
            eventPublisher.publishPaymentEventAsync(successEvent);
            
            // Update order status to CONFIRMED
            try {
                orderService.updateOrderStatus(payment.getOrderId(), Order.OrderStatus.CONFIRMED);
                logger.info("Order {} confirmed after successful payment", payment.getOrderId());
            } catch (Exception e) {
                logger.error("Failed to update order status after payment", e);
            }
            
            logger.info("Payment processed successfully: {}", paymentId);
        } else {
            // Payment failed
            String failureReason = "Payment declined by gateway";
            payment.setStatus(PaymentStatus.FAILED);
            payment.setFailureReason(failureReason);
            payment = paymentRepository.save(payment);
            
            // Publish failure event
            PaymentEvent failureEvent = PaymentEvent.paymentFailed(
                payment.getId(),
                payment.getOrderId(),
                failureReason
            );
            eventPublisher.publishPaymentEventAsync(failureEvent);
            
            // Cancel the order
            try {
                orderService.cancelOrder(payment.getOrderId());
                logger.info("Order {} cancelled due to payment failure", payment.getOrderId());
            } catch (Exception e) {
                logger.error("Failed to cancel order after payment failure", e);
            }
            
            logger.warn("Payment failed: {}, reason: {}", paymentId, failureReason);
        }
        
        return payment;
    }
    
    /**
     * Refund a payment
     */
    @Timed(value = "payment.refund", description = "Time taken to refund payment")
    public Payment refundPayment(Long paymentId, String reason) {
        logger.info("Refunding payment: {}, reason: {}", paymentId, reason);
        
        Payment payment = paymentRepository.findById(paymentId)
            .orElseThrow(() -> new IllegalArgumentException("Payment not found with ID: " + paymentId));
        
        if (payment.getStatus() != PaymentStatus.COMPLETED) {
            throw new IllegalStateException("Only completed payments can be refunded. Current status: " + payment.getStatus());
        }
        
        // Update to refunded
        payment.setStatus(PaymentStatus.REFUNDED);
        payment.setFailureReason(reason);
        payment = paymentRepository.save(payment);
        
        // Publish refund event
        PaymentEvent event = PaymentEvent.paymentRefunded(
            payment.getId(),
            payment.getOrderId(),
            payment.getAmount(),
            reason
        );
        eventPublisher.publishPaymentEventAsync(event);
        
        // Cancel the associated order
        try {
            orderService.cancelOrder(payment.getOrderId());
            logger.info("Order {} cancelled due to payment refund", payment.getOrderId());
        } catch (Exception e) {
            logger.error("Failed to cancel order after refund", e);
        }
        
        logger.info("Payment refunded successfully: {}", paymentId);
        return payment;
    }
    
    /**
     * Cancel a pending payment
     */
    @Timed(value = "payment.cancel", description = "Time taken to cancel payment")
    public Payment cancelPayment(Long paymentId, String reason) {
        logger.info("Cancelling payment: {}, reason: {}", paymentId, reason);
        
        Payment payment = paymentRepository.findById(paymentId)
            .orElseThrow(() -> new IllegalArgumentException("Payment not found with ID: " + paymentId));
        
        if (payment.getStatus() != PaymentStatus.PENDING) {
            throw new IllegalStateException("Only pending payments can be cancelled. Current status: " + payment.getStatus());
        }
        
        // Update to cancelled
        payment.setStatus(PaymentStatus.CANCELLED);
        payment.setFailureReason(reason);
        payment = paymentRepository.save(payment);
        
        // Publish cancellation event
        PaymentEvent event = PaymentEvent.paymentCancelled(
            payment.getId(),
            payment.getOrderId(),
            reason
        );
        eventPublisher.publishPaymentEventAsync(event);
        
        logger.info("Payment cancelled successfully: {}", paymentId);
        return payment;
    }
    
    /**
     * Get payment by ID
     */
    public Optional<Payment> getPaymentById(Long paymentId) {
        return paymentRepository.findById(paymentId);
    }
    
    /**
     * Get all payments by user
     */
    public List<Payment> getPaymentsByUser(Long userId) {
        return paymentRepository.findByUserId(userId);
    }
    
    /**
     * Get all payments by user with pagination
     */
    public Page<Payment> getPaymentsByUser(Long userId, Pageable pageable) {
        return paymentRepository.findByUserId(userId, pageable);
    }
    
    /**
     * Get payment by order ID
     */
    public Optional<Payment> getPaymentByOrderId(Long orderId) {
        return paymentRepository.findFirstByOrderIdOrderByCreatedAtDesc(orderId);
    }
    
    /**
     * Get all payments by status
     */
    public List<Payment> getPaymentsByStatus(PaymentStatus status) {
        return paymentRepository.findByStatus(status);
    }
    
    /**
     * Get all payments with pagination
     */
    public Page<Payment> getAllPayments(Pageable pageable) {
        return paymentRepository.findAll(pageable);
    }
    
    /**
     * Get payment statistics
     */
    public PaymentStatistics getPaymentStatistics() {
        PaymentStatistics stats = new PaymentStatistics();
        stats.totalPayments = paymentRepository.count();
        stats.completedPayments = paymentRepository.countByStatus(PaymentStatus.COMPLETED);
        stats.pendingPayments = paymentRepository.countByStatus(PaymentStatus.PENDING);
        stats.failedPayments = paymentRepository.countByStatus(PaymentStatus.FAILED);
        stats.totalRevenue = paymentRepository.calculateTotalAmountByStatus(PaymentStatus.COMPLETED);
        return stats;
    }
    
    /**
     * Get user payment statistics
     */
    public UserPaymentStatistics getUserPaymentStatistics(Long userId) {
        UserPaymentStatistics stats = new UserPaymentStatistics();
        stats.userId = userId;
        stats.totalPayments = paymentRepository.countByUserId(userId);
        stats.totalSpent = paymentRepository.calculateTotalAmountByUser(userId);
        stats.completedPayments = paymentRepository.findByUserIdAndStatus(userId, PaymentStatus.COMPLETED).size();
        return stats;
    }
    
    // Helper methods
    
    private String determinePaymentGateway(PaymentMethod method) {
        return switch (method) {
            case CREDIT_CARD, DEBIT_CARD -> "Stripe";
            case PAYPAL -> "PayPal";
            case BANK_TRANSFER -> "BankWire";
            case CRYPTO -> "Coinbase";
            case CASH_ON_DELIVERY -> "COD";
        };
    }
    
    private String generateTransactionId() {
        return "TXN-" + UUID.randomUUID().toString().substring(0, 8).toUpperCase();
    }
    
    private boolean simulatePaymentGateway() {
        // Simulate payment processing with 90% success rate
        return ThreadLocalRandom.current().nextDouble() < 0.9;
    }
    
    // Statistics classes
    public static class PaymentStatistics {
        public long totalPayments;
        public long completedPayments;
        public long pendingPayments;
        public long failedPayments;
        public BigDecimal totalRevenue;
    }
    
    public static class UserPaymentStatistics {
        public Long userId;
        public long totalPayments;
        public long completedPayments;
        public BigDecimal totalSpent;
    }
}
