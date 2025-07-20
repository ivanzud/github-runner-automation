#!/bin/bash

# Installation script for GitHub Runner Auto-Registration
# This script sets up the automated runner registration system

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root"
        exit 1
    fi
}

# Install dependencies
install_dependencies() {
    log "Installing dependencies..."
    
    # Detect OS and install dependencies
    if command -v apt-get &> /dev/null; then
        # Debian/Ubuntu
        apt-get update
        apt-get install -y jq curl git systemd
    elif command -v yum &> /dev/null; then
        # CentOS/RHEL
        yum install -y jq curl git systemd
    elif command -v dnf &> /dev/null; then
        # Fedora
        dnf install -y jq curl git systemd
    else
        error "Unsupported package manager. Please install jq, curl, and git manually."
        exit 1
    fi
    
    log "Dependencies installed successfully."
}

# Create directories and copy files
setup_files() {
    log "Setting up files and directories..."
    
    # Create scripts directory
    mkdir -p /opt/scripts
    
    # Copy the auto-registration script
    cp auto-register-runners.sh /opt/scripts/
    chmod +x /opt/scripts/auto-register-runners.sh
    
    # Copy systemd files
    cp github-runner-auto-register.service /etc/systemd/system/
    cp github-runner-auto-register.timer /etc/systemd/system/
    
    # Create log directory
    mkdir -p /var/log
    touch /var/log/github-runner-auto-register.log
    chmod 644 /var/log/github-runner-auto-register.log
    
    log "Files set up successfully."
}

# Configure GitHub token
configure_token() {
    log "Configuring GitHub token..."
    
    echo "Please enter your GitHub Personal Access Token:"
    echo "This token needs the following permissions:"
    echo "- repo (Full control of private repositories)"
    echo "- admin:org (Full control of organizations and teams)"
    echo ""
    read -s -p "GitHub Token: " github_token
    echo ""
    
    if [ -z "$github_token" ]; then
        error "GitHub token is required"
        exit 1
    fi
    
    # Test the token
    local response=$(curl -s -H "Authorization: token $github_token" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user")
    
    if echo "$response" | jq -e '.login' > /dev/null 2>&1; then
        local username=$(echo "$response" | jq -r '.login')
        log "GitHub token is valid. Authenticated as: $username"
    else
        error "Invalid GitHub token. Please check your token."
        exit 1
    fi
    
    # Store token securely
    echo "$github_token" > /etc/github-runner-token
    chmod 600 /etc/github-runner-token
    
    log "GitHub token configured successfully."
}

# Enable and start services
enable_services() {
    log "Enabling and starting services..."
    
    # Reload systemd
    systemctl daemon-reload
    
    # Enable the timer
    systemctl enable github-runner-auto-register.timer
    
    # Start the timer
    systemctl start github-runner-auto-register.timer
    
    # Run the service once immediately
    systemctl start github-runner-auto-register.service
    
    log "Services enabled and started successfully."
}

# Create a manual trigger script
create_manual_trigger() {
    log "Creating manual trigger script..."
    
    cat > /usr/local/bin/register-github-runners << 'EOF'
#!/bin/bash
# Manual trigger for GitHub runner registration

if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Read token from file
if [ ! -f /etc/github-runner-token ]; then
    echo "GitHub token not found. Please run the installation script first."
    exit 1
fi

export GITHUB_TOKEN=$(cat /etc/github-runner-token)
/opt/scripts/auto-register-runners.sh
EOF
    
    chmod +x /usr/local/bin/register-github-runners
    
    log "Manual trigger script created: /usr/local/bin/register-github-runners"
}

# Show status
show_status() {
    log "Installation completed successfully!"
    echo ""
    echo "=== Installation Summary ==="
    echo "✅ Auto-registration script: /opt/scripts/auto-register-runners.sh"
    echo "✅ Systemd service: github-runner-auto-register.service"
    echo "✅ Systemd timer: github-runner-auto-register.timer"
    echo "✅ Manual trigger: /usr/local/bin/register-github-runners"
    echo "✅ Log file: /var/log/github-runner-auto-register.log"
    echo ""
    echo "=== Service Status ==="
    systemctl status github-runner-auto-register.timer --no-pager -l
    echo ""
    echo "=== Timer Status ==="
    systemctl list-timers github-runner-auto-register.timer --no-pager
    echo ""
    echo "=== Usage ==="
    echo "• The service will automatically run every 30 minutes"
    echo "• To run manually: sudo /usr/local/bin/register-github-runners"
    echo "• To check logs: sudo journalctl -u github-runner-auto-register.service"
    echo "• To disable: sudo systemctl disable github-runner-auto-register.timer"
}

# Main installation function
main() {
    log "Starting GitHub Runner Auto-Registration installation..."
    
    check_root
    install_dependencies
    setup_files
    configure_token
    enable_services
    create_manual_trigger
    show_status
}

# Run main function
main "$@" 