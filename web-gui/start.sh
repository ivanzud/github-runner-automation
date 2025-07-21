#!/bin/bash

# GitHub Runner Automation - Web Interface Startup Script

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

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1"
}

# Check if we're in the right directory
if [ ! -f "app.py" ]; then
    error "Please run this script from the web-gui directory"
    exit 1
fi

# Check if virtual environment exists in parent directory
if [ ! -f "../venv/bin/activate" ]; then
    error "Virtual environment not found. Creating one..."
    cd ..
    python3 -m venv venv
    source venv/bin/activate
    pip install Flask==3.1.1 PyYAML==6.0.1
    cd web-gui
fi

# Activate virtual environment
log "Activating virtual environment..."
source ../venv/bin/activate

# Check if required packages are installed
log "Checking dependencies..."
if ! python -c "import flask" 2>/dev/null; then
    error "Flask not found. Installing dependencies..."
    pip install Flask==3.1.1 PyYAML==6.0.1
fi

# Check if port 8080 is available
if lsof -Pi :8080 -sTCP:LISTEN -t >/dev/null 2>&1; then
    log "Port 8080 is in use. Stopping existing process..."
    lsof -ti:8080 | xargs kill -9
    sleep 2
fi

# Start the web interface
log "Starting GitHub Runner Automation Web Interface..."
log "Access the interface at: http://localhost:8080"
log "Press Ctrl+C to stop the server"
echo ""

python app.py 