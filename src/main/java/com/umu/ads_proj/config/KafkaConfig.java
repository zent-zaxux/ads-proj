package com.umu.ads_proj.config;

import org.apache.kafka.clients.admin.NewTopic;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.config.TopicBuilder;

/**
 * Kafka configuration for topic creation and management
 */
@Configuration
public class KafkaConfig {
    
    @Value("${app.kafka.topics.user-events}")
    private String userEventsTopic;
    
    @Value("${app.kafka.topics.load-events}")
    private String loadEventsTopic;
    
    @Value("${app.kafka.topics.performance-events}")
    private String performanceEventsTopic;
    
    /**
     * Topic for user-related events (create, update, delete)
     */
    @Bean
    public NewTopic userEventsTopic() {
        return TopicBuilder.name(userEventsTopic)
                .partitions(3)
                .replicas(1)
                .compact()
                .build();
    }
    
    /**
     * Topic for load generation events
     */
    @Bean
    public NewTopic loadEventsTopic() {
        return TopicBuilder.name(loadEventsTopic)
                .partitions(3)
                .replicas(1)
                .build();
    }
    
    /**
     * Topic for performance monitoring events
     */
    @Bean
    public NewTopic performanceEventsTopic() {
        return TopicBuilder.name(performanceEventsTopic)
                .partitions(2)
                .replicas(1)
                .build();
    }
}