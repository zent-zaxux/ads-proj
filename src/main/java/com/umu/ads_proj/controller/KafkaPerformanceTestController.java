package com.umu.ads_proj.controller;

import com.umu.ads_proj.event.OrderEvent;
import com.umu.ads_proj.service.EventPublisherService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Map;
import java.util.UUID;

/**
 * Controller for isolated Kafka performance testing
 * Provides endpoints that publish to Kafka WITHOUT database operations
 * to measure pure Kafka publishing performance
 */
@RestController
@RequestMapping("/api/test")
public class KafkaPerformanceTestController {

    private static final Logger logger = LoggerFactory.getLogger(KafkaPerformanceTestController.class);

    @Autowired
    private EventPublisherService eventPublisher;

    /**
     * Test endpoint that ONLY publishes to Kafka (no database operations)
     * This isolates Kafka publishing performance to measure sync vs async difference
     */
    @PostMapping("/kafka-only")
    public ResponseEntity<Map<String, Object>> testKafkaPublishingOnly(@RequestBody Map<String, Object> request) {
        try {
            long startTime = System.currentTimeMillis();
            
            // Extract test parameters
            Long testId = request.get("testId") != null ? 
                         Long.valueOf(request.get("testId").toString()) : 
                         System.currentTimeMillis();
            String message = request.get("message") != null ? 
                            request.get("message").toString() : 
                            "Test message";
            
            // Create a test OrderEvent (no actual order in database)
            OrderEvent testEvent = new OrderEvent();
            testEvent.setEventId(UUID.randomUUID().toString());
            testEvent.setEventType("TEST_ORDER_EVENT");
            testEvent.setOrderId(testId);
            testEvent.setUserId(testId);
            testEvent.setProductName("Test Product - " + message);
            testEvent.setQuantity(1);
            testEvent.setTotalAmount(BigDecimal.valueOf(10.0));
            testEvent.setOrderStatus("TEST");
            testEvent.setAction(OrderEvent.OrderAction.CREATED);
            testEvent.setDetails("Kafka performance test message");
            testEvent.setTimestamp(LocalDateTime.now());
            
            // Publish to Kafka using async method (respects publishing mode setting)
            // This is the ONLY operation - no database involved
            eventPublisher.publishOrderEventAsync(testEvent);
            
            long endTime = System.currentTimeMillis();
            long kafkaPublishTime = endTime - startTime;
            
            logger.info("Kafka-only test completed in {}ms for testId: {}", kafkaPublishTime, testId);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "testId", testId,
                "message", "Kafka publish completed",
                "publishTimeMs", kafkaPublishTime,
                "timestamp", LocalDateTime.now().toString()
            ));
            
        } catch (Exception e) {
            logger.error("Error in Kafka-only test: {}", e.getMessage(), e);
            return ResponseEntity.internalServerError().body(Map.of(
                "success", false,
                "error", e.getMessage()
            ));
        }
    }

    /**
     * Batch test endpoint for higher throughput testing
     */
    @PostMapping("/kafka-batch")
    public ResponseEntity<Map<String, Object>> testKafkaBatch(
            @RequestParam(defaultValue = "100") int batchSize) {
        try {
            long startTime = System.currentTimeMillis();
            int successCount = 0;
            
            for (int i = 0; i < batchSize; i++) {
                OrderEvent testEvent = new OrderEvent();
                testEvent.setEventId(UUID.randomUUID().toString());
                testEvent.setEventType("TEST_BATCH_EVENT");
                testEvent.setOrderId((long) i);
                testEvent.setUserId((long) i);
                testEvent.setProductName("Batch Test Product " + i);
                testEvent.setQuantity(1);
                testEvent.setTotalAmount(BigDecimal.valueOf(10.0));
                testEvent.setOrderStatus("TEST");
                testEvent.setAction(OrderEvent.OrderAction.CREATED);
                testEvent.setDetails("Batch test event " + i);
                testEvent.setTimestamp(LocalDateTime.now());
                
                eventPublisher.publishOrderEventAsync(testEvent);
                successCount++;
            }
            
            long endTime = System.currentTimeMillis();
            long totalTime = endTime - startTime;
            double avgTimePerMessage = (double) totalTime / batchSize;
            double throughput = (batchSize * 1000.0) / totalTime;
            
            logger.info("Kafka batch test: {} messages in {}ms (avg: {}ms/msg, throughput: {} msg/s)", 
                       batchSize, totalTime, avgTimePerMessage, throughput);
            
            return ResponseEntity.ok(Map.of(
                "success", true,
                "batchSize", batchSize,
                "successCount", successCount,
                "totalTimeMs", totalTime,
                "avgTimePerMessageMs", avgTimePerMessage,
                "throughputMsgPerSec", throughput,
                "timestamp", LocalDateTime.now().toString()
            ));
            
        } catch (Exception e) {
            logger.error("Error in Kafka batch test: {}", e.getMessage(), e);
            return ResponseEntity.internalServerError().body(Map.of(
                "success", false,
                "error", e.getMessage()
            ));
        }
    }

    /**
     * Health check for test controller
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, String>> health() {
        return ResponseEntity.ok(Map.of(
            "status", "UP",
            "controller", "KafkaPerformanceTestController",
            "timestamp", LocalDateTime.now().toString()
        ));
    }
}
