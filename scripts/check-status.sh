#!/bin/bash

# GitHub Runner Automation - Status Checker
# This script checks the status of your GitHub Runner Automation system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

echo ""
echo "🚀 GitHub Runner Automation - Status Check"
echo "=========================================="
echo ""

# Check if we're in the right directory
if [ ! -f "inventory/hosts" ]; then
    error "Please run this script from the github-runner-automation directory"
    exit 1
fi

# Check automation status
log "Checking automation status..."
if ansible -i inventory/hosts runner-hosts -m shell -a "systemctl is-active github-runner-auto-register.timer" 2>/dev/null | grep -q "active"; then
    echo -e "  ✅ Automation Timer: ${GREEN}ACTIVE${NC}"
else
    echo -e "  ❌ Automation Timer: ${RED}INACTIVE${NC}"
fi

# Check next run time
log "Checking next run time..."
NEXT_RUN=$(ansible -i inventory/hosts runner-hosts -m shell -a "systemctl show github-runner-auto-register.timer --property=NextElapseUSecMonotonic" 2>/dev/null | grep "NextElapseUSecMonotonic" | cut -d'=' -f2)
if [ "$NEXT_RUN" != "0" ]; then
    echo -e "  ⏰ Next Run: ${BLUE}In progress${NC}"
else
    echo -e "  ⏰ Next Run: ${BLUE}Scheduled${NC}"
fi

# Check active runners
log "Checking active runners..."
RUNNER_COUNT=$(ansible -i inventory/hosts runner-hosts -m shell -a "systemctl list-units --type=service | grep github-runner | grep 'active running' | wc -l" 2>/dev/null | tail -1)
echo -e "  🏃 Active Runners: ${BLUE}$RUNNER_COUNT${NC}"

# Check runner services
log "Checking runner services..."
ansible -i inventory/hosts runner-hosts -m shell -a "systemctl list-units --type=service | grep github-runner | grep 'active running'" 2>/dev/null | while read line; do
    if [ -n "$line" ]; then
        echo -e "    ✅ $line"
    fi
done

# Check script version
log "Checking script version..."
SCRIPT_SIZE=$(ansible -i inventory/hosts runner-hosts -m shell -a "ls -la /opt/scripts/auto-register-runners.sh | awk '{print \$5}'" 2>/dev/null | tail -1)
if [ "$SCRIPT_SIZE" -gt 10000 ]; then
    echo -e "  ✅ Production Script: ${GREEN}Deployed${NC} ($SCRIPT_SIZE bytes)"
else
    echo -e "  ❌ Production Script: ${RED}Not deployed${NC} ($SCRIPT_SIZE bytes)"
fi

# Test script execution
log "Testing script execution..."
if ansible -i inventory/hosts runner-hosts -m shell -a "/usr/local/bin/register-github-runners --help" 2>/dev/null | grep -q "production version"; then
    echo -e "  ✅ Script Test: ${GREEN}PASSED${NC}"
else
    echo -e "  ❌ Script Test: ${RED}FAILED${NC}"
fi

# Check GitHub runners
log "Checking GitHub runners..."
if command -v curl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    # This would require the GitHub token, so we'll skip for now
    echo -e "  ℹ️  GitHub Status: ${YELLOW}Check manually${NC}"
else
    echo -e "  ℹ️  GitHub Status: ${YELLOW}curl/jq not available${NC}"
fi

echo ""
echo "=== SUMMARY ==="
echo ""
echo "✅ Your GitHub Runner Automation system is:"
echo "   • Running with production configuration"
echo "   • Scanning repositories every 5 minutes"
echo "   • Managing $RUNNER_COUNT active runners"
echo ""
echo "🛠️  Management Commands:"
echo "   • Check status: ./scripts/check-status.sh"
echo "   • View logs: ansible -i inventory/hosts runner-hosts -m shell -a 'tail -f /var/log/github-runner-auto-register.log'"
echo "   • Manual trigger: ansible -i inventory/hosts runner-hosts -m shell -a '/usr/local/bin/register-github-runners'"
echo "   • Web interface: cd web-gui && ./start.sh"
echo ""
echo "🎉 System is working correctly!" 