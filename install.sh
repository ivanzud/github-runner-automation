#!/bin/bash

# GitHub Runner Automation - One-Command Installer
# This script deploys the complete GitHub Runner Automation system

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

# Check if Ansible is installed
check_ansible() {
    if ! command -v ansible &> /dev/null; then
        error "Ansible is required but not installed."
        echo "Please install Ansible first:"
        echo "  Ubuntu/Debian: sudo apt install ansible"
        echo "  macOS: brew install ansible"
        echo "  Or visit: https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html"
        exit 1
    fi
}

# Check if inventory file exists
check_inventory() {
    if [ ! -f "inventory/hosts" ]; then
        error "Inventory file 'inventory/hosts' not found."
        echo "Please create the inventory file with your server details first."
        exit 1
    fi
}

# Check if vault file exists
check_vault() {
    if [ ! -f "group_vars/runner-hosts/vault.yml" ]; then
        error "Vault file 'group_vars/runner-hosts/vault.yml' not found."
        echo "Please create the vault file with your GitHub token and configuration first."
        exit 1
    fi
}

# Test SSH connectivity
test_connectivity() {
    log "Testing SSH connectivity to servers..."
    
    if ! ansible runner-hosts -m ping; then
        error "SSH connectivity test failed."
        echo "Please check your SSH configuration and server connectivity."
        exit 1
    fi
    
    log "SSH connectivity test passed."
}

# Deploy the automation
deploy_automation() {
    log "Starting deployment of GitHub Runner Automation..."
    
    # Run the production deployment playbook
    if ansible-playbook -i inventory/hosts deploy-production.yml; then
        log "Deployment completed successfully!"
    else
        error "Deployment failed. Please check the error messages above."
        exit 1
    fi
}

# Display status
show_status() {
    log "Checking deployment status..."
    
    echo ""
    echo "=== DEPLOYMENT STATUS ==="
    echo ""
    
    # Check automation status
    ansible runner-hosts -m shell -a "systemctl status github-runner-auto-register.timer --no-pager" || true
    
    echo ""
    echo "=== ACTIVE RUNNERS ==="
    echo ""
    
    # Check active runners
    ansible runner-hosts -m shell -a "systemctl list-units --type=service | grep github-runner" || true
    
    echo ""
    echo "=== NEXT STEPS ==="
    echo ""
    echo "1. Your GitHub Runner Automation is now deployed!"
    echo "2. The system will automatically scan for repositories every 5 minutes"
    echo "3. Runners will be registered for repositories with 'runs-on: self-hosted' workflows"
    echo "4. You can monitor the system using the web interface:"
    echo "   cd web-gui && ./start.sh"
    echo "5. View logs: tail -f /var/log/github-runner-auto-register.log"
    echo ""
}

# Main function
main() {
    echo ""
    echo "🚀 GitHub Runner Automation - One-Command Installer"
    echo "=================================================="
    echo ""
    
    # Check prerequisites
    check_ansible
    check_inventory
    check_vault
    
    # Test connectivity
    test_connectivity
    
    # Deploy automation
    deploy_automation
    
    # Show status
    show_status
    
    echo "✅ Installation completed successfully!"
}

# Run main function
main "$@" 