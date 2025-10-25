package com.umu.ads_proj.controller;

import com.umu.ads_proj.entity.Payment;
import com.umu.ads_proj.entity.Payment.PaymentMethod;
import com.umu.ads_proj.entity.Payment.PaymentStatus;
import com.umu.ads_proj.service.PaymentService;
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
 * REST Controller for Payment Service
 */
@RestController
@RequestMapping("/api/payments")
public class PaymentController {
    
    private static final Logger logger = LoggerFactory.getLogger(PaymentController.class);
    
    @Autowired
    private PaymentService paymentService;
    
    /**
     * Health check endpoint
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> healthCheck() {
        return ResponseEntity.ok(Map.of(
            "service", "Payment Service",
            "status", "UP",
            "timestamp", java.time.LocalDateTime.now().toString()
        ));
    }
    
    /**
     * Create a new payment
     */
    @PostMapping
    @Timed(value = "api.payment.create", description = "Time taken to create payment via API")
    public ResponseEntity<?> createPayment(@RequestBody PaymentRequest request) {
        try {
            logger.info("Creating payment for order: {}", request.getOrderId());
            
            Payment payment = paymentService.createPayment(
                request.getOrderId(),
                request.getUserId(),
                request.getAmount(),
                request.getPaymentMethod()
            );
            
            return ResponseEntity.status(HttpStatus.CREATED).body(payment);
        } catch (IllegalArgumentException e) {
            logger.error("Invalid payment request: {}", e.getMessage());
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (IllegalStateException e) {
            logger.error("Payment already exists: {}", e.getMessage());
            return ResponseEntity.status(HttpStatus.CONFLICT).body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error creating payment", e);
            return ResponseEntity.internalServerError().body(Map.of("error", "Failed to create payment"));
        }
    }
    
    /**
     * Process a payment
     */
    @PostMapping("/{paymentId}/process")
    @Timed(value = "api.payment.process", description = "Time taken to process payment via API")
    public ResponseEntity<?> processPayment(@PathVariable Long paymentId) {
        try {
            logger.info("Processing payment: {}", paymentId);
            
            Payment payment = paymentService.processPayment(paymentId);
            
            return ResponseEntity.ok(payment);
        } catch (IllegalArgumentException e) {
            logger.error("Payment not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (IllegalStateException e) {
            logger.error("Invalid payment status: {}", e.getMessage());
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error processing payment", e);
            return ResponseEntity.internalServerError().body(Map.of("error", "Failed to process payment"));
        }
    }
    
    /**
     * Refund a payment
     */
    @PostMapping("/{paymentId}/refund")
    @Timed(value = "api.payment.refund", description = "Time taken to refund payment via API")
    public ResponseEntity<?> refundPayment(
            @PathVariable Long paymentId,
            @RequestParam(required = false, defaultValue = "Customer request") String reason) {
        try {
            logger.info("Refunding payment: {}, reason: {}", paymentId, reason);
            
            Payment payment = paymentService.refundPayment(paymentId, reason);
            
            return ResponseEntity.ok(payment);
        } catch (IllegalArgumentException e) {
            logger.error("Payment not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (IllegalStateException e) {
            logger.error("Invalid payment status for refund: {}", e.getMessage());
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error refunding payment", e);
            return ResponseEntity.internalServerError().body(Map.of("error", "Failed to refund payment"));
        }
    }
    
    /**
     * Cancel a pending payment
     */
    @PostMapping("/{paymentId}/cancel")
    @Timed(value = "api.payment.cancel", description = "Time taken to cancel payment via API")
    public ResponseEntity<?> cancelPayment(
            @PathVariable Long paymentId,
            @RequestParam(required = false, defaultValue = "User cancelled") String reason) {
        try {
            logger.info("Cancelling payment: {}, reason: {}", paymentId, reason);
            
            Payment payment = paymentService.cancelPayment(paymentId, reason);
            
            return ResponseEntity.ok(payment);
        } catch (IllegalArgumentException e) {
            logger.error("Payment not found: {}", e.getMessage());
            return ResponseEntity.notFound().build();
        } catch (IllegalStateException e) {
            logger.error("Invalid payment status for cancellation: {}", e.getMessage());
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        } catch (Exception e) {
            logger.error("Error cancelling payment", e);
            return ResponseEntity.internalServerError().body(Map.of("error", "Failed to cancel payment"));
        }
    }
    
    /**
     * Get payment by ID
     */
    @GetMapping("/{paymentId}")
    @Timed(value = "api.payment.get", description = "Time taken to get payment by ID")
    public ResponseEntity<?> getPayment(@PathVariable Long paymentId) {
        logger.info("Fetching payment: {}", paymentId);
        
        Optional<Payment> payment = paymentService.getPaymentById(paymentId);
        
        return payment.map(ResponseEntity::ok)
                     .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Get all payments with pagination
     */
    @GetMapping
    @Timed(value = "api.payment.list", description = "Time taken to list payments")
    public ResponseEntity<Page<Payment>> getAllPayments(
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "20") int size,
            @RequestParam(defaultValue = "createdAt") String sortBy,
            @RequestParam(defaultValue = "DESC") String sortDirection) {
        
        logger.info("Fetching all payments - page: {}, size: {}", page, size);
        
        Sort sort = sortDirection.equalsIgnoreCase("ASC") ? 
                   Sort.by(sortBy).ascending() : Sort.by(sortBy).descending();
        Pageable pageable = PageRequest.of(page, size, sort);
        
        Page<Payment> payments = paymentService.getAllPayments(pageable);
        
        return ResponseEntity.ok(payments);
    }
    
    /**
     * Get payments by user ID
     */
    @GetMapping("/user/{userId}")
    @Timed(value = "api.payment.by.user", description = "Time taken to get payments by user")
    public ResponseEntity<List<Payment>> getPaymentsByUser(@PathVariable Long userId) {
        logger.info("Fetching payments for user: {}", userId);
        
        List<Payment> payments = paymentService.getPaymentsByUser(userId);
        
        return ResponseEntity.ok(payments);
    }
    
    /**
     * Get payment by order ID
     */
    @GetMapping("/order/{orderId}")
    @Timed(value = "api.payment.by.order", description = "Time taken to get payment by order")
    public ResponseEntity<?> getPaymentByOrder(@PathVariable Long orderId) {
        logger.info("Fetching payment for order: {}", orderId);
        
        Optional<Payment> payment = paymentService.getPaymentByOrderId(orderId);
        
        return payment.map(ResponseEntity::ok)
                     .orElse(ResponseEntity.notFound().build());
    }
    
    /**
     * Get payments by status
     */
    @GetMapping("/status/{status}")
    @Timed(value = "api.payment.by.status", description = "Time taken to get payments by status")
    public ResponseEntity<List<Payment>> getPaymentsByStatus(@PathVariable PaymentStatus status) {
        logger.info("Fetching payments with status: {}", status);
        
        List<Payment> payments = paymentService.getPaymentsByStatus(status);
        
        return ResponseEntity.ok(payments);
    }
    
    /**
     * Get payment statistics
     */
    @GetMapping("/stats")
    @Timed(value = "api.payment.stats", description = "Time taken to get payment statistics")
    public ResponseEntity<PaymentService.PaymentStatistics> getPaymentStatistics() {
        logger.info("Fetching payment statistics");
        
        PaymentService.PaymentStatistics stats = paymentService.getPaymentStatistics();
        
        return ResponseEntity.ok(stats);
    }
    
    /**
     * Get user payment statistics
     */
    @GetMapping("/stats/user/{userId}")
    @Timed(value = "api.payment.stats.user", description = "Time taken to get user payment statistics")
    public ResponseEntity<PaymentService.UserPaymentStatistics> getUserPaymentStatistics(@PathVariable Long userId) {
        logger.info("Fetching payment statistics for user: {}", userId);
        
        PaymentService.UserPaymentStatistics stats = paymentService.getUserPaymentStatistics(userId);
        
        return ResponseEntity.ok(stats);
    }
    
    // Request DTO
    public static class PaymentRequest {
        private Long orderId;
        private Long userId;
        private BigDecimal amount;
        private PaymentMethod paymentMethod;
        
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
        
        public BigDecimal getAmount() {
            return amount;
        }
        
        public void setAmount(BigDecimal amount) {
            this.amount = amount;
        }
        
        public PaymentMethod getPaymentMethod() {
            return paymentMethod;
        }
        
        public void setPaymentMethod(PaymentMethod paymentMethod) {
            this.paymentMethod = paymentMethod;
        }
    }
}
