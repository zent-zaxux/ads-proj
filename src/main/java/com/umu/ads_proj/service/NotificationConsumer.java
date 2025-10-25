package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.Notification;
import com.umu.ads_proj.event.OrderEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;

/**
 * Notification Consumer Service
 * 
 * IMPORTANT: This consumer uses a SEPARATE consumer group (notification-group)
 * This is different from the main EventConsumerService which uses (ads-proj-group)
 * 
 * This allows the Notification Service to consume order events independently
 * without competing with other consumers.
 */
@Service
public class NotificationConsumer {
    
    private static final Logger logger = LoggerFactory.getLogger(NotificationConsumer.class);
    
    @Autowired
    private NotificationService notificationService;
    
    /**
     * Listen to order events with SEPARATE consumer group: notification-group
     * 
     * This is the KEY to having multiple independent services consuming the same topic.
     * The notification-group will track its own offsets independently from ads-proj-group.
     * 
     * Benefits:
     * - Notification Service can process events at its own pace
     * - Idempotency prevents duplicate notifications
     * - Can pause/resume this consumer without affecting other services
     * - Demonstrates proper microservice architecture
     */
    @KafkaListener(
        topics = "${app.kafka.topics.order-events}",
        groupId = "notification-group",  // SEPARATE CONSUMER GROUP!
        containerFactory = "kafkaListenerContainerFactory"
    )
    public void consumeOrderEvent(
            @Payload OrderEvent event,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset
    ) {
        
        try {
            logger.info("═══════════════════════════════════════════════════════════");
            logger.info("📩 NOTIFICATION CONSUMER: Received order event");
            logger.info("   Topic: {}, Partition: {}, Offset: {}", topic, partition, offset);
            logger.info("   Event ID: {}", event.getEventId());
            logger.info("   Order Action: {}", event.getAction());
            logger.info("   Order ID: {}, User ID: {}", event.getOrderId(), event.getUserId());
            logger.info("═══════════════════════════════════════════════════════════");
            
            // Process the order event with idempotency check
            Notification notification = notificationService.processOrderEvent(event);
            
            if (notification != null) {
                logger.info("✅ Notification created and sent: ID = {}, Type = {}", 
                           notification.getId(), notification.getType());
            } else {
                logger.info("⏭️  No notification sent (duplicate event or non-notifiable action)");
            }
            
            logger.info("═══════════════════════════════════════════════════════════\n");
            
        } catch (Exception e) {
            logger.error("❌ ERROR processing order event in Notification Consumer", e);
            logger.error("   Event ID: {}, Order ID: {}", event.getEventId(), event.getOrderId());
            logger.error("   Error: {}", e.getMessage());
            logger.error("═══════════════════════════════════════════════════════════\n");
            
            // In production, you might want to:
            // 1. Send to dead letter queue (DLQ)
            // 2. Retry with exponential backoff
            // 3. Alert monitoring system
            // For now, we log and continue
        }
    }
    
    /**
     * Health check method
     */
    public boolean isHealthy() {
        return true;
    }
    
    /**
     * Get consumer group ID
     */
    public String getConsumerGroup() {
        return "notification-group";
    }
}
