#!/bin/bash

# Wii Covers Complete Automation Script - ENHANCED EDITION
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

check_command() {
    if ! command -v $1 &> /dev/null; then
        return 1
    fi
    return 0
}

verify_nginx() {
    if ! systemctl is-active --quiet nginx; then
        log "⚠️ Nginx not running, attempting to start..."
        systemctl start nginx
        sleep 2
        if ! systemctl is-active --quiet nginx; then
            warning "Nginx failed to start, but files are still available locally"
            return 1
        fi
    fi
    return 0
}

# ============================================
# Start Script
# ============================================
clear
echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║      Wii Covers Complete Automation Script - ENHANCED        ║${NC}"
echo -e "${GREEN}║                                                               ║${NC}"
echo -e "${GREEN}║      This script will:                                        ║${NC}"
echo -e "${GREEN}║      1. Install all dependencies                              ║${NC}"
echo -e "${GREEN}║      2. Clone the wii-covers repo                             ║${NC}"
echo -e "${GREEN}║      3. Download ALL game covers (10,150 games)               ║${NC}"
echo -e "${GREEN}║      4. Generate HTML website                                 ║${NC}"
echo -e "${GREEN}║      5. Create ZIP file with everything                       ║${NC}"
echo -e "${GREEN}║      6. Setup nginx and give you a download URL               ║${NC}"
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
    python3-dev \
    ufw \
    certbot \
    python3-certbot-nginx

# Verify nginx installation
if ! check_command nginx; then
    error "Nginx installation failed"
fi
log "✅ Nginx installed successfully"

# Configure firewall
log "Configuring firewall..."
ufw allow 22/tcp comment 'SSH'
ufw allow 80/tcp comment 'HTTP'
ufw allow 443/tcp comment 'HTTPS'
echo "y" | ufw enable
log "✅ Firewall configured"

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
log "✅ Python environment ready"

# ============================================
# Check/Create wiitdb.txt
# ============================================
section "Checking Database File"

if [ ! -f "wiitdb.txt" ]; then
    log "wiitdb.txt not found! Creating from sample data..."
    
    # Create a sample with some common games
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
if [ -f "wii-downloader.py" ]; then
    sed -i "s/BETWEEN_GAMES_DELAY = .*/BETWEEN_GAMES_DELAY = $GAME_DELAY/g" wii-downloader.py 2>/dev/null || true
    sed -i "s/BETWEEN_REQUESTS_DELAY = .*/BETWEEN_REQUESTS_DELAY = $REQUEST_DELAY/g" wii-downloader.py 2>/dev/null || true
    log "✅ Download delays configured"
fi

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
    
    # Wait for download to finish with timeout check
    while tmux has-session -t "$SESSION_NAME" 2>/dev/null; do
        echo -n "."
        sleep 60
    done
    echo ""
    log "Download completed!"
fi

# Verify JSON exists
if [ ! -f "wii_games_covers.json" ]; then
    warning "wii_games_covers.json not found! HTML generation may fail"
fi

log "Generating HTML website..."
if [ -f "wii-html.py" ]; then
    python3 wii-html.py
else
    warning "wii-html.py not found! Creating simple index..."
    cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Wii Covers Collection</title>
    <style>
        body { font-family: Arial; padding: 20px; background: #1a1a1a; color: white; }
        h1 { color: #42991b; }
        .stats { background: #333; padding: 15px; border-radius: 8px; }
    </style>
</head>
<body>
    <h1>🎮 Wii Covers Collection</h1>
    <div class="stats">
        <p>Download completed! Check the covers/ folder.</p>
    </div>
</body>
</html>
EOF
fi

if [ -f "index.html" ]; then
    log "✅ HTML generated successfully"
else
    warning "HTML generation failed"
fi

# ============================================
# Create ZIP Archive
# ============================================
section "Creating ZIP Archive"

log "Creating ZIP archive: $ZIP_NAME"

# Check if zip command exists
if ! check_command zip; then
    error "zip command not found!"
fi

# Create ZIP with progress
if check_command pv; then
    zip -r -9 "$ZIP_NAME" \
        covers/ \
        index.html \
        wii_games_covers.json \
        wii_covers_report.html \
        README.md \
        wiitdb.txt \
        -x "*.git*" "venv/*" "__pycache__/*" "*.pyc" 2>/dev/null | pv -l >/dev/null
else
    zip -r -9 "$ZIP_NAME" \
        covers/ \
        index.html \
        wii_games_covers.json \
        wii_covers_report.html \
        README.md \
        wiitdb.txt \
        -x "*.git*" "venv/*" "__pycache__/*" "*.pyc" > /dev/null 2>&1
fi

# Verify ZIP was created
if [ ! -f "$ZIP_NAME" ]; then
    error "Failed to create ZIP archive"
fi

# Get file size
ZIP_SIZE=$(du -h "$ZIP_NAME" | cut -f1)
log "✅ ZIP created: $ZIP_NAME ($ZIP_SIZE)"

# ============================================
# Setup Web Server
# ============================================
section "Setting Up Web Access"

log "Setting up web directory..."
mkdir -p "$PUBLIC_DIR"

# Remove old files
rm -rf "$PUBLIC_DIR"/* 2>/dev/null || true

log "Copying files to web directory..."
cp -r covers "$PUBLIC_DIR/" 2>/dev/null || warning "No covers folder to copy"
cp index.html "$PUBLIC_DIR/" 2>/dev/null || warning "No index.html to copy"
cp wii_games_covers.json "$PUBLIC_DIR/" 2>/dev/null || warning "No JSON file to copy"
cp wii_covers_report.html "$PUBLIC_DIR/" 2>/dev/null || true
cp "$ZIP_NAME" "$PUBLIC_DIR/" 2>/dev/null || warning "Failed to copy ZIP"

# Verify files were copied
if [ ! -f "$PUBLIC_DIR/index.html" ]; then
    warning "index.html not copied to web directory"
    # Create a simple fallback
    echo "<h1>Wii Covers</h1><p>Download: <a href='$ZIP_NAME'>$ZIP_NAME</a></p>" > "$PUBLIC_DIR/index.html"
fi

# Set permissions
chown -R www-data:www-data "$PUBLIC_DIR" 2>/dev/null || true
chmod -R 755 "$PUBLIC_DIR"

# Configure nginx (backup existing config)
if [ -f /etc/nginx/sites-available/wii-covers ]; then
    cp /etc/nginx/sites-available/wii-covers /etc/nginx/sites-available/wii-covers.bak
fi

cat > /etc/nginx/sites-available/wii-covers << EOF
server {
    listen 80;
    server_name _;
    
    root $PUBLIC_DIR;
    index index.html;
    
    location / {
        try_files \$uri \$uri/ =404;
        autoindex on;
        autoindex_format html;
        autoindex_localtime on;
    }
    
    location ~ \.zip$ {
        add_header Content-Disposition 'attachment; filename="$ZIP_NAME"';
        add_header Cache-Control 'no-cache, no-store, must-revalidate';
    }
    
    # Security headers
    add_header X-Content-Type-Options nosniff;
    add_header X-Frame-Options SAMEORIGIN;
}
EOF

# Enable site
ln -sf /etc/nginx/sites-available/wii-covers /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Test nginx configuration
log "Testing nginx configuration..."
if nginx -t; then
    log "✅ Nginx configuration test passed"
    systemctl reload nginx
else
    warning "Nginx configuration test failed, using default config"
    # Restore default
    ln -sf /etc/nginx/sites-available/default /etc/nginx/sites-enabled/
fi

# Verify nginx is running
if verify_nginx; then
    log "✅ Nginx is running"
else
    warning "Nginx is not running, but files are available locally"
fi

# Get server IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

# Test web access locally
log "Testing local web access..."
if curl -s "http://localhost/wii-covers/" | grep -q "html"; then
    log "✅ Web server serving files locally"
else
    warning "Local web test failed, but files are in $PUBLIC_DIR"
fi

# ============================================
# Create Status Check Script
# ============================================
cat > /usr/local/bin/check-wii-covers << 'EOF'
#!/bin/bash
PUBLIC_DIR="/var/www/html/wii-covers"
echo "=== Wii Covers Status ==="
echo ""
echo "📊 Files in web directory:"
ls -la $PUBLIC_DIR | grep -E "(index|zip|json|covers)" || echo "No files found"
echo ""
echo "🌐 Test URLs:"
echo "   http://localhost/wii-covers/"
echo "   http://$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')/wii-covers/"
echo ""
echo "🔍 Nginx status:"
systemctl status nginx --no-pager | grep "Active:"
EOF
chmod +x /usr/local/bin/check-wii-covers

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
if [ -f "$PROJECT_DIR/wii_games_covers.json" ]; then
    TOTAL_GAMES=$(grep -c "cover_url" "$PROJECT_DIR/wii_games_covers.json")
    TOTAL_2D=$(grep -c "raw.githubusercontent.*2d" "$PROJECT_DIR/wii_games_covers.json" 2>/dev/null || echo "unknown")
    echo -e "${YELLOW}📊 STATISTICS:${NC}"
    echo "   - Total games processed: ~$((TOTAL_GAMES / 2))"
    echo "   - 2D covers downloaded: $TOTAL_2D"
    echo "   - ZIP size: $ZIP_SIZE"
fi
echo "   - Server IP: $SERVER_IP"
echo ""
echo -e "${YELLOW}📁 FILES LOCATIONS:${NC}"
echo "   - Web directory: $PUBLIC_DIR"
echo "   - Project directory: $PROJECT_DIR"
echo "   - Log file: $LOG_FILE"
echo ""
echo -e "${YELLOW}🛠️  Management Commands:${NC}"
echo "   - Check status: /usr/local/bin/check-wii-covers"
echo "   - View nginx logs: journalctl -u nginx -f"
echo "   - Restart nginx: systemctl restart nginx"
echo "   - View tmux session: tmux attach -t wii-download (if still running)"
echo ""
echo -e "${YELLOW}🔧 Troubleshooting:${NC}"
echo "   If URLs don't work, check:"
echo "   1. Firewall: ufw status"
echo "   2. Nginx: systemctl status nginx"
echo "   3. Files: ls -la $PUBLIC_DIR"
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
Project Dir: $PROJECT_DIR
Web Dir: $PUBLIC_DIR
Log File: $LOG_FILE
EOF

log "✅ All done! Share the download URL above!"
log "ℹ️  Run 'check-wii-covers' anytime to see status"

# 🚀 Key Enhancements:
#     ✅ Nginx verification - Checks if installed, tests config, verifies it's running
#     ✅ Firewall setup - Opens ports 80/443 automatically
#     ✅ Better error handling - Graceful fallbacks if files missing
#     ✅ ZIP verification - Confirms ZIP was created successfully
#     ✅ Local web testing - Tests if nginx is serving files
#     ✅ Status check script - check-wii-covers command for later use
#     ✅ Backup configs - Saves backup before overwriting
#     ✅ Better permissions - Ensures www-data owns files
#     ✅ More logging - Every step is logged
#     ✅ Troubleshooting section - Built-in debug tips

# ============================================
# TROUBLESHOOTING COMMANDS - WHAT WE DID
# ============================================

# 🔍 Check if tmux session is still running
# tmux ls
# Output: wii-download: 1 windows (created Thu Mar 12 12:07:33 2026)

# 📊 Attach to see live progress
# tmux attach -t wii-download
# (Shows: [4331/10146] RMCPGP - Mario Kart CTGP Revolution...)
# (To detach: Ctrl+B, then D)

# 📁 Count downloaded covers
# ls -la ~/wii-covers/covers/2d/ | grep -c ".png"
# ls -la ~/wii-covers/covers/3d/ | grep -c ".png"
# Our result: 3954 2D, 3955 3D

# 📄 Check JSON progress
# cat ~/wii-covers/wii_games_covers.json | grep -c "cover_url"
# Our result: 8690 entries (4345 games)

# 🔍 Check if JSON has real covers vs placeholders
# cat ~/wii-covers/wii_games_covers.json | grep -c "raw.githubusercontent"
# Our result: 7909 actual downloaded covers

# 🛑 Check if downloader crashed
# ps aux | grep python | grep wii
# (If nothing shows, download finished or crashed)

# 📝 Check error logs
# ls -la ~/wii-covers/logs/
# cat ~/wii-covers/logs/* 2>/dev/null
# (If empty, no errors logged)

# 💾 Check ZIP creation
# ls -la ~/wii-covers-complete-*.zip
# du -sh ~/wii-covers-complete-*.zip
# Our result: 570M

# 🌐 Check nginx status
# systemctl status nginx
# (Should show: active (running))

# 📂 Check web directory
# ls -la /var/www/html/wii-covers/
# (Should show: index.html, covers/, zip file)

# 🔌 Test web access locally
# curl http://localhost/wii-covers/index.html | head -20
# (Should return HTML)

# 🌍 Get server IP for sharing
# curl ifconfig.me
# Our result: 178.128.40.69

# ✅ Final URLs to share
# echo "http://178.128.40.69/wii-covers/index.html"
# echo "http://178.128.40.69/wii-covers/wii-covers-complete-20250312-182802.zip"