package com.umu.ads_proj.service;

import com.umu.ads_proj.entity.Notification;
import com.umu.ads_proj.entity.ProcessedEvent;
import com.umu.ads_proj.event.OrderEvent;
import com.umu.ads_proj.event.PaymentEvent;
import com.umu.ads_proj.repository.ProcessedEventRepository;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.kafka.annotation.KafkaListener;
import org.springframework.kafka.support.KafkaHeaders;
import org.springframework.messaging.handler.annotation.Header;
import org.springframework.messaging.handler.annotation.Payload;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Notification Consumer Service with idempotency support
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
    
    @Autowired
    private ProcessedEventRepository processedEventRepository;
    
    /**
     * Listen to order events with SEPARATE consumer group: notification-group
     * WITH IDEMPOTENCY CHECK
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
    @Transactional
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
            
            // ✅ IDEMPOTENCY CHECK - Skip if already processed
            if (event.getEventId() != null && processedEventRepository.existsByEventId(event.getEventId())) {
                logger.info("⚠️  DUPLICATE EVENT DETECTED - Already processed");
                logger.info("   EventID: {}", event.getEventId());
                logger.info("   Skipping notification to prevent duplicates");
                logger.info("═══════════════════════════════════════════════════════════\n");
                return; // Exit early - don't reprocess
            }
            
            logger.info("═══════════════════════════════════════════════════════════");
            
            // Process the order event
            Notification notification = notificationService.processOrderEvent(event);
            
            if (notification != null) {
                logger.info("✅ Notification created and sent: ID = {}, Type = {}", 
                           notification.getId(), notification.getType());
                
                // Mark event as processed (within same transaction as notification creation)
                if (event.getEventId() != null) {
                    ProcessedEvent processed = new ProcessedEvent(
                        event.getEventId(),
                        "ORDER_" + event.getAction(),
                        "notification-group",
                        event.getOrderId() != null ? event.getOrderId().toString() : null
                    );
                    processedEventRepository.save(processed);
                    logger.info("✓ Event marked as processed: {}", event.getEventId());
                }
            } else {
                logger.info("⏭️  No notification sent (non-notifiable action)");
            }
            
            logger.info("═══════════════════════════════════════════════════════════\n");
            
        } catch (Exception e) {
            logger.error("❌ ERROR processing order event in Notification Consumer", e);
            logger.error("   Event ID: {}, Order ID: {}", event.getEventId(), event.getOrderId());
            logger.error("   Error: {}", e.getMessage());
            logger.error("═══════════════════════════════════════════════════════════\n");
            
            // Rethrow to trigger Kafka redelivery
            throw e;
        }
    }
    
    /**
     * Listen to payment events with SEPARATE consumer group: notification-group
     * WITH IDEMPOTENCY CHECK
     * 
     * This consumer handles both payment success and failure events
     * and sends appropriate notifications to users
     */
    @KafkaListener(
        topics = "${app.kafka.topics.payment-events}",
        groupId = "notification-group",
        containerFactory = "kafkaListenerContainerFactory"
    )
    @Transactional
    public void consumePaymentEvent(
            @Payload PaymentEvent event,
            @Header(KafkaHeaders.RECEIVED_TOPIC) String topic,
            @Header(KafkaHeaders.RECEIVED_KEY) String key,
            @Header(KafkaHeaders.RECEIVED_PARTITION) int partition,
            @Header(KafkaHeaders.OFFSET) long offset
    ) {
        
        try {
            logger.info("═══════════════════════════════════════════════════════════");
            logger.info("💳 NOTIFICATION CONSUMER: Received payment event");
            logger.info("   Topic: {}, Partition: {}, Offset: {}", topic, partition, offset);
            logger.info("   Event ID: {}", event.getEventId());
            logger.info("   Payment Action: {}", event.getAction());
            logger.info("   Payment ID: {}, Order ID: {}, User ID: {}", 
                       event.getPaymentId(), event.getOrderId(), event.getUserId());
            
            // ✅ IDEMPOTENCY CHECK - Skip if already processed
            if (event.getEventId() != null && processedEventRepository.existsByEventId(event.getEventId())) {
                logger.info("⚠️  DUPLICATE EVENT DETECTED - Already processed");
                logger.info("   EventID: {}", event.getEventId());
                logger.info("   Skipping notification to prevent duplicates");
                logger.info("═══════════════════════════════════════════════════════════\n");
                return;
            }
            
            logger.info("═══════════════════════════════════════════════════════════");
            
            // Process payment event and send notification
            Notification notification = notificationService.processPaymentEvent(event);
            
            if (notification != null) {
                logger.info("✅ Payment notification created and sent: ID = {}, Type = {}", 
                           notification.getId(), notification.getType());
                
                // Mark event as processed
                if (event.getEventId() != null) {
                    ProcessedEvent processed = new ProcessedEvent(
                        event.getEventId(),
                        "PAYMENT_" + event.getAction(),
                        "notification-group",
                        event.getPaymentId() != null ? event.getPaymentId().toString() : null
                    );
                    processedEventRepository.save(processed);
                    logger.info("✓ Event marked as processed: {}", event.getEventId());
                }
            } else {
                logger.info("⏭️  No notification sent (non-notifiable action)");
            }
            
            logger.info("═══════════════════════════════════════════════════════════\n");
            
        } catch (Exception e) {
            logger.error("❌ ERROR processing payment event in Notification Consumer", e);
            logger.error("   Event ID: {}, Payment ID: {}", event.getEventId(), event.getPaymentId());
            logger.error("   Error: {}", e.getMessage());
            logger.error("═══════════════════════════════════════════════════════════\n");
            
            // Rethrow to trigger Kafka redelivery
            throw e;
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
