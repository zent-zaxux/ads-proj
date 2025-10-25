# Performance Optimization Summary

## Overview
This directory contains automated performance optimization scripts and documentation for the distributed Kafka-based order processing system.

## Available Scripts

### 1. `quick-optimize.sh` ⚡ (Recommended)
**Purpose**: Quickly apply all performance optimizations and validate the system

**What it does**:
- Backs up current configuration
- Applies Kafka, Database, Application, and Docker optimizations
- Restarts all services
- Runs validation test
- Takes ~5-10 minutes

**Usage**:
```bash
./quick-optimize.sh
```

**Optimizations Applied**:
- ✅ Kafka consumer concurrency (5 threads)
- ✅ Kafka producer batching and compression (LZ4)
- ✅ Database connection pooling (HikariCP)
- ✅ JPA batch operations
- ✅ Docker resource limits and JVM tuning
- ✅ Logging optimization (INFO level)

### 2. `auto-optimize.sh` 📊 (Advanced)
**Purpose**: Full benchmark-driven optimization with before/after comparison

**What it does**:
- Runs baseline performance tests (3 sessions)
- Analyzes bottlenecks
- Applies all optimizations
- Runs optimized performance tests (3 sessions)
- Generates detailed comparison report
- Takes ~15-20 minutes

**Usage**:
```bash
./auto-optimize.sh
```

**Output Files**:
- `optimization_report_[timestamp].md` - Detailed comparison report
- `baseline_test_[timestamp]/` - Baseline test results
- `optimized_test_[timestamp]/` - Optimized test results
- `config_backup_[timestamp]/` - Configuration backups

## Key Optimizations

### Kafka Optimizations
| Parameter | Before | After | Impact |
|-----------|--------|-------|--------|
| Concurrency | 1 | 5 | 5x parallel processing |
| Max Poll Records | 500 | 100 | Better batching |
| Fetch Min Size | 512KB | 1MB | Fewer round trips |
| Producer Batch Size | 16KB | 32KB | Better throughput |
| Compression | none | LZ4 | Reduced network I/O |
| Linger MS | 0 | 10 | Batch accumulation |

### Database Optimizations
| Parameter | Before | After | Impact |
|-----------|--------|-------|--------|
| HikariCP Max Pool | 10 | 20 | Handle more load |
| HikariCP Min Idle | 10 | 10 | Ready connections |
| Prepared Stmt Cache | none | 250 | Faster queries |
| JPA Batch Size | none | 25 | Bulk operations |
| SQL Logging | ON | OFF | Reduced overhead |

### Application Optimizations
| Parameter | Before | After | Impact |
|-----------|--------|-------|--------|
| Logging Level | DEBUG | INFO | 60% less logs |
| Show SQL | true | false | No SQL overhead |
| JVM Heap | default | 1GB | Better GC |
| GC Algorithm | default | G1GC | Lower pause times |

### Docker Optimizations
| Container | Memory Before | Memory After | CPUs |
|-----------|---------------|--------------|------|
| Kafka | unlimited | 2GB + 1.5GB heap | 2.0 |
| PostgreSQL | unlimited | 1GB | 1.5 |
| Zookeeper | unlimited | 512MB | 1.0 |

## Expected Results

Based on analysis of system bottlenecks:

### Performance Improvements
- **Throughput**: 3-5x increase
- **Latency**: 40-60% reduction
- **Success Rate**: 90%+ under load
- **Resource Efficiency**: Better CPU and memory utilization

### Before Optimization (Typical)
- Success Rate: ~57.5% at 200 users
- Average Latency: ~300-500ms
- Throughput: ~10-20 req/s
- Kafka: 820MB RAM, 2.4% CPU (underutilized)

### After Optimization (Expected)
- Success Rate: ~95%+ at 500+ users
- Average Latency: ~100-200ms
- Throughput: ~50-100 req/s
- Kafka: 2GB RAM, better distributed load

## Testing the Optimizations

After running `quick-optimize.sh` or `auto-optimize.sh`:

### 1. Run Stress Tests
```bash
./stress-test.sh
```
This will run 10 continuous scalability sessions (10→1000 users each)

### 2. Monitor Performance
```bash
# Application logs
tail -f app.log

# Docker resource usage
docker stats

# Kafka UI
open http://localhost:8080
```

### 3. Check Metrics
```bash
# Prometheus metrics
curl http://localhost:8081/actuator/prometheus

# Health check
curl http://localhost:8081/actuator/health
```

## Identified Bottlenecks (Before Optimization)

### 1. Kafka Consumer (Critical)
- ❌ No concurrency (single-threaded)
- ❌ No batch processing
- ❌ Default fetch sizes
- ❌ Sequential message processing

### 2. Database (High Impact)
- ❌ No connection pool tuning
- ❌ No prepared statement cache
- ❌ No batch operations
- ❌ Verbose SQL logging

### 3. Application (Medium Impact)
- ❌ DEBUG logging overhead
- ❌ show-sql=true (extra logging)
- ❌ Default JVM settings

### 4. Kafka Producer (Medium Impact)
- ❌ Small batch size (16KB)
- ❌ No compression
- ❌ Immediate sends (linger=0ms)

### 5. Infrastructure (Low Impact)
- ❌ No resource limits
- ❌ No JVM heap tuning
- ❌ Resource headroom available (89% unused)

## Configuration Backups

All scripts automatically create backups before making changes:

```
config_backup_[timestamp]/
├── application.properties  # Spring Boot config
└── compose.yaml           # Docker Compose config
```

### Restore Original Configuration
```bash
# Replace timestamp with your backup
BACKUP_DIR="config_backup_20250124_120000"

cp ${BACKUP_DIR}/application.properties src/main/resources/
cp ${BACKUP_DIR}/compose.yaml .

# Restart services
docker-compose down
docker-compose up -d
./mvnw clean package -DskipTests
java -jar target/ads-proj-0.0.1-SNAPSHOT.jar
```

## Monitoring Recommendations

### Key Metrics to Track

1. **Kafka Consumer Lag**
   - Check in Kafka UI: http://localhost:8080
   - Should be < 100 messages under normal load

2. **Database Connection Pool**
   ```sql
   SELECT count(*) FROM pg_stat_activity;
   ```
   - Should be < maximum-pool-size (20)

3. **JVM Heap Usage**
   ```bash
   curl http://localhost:8081/actuator/metrics/jvm.memory.used
   ```
   - Should stay < 80% of max heap

4. **Response Times**
   ```bash
   curl -w "@curl-format.txt" -o /dev/null -s http://localhost:8081/api/orders
   ```
   - p95 latency should be < 200ms

## Troubleshooting

### Application Won't Start
```bash
# Check logs
tail -50 app.log

# Check if port is in use
lsof -i :8081

# Check Kafka connectivity
docker exec kafka kafka-broker-api-versions --bootstrap-server localhost:9092
```

### High Memory Usage
```bash
# Check container stats
docker stats

# Adjust JVM heap if needed (in quick-optimize.sh)
# Change: -Xmx1g to -Xmx512m
```

### Database Connection Issues
```bash
# Check PostgreSQL
docker logs postgres

# Verify connection pool
# Check application.properties:
# spring.datasource.hikari.maximum-pool-size=20
```

## Files Reference

### Generated by Optimization Scripts
- `optimization_report_*.md` - Detailed performance comparison
- `baseline_test_*/` - Pre-optimization test data
- `optimized_test_*/` - Post-optimization test data
- `config_backup_*/` - Configuration backups
- `app.log` - Application runtime logs

### Testing Scripts
- `e2e-demo.sh` - End-to-end Kafka flow demonstration
- `stress-test.sh` - Continuous scalability testing (10 sessions)
- `simple-stress-test.sh` - Basic load testing

### Documentation
- `PERFORMANCE_OPTIMIZATION_PLAN.md` - Detailed optimization strategy
- `TESTING_SCRIPTS_GUIDE.md` - Testing scripts documentation
- `COMPLETE_TESTING_GUIDE.md` - Comprehensive testing guide

## Quick Reference Commands

```bash
# Apply optimizations (quick)
./quick-optimize.sh

# Full optimization with benchmarks
./auto-optimize.sh

# Run stress tests
./stress-test.sh

# Monitor application
tail -f app.log

# Check Kafka
open http://localhost:8080

# View metrics
curl http://localhost:8081/actuator/prometheus | grep -E "(kafka|hikari|jvm)"

# Docker stats
docker stats --no-stream

# Database connections
docker exec postgres psql -U adsuser -d adsdb -c "SELECT count(*) FROM pg_stat_activity;"
```

## Next Steps After Optimization

1. **Run Extended Tests**: Use `stress-test.sh` to validate improvements
2. **Monitor Metrics**: Track Kafka lag, DB connections, JVM heap
3. **Fine-tune**: Adjust concurrency and pool sizes based on actual load
4. **Consider Scaling**: If needed, add more Kafka partitions or app instances
5. **Add Caching**: Implement Redis for frequently accessed data
6. **Enable Monitoring**: Set up Prometheus + Grafana for visualization

## Support

For issues or questions:
- Check application logs: `tail -f app.log`
- Review Kafka logs: `docker logs kafka`
- Verify database: `docker logs postgres`
- Test connectivity: `curl http://localhost:8081/actuator/health`

---
**Last Updated**: 2025-01-24
