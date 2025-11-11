#!/bin/bash

###############################################################################
# Demo Cleanup Script
# Stops all services and cleans up demo environment
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              DEMO CLEANUP                                ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Confirmation
###############################################################################
echo -e "${YELLOW}⚠  WARNING: This will stop all services and clean up data${NC}"
echo ""
echo "The following will be cleaned:"
echo "  • Spring Boot application"
echo "  • Docker containers (PostgreSQL, Kafka, Zookeeper)"
echo "  • Docker volumes (database data, Kafka topics)"
echo "  • Temporary demo files"
echo ""
echo -e "${YELLOW}Press ENTER to continue or Ctrl+C to cancel...${NC}"
read

echo ""

###############################################################################
# Step 1: Stop Spring Boot application
###############################################################################
echo -e "${YELLOW}[1/5]${NC} Stopping Spring Boot application..."

if [ -f app.pid ]; then
    APP_PID=$(cat app.pid)
    if ps -p $APP_PID > /dev/null 2>&1; then
        echo "   Stopping process $APP_PID..."
        kill $APP_PID 2>/dev/null || true
        sleep 3
        
        # Force kill if still running
        if ps -p $APP_PID > /dev/null 2>&1; then
            echo "   Force killing process $APP_PID..."
            kill -9 $APP_PID 2>/dev/null || true
        fi
    fi
    rm -f app.pid
fi

# Fallback: kill by process name
if pgrep -f "spring-boot:run" > /dev/null; then
    echo "   Killing remaining Spring Boot processes..."
    pkill -f "spring-boot:run" || true
    sleep 2
fi

echo -e "${GREEN}✓${NC} Spring Boot application stopped"
echo ""

###############################################################################
# Step 2: Stop Docker containers
###############################################################################
echo -e "${YELLOW}[2/5]${NC} Stopping Docker containers..."

docker compose down

echo -e "${GREEN}✓${NC} Docker containers stopped"
echo ""

###############################################################################
# Step 3: Remove Docker volumes
###############################################################################
echo -e "${YELLOW}[3/5]${NC} Cleaning Docker volumes..."

# Remove project volumes
docker compose down -v 2>/dev/null || true

# Prune unused volumes
docker volume prune -f > /dev/null 2>&1

echo -e "${GREEN}✓${NC} Docker volumes cleaned"
echo ""

###############################################################################
# Step 4: Clean temporary files
###############################################################################
echo -e "${YELLOW}[4/5]${NC} Removing temporary files..."

# Remove demo environment files
rm -f /tmp/demo_users.env
rm -f /tmp/demo_order.env

# Remove application logs
rm -f app.log
rm -f nohup.out

# Remove any leftover PID files
rm -f *.pid

echo -e "${GREEN}✓${NC} Temporary files removed"
echo ""

###############################################################################
# Step 5: Archive demo logs (optional)
###############################################################################
echo -e "${YELLOW}[5/5]${NC} Archiving demo session (optional)..."

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
ARCHIVE_DIR="demo_archive_${TIMESTAMP}"

if [ -f app.log ] || ls *.log 1> /dev/null 2>&1; then
    mkdir -p "$ARCHIVE_DIR"
    
    # Archive any log files
    if [ -f app.log ]; then
        cp app.log "$ARCHIVE_DIR/" 2>/dev/null || true
    fi
    
    # Archive configuration backups if they exist
    if [ -d config_backup_* ]; then
        cp -r config_backup_* "$ARCHIVE_DIR/" 2>/dev/null || true
    fi
    
    echo -e "${GREEN}✓${NC} Logs archived to $ARCHIVE_DIR"
else
    echo -e "${CYAN}ℹ${NC}  No logs to archive"
fi

echo ""

###############################################################################
# Verification
###############################################################################
echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}"
echo ""
echo "Cleanup verification:"
echo ""

# Check Spring Boot
if pgrep -f "spring-boot:run" > /dev/null; then
    echo -e "  Spring Boot: ${RED}✗ Still running${NC}"
else
    echo -e "  Spring Boot: ${GREEN}✓ Stopped${NC}"
fi

# Check Docker
RUNNING_CONTAINERS=$(docker ps --filter "name=ads-" --format "{{.Names}}" 2>/dev/null)
if [ -z "$RUNNING_CONTAINERS" ]; then
    echo -e "  Docker:      ${GREEN}✓ No containers running${NC}"
else
    echo -e "  Docker:      ${YELLOW}⚠ Containers still running:${NC}"
    echo "$RUNNING_CONTAINERS" | sed 's/^/               /'
fi

# Check volumes
ADS_VOLUMES=$(docker volume ls --filter "name=ads" --format "{{.Name}}" 2>/dev/null)
if [ -z "$ADS_VOLUMES" ]; then
    echo -e "  Volumes:     ${GREEN}✓ Cleaned${NC}"
else
    echo -e "  Volumes:     ${YELLOW}⚠ Some volumes remain${NC}"
fi

# Check temp files
if [ -f /tmp/demo_users.env ] || [ -f /tmp/demo_order.env ]; then
    echo -e "  Temp Files:  ${YELLOW}⚠ Some temp files remain${NC}"
else
    echo -e "  Temp Files:  ${GREEN}✓ Cleaned${NC}"
fi

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║              CLEANUP COMPLETED ✅                         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Your system is now clean and ready for the next demo session."
echo ""
echo "To run another demo:"
echo "  ./scripts/demo-setup.sh"
echo ""

if [ -d "$ARCHIVE_DIR" ]; then
    echo "Demo logs archived in: $ARCHIVE_DIR"
    echo ""
fi
