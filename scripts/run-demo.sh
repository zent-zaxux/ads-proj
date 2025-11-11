#!/bin/bash

###############################################################################
# Master Demo Runner
# Orchestrates complete demo workflow with automated execution
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                          ║${NC}"
echo -e "${MAGENTA}║         EVENT-DRIVEN ORDER SYSTEM - LIVE DEMO            ║${NC}"
echo -e "${MAGENTA}║                                                          ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

###############################################################################
# Demo Mode Selection
###############################################################################
echo -e "${YELLOW}Select demo mode:${NC}"
echo ""
echo "  1. Full Automated Demo  (runs all parts automatically)"
echo "  2. Interactive Demo     (pause between each part)"
echo "  3. Quick Demo           (essential parts only)"
echo "  4. Custom Demo          (select specific parts)"
echo ""
echo -ne "${CYAN}Enter choice [1-4]: ${NC}"
read DEMO_MODE

echo ""

case $DEMO_MODE in
    1)
        MODE="automated"
        PAUSE_BETWEEN=5
        ;;
    2)
        MODE="interactive"
        PAUSE_BETWEEN=0
        ;;
    3)
        MODE="quick"
        PAUSE_BETWEEN=3
        ;;
    4)
        MODE="custom"
        PAUSE_BETWEEN=0
        ;;
    *)
        echo -e "${RED}Invalid choice. Defaulting to interactive mode.${NC}"
        MODE="interactive"
        PAUSE_BETWEEN=0
        ;;
esac

echo ""

###############################################################################
# Custom Mode Part Selection
###############################################################################
RUN_SETUP=true
RUN_USERS=true
RUN_ORDERS=true
RUN_NOTIFICATIONS=true
RUN_TRAFFIC=true
RUN_FULFILLMENT=true
RUN_SUMMARY=true

if [ "$MODE" = "custom" ]; then
    echo -e "${YELLOW}Select parts to run (y/n):${NC}"
    echo ""
    
    echo -ne "  Setup environment? [Y/n]: "
    read RESP
    [[ "$RESP" =~ ^[Nn]$ ]] && RUN_SETUP=false
    
    echo -ne "  User Registration? [Y/n]: "
    read RESP
    [[ "$RESP" =~ ^[Nn]$ ]] && RUN_USERS=false
    
    echo -ne "  Order Creation? [Y/n]: "
    read RESP
    [[ "$RESP" =~ ^[Nn]$ ]] && RUN_ORDERS=false
    
    echo -ne "  Notifications? [Y/n]: "
    read RESP
    [[ "$RESP" =~ ^[Nn]$ ]] && RUN_NOTIFICATIONS=false
    
    echo -ne "  Traffic Simulation? [Y/n]: "
    read RESP
    [[ "$RESP" =~ ^[Nn]$ ]] && RUN_TRAFFIC=false
    
    echo -ne "  Fulfillment Agent? [Y/n]: "
    read RESP
    [[ "$RESP" =~ ^[Nn]$ ]] && RUN_FULFILLMENT=false
    
    echo -ne "  Summary Report? [Y/n]: "
    read RESP
    [[ "$RESP" =~ ^[Nn]$ ]] && RUN_SUMMARY=false
    
    echo ""
fi

# Quick mode adjustments
if [ "$MODE" = "quick" ]; then
    RUN_FULFILLMENT=false
fi

###############################################################################
# Helper Functions
###############################################################################
pause_demo() {
    if [ "$MODE" = "interactive" ]; then
        echo ""
        echo -e "${CYAN}Press ENTER to continue to next part...${NC}"
        read
    elif [ "$PAUSE_BETWEEN" -gt 0 ]; then
        echo ""
        echo -e "${CYAN}Continuing in $PAUSE_BETWEEN seconds...${NC}"
        sleep $PAUSE_BETWEEN
    fi
}

run_part() {
    local script_name=$1
    local part_title=$2
    
    echo ""
    echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║  $part_title${NC}"
    echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    if [ "$MODE" = "automated" ]; then
        # In automated mode, skip manual prompts
        export DEMO_AUTO_MODE=1
    fi
    
    bash "$SCRIPT_DIR/$script_name"
    
    unset DEMO_AUTO_MODE
}

###############################################################################
# Demo Execution
###############################################################################
START_TIME=$(date +%s)

echo -e "${BLUE}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Starting Demo in $MODE mode...${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Part 0: Setup
if [ "$RUN_SETUP" = true ]; then
    run_part "demo-setup.sh" "PART 0: Environment Setup                            "
    pause_demo
fi

# Part 1: User Registration
if [ "$RUN_USERS" = true ]; then
    run_part "demo-1-users.sh" "PART 1: User Registration + Events                   "
    pause_demo
fi

# Part 2: Order Creation
if [ "$RUN_ORDERS" = true ]; then
    run_part "demo-2-orders.sh" "PART 2: Order Creation + Event Flow                  "
    pause_demo
fi

# Part 3: Notifications
if [ "$RUN_NOTIFICATIONS" = true ]; then
    run_part "demo-3-notifications.sh" "PART 3: Notification System                          "
    pause_demo
fi

# Part 4: Traffic Simulation
if [ "$RUN_TRAFFIC" = true ]; then
    run_part "demo-4-traffic.sh" "PART 4: Traffic Simulation                           "
    pause_demo
fi

# Part 5: Fulfillment Agent
if [ "$RUN_FULFILLMENT" = true ]; then
    run_part "demo-5-fulfillment.sh" "PART 5: Fulfillment & Traffic Agents                 "
    pause_demo
fi

# Summary
if [ "$RUN_SUMMARY" = true ]; then
    run_part "demo-summary.sh" "SUMMARY: Final Report                                "
fi

###############################################################################
# Demo Completion
###############################################################################
END_TIME=$(date +%s)
TOTAL_TIME=$((END_TIME - START_TIME))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo ""
echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                                                          ║${NC}"
echo -e "${MAGENTA}║              DEMO COMPLETED SUCCESSFULLY! 🎉              ║${NC}"
echo -e "${MAGENTA}║                                                          ║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo "Demo Statistics:"
echo "  Mode:          $MODE"
echo "  Duration:      ${MINUTES}m ${SECONDS}s"
echo "  Parts Run:     "
[ "$RUN_SETUP" = true ] && echo "    ✓ Setup"
[ "$RUN_USERS" = true ] && echo "    ✓ User Registration"
[ "$RUN_ORDERS" = true ] && echo "    ✓ Order Creation"
[ "$RUN_NOTIFICATIONS" = true ] && echo "    ✓ Notifications"
[ "$RUN_TRAFFIC" = true ] && echo "    ✓ Traffic Simulation"
[ "$RUN_FULFILLMENT" = true ] && echo "    ✓ Fulfillment Agent"
[ "$RUN_SUMMARY" = true ] && echo "    ✓ Summary Report"

echo ""
echo "Next Steps:"
echo "  • Review detailed metrics in the summary above"
echo "  • Check application logs: tail -f app.log"
echo "  • Monitor Kafka: docker exec -it ads-kafka ..."
echo "  • Query database: docker exec -it ads-postgres psql -U adsuser -d adsdb"
echo ""
echo "When finished:"
echo "  • Run cleanup: ./scripts/demo-cleanup.sh"
echo ""
echo -e "${GREEN}Thank you for watching the demonstration! ✨${NC}"
echo ""
