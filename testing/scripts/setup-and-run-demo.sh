#!/bin/bash

# ═══════════════════════════════════════════════════════════════════
# Complete Setup and Observability Demo
# ═══════════════════════════════════════════════════════════════════

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}$1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_info() {
    echo -e "${YELLOW}ℹ${NC} $1"
}

# ═══════════════════════════════════════════════════════════════════
# Setup Phase
# ═══════════════════════════════════════════════════════════════════

print_header "OBSERVABILITY DEMO - SETUP PHASE"

print_step "Step 1: Starting Docker services (Kafka, Zookeeper, PostgreSQL)..."
docker-compose up -d
print_success "Docker services started"

echo ""
print_step "Step 2: Waiting for services to be ready (30 seconds)..."
sleep 30
print_success "Services should be ready"

echo ""
print_step "Step 3: Starting Spring Boot application..."
print_info "This may take 30-60 seconds..."

# Kill any existing instance
pkill -f "spring-boot:run" 2>/dev/null || true
sleep 3

# Start application in background
nohup ./mvnw spring-boot:run > app-observability-demo.log 2>&1 &
APP_PID=$!

echo ""
print_info "Application starting... (PID: $APP_PID)"
print_info "Waiting for application to be ready..."

# Wait for application to be ready (up to 2 minutes)
for i in {1..24}; do
    if curl -s http://localhost:8081/actuator/health > /dev/null 2>&1; then
        print_success "Application is ready!"
        break
    fi
    echo -n "."
    sleep 5
done

echo ""
echo ""

# Check if application is actually running
if ! curl -s http://localhost:8081/actuator/health > /dev/null 2>&1; then
    echo -e "${RED}✗${NC} Application failed to start"
    echo "Check app-observability-demo.log for errors"
    exit 1
fi

print_header "SETUP COMPLETE - READY FOR DEMO"

print_success "All services are running:"
echo "  • PostgreSQL: localhost:5432"
echo "  • Kafka: localhost:9092"
echo "  • Application: localhost:8081"
echo "  • Kafka UI: http://localhost:8080"
echo ""

print_info "Opening Kafka UI in browser..."
# Try to open browser
if command -v open &> /dev/null; then
    open "http://localhost:8080" 2>/dev/null || true
fi

echo ""
print_step "Press ENTER to start the observability demo..."
read

# ═══════════════════════════════════════════════════════════════════
# Run Demo
# ═══════════════════════════════════════════════════════════════════

./observability-demo.sh

print_header "DEMO COMPLETE"
print_info "To stop all services:"
echo "  • Stop application: pkill -f 'spring-boot:run'"
echo "  • Stop Docker: docker-compose down"
echo ""
