#!/bin/bash

# Wii Covers - Final Packaging Script
# Run this to regenerate HTML, create dolphin copy, and final ZIP

set -e

# Colors - FIXED
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}📦 Wii Covers - Final Packaging${NC}"
echo "=================================="
echo ""

# Create web directory if it doesn't exist
echo -e "${YELLOW}📁 Ensuring web directory exists...${NC}"
sudo mkdir -p /var/www/html/wii-covers/
sudo chmod 755 /var/www/html/wii-covers/

cd ~/wii-covers

# STEP 0: REDOWNLOAD THE LATEST wii-downloader.py
echo -e "${YELLOW}⬇️ Downloading latest wii-downloader.py from GitHub...${NC}"
mv wii-downloader.py wii-downloader.py.bak 2>/dev/null || true
wget -O wii-downloader.py https://raw.githubusercontent.com/igiteam/wii-covers/refs/heads/main/wii-downloader.py
chmod +x wii-downloader.py
echo -e "${BLUE}✅ wii-html.py updated${NC}"
echo ""

# STEP 0: REDOWNLOAD THE LATEST wii-html.py
echo -e "${YELLOW}⬇️ Downloading latest wii-html.py from GitHub...${NC}"
mv wii-html.py wii-html.py.bak 2>/dev/null || true
wget -O wii-html.py https://raw.githubusercontent.com/igiteam/wii-covers/refs/heads/main/wii-html.py
chmod +x wii-html.py
echo -e "${BLUE}✅ wii-html.py updated${NC}"
echo ""

# STEP 1: REGENERATE HTML FROM LATEST JSON
echo -e "${YELLOW}🔄 Regenerating index.html from latest data...${NC}"
python3 wii-html.py

# STEP 2: Create dolphin HTML file (copy of fresh index)
echo -e "${YELLOW}📄 Creating wii_games_dolphin.html...${NC}"
cp index.html wii_games_dolphin.html

# STEP 3: Verify both exist
echo -e "${BLUE}✅ Files present:${NC}"
ls -la index.html wii_games_dolphin.html wii_games_covers.json
echo ""

# STEP 4: Create the complete ZIP archive
echo -e "${YELLOW}📦 Creating ZIP archive...${NC}"
zip -r wii-covers-complete.zip \
    index.html \
    wii_games_dolphin.html \
    wii_games_covers.json \
    covers/ \
    README.md \
    wiitdb.txt \
    -x "*.git*" "venv/*" "__pycache__/*" "*.pyc"

# STEP 5: Check the ZIP
echo -e "${BLUE}✅ ZIP created:${NC}"
ls -la wii-covers-complete.zip
ZIP_SIZE=$(du -sh wii-covers-complete.zip | cut -f1)
echo "Size: $ZIP_SIZE"
echo ""

# STEP 6: Copy everything to web folder
echo -e "${YELLOW}🌐 Copying to web directory...${NC}"
sudo cp wii-covers-complete.zip wii_games_dolphin.html /var/www/html/wii-covers/

# Also copy the fresh index and JSON
sudo cp index.html wii_games_covers.json /var/www/html/wii-covers/

# STEP 7: Check web directory
echo -e "${BLUE}✅ Web directory contents:${NC}"
ls -la /var/www/html/wii-covers/
echo ""

# STEP 8: Get IP and show download links
IP=$(curl -s ifconfig.me)
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  DOWNLOAD LINKS READY!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}🌐 Main Website:${NC}"
echo "   http://$IP/wii-covers/index.html"
echo ""
echo -e "${YELLOW}🌐 Dolphin HTML:${NC}"
echo "   http://$IP/wii-covers/wii_games_dolphin.html"
echo ""
echo -e "${YELLOW}📦 Complete ZIP:${NC}"
echo "   http://$IP/wii-covers/wii-covers-complete.zip"
echo ""
echo -e "${YELLOW}📊 JSON Data:${NC}"
echo "   http://$IP/wii-covers/wii_games_covers.json"
echo ""
echo -e "${GREEN}✅ Done!${NC}"