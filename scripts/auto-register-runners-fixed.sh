#!/bin/bash

# Auto-register GitHub Runners for repositories with self-hosted configurations
# This script automatically detects repositories that need runners and registers them

set -e

# Configuration
GITHUB_TOKEN="${GITHUB_TOKEN:-}"
GITHUB_USERNAME="${GITHUB_USERNAME:-ivanzud}"
RUNNER_LABELS="${RUNNER_LABELS:-self-hosted,linux,x64,ansible,test}"
RUNNER_NAME_PREFIX="${RUNNER_NAME_PREFIX:-test-runner}"
RUNNER_WORK_DIR="${RUNNER_WORK_DIR:-/opt/github-runners}"
RUNNER_USER="${RUNNER_USER:-github-runner}"
LOG_FILE="/var/log/github-runner-auto-register.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function - redirect to stderr to avoid interfering with command substitution
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE" >&2
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE" >&2
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE" >&2
}

# Check if required tools are installed
check_dependencies() {
    log "Checking dependencies..."
    
    if ! command -v jq &> /dev/null; then
        error "jq is required but not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        error "curl is required but not installed. Please install it first."
        exit 1
    fi
    
    if ! command -v git &> /dev/null; then
        error "git is required but not installed. Please install it first."
        exit 1
    fi
    
    log "All dependencies are installed."
}

# Check if GitHub token is valid
check_github_token() {
    log "Validating GitHub token..."
    
    if [ -z "$GITHUB_TOKEN" ]; then
        error "GITHUB_TOKEN environment variable is not set."
        exit 1
    fi
    
    # Test the token by making a request to GitHub API
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/user")
    
    if echo "$response" | jq -e '.login' > /dev/null 2>&1; then
        local username=$(echo "$response" | jq -r '.login')
        log "GitHub token is valid. Authenticated as: $username"
        GITHUB_USERNAME="$username"
    else
        error "Invalid GitHub token. Please check your token."
        exit 1
    fi
}

# Get list of repositories that need runners
get_repositories_needing_runners() {
    log "Fetching repositories that need runners..."
    
    local repos=()
    local page=1
    local per_page=100
    
    while true; do
        local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
            -H "Accept: application/vnd.github.v3+json" \
            "https://api.github.com/user/repos?page=$page&per_page=$per_page&type=owner")
        
        local repos_in_page=$(echo "$response" | jq -r '.[] | select(.fork == false) | .full_name')
        
        if [ -z "$repos_in_page" ]; then
            break
        fi
        
        # Check each repository for self-hosted runner configurations
        while IFS= read -r repo; do
            if [ -n "$repo" ]; then
                if repository_needs_runner "$repo"; then
                    repos+=("$repo")
                    log "Repository $repo needs a runner"
                fi
            fi
        done <<< "$repos_in_page"
        
        page=$((page + 1))
    done
    
    # Return repositories as space-separated string
    printf '%s\n' "${repos[@]}"
}

# Check if a repository needs a runner
repository_needs_runner() {
    local repo="$1"
    
    # Check if repository has .github/workflows directory with self-hosted runner configurations
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$repo/contents/.github/workflows")
    
    if echo "$response" | jq -e '.[]' > /dev/null 2>&1; then
        # Check each workflow file for self-hosted runner usage
        local workflows=$(echo "$response" | jq -r '.[] | select(.name | endswith(".yml")) | .name')
        
        while IFS= read -r workflow; do
            if [ -n "$workflow" ]; then
                local workflow_content=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
                    -H "Accept: application/vnd.github.v3+json" \
                    "https://api.github.com/repos/$repo/contents/.github/workflows/$workflow")
                
                local content=$(echo "$workflow_content" | jq -r '.content' | base64 -d)
                
                # Check for any runs-on value (ubuntu-latest, self-hosted, or any other runner)
                if echo "$content" | grep -qE "runs-on:\s*(\[.*\]|.+)"; then
                    return 0  # Repository needs a runner
                fi
            fi
        done <<< "$workflows"
    fi
    
    return 1  # Repository doesn't need a runner
}

# Check if a runner is already registered for a repository
runner_exists() {
    local repo="$1"
    local runner_name="$2"
    
    local response=$(curl -s -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$repo/actions/runners")
    
    if echo "$response" | jq -e '.runners' > /dev/null 2>&1; then
        local existing_runners=$(echo "$response" | jq -r '.runners[].name')
        
        while IFS= read -r existing_runner; do
            if [ "$existing_runner" = "$runner_name" ]; then
                return 0  # Runner exists
            fi
        done <<< "$existing_runners"
    fi
    
    return 1  # Runner doesn't exist
}

# Register a runner for a repository
register_runner() {
    local repo="$1"
    local runner_name="$2"
    
    log "Registering runner '$runner_name' for repository '$repo'..."
    
    # Create runner directory
    local runner_dir="$RUNNER_WORK_DIR/$repo/$runner_name"
    mkdir -p "$runner_dir"
    chown -R "$RUNNER_USER:$RUNNER_USER" "$runner_dir"
    
    # Download the latest runner
    cd "$runner_dir"
    
    if [ ! -f "actions-runner-linux-x64.tar.gz" ]; then
        log "Downloading latest GitHub Actions runner..."
        curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v2.311.0/actions-runner-linux-x64-2.311.0.tar.gz
        chown "$RUNNER_USER:$RUNNER_USER" actions-runner-linux-x64.tar.gz
    fi
    
    # Extract runner
    if [ ! -d "bin" ]; then
        log "Extracting runner..."
        tar xzf actions-runner-linux-x64.tar.gz
        chown -R "$RUNNER_USER:$RUNNER_USER" .
    fi
    
    # Get registration token
    local token_response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$repo/actions/runners/registration-token")
    
    local registration_token=$(echo "$token_response" | jq -r '.token')
    
    if [ "$registration_token" = "null" ] || [ -z "$registration_token" ]; then
        error "Failed to get registration token for $repo"
        return 1
    fi
    
    # Configure and start the runner as the runner user
    log "Configuring runner..."
    sudo -u "$RUNNER_USER" ./config.sh \
        --url "https://github.com/$repo" \
        --token "$registration_token" \
        --name "$runner_name" \
        --labels "$RUNNER_LABELS" \
        --unattended \
        --replace
    
    # Create systemd service
    create_systemd_service "$repo" "$runner_name" "$runner_dir"
    
    # Start the service
    local repo_hash=$(echo "$repo" | md5sum | cut -c1-8)
    systemctl enable "github-runner@${repo_hash}"
    systemctl start "github-runner@${repo_hash}"
    
    log "Runner '$runner_name' successfully registered for repository '$repo'"
}

# Create systemd service for the runner
create_systemd_service() {
    local repo="$1"
    local runner_name="$2"
    local runner_dir="$3"
    # Create a shorter service name using hash of repo name
    local repo_hash=$(echo "$repo" | md5sum | cut -c1-8)
    local service_name="github-runner@${repo_hash}"
    
    cat > "/etc/systemd/system/$service_name.service" << EOF
[Unit]
Description=GitHub Actions Runner for $repo
After=network.target

[Service]
Type=simple
User=$RUNNER_USER
WorkingDirectory=$runner_dir
ExecStart=$runner_dir/run.sh
Restart=always
RestartSec=10
Environment=PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
}

# Main function
main() {
    log "Starting automated GitHub runner registration..."
    
    check_dependencies
    check_github_token
    
    # Create runner user if it doesn't exist
    if ! id "$RUNNER_USER" &>/dev/null; then
        log "Creating runner user: $RUNNER_USER"
        useradd -r -s /bin/bash -d /home/$RUNNER_USER -m $RUNNER_USER
    fi
    
    # Create work directory
    mkdir -p "$RUNNER_WORK_DIR"
    chown -R "$RUNNER_USER:$RUNNER_USER" "$RUNNER_WORK_DIR"
    
    # Get repositories that need runners
    local repos=($(get_repositories_needing_runners))
    
    if [ ${#repos[@]} -eq 0 ]; then
        log "No repositories found that need runners."
        return 0
    fi
    
    log "Found ${#repos[@]} repositories that need runners: ${repos[*]}"
    
    # Register runners for each repository
    for repo in "${repos[@]}"; do
        local runner_name="${RUNNER_NAME_PREFIX}-$(echo "$repo" | tr '/' '-')-$(hostname)"
        
        if runner_exists "$repo" "$runner_name"; then
            log "Runner '$runner_name' already exists for repository '$repo'"
        else
            if register_runner "$repo" "$runner_name"; then
                log "Successfully registered runner for $repo"
            else
                error "Failed to register runner for $repo"
            fi
        fi
    done
    
    log "Automated runner registration completed."
}

# Run main function
main "$@" 