package com.umu.ads_proj.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.umu.ads_proj.entity.Payment.PaymentMethod;
import com.umu.ads_proj.entity.ProcessedEvent;
import com.umu.ads_proj.event.OrderEvent;
import com.umu.ads_proj.event.PaymentEvent;
import com.umu.ads_proj.event.PerformanceEvent;
import com.umu.ads_proj.event.UserEvent;
import com.umu.ads_proj.repository.ProcessedEventRepository;

/**
 * Service for consuming events from Kafka topics with idempotency support
 */
@Service
public class EventConsumerService {
    
    private static final Logger logger = LoggerFactory.getLogger(EventConsumerService.class);
    
    @Autowired
    private PaymentService paymentService;
    
    @Autowired
    private ProcessedEventRepository processedEventRepository;
    
    /**
     * Listen to user events
     */
    @KafkaListener(topics = "${app.kafka.topics.user-events}", groupId = "${spring.kafka.consumer.group-id}")
    public void handleUserEvent(
            @Payload UserEvent event,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset
            ) {
        
        try {
            logger.info("Received user event from topic '{}' [partition={}, offset={}]: {}", 
                       topic, partition, offset, event);
            
            // Process the user event
            processUserEvent(event);
            
            // Acknowledge the message
            // acknowledgment.acknowledge();
            
        } catch (Exception e) {
            logger.error("Error processing user event from topic '{}': {}", topic, e.getMessage(), e);
            // In production, you might want to send to a dead letter queue
        }
    }
    
    /**
     * Listen to performance events
     */
    @KafkaListener(topics = "${app.kafka.topics.performance-events}", groupId = "${spring.kafka.consumer.group-id}")
    public void handlePerformanceEvent(
            @Payload PerformanceEvent event,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset
            ) {
        
        try {
            logger.info("Received performance event from topic '{}' [partition={}, offset={}]: {}", 
                       topic, partition, offset, event);
            
            // Process the performance event
            processPerformanceEvent(event);
            
            // Acknowledge the message
            // acknowledgment.acknowledge();
            
        } catch (Exception e) {
            logger.error("Error processing performance event from topic '{}': {}", topic, e.getMessage(), e);
        }
    }
    
    /**
     * Listen to order events with idempotency
     */
    @KafkaListener(topics = "${app.kafka.topics.order-events}", groupId = "${spring.kafka.consumer.group-id}")
    @Transactional
    public void handleOrderEvent(
            @Payload OrderEvent event,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset
) {
        
        try {
            // Check for idempotency - has this event already been processed?
            if (event.getEventId() != null && processedEventRepository.existsByEventId(event.getEventId())) {
                logger.info("⚠️  Duplicate event detected and skipped - EventID: {} (Order #{})", 
                           event.getEventId(), event.getOrderId());
                return; // Skip duplicate processing
            }
            
            logger.info("Received order event from topic '{}' [partition={}, offset={}]: {}", 
                       topic, partition, offset, event);
            
            // Process the order event
            processOrderEvent(event);
            
            // Mark event as processed (within same transaction)
            if (event.getEventId() != null) {
                ProcessedEvent processed = new ProcessedEvent(
                    event.getEventId(),
                    "ORDER_" + event.getAction(),
                    "event-consumer-service",
                    event.getOrderId() != null ? event.getOrderId().toString() : null
                );
                processedEventRepository.save(processed);
                logger.debug("✓ Event marked as processed: {}", event.getEventId());
            }
            
            // Acknowledge the message
            // acknowledgment.acknowledge();
            
        } catch (Exception e) {
            logger.error("Error processing order event from topic '{}': {}", topic, e.getMessage(), e);
            throw e; // Rethrow to trigger Kafka redelivery
        }
    }
    
    /**
     * Listen to payment events
     */
    @KafkaListener(topics = "${app.kafka.topics.payment-events}", groupId = "${spring.kafka.consumer.group-id}")
    public void handlePaymentEvent(
            @Payload PaymentEvent event,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset
) {
        
        try {
            logger.info("Received payment event from topic '{}' [partition={}, offset={}]: {}", 
                       topic, partition, offset, event);
            
            // Process the payment event
            processPaymentEvent(event);
            
            // Acknowledge the message
            // acknowledgment.acknowledge();
            
        } catch (Exception e) {
            logger.error("Error processing payment event from topic '{}': {}", topic, e.getMessage(), e);
        }
    }
    
    /**
     * Process user events based on action type
     */
    private void processUserEvent(UserEvent event) {
        switch (event.getAction()) {
            case CREATED:
                logger.info("Processing user creation: {} ({})", event.getUserName(), event.getUserEmail());
                // Add any business logic for user creation events
                // For example: send welcome email, update analytics, etc.
                break;
                
            case UPDATED:
                logger.info("Processing user update: {} ({})", event.getUserName(), event.getUserEmail());
                // Add any business logic for user update events
                break;
                
            case DELETED:
                logger.info("Processing user deletion: {} ({})", event.getUserName(), event.getUserEmail());
                // Add any business logic for user deletion events
                // For example: cleanup related data, send farewell email, etc.
                break;
                
            default:
                logger.warn("Unknown user action: {}", event.getAction());
        }
    }
    
    /**
     * Process performance events based on action type
     */
    private void processPerformanceEvent(PerformanceEvent event) {
        switch (event.getAction()) {
            case LOAD_TEST_STARTED:
                logger.info("Load test started: {} with {} operations", 
                           event.getTestType(), event.getNumberOfOperations());
                // Add any business logic for test start events
                // For example: prepare monitoring, allocate resources, etc.
                break;
                
            case LOAD_TEST_COMPLETED:
                logger.info("Load test completed: {} - Throughput: {} ops/sec, Duration: {}ms", 
                    event.getTestType(),
                    String.format("%.2f", event.getThroughput()),
                    event.getDurationMs());
                break;
                
            case PERFORMANCE_DEGRADATION:
                logger.warn("Performance degradation detected: {}", event.getDetails());
                // Add any business logic for performance issues
                // For example: trigger alerts, scale resources, etc.
                break;
                
            case SYSTEM_HEALTHY:
                logger.info("System performance is healthy: {}", event.getDetails());
                break;
                
            default:
                logger.warn("Unknown performance action: {}", event.getAction());
        }
    }
    
    /**
     * Process order events based on action type
     */
    private void processOrderEvent(OrderEvent event) {
        switch (event.getAction()) {
            case CREATED:
                logger.info("Processing order creation: Order #{} for user {} - {} x{} = ${}", 
                           event.getOrderId(), event.getUserId(), event.getProductName(), 
                           event.getQuantity(), event.getTotalAmount());
                
                // Auto-create payment when order is created
                try {
                    paymentService.createPayment(
                        event.getOrderId(), 
                        event.getUserId(), 
                        event.getTotalAmount(), 
                        PaymentMethod.CREDIT_CARD  // Default payment method
                    );
                    logger.info("✓ Payment auto-created for order #{}", event.getOrderId());
                } catch (Exception e) {
                    logger.error("Failed to auto-create payment for order #{}: {}", 
                                event.getOrderId(), e.getMessage());
                }
                break;
                
            case UPDATED:
                logger.info("Processing order update: Order #{} for user {} - {} x{} = ${}", 
                           event.getOrderId(), event.getUserId(), event.getProductName(), 
                           event.getQuantity(), event.getTotalAmount());
                // Add any business logic for order update events
                // For example: inventory adjustment, price recalculation, etc.
                break;
                
            case CONFIRMED:
                logger.info("Processing order confirmation: Order #{} confirmed for user {}", 
                           event.getOrderId(), event.getUserId());
                // Add any business logic for order confirmation events
                // For example: payment processing, inventory reservation, etc.
                break;
                
            case SHIPPED:
                logger.info("Processing order shipment: Order #{} shipped for user {}", 
                           event.getOrderId(), event.getUserId());
                // Add any business logic for order shipment events
                // For example: tracking number generation, customer notification, etc.
                break;
                
            case DELIVERED:
                logger.info("Processing order delivery: Order #{} delivered to user {}", 
                           event.getOrderId(), event.getUserId());
                // Add any business logic for order delivery events
                // For example: customer satisfaction survey, inventory update, etc.
                break;
                
            case CANCELLED:
                logger.info("Processing order cancellation: Order #{} cancelled for user {}", 
                           event.getOrderId(), event.getUserId());
                // Add any business logic for order cancellation events
                // For example: refund processing, inventory release, etc.
                break;
                
            default:
                logger.warn("Unknown order action: {}", event.getAction());
        }
    }
    
    /**
     * Process payment events based on action type
     */
    private void processPaymentEvent(PaymentEvent event) {
        switch (event.getAction()) {
            case PAYMENT_CREATED:
                logger.info("Processing payment creation: Payment #{} for order #{}, user {} - Amount: ${}", 
                           event.getPaymentId(), event.getOrderId(), event.getUserId(), event.getAmount());
                // Add any business logic for payment creation events
                // For example: fraud detection, risk assessment, etc.
                break;
                
            case PAYMENT_PROCESSING:
                logger.info("Processing payment: Payment #{} for order #{} - Transaction: {}", 
                           event.getPaymentId(), event.getOrderId(), event.getTransactionId());
                // Add any business logic for payment processing events
                // For example: update payment gateway status, notify customer, etc.
                break;
                
            case PAYMENT_COMPLETED:
                logger.info("Payment completed: Payment #{} for order #{}, user {} - Amount: ${}, Transaction: {}", 
                           event.getPaymentId(), event.getOrderId(), event.getUserId(), 
                           event.getAmount(), event.getTransactionId());
                // Add any business logic for successful payment events
                // For example: send receipt, update inventory, trigger order fulfillment, etc.
                break;
                
            case PAYMENT_FAILED:
                logger.warn("Payment failed: Payment #{} for order #{} - Reason: {}", 
                           event.getPaymentId(), event.getOrderId(), event.getFailureReason());
                // Add any business logic for failed payment events
                // For example: notify customer, suggest alternative payment methods, cancel order, etc.
                break;
                
            case PAYMENT_REFUNDED:
                logger.info("Payment refunded: Payment #{} for order #{} - Amount: ${}, Reason: {}", 
                           event.getPaymentId(), event.getOrderId(), event.getAmount(), event.getFailureReason());
                // Add any business logic for refund events
                // For example: update accounting, notify customer, trigger return process, etc.
                break;
                
            case PAYMENT_CANCELLED:
                logger.info("Payment cancelled: Payment #{} for order #{} - Reason: {}", 
                           event.getPaymentId(), event.getOrderId(), event.getFailureReason());
                // Add any business logic for cancelled payment events
                // For example: release payment authorization, notify customer, etc.
                break;
                
            default:
                logger.warn("Unknown payment action: {}", event.getAction());
        }
    }
}