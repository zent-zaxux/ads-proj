#!/bin/bash

# Analyze experiment results and generate insights

EXPERIMENT_DIR="experiments"
REPORT_FILE="experiments_analysis.md"

echo "# Performance Experiments Analysis" > "${REPORT_FILE}"
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S')" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "## Experiment Overview" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "Testing different configurations of:" >> "${REPORT_FILE}"
echo "- **Kafka Listener Concurrency**: 1, 3, 5, 8, 10 threads" >> "${REPORT_FILE}"
echo "- **HikariCP Maximum Pool Size**: 10, 20, 40 connections" >> "${REPORT_FILE}"
echo "- **Load Pattern**: 10 → 1000 concurrent users over 30s" >> "${REPORT_FILE}"
echo "- **Sessions per Config**: 10 sessions" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "## Results Summary" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "| Concurrency | Pool Size | Avg Success Rate | Avg Throughput | Avg Failed | Status |" >> "${REPORT_FILE}"
echo "|-------------|-----------|------------------|----------------|------------|--------|" >> "${REPORT_FILE}"

# Process each CSV file
for csv in ${EXPERIMENT_DIR}/scaling_conc*_pool*.csv; do
    [ -f "$csv" ] || continue
    
    # Extract config from filename
    concurrency=$(echo "$csv" | sed -n 's/.*scaling_conc\([0-9]*\)_pool\([0-9]*\)\.csv/\1/p')
    pool=$(echo "$csv" | sed -n 's/.*scaling_conc\([0-9]*\)_pool\([0-9]*\)\.csv/\2/p')
    
    # Calculate averages from CSV (skip header)
    avg_success_rate=$(awk -F',' 'NR>1 {sum+=$8; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}' "$csv")
    avg_throughput=$(awk -F',' 'NR>1 {sum+=$10; count++} END {if(count>0) printf "%.2f", sum/count; else print "N/A"}' "$csv")
    avg_failed=$(awk -F',' 'NR>1 {sum+=$7; count++} END {if(count>0) printf "%.0f", sum/count; else print "N/A"}' "$csv")
    session_count=$(awk 'NR>1' "$csv" | wc -l | tr -d ' ')
    
    status="✓"
    if [ "$session_count" -lt 10 ]; then
        status="⚠️ Running ($session_count/10)"
    fi
    
    echo "| $concurrency | $pool | ${avg_success_rate}% | ${avg_throughput} req/s | ${avg_failed} | $status |" >> "${REPORT_FILE}"
done

echo "" >> "${REPORT_FILE}"

echo "## Detailed Analysis" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Analyze each configuration
for csv in ${EXPERIMENT_DIR}/scaling_conc*_pool*.csv; do
    [ -f "$csv" ] || continue
    
    concurrency=$(echo "$csv" | sed -n 's/.*scaling_conc\([0-9]*\)_pool\([0-9]*\)\.csv/\1/p')
    pool=$(echo "$csv" | sed -n 's/.*scaling_conc\([0-9]*\)_pool\([0-9]*\)\.csv/\2/p')
    
    echo "### Configuration: Concurrency=$concurrency, Pool=$pool" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
    
    # Calculate detailed metrics
    avg_success=$(awk -F',' 'NR>1 {sum+=$6; count++} END {if(count>0) printf "%.0f", sum/count}' "$csv")
    avg_failed=$(awk -F',' 'NR>1 {sum+=$7; count++} END {if(count>0) printf "%.0f", sum/count}' "$csv")
    avg_success_rate=$(awk -F',' 'NR>1 {sum+=$8; count++} END {if(count>0) printf "%.2f", sum/count}' "$csv")
    min_success_rate=$(awk -F',' 'NR>1 {if(NR==2 || $8<min) min=$8} END {printf "%.2f", min}' "$csv")
    max_success_rate=$(awk -F',' 'NR>1 {if(NR==2 || $8>max) max=$8} END {printf "%.2f", max}' "$csv")
    avg_throughput=$(awk -F',' 'NR>1 {sum+=$10; count++} END {if(count>0) printf "%.2f", sum/count}' "$csv")
    
    echo "- **Average Success Rate**: ${avg_success_rate}% (min: ${min_success_rate}%, max: ${max_success_rate}%)" >> "${REPORT_FILE}"
    echo "- **Average Successful Requests**: ${avg_success}" >> "${REPORT_FILE}"
    echo "- **Average Failed Requests**: ${avg_failed}" >> "${REPORT_FILE}"
    echo "- **Average Throughput**: ${avg_throughput} req/s" >> "${REPORT_FILE}"
    echo "- **Stability**: $([[ $(echo "$max_success_rate - $min_success_rate < 10" | bc -l) == 1 ]] && echo "High (variance < 10%)" || echo "Low (variance ≥ 10%)")" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
done

echo "## Key Findings" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Find best configuration
best_config=""
best_success_rate=0
for csv in ${EXPERIMENT_DIR}/scaling_conc*_pool*.csv; do
    [ -f "$csv" ] || continue
    concurrency=$(echo "$csv" | sed -n 's/.*scaling_conc\([0-9]*\)_pool\([0-9]*\)\.csv/\1/p')
    pool=$(echo "$csv" | sed -n 's/.*scaling_conc\([0-9]*\)_pool\([0-9]*\)\.csv/\2/p')
    avg_success_rate=$(awk -F',' 'NR>1 {sum+=$8; count++} END {if(count>0) printf "%.2f", sum/count; else print "0"}' "$csv")
    
    if (( $(echo "$avg_success_rate > $best_success_rate" | bc -l) )); then
        best_success_rate=$avg_success_rate
        best_config="Concurrency=$concurrency, Pool=$pool"
    fi
done

echo "### Best Performing Configuration" >> "${REPORT_FILE}"
echo "- **Configuration**: $best_config" >> "${REPORT_FILE}"
echo "- **Success Rate**: ${best_success_rate}%" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "### Observed Bottlenecks" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "Based on the test results:" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Analyze patterns
if (( $(echo "$best_success_rate < 70" | bc -l) )); then
    echo "1. **Overall Low Success Rate (< 70%)**" >> "${REPORT_FILE}"
    echo "   - Even the best configuration shows < 70% success rate" >> "${REPORT_FILE}"
    echo "   - Indicates fundamental bottlenecks beyond thread/connection tuning" >> "${REPORT_FILE}"
    echo "   - Likely causes:" >> "${REPORT_FILE}"
    echo "     - Database query performance (N+1 queries, missing indexes)" >> "${REPORT_FILE}"
    echo "     - Synchronous processing blocking request threads" >> "${REPORT_FILE}"
    echo "     - Network I/O saturation" >> "${REPORT_FILE}"
    echo "     - Kafka producer/consumer lag" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
fi

echo "2. **High Failure Rate Under Load**" >> "${REPORT_FILE}"
echo "   - Failures increase as concurrent users ramp up" >> "${REPORT_FILE}"
echo "   - Suggests resource exhaustion or timeout issues" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "3. **Low Throughput (~13 req/s)**" >> "${REPORT_FILE}"
echo "   - Current throughput is very low for modern systems" >> "${REPORT_FILE}"
echo "   - Expected throughput for optimized system: 100-500 req/s" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "## Recommendations for Further Optimization" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "### Immediate Actions (High Impact)" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "1. **Database Query Optimization**" >> "${REPORT_FILE}"
echo "   - Enable SQL query logging temporarily to identify slow queries" >> "${REPORT_FILE}"
echo "   - Check for N+1 query problems" >> "${REPORT_FILE}"
echo "   - Add database indexes on frequently queried columns (user_id, order_id)" >> "${REPORT_FILE}"
echo "   - Consider using @EntityGraph to optimize JPA fetch strategies" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "2. **Async Processing**" >> "${REPORT_FILE}"
echo "   - Move Kafka event publishing to async (@Async)" >> "${REPORT_FILE}"
echo "   - Use CompletableFuture for non-blocking operations" >> "${REPORT_FILE}"
echo "   - Consider reactive programming (WebFlux) for high concurrency" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "3. **Kafka Partitioning**" >> "${REPORT_FILE}"
echo "   - Current setup likely uses 1 partition per topic" >> "${REPORT_FILE}"
echo "   - Increase to 5-10 partitions to enable parallel processing" >> "${REPORT_FILE}"
echo "   - Match partition count with consumer concurrency" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "4. **Connection Pool Validation**" >> "${REPORT_FILE}"
echo "   - Monitor HikariCP metrics for pool exhaustion" >> "${REPORT_FILE}"
echo "   - Check for connection leaks (connections not returned to pool)" >> "${REPORT_FILE}"
echo "   - Enable connection leak detection: \`leakDetectionThreshold=2000\`" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "### Medium Priority" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "5. **Application Profiling**" >> "${REPORT_FILE}"
echo "   - Use JProfiler or VisualVM to identify CPU hotspots" >> "${REPORT_FILE}"
echo "   - Check for thread contention and lock waits" >> "${REPORT_FILE}"
echo "   - Profile memory usage to detect excessive GC" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "6. **Caching Layer**" >> "${REPORT_FILE}"
echo "   - Add Redis for frequently accessed data" >> "${REPORT_FILE}"
echo "   - Enable second-level Hibernate cache" >> "${REPORT_FILE}"
echo "   - Cache user lookups and reference data" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "7. **Batch Processing**" >> "${REPORT_FILE}"
echo "   - Enable JDBC batch inserts/updates (already configured)" >> "${REPORT_FILE}"
echo "   - Use batch operations in Kafka consumers" >> "${REPORT_FILE}"
echo "   - Process events in batches instead of one-by-one" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "### Long-term Improvements" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "8. **Horizontal Scaling**" >> "${REPORT_FILE}"
echo "   - Deploy multiple application instances behind load balancer" >> "${REPORT_FILE}"
echo "   - Add more Kafka brokers for better throughput" >> "${REPORT_FILE}"
echo "   - Consider database read replicas" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "9. **Event Sourcing / CQRS**" >> "${REPORT_FILE}"
echo "   - Separate read and write models" >> "${REPORT_FILE}"
echo "   - Use event sourcing for better scalability" >> "${REPORT_FILE}"
echo "   - Implement materialized views for queries" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "10. **Message Queue Optimization**" >> "${REPORT_FILE}"
echo "   - Consider RabbitMQ or Redis Streams for some use cases" >> "${REPORT_FILE}"
echo "   - Implement backpressure mechanisms" >> "${REPORT_FILE}"
echo "   - Add circuit breakers for external services" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "## Next Steps" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "1. **Profile the Application**: Use JProfiler/VisualVM during load test to identify CPU/memory hotspots" >> "${REPORT_FILE}"
echo "2. **Enable SQL Logging**: Temporarily enable \`show-sql=true\` and \`logging.level.org.hibernate.SQL=DEBUG\` to identify slow queries" >> "${REPORT_FILE}"
echo "3. **Check Kafka Metrics**: Monitor consumer lag, partition assignment, and message throughput" >> "${REPORT_FILE}"
echo "4. **Review Application Logs**: Look for exceptions, timeouts, or warning messages during load tests" >> "${REPORT_FILE}"
echo "5. **Database Analysis**: Run EXPLAIN ANALYZE on common queries to check execution plans" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "## Monitoring Queries" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo '```bash' >> "${REPORT_FILE}"
echo "# Check Kafka consumer lag" >> "${REPORT_FILE}"
echo "docker exec kafka kafka-consumer-groups --bootstrap-server localhost:9092 --describe --group ads-proj-group" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "# Check HikariCP metrics" >> "${REPORT_FILE}"
echo "curl -s http://localhost:8081/actuator/metrics/hikaricp.connections.active | jq" >> "${REPORT_FILE}"
echo "curl -s http://localhost:8081/actuator/metrics/hikaricp.connections.idle | jq" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "# Check database connections" >> "${REPORT_FILE}"
echo "docker exec postgres psql -U adsuser -d adsdb -c \"SELECT count(*), state FROM pg_stat_activity GROUP BY state;\"" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
echo "# Check JVM metrics" >> "${REPORT_FILE}"
echo "curl -s http://localhost:8081/actuator/metrics/jvm.memory.used | jq" >> "${REPORT_FILE}"
echo "curl -s http://localhost:8081/actuator/metrics/jvm.threads.live | jq" >> "${REPORT_FILE}"
echo '```' >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "---" >> "${REPORT_FILE}"
echo "*Report generated from ${EXPERIMENT_DIR}/ at $(date)*" >> "${REPORT_FILE}"

echo "Analysis complete! Report saved to: ${REPORT_FILE}"
cat "${REPORT_FILE}"
