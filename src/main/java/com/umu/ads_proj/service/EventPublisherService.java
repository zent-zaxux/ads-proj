package com.umu.ads_proj.service;

import com.umu.ads_proj.event.BaseEvent;
import com.umu.ads_proj.event.OrderEvent;
import com.umu.ads_proj.event.PerformanceEvent;
import com.umu.ads_proj.event.UserEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.support.SendResult;
import org.springframework.stereotype.Service;

import java.util.concurrent.CompletableFuture;

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
    
    /**
     * Publish user-related events
     */
    public void publishUserEvent(UserEvent event) {
        publishEvent(userEventsTopic, event.getUserId().toString(), event);
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
     * Generic method to publish any event to a specified topic
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