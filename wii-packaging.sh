#!/bin/bash

# Wii Covers - Final Packaging Script
# Run this to create dolphin HTML and final ZIP

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${GREEN}📦 Wii Covers - Final Packaging${NC}"
echo "=================================="
echo ""

cd ~/wii-covers

# Create dolphin HTML file
echo -e "${YELLOW}📄 Creating wii_games_dolphin.html...${NC}"
cp index.html wii_games_dolphin.html

# Verify both exist
echo -e "${BLUE}✅ Files present:${NC}"
ls -la index.html wii_games_dolphin.html
echo ""

# Create the complete ZIP archive
echo -e "${YELLOW}📦 Creating ZIP archive...${NC}"
zip -r wii-covers-complete.zip \
    index.html \
    wii_games_dolphin.html \
    wii_games_covers.json \
    covers/ \
    README.md \
    wiitdb.txt \
    -x "*.git*" "venv/*" "__pycache__/*" "*.pyc"

# Check the ZIP
echo -e "${BLUE}✅ ZIP created:${NC}"
ls -la wii-covers-complete.zip
ZIP_SIZE=$(du -sh wii-covers-complete.zip | cut -f1)
echo "Size: $ZIP_SIZE"
echo ""

# Copy everything to web folder
echo -e "${YELLOW}🌐 Copying to web directory...${NC}"
sudo cp wii-covers-complete.zip wii_games_dolphin.html /var/www/html/wii-covers/

# Check web directory
echo -e "${BLUE}✅ Web directory contents:${NC}"
ls -la /var/www/html/wii-covers/
echo ""

# Get IP and show download links
IP=$(curl -s ifconfig.me)
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  DOWNLOAD LINKS READY!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}🌐 Dolphin HTML:${NC}"
echo "   http://$IP/wii-covers/wii_games_dolphin.html"
echo ""
echo -e "${YELLOW}📦 Complete ZIP:${NC}"
echo "   http://$IP/wii-covers/wii-covers-complete.zip"
echo ""
echo -e "${GREEN}✅ Done!${NC}"