package com.umu.ads_proj.service;

import com.umu.ads_proj.event.BaseEvent;
import com.umu.ads_proj.event.NotificationEvent;
import com.umu.ads_proj.event.OrderEvent;
import com.umu.ads_proj.event.PaymentEvent;
import com.umu.ads_proj.event.PerformanceEvent;
import com.umu.ads_proj.event.UserEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;
import java.util.concurrent.ExecutionException;

/**
 * Service for publishing events to Kafka topics
 */
@Service
public class EventPublisherService {
    
    private static final Logger logger = LoggerFactory.getLogger(EventPublisherService.class);
    
    @Autowired
    private KafkaTemplate<String, Object> kafkaTemplate;
    
    @Value("${app.kafka.topics.user-events}")
    private String userEventsTopic;
    
    @Value("${app.kafka.topics.load-events}")
    private String loadEventsTopic;
    
    @Value("${app.kafka.topics.performance-events}")
    private String performanceEventsTopic;
    
    @Value("${app.kafka.topics.order-events}")
    private String orderEventsTopic;
    
    @Value("${app.kafka.topics.payment-events}")
    private String paymentEventsTopic;
    
    @Value("${app.kafka.topics.notification-events}")
    private String notificationEventsTopic;
    
    @Value("${app.kafka.publishing.mode:async}")
    private String publishingMode;
    
    /**
     * Publish user-related events
     */
    public void publishUserEvent(UserEvent event) {
        publishEvent(userEventsTopic, event.getUserId().toString(), event);
    }
    
    /**
     * Publish user-related events asynchronously (non-blocking)
     * This method does NOT block the caller - it returns immediately
     * Runs in async- thread pool
     */
    @Async
    public CompletableFuture<Void> publishUserEventAsync(UserEvent event) {
        try {
            logger.info("[ASYNC] Publishing user event with key '{}': {}", event.getUserId(), event.getEventType());
            kafkaTemplate.send(userEventsTopic, event.getUserId().toString(), event);
        } catch (Exception e) {
            logger.error("[ASYNC] Error publishing user event: {}", e.getMessage(), e);
        }
        return CompletableFuture.completedFuture(null);
    }
    
    /**
     * Publish performance-related events
     */
    public void publishPerformanceEvent(PerformanceEvent event) {
        publishEvent(performanceEventsTopic, event.getTestType(), event);
    }
    
    /**
     * Publish order-related events
     */
    public void publishOrderEvent(OrderEvent event) {
        publishEvent(orderEventsTopic, event.getOrderId().toString(), event);
    }
    
    /**
     * Publish order-related events asynchronously (non-blocking)
     * This method does NOT block the caller - it returns immediately
     * Runs in async- thread pool
     * 
     * For performance comparison testing, this method can be toggled between:
     * - async mode: Non-blocking, returns immediately (optimized)
     * - sync mode: Blocks waiting for Kafka ACK (baseline for comparison)
     */
    @Async
    public CompletableFuture<Void> publishOrderEventAsync(OrderEvent event) {
        try {
            if ("sync".equalsIgnoreCase(publishingMode)) {
                // SYNCHRONOUS MODE (for performance comparison - simulates baseline)
                logger.info("[SYNC-MODE] Publishing order event with key '{}': {} (BLOCKING)", 
                           event.getOrderId(), event.getEventType());
                try {
                    // Block and wait for Kafka acknowledgment (simulates pre-optimization behavior)
                    kafkaTemplate.send(orderEventsTopic, event.getOrderId().toString(), event).get();
                    logger.info("[SYNC-MODE] Order event published and acknowledged: {}", event.getOrderId());
                } catch (Exception e) {
                    logger.error("[SYNC-MODE] Error waiting for Kafka ACK: {}", e.getMessage(), e);
                }
            } else {
                // ASYNCHRONOUS MODE (optimized - default)
                logger.info("[ASYNC] Publishing order event with key '{}': {}", 
                           event.getOrderId(), event.getEventType());
                kafkaTemplate.send(orderEventsTopic, event.getOrderId().toString(), event);
            }
        } catch (Exception e) {
            logger.error("Error publishing order event: {}", e.getMessage(), e);
        }
        return CompletableFuture.completedFuture(null);
    }
    
    /**
     * Publish payment-related events
     */
    public void publishPaymentEvent(PaymentEvent event) {
        publishEvent(paymentEventsTopic, event.getPaymentId().toString(), event);
    }
    
    /**
     * Publish payment-related events asynchronously (non-blocking)
     * This method does NOT block the caller - it returns immediately
     * Runs in async- thread pool
     */
    @Async
    public CompletableFuture<Void> publishPaymentEventAsync(PaymentEvent event) {
        try {
            logger.info("[ASYNC] Publishing payment event with key '{}': {}", event.getPaymentId(), event.getEventType());
            kafkaTemplate.send(paymentEventsTopic, event.getPaymentId().toString(), event);
        } catch (Exception e) {
            logger.error("[ASYNC] Error publishing payment event: {}", e.getMessage(), e);
        }
        return CompletableFuture.completedFuture(null);
    }
    
    /**
     * Publish notification-related events
     */
    public void publishNotificationEvent(NotificationEvent event) {
        String key = event.getNotificationId() != null ? 
                     event.getNotificationId().toString() : 
                     event.getOrderId().toString();
        publishEvent(notificationEventsTopic, key, event);
    }
    
    /**
     * Generic method to publish any event to a specified topic
     * WARNING: This method is SYNCHRONOUS and BLOCKS until Kafka acknowledges
     * For async publishing, use publishEventAsync() instead
     */
    public void publishEvent(String topic, String key, BaseEvent event) {
        try {
            logger.info("Publishing event to topic '{}' with key '{}': {}", topic, key, event.getEventType());
            
            CompletableFuture<SendResult<String, Object>> future = 
                kafkaTemplate.send(topic, key, event);
            
            future.whenComplete((result, ex) -> {
                if (ex == null) {
                    logger.info("Event published successfully: {} to topic '{}' with offset {}",
                               event.getEventId(), topic, result.getRecordMetadata().offset());
                } else {
                    logger.error("Failed to publish event: {} to topic '{}'", 
                               event.getEventId(), topic, ex);
                }
            });
            
        } catch (Exception e) {
            logger.error("Error publishing event to topic '{}': {}", topic, e.getMessage(), e);
        }
    }
    
    /**
     * Generic ASYNC method to publish any event to a specified topic
     * This method runs in the configured async thread pool and does NOT block the caller
     * The actual Kafka send happens in a background thread from our AsyncConfig pool
     */
    @Async  // Uses our configured thread pool (async-)
    public CompletableFuture<Void> publishEventAsync(String topic, String key, BaseEvent event) {
        try {
            logger.info("[ASYNC] Publishing event to topic '{}' with key '{}': {}", topic, key, event.getEventType());
            
            // Fire and forget - we don't wait for Kafka acknowledgment
            kafkaTemplate.send(topic, key, event)
                .whenComplete((result, ex) -> {
                    if (ex == null) {
                        logger.info("[ASYNC] Event published successfully: {} to topic '{}' with offset {}",
                                   event.getEventId(), topic, result.getRecordMetadata().offset());
                    } else {
                        logger.error("[ASYNC] Failed to publish event: {} to topic '{}'", 
                                   event.getEventId(), topic, ex);
                    }
                });
            
        } catch (Exception e) {
            logger.error("[ASYNC] Error publishing event to topic '{}': {}", topic, e.getMessage(), e);
        }
        
        return CompletableFuture.completedFuture(null);
    }
    
    /**
     * Publish a simple message event (for testing)
     */
    public void publishTestMessage(String topic, String message) {
        try {
            logger.info("Publishing test message to topic '{}': {}", topic, message);
            
            CompletableFuture<SendResult<String, Object>> future = 
                kafkaTemplate.send(topic, "test-key", message);
            
            future.whenComplete((result, ex) -> {
                if (ex == null) {
                    logger.info("Test message published successfully to topic '{}' with offset {}",
                               topic, result.getRecordMetadata().offset());
                } else {
                    logger.error("Failed to publish test message to topic '{}'", topic, ex);
                }
            });
            
        } catch (Exception e) {
            logger.error("Error publishing test message to topic '{}': {}", topic, e.getMessage(), e);
        }
    }
}