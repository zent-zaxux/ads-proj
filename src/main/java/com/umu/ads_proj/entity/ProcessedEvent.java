package com.umu.ads_proj.entity;

import jakarta.persistence.*;
import java.time.LocalDateTime;

/**
 * Entity to track processed events for idempotency
 * Ensures that duplicate Kafka messages are not processed twice
 */
@Entity
@Table(name = "processed_events", 
       indexes = @Index(name = "idx_event_id", columnList = "eventId", unique = true))
public class ProcessedEvent {
    
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    
    @Column(unique = true, nullable = false, length = 255)
    private String eventId;
    
    @Column(nullable = false, length = 100)
    private String eventType;
    
    @Column(length = 100)
    private String consumerGroup;
    
    @Column(nullable = false)
    private LocalDateTime processedAt;
    
    @Column(length = 500)
    private String aggregateId;  // orderId, paymentId, etc.
    
    public ProcessedEvent() {
        this.processedAt = LocalDateTime.now();
    }
    
    public ProcessedEvent(String eventId, String eventType, String consumerGroup) {
        this();
        this.eventId = eventId;
        this.eventType = eventType;
        this.consumerGroup = consumerGroup;
    }
    
    public ProcessedEvent(String eventId, String eventType, String consumerGroup, String aggregateId) {
        this(eventId, eventType, consumerGroup);
        this.aggregateId = aggregateId;
    }
    
    // Getters and Setters
    public Long getId() {
        return id;
    }
    
    public void setId(Long id) {
        this.id = id;
    }
    
    public String getEventId() {
        return eventId;
    }
    
    public void setEventId(String eventId) {
        this.eventId = eventId;
    }
    
    public String getEventType() {
        return eventType;
    }
    
    public void setEventType(String eventType) {
        this.eventType = eventType;
    }
    
    public String getConsumerGroup() {
        return consumerGroup;
    }
    
    public void setConsumerGroup(String consumerGroup) {
        this.consumerGroup = consumerGroup;
    }
    
    public LocalDateTime getProcessedAt() {
        return processedAt;
    }
    
    public void setProcessedAt(LocalDateTime processedAt) {
        this.processedAt = processedAt;
    }
    
    public String getAggregateId() {
        return aggregateId;
    }
    
    public void setAggregateId(String aggregateId) {
        this.aggregateId = aggregateId;
    }
    
    @Override
    public String toString() {
        return "ProcessedEvent{" +
                "id=" + id +
                ", eventId='" + eventId + '\'' +
                ", eventType='" + eventType + '\'' +
                ", consumerGroup='" + consumerGroup + '\'' +
                ", aggregateId='" + aggregateId + '\'' +
                ", processedAt=" + processedAt +
                '}';
    }
}
