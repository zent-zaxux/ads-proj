package com.umu.ads_proj.repository;

import com.umu.ads_proj.entity.ProcessedEvent;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.stereotype.Repository;

import java.util.Optional;

/**
 * Repository for tracking processed events (idempotency)
 */
@Repository
public interface ProcessedEventRepository extends JpaRepository<ProcessedEvent, Long> {
    
    /**
     * Check if an event has already been processed
     * @param eventId The unique event ID
     * @return true if event was already processed
     */
    boolean existsByEventId(String eventId);
    
    /**
     * Find a processed event by its ID
     * @param eventId The unique event ID
     * @return Optional containing the processed event if found
     */
    Optional<ProcessedEvent> findByEventId(String eventId);
}
