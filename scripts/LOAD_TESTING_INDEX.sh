#!/bin/bash

# List all load testing related files and their purposes

cat << "EOF"
╔══════════════════════════════════════════════════════════════════════════════════╗
║                 CONCURRENT LOAD TESTING SYSTEM - FILE INDEX                      ║
╚══════════════════════════════════════════════════════════════════════════════════╝

📁 JAVA SOURCE FILES (src/main/java/com/umu/ads_proj/)
────────────────────────────────────────────────────────────────────────────────────

📦 loadtest/
  ├─ ConcurrentLoadTestRunner.java    ⭐ Core load testing engine
  │   • Multi-threaded user simulation (10-1000 users)
  │   • Kafka event publishing with JSON serialization
  │   • Variable message rates and burst patterns
  │   • Random delays (100-2000ms) and failures (5%)
  │   • Real-time metrics collection
  │
  └─ LoadTestMetrics.java              📊 Metrics collection system
      • Per-action success/failure tracking
      • Latency measurement and averaging
      • Throughput calculation
      • Real-time and final reporting

📦 service/
  └─ ConcurrentLoadTestService.java    🔧 Spring service layer
      • Async test execution (@Async)
      • Predefined scenarios (stress, spike, sustained)
      • Test orchestration and lifecycle management

📦 controller/
  └─ ConcurrentLoadTestController.java 🌐 REST API controller
      • HTTP endpoints for test control
      • Parameter validation
      • Response formatting
      • Test status monitoring

────────────────────────────────────────────────────────────────────────────────────

🚀 EXECUTABLE SHELL SCRIPTS
────────────────────────────────────────────────────────────────────────────────────

quick-start-load-test.sh               🎯 RECOMMENDED STARTING POINT
  • Interactive guided testing
  • Prerequisites checking
  • Test type selection menu
  • Progress monitoring with visual feedback
  
  USAGE: ./quick-start-load-test.sh

────────────────────────────────────────────────────────────────────────────────────

run-concurrent-load-test.sh            🏃 Main test runner
  • Supports all test types
  • Environment variable configuration
  • Progress tracking
  • Health checks
  
  USAGE: 
    ./run-concurrent-load-test.sh TEST_TYPE=quick
    MIN_USERS=10 MAX_USERS=500 ./run-concurrent-load-test.sh

────────────────────────────────────────────────────────────────────────────────────

test-all-load-scenarios.sh             📋 Comprehensive test suite
  • Runs 7 different scenarios
  • Quick, Gradual, Sustained, Spike, Stress tests
  • Automatic progression through all scenarios
  • Complete system validation
  
  USAGE: ./test-all-load-scenarios.sh

────────────────────────────────────────────────────────────────────────────────────

monitor-kafka-metrics.sh               📡 Real-time monitoring
  • Live Kafka topic metrics
  • Consumer group lag tracking
  • Auto-refresh every 5 seconds
  • Message count tracking
  
  USAGE: ./monitor-kafka-metrics.sh

────────────────────────────────────────────────────────────────────────────────────

demo-load-testing.sh                   🎬 Interactive demonstration
  • Step-by-step walkthrough
  • Health checks
  • Sample test execution
  • Kafka inspection
  • Complete feature showcase
  
  USAGE: ./demo-load-testing.sh

────────────────────────────────────────────────────────────────────────────────────

📚 DOCUMENTATION FILES
────────────────────────────────────────────────────────────────────────────────────

CONCURRENT_LOAD_TESTING_GUIDE.md      📖 Complete documentation
  • Architecture overview
  • Detailed feature descriptions
  • Usage examples and patterns
  • Configuration tuning guide
  • Troubleshooting section
  • Performance expectations

────────────────────────────────────────────────────────────────────────────────────

LOAD_TESTING_QUICK_REFERENCE.md       🔖 Quick reference guide
  • Command examples
  • Test type comparison table
  • Metrics reference
  • Common usage patterns
  • Success criteria
  • Troubleshooting quick tips

────────────────────────────────────────────────────────────────────────────────────

LOAD_TESTING_IMPLEMENTATION_SUMMARY.md 📝 Implementation overview
  • What was created
  • Files and components
  • Features implemented
  • How to use
  • Example outputs
  • Validation results

────────────────────────────────────────────────────────────────────────────────────

ARCHITECTURE_DIAGRAM.md                🏗️ Visual architecture
  • System architecture diagram
  • Component relationships
  • Data flow visualization
  • Key features summary

────────────────────────────────────────────────────────────────────────────────────

📊 QUICK START GUIDE
────────────────────────────────────────────────────────────────────────────────────

STEP 1: Make scripts executable
  chmod +x *.sh

STEP 2: Choose your path

  🎯 NEW USERS - Interactive Guide:
    ./quick-start-load-test.sh
  
  🏃 QUICK TEST - Fast Validation:
    ./run-concurrent-load-test.sh TEST_TYPE=quick
  
  📋 COMPREHENSIVE - All Scenarios:
    ./test-all-load-scenarios.sh
  
  🎬 DEMO - See Everything:
    ./demo-load-testing.sh

STEP 3: Monitor results
  
  Option A: Application logs (real-time metrics every 5s)
  Option B: ./monitor-kafka-metrics.sh (Kafka-specific)

────────────────────────────────────────────────────────────────────────────────────

🎯 TEST TYPES AVAILABLE
────────────────────────────────────────────────────────────────────────────────────

TEST TYPE    USERS      DURATION  RAMP-UP  PURPOSE
───────────────────────────────────────────────────────────────────────────────────
quick        10-50      60s       10s      Quick validation
gradual      10-1000    300s      60s      Scalability testing
sustained    Constant   300s      5s       Stability testing
spike        10-1000    120s      5s       Resilience testing
stress       10-500     180s      30s      Limit identification

────────────────────────────────────────────────────────────────────────────────────

📈 METRICS TRACKED
────────────────────────────────────────────────────────────────────────────────────

REAL-TIME (Every 5 seconds):
  • Active concurrent users
  • Total requests count
  • Success rate (%)
  • Failure rate (%)
  • Average latency (ms)
  • Throughput (req/sec)
  • Per-action breakdown

FINAL SUMMARY:
  • Detailed per-action statistics
  • Success/failure percentages
  • Latency statistics
  • Peak concurrent users
  • Test duration and configuration

────────────────────────────────────────────────────────────────────────────────────

🌐 REST API ENDPOINTS
────────────────────────────────────────────────────────────────────────────────────

Base URL: http://localhost:8081

Health Check:
  GET /api/concurrent-load/health

Quick Test:
  POST /api/concurrent-load/quick-test

Gradual Test:
  POST /api/concurrent-load/gradual
    ?minUsers=10&maxUsers=1000&durationSeconds=300&rampUpSeconds=60

Sustained Test:
  POST /api/concurrent-load/sustained
    ?users=200&durationSeconds=300

Spike Test:
  POST /api/concurrent-load/spike-test

Stress Test:
  POST /api/concurrent-load/stress-test

────────────────────────────────────────────────────────────────────────────────────

🎪 EXAMPLE COMMANDS
────────────────────────────────────────────────────────────────────────────────────

# Quick smoke test
./run-concurrent-load-test.sh TEST_TYPE=quick

# Custom gradual test
MIN_USERS=50 MAX_USERS=500 DURATION=600 RAMP_UP=120 ./run-concurrent-load-test.sh

# All scenarios
./test-all-load-scenarios.sh

# REST API call
curl -X POST "http://localhost:8081/api/concurrent-load/gradual?minUsers=10&maxUsers=1000&durationSeconds=300&rampUpSeconds=60"

# Monitor Kafka
./monitor-kafka-metrics.sh

# Interactive demo
./demo-load-testing.sh

────────────────────────────────────────────────────────────────────────────────────

✅ SUCCESS CRITERIA
────────────────────────────────────────────────────────────────────────────────────

METRIC             TARGET    ACCEPTABLE
─────────────────────────────────────────
Success Rate       > 99%     > 95%
Avg Latency        < 200ms   < 500ms
Consumer Lag       < 10 msg  < 100 msg
Throughput         Linear    Acceptable degradation

────────────────────────────────────────────────────────────────────────────────────

🔧 TROUBLESHOOTING
────────────────────────────────────────────────────────────────────────────────────

Application not running:
  curl http://localhost:8081/actuator/health
  ./mvnw spring-boot:run

Kafka not accessible:
  kafka-broker-api-versions.sh --bootstrap-server localhost:9092
  docker-compose up -d kafka

High failure rate:
  • Check Kafka broker capacity
  • Verify database connection pool
  • Review application logs
  • Increase JVM heap size

────────────────────────────────────────────────────────────────────────────────────

📚 LEARN MORE
────────────────────────────────────────────────────────────────────────────────────

Complete Guide:         cat CONCURRENT_LOAD_TESTING_GUIDE.md
Quick Reference:        cat LOAD_TESTING_QUICK_REFERENCE.md
Implementation Details: cat LOAD_TESTING_IMPLEMENTATION_SUMMARY.md
Architecture:           cat ARCHITECTURE_DIAGRAM.md

────────────────────────────────────────────────────────────────────────────────────

✨ YOU'RE READY TO START! ✨

Run this command to begin:
  ./quick-start-load-test.sh

Happy Load Testing! 🚀

EOF
