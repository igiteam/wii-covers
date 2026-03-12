#!/bin/bash

# Wii Covers Complete Automation Script
# Run with: curl -o wii-bash.sh https://yourdomain.com/wii-bash.sh && chmod +x wii-bash.sh && sudo ./wii-bash.sh

set -e  # Exit on any error

# ============================================
# Configuration
# ============================================
REPO_URL="https://github.com/igiteam/wii-covers.git"
PROJECT_DIR="$HOME/wii-covers"
ZIP_NAME="wii-covers-complete-$(date +%Y%m%d-%H%M%S).zip"
PUBLIC_DIR="/var/www/html/wii-covers"
LOG_FILE="/root/wii-deployment-$(date +%Y%m%d-%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ============================================
# Helper Functions
# ============================================
log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_FILE"
}

section() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================
# Start Script
# ============================================
clear
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║      Wii Covers Complete Automation Script                    ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║      This script will:                                        ║${NC}"
echo -e "${GREEN}║      1. Install all dependencies                              ║${NC}"
echo -e "${GREEN}║      2. Clone the wii-covers repo                             ║${NC}"
echo -e "${GREEN}║      3. Download ALL game covers (10,150 games)               ║${NC}"
echo -e "${GREEN}║      4. Generate HTML website                                 ║${NC}"
echo -e "${GREEN}║      5. Create ZIP file with everything                       ║${NC}"
echo -e "${GREEN}║      6. Give you a download URL                               ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""

log "Starting deployment at $(date)"
log "Log file: $LOG_FILE"

# Check if running as root
if [ "$EUID" -ne 0 ]; then 
    error "Please run as root (use sudo)"
fi

# ============================================
# Install System Dependencies
# ============================================
section "Installing System Dependencies"

log "Updating package list..."
apt-get update -y

log "Installing required packages..."
apt-get install -y \
    python3 \
    python3-pip \
    python3-venv \
    git \
    wget \
    curl \
    zip \
    unzip \
    nginx \
    screen \
    bc \
    tmux \
    htop \
    pv \
    build-essential \
    python3-dev

# ============================================
# Clone Repository
# ============================================
section "Cloning Repository"

log "Cleaning up any existing directory..."
rm -rf "$PROJECT_DIR"

log "Cloning from $REPO_URL..."
git clone "$REPO_URL" "$PROJECT_DIR"

if [ ! -d "$PROJECT_DIR" ]; then
    error "Failed to clone repository"
fi

cd "$PROJECT_DIR"
log "✅ Repository cloned successfully"

# ============================================
# Setup Python Environment
# ============================================
section "Setting Up Python Environment"

log "Creating Python virtual environment..."
python3 -m venv venv
source venv/bin/activate

log "Installing Python packages..."
pip install --upgrade pip
pip install requests urllib3 pillow

# Create requirements.txt if it doesn't exist
if [ ! -f "requirements.txt" ]; then
    echo "requests>=2.28.0" > requirements.txt
    echo "urllib3>=1.26.0" >> requirements.txt
fi

pip install -r requirements.txt

# ============================================
# Check/Create wiitdb.txt
# ============================================
section "Checking Database File"

if [ ! -f "wiitdb.txt" ]; then
    log "wiitdb.txt not found! Creating from sample data..."
    
    # Create a sample with some common games (you should upload your real one!)
    cat > wiitdb.txt << 'EOF'
TITLES = https://www.gametdb.com (type: Wii language: ORIG version: 20260307144934)
RSPE01 = New Super Mario Bros. Wii
RZDE01 = The Legend of Zelda: Twilight Princess
RMCE01 = Mario Kart Wii
RSBE01 = Super Smash Bros. Brawl
RZPJ01 = Wii Sports
RSPE02 = Super Mario Galaxy
RZDE02 = Super Mario Galaxy 2
RSPE03 = Donkey Kong Country Returns
RZDE03 = Metroid Prime Trilogy
RSPE04 = Wii Fit Plus
EOF
    log "Created sample wiitdb.txt with 10 games (for testing)"
    warning "For full 10,150 games, upload your real wiitdb.txt to $PROJECT_DIR/wiitdb.txt"
else
    GAME_COUNT=$(wc -l < wiitdb.txt)
    log "Found wiitdb.txt with $GAME_COUNT games"
fi

# ============================================
# Create Directory Structure
# ============================================
log "Creating directory structure..."
mkdir -p covers/{2d,3d}
mkdir -p downloads
mkdir -p logs

# ============================================
# Modify Downloader with Speed Settings
# ============================================
section "Configuring Downloader"

# Check if downloader exists
if [ ! -f "wii-downloader.py" ]; then
    error "wii-downloader.py not found in repository!"
fi

# Ask for speed preference
echo ""
echo "Select download speed (impacts time and ban risk):"
echo "1) 🚀 Fast (0.5s delay) - ~1.5 hours - HIGH RISK OF IP BAN"
echo "2) ⚖️  Balanced (2s delay) - ~6 hours - Recommended"
echo "3) 🐢 Slow (5s delay) - ~14 hours - Safe"
echo "4) 🐌 Ultra slow (10s delay) - ~28 hours - Very safe"
echo ""
read -p "Enter choice (1-4) [default: 2]: " SPEED_CHOICE
SPEED_CHOICE=${SPEED_CHOICE:-2}

case $SPEED_CHOICE in
    1)
        GAME_DELAY=0.5
        REQUEST_DELAY=0.2
        TOTAL_HOURS=1.5
        warning "FAST MODE: High risk of IP ban!"
        ;;
    2)
        GAME_DELAY=2
        REQUEST_DELAY=0.5
        TOTAL_HOURS=6
        log "Balanced mode: ~6 hours"
        ;;
    3)
        GAME_DELAY=5
        REQUEST_DELAY=1
        TOTAL_HOURS=14
        log "Slow mode: ~14 hours"
        ;;
    4)
        GAME_DELAY=10
        REQUEST_DELAY=2
        TOTAL_HOURS=28
        log "Ultra safe mode: ~28 hours"
        ;;
    *)
        GAME_DELAY=2
        REQUEST_DELAY=0.5
        TOTAL_HOURS=6
        warning "Invalid choice, using balanced mode"
        ;;
esac

# Modify the downloader script
log "Configuring download delays..."
sed -i "s/BETWEEN_GAMES_DELAY = .*/BETWEEN_GAMES_DELAY = $GAME_DELAY # Auto-configured/g" wii-downloader.py 2>/dev/null || \
    echo "# Auto-configured delays" >> wii-downloader.py
sed -i "s/BETWEEN_REQUESTS_DELAY = .*/BETWEEN_REQUESTS_DELAY = $REQUEST_DELAY # Auto-configured/g" wii-downloader.py 2>/dev/null

# Ask for download mode
echo ""
echo "Download mode:"
echo "1) Download only missing covers (recommended)"
echo "2) Download all covers (redownload everything)"
echo "3) Just generate HTML from existing JSON"
read -p "Enter choice (1-3) [default: 1]: " DOWNLOAD_MODE
DOWNLOAD_MODE=${DOWNLOAD_MODE:-1}

# ============================================
# Start Download
# ============================================
section "Starting Download Process"

# Create a download script
cat > run_download.sh << 'EOF'
#!/bin/bash
cd "$PROJECT_DIR"
source venv/bin/activate
python3 wii-downloader.py
EOF

chmod +x run_download.sh

# Create a tmux session (better than screen)
SESSION_NAME="wii-download"

log "Starting download in tmux session: $SESSION_NAME"
log "Estimated time: ~${TOTAL_HOURS} hours"

# Kill existing session if any
tmux kill-session -t "$SESSION_NAME" 2>/dev/null || true

# Create new session with download command
tmux new-session -d -s "$SESSION_NAME" "cd $PROJECT_DIR && source venv/bin/activate && python3 wii-downloader.py"

log "✅ Download started in tmux session"
log ""
log "📌 Useful commands:"
log "   - View progress: tmux attach -t $SESSION_NAME"
log "   - Detach: Ctrl+B, then D"
log "   - List sessions: tmux ls"
log "   - Kill session: tmux kill-session -t $SESSION_NAME"
log ""

# Ask if user wants to attach
echo "Do you want to:"
echo "1) Attach now and watch progress"
echo "2) Detach and let it run (will continue after SSH disconnect)"
echo "3) Exit and check later"
read -p "Enter choice (1-3) [default: 1]: " ATTACH_CHOICE
ATTACH_CHOICE=${ATTACH_CHOICE:-1}

if [ "$ATTACH_CHOICE" == "1" ]; then
    log "Attaching to tmux session..."
    sleep 2
    tmux attach -t "$SESSION_NAME"
fi

# ============================================
# Generate HTML (will run after download)
# ============================================
section "Waiting for Download to Complete"

if [ "$ATTACH_CHOICE" != "1" ]; then
    log "Download running in background"
    log "This script will continue once download completes"
    log ""
    
    # Wait for download to finish
    while tmux has-session -t "$SESSION_NAME" 2>/dev/null; do
        echo -n "."
        sleep 60
    done
    echo ""
    log "Download completed!"
fi

log "Generating HTML website..."
python3 wii-html.py

if [ -f "index.html" ]; then
    log "✅ HTML generated successfully"
else
    warning "HTML generation may have failed"
fi

# ============================================
# Create ZIP Archive
# ============================================
section "Creating ZIP Archive"

log "Creating ZIP archive: $ZIP_NAME"

# Create ZIP with progress
zip -r -9 "$ZIP_NAME" \
    covers/ \
    index.html \
    wii_games_covers.json \
    wii_covers_report.html \
    README.md \
    wiitdb.txt \
    -x "*.git*" "venv/*" "__pycache__/*" "*.pyc" 2>/dev/null | pv -l >/dev/null

# Get file size
ZIP_SIZE=$(du -h "$ZIP_NAME" | cut -f1)
log "✅ ZIP created: $ZIP_NAME ($ZIP_SIZE)"

# ============================================
# Setup Web Server
# ============================================
section "Setting Up Web Access"

log "Setting up web directory..."
mkdir -p "$PUBLIC_DIR"

log "Copying files to web directory..."
cp -r covers "$PUBLIC_DIR/" 2>/dev/null
cp index.html "$PUBLIC_DIR/" 2>/dev/null
cp wii_games_covers.json "$PUBLIC_DIR/" 2>/dev/null
cp wii_covers_report.html "$PUBLIC_DIR/" 2>/dev/null
cp "$ZIP_NAME" "$PUBLIC_DIR/" 2>/dev/null

# Set permissions
chown -R www-data:www-data "$PUBLIC_DIR" 2>/dev/null || true
chmod -R 755 "$PUBLIC_DIR"

# Configure nginx
cat > /etc/nginx/sites-available/wii-covers << EOF
server {
    listen 80;
    server_name _;
    root $PUBLIC_DIR;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
        autoindex on;
    }
    
    location ~ \.zip$ {
        add_header Content-Disposition 'attachment; filename="$ZIP_NAME"';
    }
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/wii-covers /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test and reload nginx
nginx -t && systemctl reload nginx

# Get server IP
SERVER_IP=$(curl -s ifconfig.me)

# ============================================
# Final Output
# ============================================
section "DEPLOYMENT COMPLETE!"

echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  YOUR FILES ARE READY!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}📦 DOWNLOAD THE COMPLETE PACKAGE:${NC}"
echo -e "${BLUE}   http://$SERVER_IP/wii-covers/$ZIP_NAME${NC}"
echo ""
echo -e "${YELLOW}🌐 VIEW THE WEBSITE:${NC}"
echo -e "${BLUE}   http://$SERVER_IP/wii-covers/${NC}"
echo ""
echo -e "${YELLOW}📊 STATISTICS:${NC}"
echo "   - Total games: $(wc -l < wiitdb.txt | tr -d ' ')"
echo "   - ZIP size: $ZIP_SIZE"
echo "   - Server IP: $SERVER_IP"
echo ""
echo -e "${YELLOW}📁 FILES INCLUDED IN ZIP:${NC}"
echo "   - covers/2d/ - All 2D covers"
echo "   - covers/3d/ - All 3D covers"
echo "   - index.html - Main website"
echo "   - wii_games_covers.json - Complete database"
echo "   - wii_covers_report.html - Visual report"
echo "   - wiitdb.txt - Original game list"
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Save info
cat > /root/wii-covers-info.txt << EOF
Wii Covers Deployment
Date: $(date)
ZIP File: http://$SERVER_IP/wii-covers/$ZIP_NAME
Website: http://$SERVER_IP/wii-covers/
Server IP: $SERVER_IP
ZIP Size: $ZIP_SIZE
Games: $(wc -l < wiitdb.txt | tr -d ' ')
EOF

log "✅ All done! Share the download URL above!"

# # Check if tmux session is still running
# tmux ls

# # Check the wii-covers directory
# ls -la ~/wii-covers/

# # Check for the JSON file in the correct directory
# ls -la ~/wii-covers/wii_games_covers.json

# # If you want to see the progress, attach to the tmux session
# tmux attach -t wii-download

# ✅ tmux session - survives SSH disconnects

# Let me break down how tmux works its magic to keep your downloads alive even when you close your laptop or your WiFi drops.
# The Problem It Solves

# Normally, when you SSH into a server and run a command (like your downloader), that process is tied to your SSH session. If you:
#     Close your terminal
#     Lose WiFi
#     Put your laptop to sleep
#     Your SSH connection times out

# POOF! The process dies and your download stops .
# What Tmux Does

# Tmux is a terminal multiplexer - think of it as giving each of your programs its own permanent "room" on the server that exists independently of you .
# The Architecture

# Here's what happens behind the scenes:

# ┌─────────────────────────────────────────┐
# │         YOUR LOCAL COMPUTER              │
# │  ┌────────────────────────────────┐     │
# │  │   SSH Client (temporary)       │     │
# │  └────────────┬───────────────────┘     │
# └───────────────┼─────────────────────────┘
#                 │ SSH connection
#                 ▼ (may disconnect!)
# ┌─────────────────────────────────────────┐
# │         DIGITAL OCEAN SERVER             │
# │  ┌────────────────────────────────┐     │
# │  │   TMUX SERVER PROCESS          │     │
# │  │   (runs continuously)          │     │
# │  │  ┌────────────────────────┐    │     │
# │  │  │ Session "wii-download" │    │     │
# │  │  │  ┌────────────────┐    │    │     │
# │  │  │  │ Your Python    │    │    │     │
# │  │  │  │ Downloader     │    │    │     │
# │  │  │  │ (PID 12345)    │    │    │     │
# │  │  │  └────────────────┘    │    │     │
# │  │  └────────────────────────┘    │     │
# │  └────────────────────────────────┘     │
# │                                         │
# │  ┌────────────────────────────────┐     │
# │  │   SSH Client (reattach later)  │     │
# │  └────────────┬───────────────────┘     │
# └───────────────┼─────────────────────────┘
#                 │ New SSH connection
#                 ▼
#          You're back in!

# Key Concepts
# 1. Client-Server Model
#     Server: Runs continuously on your Digital Ocean droplet, managing all sessions
#     Client: The terminal window you're using to interact with tmux
#     You can disconnect the client, but the server keeps running 

# 2. Sessions
#     A session is a container for your running programs
#     Each session has its own:
#         Windows (like tabs)
#         Panes (split screens)
#         Environment variables
#         Running processes 

# 3. Detach/Attach

# # Start a new session
# tmux new -s wii-download

# # Run your program inside
# python wii-downloader.py

# # Detach (program keeps running!)
# # Press: Ctrl+B, then D
# # Or type: tmux detach

# # Later, reattach to check progress
# tmux attach -t wii-download

# Why Your Download Survives

# When you run your script inside tmux:
#     Process Independence: Your Python script becomes a child of the tmux server process, not your SSH session
#     Signal Handling: When SSH disconnects, the tmux server ignores the hangup signals that would normally kill processes
#     Socket Communication: Tmux uses a socket file in /tmp to communicate between server and clients - when you reconnect, you're just attaching to that existing socket
#     Session Persistence: The session continues running with all its processes intact, regardless of client connections 

# The Commands You Used

# # You ran this in your script:
# tmux new-session -d -s "$SESSION_NAME" "cd $PROJECT_DIR && source venv/bin/activate && python3 wii-downloader.py"

# # This means:
# # -d           = Create session but don't attach (daemon mode)
# # -s wii-download = Name the session
# # The command   = Run inside the session, then keep it alive

# Checking Your Session
# # List all running sessions
# tmux ls
# # Output: wii-download: 1 windows (created Thu Mar 12 12:05:03 2026)

# # Reattach to see progress
# tmux attach -t wii-download

# # Detach again: Ctrl+B, then D

# Pro Tips
#     Multiple windows: You can have several tabs in one session (Ctrl+B c)
#     Split panes: Watch logs and run commands side-by-side (Ctrl+B % to split vertically)
#     Scrollback: Use Ctrl+B [ to scroll through output, q to exit
#     Named sessions: Always use -s to name sessions - makes reattaching easier 

# So in simple terms: tmux is like giving your download its own apartment on the server. You can leave, come back, and it's still there doing its thing! 🔥