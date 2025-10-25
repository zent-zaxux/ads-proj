#!/bin/bash
set -euo pipefail

# Quick experiments: vary Kafka listener concurrency and Hikari pool size
# For each config: restart application with external application.properties,
# run 1 stress-test session (duration 30s) and save results.

BASE_DIR="$(pwd)"
JAR="${BASE_DIR}/target/ads-proj-0.0.1-SNAPSHOT.jar"
EXPERIMENT_DIR="experiments"
mkdir -p "${EXPERIMENT_DIR}"

# Lists to try
CONCURRENCY_LIST=(1 3 5 8 10)
POOL_LIST=(10 20 40)

# Ensure external application.properties file exists at repo root
if [ ! -f "${BASE_DIR}/application.properties" ]; then
  echo "Copying src/main/resources/application.properties -> ./application.properties"
  cp src/main/resources/application.properties ./application.properties
fi

# Backup
cp application.properties application.properties.bak

start_app(){
  pkill -f "ads-proj-0.0.1-SNAPSHOT.jar" || true
  sleep 2
  nohup java -Xmx1g -Xms512m -XX:+UseG1GC -jar "${JAR}" --spring.config.location=file:./application.properties > app.log 2>&1 &
  APP_PID=$!
  echo "Started app PID=${APP_PID}"
  # Wait for health
  for i in {1..60}; do
    if curl -s http://localhost:8081/actuator/health | grep -q UP; then
      echo "Application is healthy"
      break
    fi
    if [ $i -eq 60 ]; then
      echo "Application failed to start"
      tail -n 100 app.log
      exit 1
    fi
    sleep 2
  done
}

# Start app initially
start_app

# Run experiments
for c in "${CONCURRENCY_LIST[@]}"; do
  for p in "${POOL_LIST[@]}"; do
    echo "\n=== Experiment: concurrency=${c}, hikari.maxPool=${p} ==="
    # Modify application.properties (replace lines or append)
    sed -i.bak "/^spring.kafka.listener.concurrency=/d" application.properties || true
    sed -i.bak "/^spring.datasource.hikari.maximum-pool-size=/d" application.properties || true
    echo "spring.kafka.listener.concurrency=${c}" >> application.properties
    echo "spring.datasource.hikari.maximum-pool-size=${p}" >> application.properties

    # Restart app to pick up external config
    pkill -f "ads-proj-0.0.1-SNAPSHOT.jar" || true
    sleep 2
    nohup java -Xmx1g -Xms512m -XX:+UseG1GC -jar "${JAR}" --spring.config.location=file:./application.properties > app.log 2>&1 &
    APP_PID=$!
    echo "Started app PID=${APP_PID} with concurrency=${c}, pool=${p}"

    # Wait for health
    for i in {1..60}; do
      if curl -s http://localhost:8081/actuator/health | grep -q UP; then
        echo "Application is healthy"
        break
      fi
      if [ $i -eq 60 ]; then
        echo "Application failed to start"
        tail -n 100 app.log
        exit 1
      fi
      sleep 2
    done

    # Run one short stress session
    echo "Running short stress-test (1 session, 30s)"
    NUM_SESSIONS=1 DURATION=30 ./stress-test.sh > "${EXPERIMENT_DIR}/run_${c}_${p}.log" 2>&1 || true

    # Move CSV and logs
    if [ -f scaling_results.csv ]; then
      mv scaling_results.csv "${EXPERIMENT_DIR}/scaling_conc${c}_pool${p}.csv"
    fi
    TIMESTAMP_DIR=$(ls -td test-logs/* | head -n1 2>/dev/null || true)
    if [ -n "${TIMESTAMP_DIR}" ]; then
      mkdir -p "${EXPERIMENT_DIR}/logs_conc${c}_pool${p}"
      cp -r "${TIMESTAMP_DIR}"/* "${EXPERIMENT_DIR}/logs_conc${c}_pool${p}/" || true
    fi

    echo "Experiment completed: results -> ${EXPERIMENT_DIR}/scaling_conc${c}_pool${p}.csv"
    # short cooldown
    sleep 5
  done
done

# Restore original application.properties
mv application.properties.bak application.properties || true

# Restart app with original config
pkill -f "ads-proj-0.0.1-SNAPSHOT.jar" || true
sleep 2
nohup java -Xmx1g -Xms512m -XX:+UseG1GC -jar "${JAR}" --spring.config.location=file:./application.properties > app.log 2>&1 &
APP_PID=$!

echo "Experiments finished. App restarted with original config (PID=${APP_PID})."

# Summarize experiments - basic parsing
echo "session,concurrency,pool,total_requests,successful,failed,success_rate,throughput" > "${EXPERIMENT_DIR}/experiments_summary.csv"
for f in ${EXPERIMENT_DIR}/scaling_conc*_pool*.csv; do
  [ -f "$f" ] || continue
  concurrency=$(echo "$f" | sed -n 's/.*scaling_conc\([0-9]*\)_pool\([0-9]*\)\.csv/\1/p')
  pool=$(echo "$f" | sed -n 's/.*scaling_conc\([0-9]*\)_pool\([0-9]*\)\.csv/\2/p')
  # read first data line
  data_line=$(tail -n +2 "$f" | head -n1)
  if [ -n "$data_line" ]; then
    total=$(echo "$data_line" | awk -F',' '{print $5}')
    success=$(echo "$data_line" | awk -F',' '{print $6}')
    failed=$(echo "$data_line" | awk -F',' '{print $7}')
    rate=$(echo "$data_line" | awk -F',' '{print $8}')
    throughput=$(echo "$data_line" | awk -F',' '{print $10}')
    echo ",${concurrency},${pool},${total},${success},${failed},${rate},${throughput}" >> "${EXPERIMENT_DIR}/experiments_summary.csv"
  fi
done

echo "Experiment summary saved to ${EXPERIMENT_DIR}/experiments_summary.csv"
