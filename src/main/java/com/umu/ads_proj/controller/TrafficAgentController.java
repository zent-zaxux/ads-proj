package com.umu.ads_proj.controller;

import com.umu.ads_proj.agent.TrafficAgent;
import com.umu.ads_proj.agent.TrafficAgent.AgentStats;
import com.umu.ads_proj.agent.TrafficAgent.TrafficPattern;
import io.micrometer.core.annotation.Timed;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

import java.util.HashMap;
import java.util.Map;

/**
 * Controller for managing the Traffic Agent
 * 
 * Provides REST API to control autonomous traffic generation:
 * - Start/Stop agent
 * - Pause/Resume (for lag testing)
 * - Get statistics
 * - Change traffic patterns
 */
@RestController
@RequestMapping("/api/agent/traffic")
public class TrafficAgentController {
    
    private static final Logger logger = LoggerFactory.getLogger(TrafficAgentController.class);
    
    @Autowired
    private TrafficAgent trafficAgent;
    
    /**
     * Start the traffic agent
     * 
     * POST /api/agent/traffic/start
     */
    @PostMapping("/start")
    @Timed(value = "agent.traffic.start", description = "Start traffic agent")
    public ResponseEntity<Map<String, Object>> startAgent(
            @RequestParam(defaultValue = "5") int opsPerSecond,
            @RequestParam(defaultValue = "STEADY") TrafficPattern pattern) {
        
        logger.info("Starting traffic agent with {} ops/sec, pattern: {}", opsPerSecond, pattern);
        
        try {
            trafficAgent.setOperationsPerSecond(opsPerSecond);
            trafficAgent.setCurrentPattern(pattern);
            trafficAgent.start();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Traffic agent started");
            response.put("agentId", trafficAgent.getAgentId());
            response.put("opsPerSecond", opsPerSecond);
            response.put("pattern", pattern);
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to start traffic agent: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to start traffic agent: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Stop the traffic agent
     * 
     * POST /api/agent/traffic/stop
     */
    @PostMapping("/stop")
    @Timed(value = "agent.traffic.stop", description = "Stop traffic agent")
    public ResponseEntity<Map<String, Object>> stopAgent() {
        logger.info("Stopping traffic agent");
        
        try {
            trafficAgent.stop();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Traffic agent stopped");
            response.put("agentId", trafficAgent.getAgentId());
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to stop traffic agent: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to stop traffic agent: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Pause the traffic agent (for lag testing)
     * 
     * POST /api/agent/traffic/pause
     */
    @PostMapping("/pause")
    @Timed(value = "agent.traffic.pause", description = "Pause traffic agent")
    public ResponseEntity<Map<String, Object>> pauseAgent() {
        logger.info("Pausing traffic agent");
        
        try {
            trafficAgent.pause();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Traffic agent paused");
            response.put("agentId", trafficAgent.getAgentId());
            response.put("note", "Messages will accumulate in Kafka (lag simulation)");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to pause traffic agent: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to pause traffic agent: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Resume the traffic agent (after pause)
     * 
     * POST /api/agent/traffic/resume
     */
    @PostMapping("/resume")
    @Timed(value = "agent.traffic.resume", description = "Resume traffic agent")
    public ResponseEntity<Map<String, Object>> resumeAgent() {
        logger.info("Resuming traffic agent");
        
        try {
            trafficAgent.resume();
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Traffic agent resumed");
            response.put("agentId", trafficAgent.getAgentId());
            response.put("note", "Agent will catch up on accumulated messages");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to resume traffic agent: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to resume traffic agent: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Get traffic agent status and statistics
     * 
     * GET /api/agent/traffic/status
     */
    @GetMapping("/status")
    @Timed(value = "agent.traffic.status", description = "Get traffic agent status")
    public ResponseEntity<AgentStats> getStatus() {
        logger.debug("Getting traffic agent status");
        
        AgentStats stats = trafficAgent.getStats();
        return ResponseEntity.ok(stats);
    }
    
    /**
     * Change traffic pattern
     * 
     * POST /api/agent/traffic/pattern
     */
    @PostMapping("/pattern")
    @Timed(value = "agent.traffic.pattern", description = "Change traffic pattern")
    public ResponseEntity<Map<String, Object>> changePattern(
            @RequestParam TrafficPattern pattern) {
        
        logger.info("Changing traffic pattern to: {}", pattern);
        
        try {
            trafficAgent.setCurrentPattern(pattern);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Traffic pattern changed");
            response.put("newPattern", pattern);
            response.put("note", "Restart agent to apply new pattern");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to change pattern: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to change pattern: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Change operations per second
     * 
     * POST /api/agent/traffic/rate
     */
    @PostMapping("/rate")
    @Timed(value = "agent.traffic.rate", description = "Change traffic rate")
    public ResponseEntity<Map<String, Object>> changeRate(
            @RequestParam int opsPerSecond) {
        
        logger.info("Changing traffic rate to: {} ops/sec", opsPerSecond);
        
        try {
            if (opsPerSecond < 1 || opsPerSecond > 100) {
                Map<String, Object> response = new HashMap<>();
                response.put("success", false);
                response.put("message", "Invalid rate. Must be between 1 and 100 ops/sec");
                return ResponseEntity.badRequest().body(response);
            }
            
            trafficAgent.setOperationsPerSecond(opsPerSecond);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", true);
            response.put("message", "Traffic rate changed");
            response.put("newRate", opsPerSecond);
            response.put("note", "Restart agent to apply new rate");
            
            return ResponseEntity.ok(response);
            
        } catch (Exception e) {
            logger.error("Failed to change rate: {}", e.getMessage(), e);
            
            Map<String, Object> response = new HashMap<>();
            response.put("success", false);
            response.put("message", "Failed to change rate: " + e.getMessage());
            
            return ResponseEntity.internalServerError().body(response);
        }
    }
    
    /**
     * Health check
     * 
     * GET /api/agent/traffic/health
     */
    @GetMapping("/health")
    public ResponseEntity<Map<String, Object>> health() {
        Map<String, Object> health = new HashMap<>();
        health.put("service", "traffic-agent");
        health.put("status", "UP");
        health.put("agentId", trafficAgent.getAgentId());
        health.put("running", trafficAgent.isRunning());
        health.put("paused", trafficAgent.isPaused());
        
        return ResponseEntity.ok(health);
    }
    
    /**
     * Get available traffic patterns
     * 
     * GET /api/agent/traffic/patterns
     */
    @GetMapping("/patterns")
    public ResponseEntity<Map<String, Object>> getAvailablePatterns() {
        Map<String, Object> response = new HashMap<>();
        response.put("patterns", TrafficPattern.values());
        response.put("descriptions", Map.of(
                "STEADY", "Constant rate of operations",
                "BURST", "Periodic bursts of traffic",
                "RAMP_UP", "Gradually increasing load",
                "SPIKE", "Sudden spike then back to normal",
                "RANDOM", "Random fluctuations in traffic"
        ));
        
        return ResponseEntity.ok(response);
    }
}
