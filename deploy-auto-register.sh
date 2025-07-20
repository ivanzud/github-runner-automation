#!/bin/bash

# Deploy GitHub Runner Auto-Registration System
# This script deploys the auto-registration system using Ansible

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

# Check if we're in the right directory
check_directory() {
    if [ ! -f "ansible/deploy-auto-register.yml" ]; then
        error "This script must be run from the project root directory"
        exit 1
    fi
}

# Check if Ansible is installed
check_ansible() {
    if ! command -v ansible-playbook &> /dev/null; then
        error "Ansible is not installed. Please install it first."
        exit 1
    fi
}

# Check if vault file exists and is encrypted
check_vault() {
    local vault_file="ansible/group_vars/runner-hosts/vault.yml"
    
    if [ ! -f "$vault_file" ]; then
        error "Vault file not found: $vault_file"
        echo "Please create and configure the vault file first."
        exit 1
    fi
    
    # Check if file is encrypted (contains "!vault" at the beginning)
    if ! head -n1 "$vault_file" | grep -q "^\$ANSIBLE_VAULT"; then
        warn "Vault file is not encrypted. Please encrypt it with:"
        echo "  ansible-vault encrypt $vault_file"
        echo ""
        read -p "Do you want to encrypt it now? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ansible-vault encrypt "$vault_file"
        else
            error "Vault file must be encrypted to proceed"
            exit 1
        fi
    fi
}

# Show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -i, --inventory FILE    Use specified inventory file (default: ansible/inventory/hosts)"
    echo "  -l, --limit HOSTS       Limit execution to specific hosts"
    echo "  -c, --check             Run in check mode (dry-run)"
    echo "  -v, --verbose           Verbose output"
    echo "  --vault-password-file   Path to vault password file"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy to all runner hosts"
    echo "  $0 -l runner1                         # Deploy to specific host"
    echo "  $0 -c                                 # Dry-run deployment"
    echo "  $0 -v --vault-password-file .vault   # Verbose with vault password file"
}

# Parse command line arguments
parse_args() {
    INVENTORY="ansible/inventory/hosts"
    LIMIT=""
    CHECK_MODE=""
    VERBOSE=""
    VAULT_PASSWORD_FILE=""
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_usage
                exit 0
                ;;
            -i|--inventory)
                INVENTORY="$2"
                shift 2
                ;;
            -l|--limit)
                LIMIT="$2"
                shift 2
                ;;
            -c|--check)
                CHECK_MODE="--check"
                shift
                ;;
            -v|--verbose)
                VERBOSE="-v"
                shift
                ;;
            --vault-password-file)
                VAULT_PASSWORD_FILE="--vault-password-file $2"
                shift 2
                ;;
            *)
                error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

# Build ansible-playbook command
build_command() {
    local cmd="ansible-playbook"
    
    cmd="$cmd -i $INVENTORY"
    cmd="$cmd ansible/deploy-auto-register.yml"
    
    if [ -n "$LIMIT" ]; then
        cmd="$cmd -l $LIMIT"
    fi
    
    if [ -n "$CHECK_MODE" ]; then
        cmd="$cmd $CHECK_MODE"
    fi
    
    if [ -n "$VERBOSE" ]; then
        cmd="$cmd $VERBOSE"
    fi
    
    if [ -n "$VAULT_PASSWORD_FILE" ]; then
        cmd="$cmd $VAULT_PASSWORD_FILE"
    fi
    
    echo "$cmd"
}

# Main deployment function
main() {
    log "Starting GitHub Runner Auto-Registration deployment..."
    
    check_directory
    check_ansible
    check_vault
    
    log "Checking inventory..."
    if [ ! -f "$INVENTORY" ]; then
        error "Inventory file not found: $INVENTORY"
        exit 1
    fi
    
    # Check if runner-hosts group exists in inventory
    if ! grep -q "^\[runner-hosts\]" "$INVENTORY"; then
        error "No [runner-hosts] group found in inventory: $INVENTORY"
        echo "Please add your runner hosts to the [runner-hosts] group."
        exit 1
    fi
    
    # Check if any runner hosts are defined
    local runner_hosts=$(ansible-inventory -i "$INVENTORY" --list | jq -r '.runner-hosts.hosts[]?' 2>/dev/null || echo "")
    if [ -z "$runner_hosts" ]; then
        warn "No runner hosts found in inventory"
        echo "Please add your runner hosts to the [runner-hosts] group in $INVENTORY"
        echo "Example:"
        echo "  [runner-hosts]"
        echo "  runner1 ansible_host=192.168.1.100"
        exit 1
    fi
    
    log "Found runner hosts: $runner_hosts"
    
    # Build and execute command
    local cmd=$(build_command)
    log "Executing: $cmd"
    
    if [ -n "$CHECK_MODE" ]; then
        log "Running in check mode (no changes will be made)"
    fi
    
    # Execute the command
    eval "$cmd"
    
    if [ $? -eq 0 ]; then
        log "Deployment completed successfully!"
        
        if [ -z "$CHECK_MODE" ]; then
            echo ""
            echo "=== Next Steps ==="
            echo "1. Check the auto-registration logs:"
            echo "   sudo journalctl -u github-runner-auto-register.service"
            echo ""
            echo "2. Run manual registration:"
            echo "   sudo /usr/local/bin/register-github-runners"
            echo ""
            echo "3. Check timer status:"
            echo "   sudo systemctl status github-runner-auto-register.timer"
            echo ""
            echo "4. Monitor registered runners:"
            echo "   sudo systemctl list-units --type=service | grep github-runner"
        fi
    else
        error "Deployment failed!"
        exit 1
    fi
}

# Parse arguments and run main function
parse_args "$@"
main 