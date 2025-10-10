package com.umu.ads_proj.service;

import com.umu.ads_proj.event.PerformanceEvent;
import com.umu.ads_proj.event.UserEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.Acknowledgment;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;

/**
 * Service for consuming events from Kafka topics
 */
@Service
public class EventConsumerService {
    
    private static final Logger logger = LoggerFactory.getLogger(EventConsumerService.class);
    
    /**
     * Listen to user events
     */
    @KafkaListener(topics = "${app.kafka.topics.user-events}", groupId = "${spring.kafka.consumer.group-id}")
    public void handleUserEvent(
            @Payload UserEvent event,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset,
            Acknowledgment acknowledgment) {
        
        try {
            logger.info("Received user event from topic '{}' [partition={}, offset={}]: {}", 
                       topic, partition, offset, event);
            
            // Process the user event
            processUserEvent(event);
            
            // Acknowledge the message
            acknowledgment.acknowledge();
            
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
            @Header(KafkaHeaders.OFFSET) long offset,
            Acknowledgment acknowledgment) {
        
        try {
            logger.info("Received performance event from topic '{}' [partition={}, offset={}]: {}", 
                       topic, partition, offset, event);
            
            // Process the performance event
            processPerformanceEvent(event);
            
            // Acknowledge the message
            acknowledgment.acknowledge();
            
        } catch (Exception e) {
            logger.error("Error processing performance event from topic '{}': {}", topic, e.getMessage(), e);
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
                logger.info("Load test completed: {} - Throughput: {:.2f} ops/sec, Duration: {}ms", 
                           event.getTestType(), event.getThroughput(), event.getDurationMs());
                // Add any business logic for test completion events
                // For example: generate reports, send notifications, etc.
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
}