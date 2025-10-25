package com.umu.ads_proj.controller;

import com.umu.ads_proj.agent.FulfillmentAgent;
import com.umu.ads_proj.agent.FulfillmentAgent.AgentStats;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * Controller for managing the Fulfillment Agent
 * 
 * Provides REST API to control autonomous order fulfillment:
 * - Start/Stop agent
 * - Pause/Resume (for lag testing)
 * - Get statistics
 * - Configure processing parameters
 */
@RestController
@RequestMapping("/api/agent/fulfillment")
public class FulfillmentAgentController {
    
    private static final Logger logger = LoggerFactory.getLogger(FulfillmentAgentController.class);
    
    @Autowired
    private FulfillmentAgent fulfillmentAgent;
    
    /**
     * Start the fulfillment agent
     * 
     * POST /api/agent/fulfillment/start
     */
    @PostMapping("/start")
    @Timed(value = "agent.fulfillment.start", description = "Start fulfillment agent")
    public ResponseEntity<Map<String, Object>> startAgent(
            @RequestParam(defaultValue = "2000") int processingDelayMs,
            @RequestParam(defaultValue = "5") int batchSize,
            @RequestParam(defaultValue = "5") int pollingIntervalSeconds) {
        
        logger.info("Starting fulfillment agent with delay={}ms, batch={}, interval={}s", 
            processingDelayMs, batchSize, pollingIntervalSeconds);
        
        try {
            fulfillmentAgent.setProcessingDelayMs(processingDelayMs);
            fulfillmentAgent.setBatchSize(batchSize);
            fulfillmentAgent.setPollingIntervalSeconds(pollingIntervalSeconds);
            fulfillmentAgent.start();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Fulfillment agent started");
            response.put("agentId", fulfillmentAgent.getAgentId());
            response.put("processingDelayMs", processingDelayMs);
            response.put("batchSize", batchSize);
            response.put("pollingIntervalSeconds", pollingIntervalSeconds);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to start fulfillment agent: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to start fulfillment agent: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Stop the fulfillment agent
     * 
     * POST /api/agent/fulfillment/stop
     */
    @PostMapping("/stop")
    @Timed(value = "agent.fulfillment.stop", description = "Stop fulfillment agent")
    public ResponseEntity<Map<String, Object>> stopAgent() {
        logger.info("Stopping fulfillment agent");
        
        try {
            fulfillmentAgent.stop();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Fulfillment agent stopped");
            response.put("agentId", fulfillmentAgent.getAgentId());
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to stop fulfillment agent: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to stop fulfillment agent: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Pause the fulfillment agent (for lag testing)
     * 
     * POST /api/agent/fulfillment/pause
     */
    @PostMapping("/pause")
    @Timed(value = "agent.fulfillment.pause", description = "Pause fulfillment agent")
    public ResponseEntity<Map<String, Object>> pauseAgent() {
        logger.info("Pausing fulfillment agent");
        
        try {
            fulfillmentAgent.pause();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Fulfillment agent paused");
            response.put("agentId", fulfillmentAgent.getAgentId());
            response.put("note", "Orders will accumulate (backlog simulation)");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to pause fulfillment agent: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to pause fulfillment agent: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Resume the fulfillment agent (after pause)
     * 
     * POST /api/agent/fulfillment/resume
     */
    @PostMapping("/resume")
    @Timed(value = "agent.fulfillment.resume", description = "Resume fulfillment agent")
    public ResponseEntity<Map<String, Object>> resumeAgent() {
        logger.info("Resuming fulfillment agent");
        
        try {
            fulfillmentAgent.resume();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Fulfillment agent resumed");
            response.put("agentId", fulfillmentAgent.getAgentId());
            response.put("note", "Agent will process backlog");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to resume fulfillment agent: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to resume fulfillment agent: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Get fulfillment agent status and statistics
     * 
     * GET /api/agent/fulfillment/status
     */
    @GetMapping("/status")
    @Timed(value = "agent.fulfillment.status", description = "Get fulfillment agent status")
    public ResponseEntity<AgentStats> getStatus() {
        logger.debug("Getting fulfillment agent status");
        
        AgentStats stats = fulfillmentAgent.getStats();
        return ResponseEntity.ok(stats);
    }
    
    /**
     * Configure processing delay
     * 
     * POST /api/agent/fulfillment/config/delay
     */
    @PostMapping("/config/delay")
    @Timed(value = "agent.fulfillment.config.delay", description = "Configure processing delay")
    public ResponseEntity<Map<String, Object>> configureDelay(
            @RequestParam int delayMs) {
        
        logger.info("Configuring fulfillment agent delay to: {}ms", delayMs);
        
        try {
            if (delayMs < 100 || delayMs > 60000) {
                Map<String, Object> response = new HashMap<>();
                response.put("success", false);
                response.put("message", "Invalid delay. Must be between 100ms and 60000ms");
                return ResponseEntity.badRequest().body(response);
            }
            
            fulfillmentAgent.setProcessingDelayMs(delayMs);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Processing delay configured");
            response.put("delayMs", delayMs);
            response.put("note", "New delay applies immediately");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to configure delay: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to configure delay: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Configure batch size
     * 
     * POST /api/agent/fulfillment/config/batch
     */
    @PostMapping("/config/batch")
    @Timed(value = "agent.fulfillment.config.batch", description = "Configure batch size")
    public ResponseEntity<Map<String, Object>> configureBatchSize(
            @RequestParam int batchSize) {
        
        logger.info("Configuring fulfillment agent batch size to: {}", batchSize);
        
        try {
            if (batchSize < 1 || batchSize > 100) {
                Map<String, Object> response = new HashMap<>();
                response.put("success", false);
                response.put("message", "Invalid batch size. Must be between 1 and 100");
                return ResponseEntity.badRequest().body(response);
            }
            
            fulfillmentAgent.setBatchSize(batchSize);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Batch size configured");
            response.put("batchSize", batchSize);
            response.put("note", "New batch size applies immediately");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to configure batch size: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to configure batch size: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Configure polling interval
     * 
     * POST /api/agent/fulfillment/config/interval
     */
    @PostMapping("/config/interval")
    @Timed(value = "agent.fulfillment.config.interval", description = "Configure polling interval")
    public ResponseEntity<Map<String, Object>> configurePollingInterval(
            @RequestParam int intervalSeconds) {
        
        logger.info("Configuring fulfillment agent polling interval to: {}s", intervalSeconds);
        
        try {
            if (intervalSeconds < 1 || intervalSeconds > 300) {
                Map<String, Object> response = new HashMap<>();
                response.put("success", false);
                response.put("message", "Invalid interval. Must be between 1 and 300 seconds");
                return ResponseEntity.badRequest().body(response);
            }
            
            fulfillmentAgent.setPollingIntervalSeconds(intervalSeconds);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Polling interval configured");
            response.put("intervalSeconds", intervalSeconds);
            response.put("note", "Restart agent to apply new interval");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to configure polling interval: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to configure polling interval: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Health check
     * 
     * GET /api/agent/fulfillment/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> health = new HashMap<>();
        health.put("service", "fulfillment-agent");
        health.put("status", "UP");
        health.put("agentId", fulfillmentAgent.getAgentId());
        health.put("running", fulfillmentAgent.isRunning());
        health.put("paused", fulfillmentAgent.isPaused());
        
        return ResponseEntity.ok(health);
    }
}
