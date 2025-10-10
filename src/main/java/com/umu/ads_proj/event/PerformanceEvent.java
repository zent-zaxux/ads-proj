package com.umu.ads_proj.event;

import com.fasterxml.jackson.annotation.JsonCreator;
import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * Event published when performance testing is started or completed
 */
public class PerformanceEvent extends BaseEvent {
    
    public enum PerformanceAction {
        LOAD_TEST_STARTED, LOAD_TEST_COMPLETED, PERFORMANCE_DEGRADATION, SYSTEM_HEALTHY
    }
    
    private String testType;
    private PerformanceAction action;
    private Integer numberOfOperations;
    private Integer concurrencyLevel;
    private Long durationMs;
    private Double throughput;
    private String details;
    
    // Default constructor for JSON deserialization
    public PerformanceEvent() {
        super();
    }
    
    @JsonCreator
    public PerformanceEvent(
            @JsonProperty("testType") String testType,
            @JsonProperty("action") PerformanceAction action,
            @JsonProperty("numberOfOperations") Integer numberOfOperations,
            @JsonProperty("concurrencyLevel") Integer concurrencyLevel,
            @JsonProperty("durationMs") Long durationMs,
            @JsonProperty("throughput") Double throughput,
            @JsonProperty("details") String details) {
        super("PERFORMANCE_EVENT", "load-generation-service");
        this.testType = testType;
        this.action = action;
        this.numberOfOperations = numberOfOperations;
        this.concurrencyLevel = concurrencyLevel;
        this.durationMs = durationMs;
        this.throughput = throughput;
        this.details = details;
    }
    
    // Static factory methods
    public static PerformanceEvent loadTestStarted(String testType, int operations, int concurrency) {
        return new PerformanceEvent(testType, PerformanceAction.LOAD_TEST_STARTED, 
                                   operations, concurrency, null, null, 
                                   "Load test started: " + testType);
    }
    
    public static PerformanceEvent loadTestCompleted(String testType, int operations, 
                                                   long durationMs, double throughput) {
        return new PerformanceEvent(testType, PerformanceAction.LOAD_TEST_COMPLETED, 
                                   operations, null, durationMs, throughput, 
                                   String.format("Load test completed: %s (%.2f ops/sec)", 
                                               testType, throughput));
    }
    
    // Getters and Setters
    public String getTestType() {
        return testType;
    }
    
    public void setTestType(String testType) {
        this.testType = testType;
    }
    
    public PerformanceAction getAction() {
        return action;
    }
    
    public void setAction(PerformanceAction action) {
        this.action = action;
    }
    
    public Integer getNumberOfOperations() {
        return numberOfOperations;
    }
    
    public void setNumberOfOperations(Integer numberOfOperations) {
        this.numberOfOperations = numberOfOperations;
    }
    
    public Integer getConcurrencyLevel() {
        return concurrencyLevel;
    }
    
    public void setConcurrencyLevel(Integer concurrencyLevel) {
        this.concurrencyLevel = concurrencyLevel;
    }
    
    public Long getDurationMs() {
        return durationMs;
    }
    
    public void setDurationMs(Long durationMs) {
        this.durationMs = durationMs;
    }
    
    public Double getThroughput() {
        return throughput;
    }
    
    public void setThroughput(Double throughput) {
        this.throughput = throughput;
    }
    
    public String getDetails() {
        return details;
    }
    
    public void setDetails(String details) {
        this.details = details;
    }
    
    @Override
    public String toString() {
        return "PerformanceEvent{" +
                "testType='" + testType + '\'' +
                ", action=" + action +
                ", numberOfOperations=" + numberOfOperations +
                ", concurrencyLevel=" + concurrencyLevel +
                ", durationMs=" + durationMs +
                ", throughput=" + throughput +
                ", details='" + details + '\'' +
                ", " + super.toString() +
                '}';
    }
}