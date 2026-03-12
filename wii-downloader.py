#!/usr/bin/env python3
"""
Wii Cover Downloader - Python Edition
Reads a wiitdb.txt file and downloads covers from GameTDB
Organizes covers in 2d/ and 3d/ folders with ID as filename
Saves JSON after EVERY game so you always have up-to-date data
"""

import os
import json
import requests
import re
from pathlib import Path
import time
import random
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

# Configuration
COVERS_FOLDER = "covers"
JSON_FILE = "wii_games_covers.json"
BACKUP_JSON_FILE = "wii_games_covers_backup.json"  # Backup file
GITHUB_BASE_URL = "https://github.com/igiteam/wii-covers/blob/main/covers"
PLACEHOLDER_IMAGE = "https://github.com/igiteam/wii-covers/blob/main/covers/wii-cover-default.png"
RAW_BASE_URL = "https://raw.githubusercontent.com/igiteam/wii-covers/main/covers"

# Download settings
REQUEST_TIMEOUT = 15  # seconds
MAX_RETRIES = 2
BACKOFF_FACTOR = 1
BETWEEN_REQUESTS_DELAY = 0.2
BETWEEN_GAMES_DELAY = 0.5
MAX_CONSECUTIVE_FAILURES = 5

class WiiCoverDownloader:
    def __init__(self, txt_file):
        self.txt_file = txt_file
        self.games = []
        self.results = []
        self.session = self._create_session()
        self.consecutive_failures = 0
        
        # Create folder structure
        Path(COVERS_FOLDER).mkdir(parents=True, exist_ok=True)
        Path(os.path.join(COVERS_FOLDER, "2d")).mkdir(parents=True, exist_ok=True)
        Path(os.path.join(COVERS_FOLDER, "3d")).mkdir(parents=True, exist_ok=True)
        
        # Try to load existing progress
        self.load_existing_progress()
        
    def _create_session(self):
        """Create a requests session with retry strategy"""
        session = requests.Session()
        
        retry_strategy = Retry(
            total=MAX_RETRIES,
            status_forcelist=[429, 500, 502, 503, 504],
            backoff_factor=BACKOFF_FACTOR,
            allowed_methods=["GET"]
        )
        
        adapter = HTTPAdapter(max_retries=retry_strategy, pool_connections=5, pool_maxsize=5)
        session.mount("http://", adapter)
        session.mount("https://", adapter)
        
        session.headers.update({
            'User-Agent': 'WiiCoverDownloader/1.0 (Python)',
            'Accept': 'image/png,image/*;q=0.9,*/*;q=0.8'
        })
        
        return session
    
    def load_existing_progress(self):
        """Load existing JSON file if it exists to resume progress"""
        if os.path.exists(JSON_FILE):
            try:
                with open(JSON_FILE, 'r', encoding='utf-8') as f:
                    self.results = json.load(f)
                print(f"📂 Loaded {len(self.results)} previously processed games from {JSON_FILE}")
            except Exception as e:
                print(f"⚠️  Could not load existing JSON: {e}")
                self.results = []
    
    def save_json(self, is_final=False):
        """Save results to JSON file - called after EVERY game"""
        # Save main JSON
        with open(JSON_FILE, 'w', encoding='utf-8') as f:
            json.dump(self.results, f, indent=2, ensure_ascii=False)
        
        # Also save a backup every 50 games
        if len(self.results) % 50 == 0:
            with open(BACKUP_JSON_FILE, 'w', encoding='utf-8') as f:
                json.dump(self.results, f, indent=2, ensure_ascii=False)
            print(f"  💾 Backup saved: {BACKUP_JSON_FILE}")
        
        # Only show stats on final save or every 100 games
        if is_final or len(self.results) % 100 == 0:
            total = len(self.results)
            with_2d = sum(1 for g in self.results if g['cover_url'] != PLACEHOLDER_IMAGE)
            with_3d = sum(1 for g in self.results if g['3d_cover_url'] != PLACEHOLDER_IMAGE)
            
            print(f"\n📊 Current progress: {total} games processed")
            print(f"   - 2D covers: {with_2d} ({with_2d/total*100:.1f}%)")
            print(f"   - 3D covers: {with_3d} ({with_3d/total*100:.1f}%)")
    
    def is_valid_game_id(self, game_id):
        """Check if the game ID is valid for cover downloading"""
        # System/utility discs often don't have covers
        invalid_patterns = [
            r'^00',  # System discs
            r'^09',  # Channel installers
            r'^41',  # Update discs
            r'^51',  # More system stuff
            r'^52',  # More system stuff
            r'^10',  # Wii Menu
            r'^11',  # System
            r'^1[0-9]',  # Various system tools
        ]
        
        for pattern in invalid_patterns:
            if re.match(pattern, game_id):
                return False
        return True
        
    def parse_txt_file(self):
        """Parse the wiitdb.txt file to extract game IDs and titles"""
        print(f"📖 Reading {self.txt_file}...")
        
        try:
            with open(self.txt_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except Exception as e:
            print(f"❌ Error reading file: {e}")
            return []
        
        skipped = 0
        # Skip the header line
        for line in lines:
            line = line.strip()
            if not line or line.startswith('TITLES ='):
                continue
                
            match = re.match(r'^([A-Z0-9]{4,6})\s*=\s*(.+)$', line)
            if match:
                game_id = match.group(1)
                title = match.group(2)
                
                # Skip invalid/system IDs
                if not self.is_valid_game_id(game_id):
                    skipped += 1
                    continue
                    
                self.games.append({
                    'id': game_id,
                    'title': title
                })
        
        print(f"✅ Found {len(self.games)} valid games (skipped {skipped} system/utility discs)")
        return self.games
    
    def is_game_already_processed(self, game_id):
        """Check if a game is already in results"""
        for result in self.results:
            if result['id'] == game_id:
                return True
        return False
    
    def download_cover(self, game_id, cover_type):
        """Download a specific cover type for a game"""
        languages = ['EN', 'US', 'JA', 'FR', 'DE', 'ES', 'IT', 'PT', 'NL']
        
        endpoint_map = {
            '2d': 'cover',
            '3d': 'cover3D',
        }
        
        endpoint = endpoint_map.get(cover_type, 'cover')
        folder = cover_type
        
        filename = f"{game_id}.png"
        filepath = os.path.join(COVERS_FOLDER, folder, filename)
        
        # Skip if already downloaded
        if os.path.exists(filepath) and not self.force_redownload:
            self.consecutive_failures = 0
            return True
        
        for lang in languages:
            url = f"https://art.gametdb.com/wii/{endpoint}/{lang}/{game_id}.png"
            
            jitter = random.uniform(0.05, 0.15)
            time.sleep(BETWEEN_REQUESTS_DELAY + jitter)
            
            try:
                response = self.session.get(url, timeout=REQUEST_TIMEOUT, stream=False)
                
                if response.status_code == 200:
                    content_type = response.headers.get('content-type', '')
                    if 'image' in content_type:
                        with open(filepath, 'wb') as f:
                            f.write(response.content)
                        self.consecutive_failures = 0
                        return True
                elif response.status_code == 404:
                    continue
                else:
                    print(f"  ⚠️  Error {response.status_code} for {folder}/{filename} with {lang}")
                    
            except Exception as e:
                print(f"  ⚠️  Error: {e}")
                continue
        
        self.consecutive_failures += 1
        return False
    
    def download_all_covers(self, force_redownload=False):
        """Download all cover types for all games"""
        self.force_redownload = force_redownload
        print(f"\n🖼️  Downloading covers...")
        print(f"⏱️  JSON will be updated after EVERY game")
        
        total_games = len(self.games)
        start_time = time.time()
        self.consecutive_failures = 0
        
        # Count how many games we've already processed
        processed_count = len(self.results)
        if processed_count > 0:
            print(f"📝 Resuming from game {processed_count + 1}/{total_games}")
        
        for i, game in enumerate(self.games, 1):
            # Skip if already processed (for resume mode)
            if self.is_game_already_processed(game['id']) and not force_redownload:
                if i % 100 == 0:  # Only show progress every 100 games
                    print(f"⏩ Game {i}/{total_games} already processed, skipping...")
                continue
            
            # Calculate progress and ETA
            elapsed = time.time() - start_time
            processed = i - 1
            if processed > 0:
                avg_time = elapsed / processed
                remaining = avg_time * (total_games - i + 1)
                eta_min = int(remaining // 60)
                eta_sec = int(remaining % 60)
                eta_str = f" (ETA: {eta_min}m {eta_sec}s)"
            else:
                eta_str = ""
            
            # Check for too many consecutive failures
            if self.consecutive_failures >= MAX_CONSECUTIVE_FAILURES:
                print(f"\n⚠️  Too many failures. Pausing for 10 seconds...")
                time.sleep(10)
                self.consecutive_failures = 0
            
            print(f"\n[{i}/{total_games}]{eta_str} {game['id']} - {game['title'][:50]}...")
            
            game_result = {
                'title': game['title'],
                'id': game['id'],
                'cover_url': PLACEHOLDER_IMAGE,
                '3d_cover_url': PLACEHOLDER_IMAGE
            }
            
            # Try to download 2D cover
            if self.download_cover(game['id'], '2d'):
                game_result['cover_url'] = f"{RAW_BASE_URL}/2d/{game['id']}.png"
                print(f"  ✅ 2D cover saved")
            
            # Try to download 3D cover
            if self.download_cover(game['id'], '3d'):
                game_result['3d_cover_url'] = f"{RAW_BASE_URL}/3d/{game['id']}.png"
                print(f"  ✅ 3D cover saved")
            
            # Add to results and save JSON immediately
            self.results.append(game_result)
            self.save_json()
            
            # Add delay between games
            if i < total_games:
                time.sleep(BETWEEN_GAMES_DELAY)
        
        # Final save
        self.save_json(is_final=True)
        return self.results

def main():
    print("🎮 Wii Cover Downloader - Python Edition")
    print("=" * 50)
    print("🔄 JSON updates after EVERY game - never lose progress!")
    print("=" * 50)
    
    # Check for the txt file
    txt_file = "wiitdb.txt"
    if not os.path.exists(txt_file):
        print(f"❌ Error: {txt_file} not found!")
        return
    
    # Create downloader instance
    downloader = WiiCoverDownloader(txt_file)
    
    # Parse the txt file
    games = downloader.parse_txt_file()
    if not games:
        print("❌ No valid games found!")
        return
    
    print(f"\n📊 Total games to process: {len(games)}")
    print(f"📁 Already processed: {len(downloader.results)}")
    
    # Ask user what to do
    print("\n📋 What would you like to do?")
    print("1. Download only missing covers (fastest)")
    print("2. Download all covers (redownload everything)")
    print("3. Just create JSON with placeholders (no downloads)")
    print("4. Resume interrupted download (skip existing)")
    
    choice = input("\nEnter your choice (1/2/3/4): ").strip()
    
    if choice == '3':
        # Just create JSON with placeholders
        print("\n📝 Creating JSON with placeholders...")
        for game in games:
            if not downloader.is_game_already_processed(game['id']):
                downloader.results.append({
                    'title': game['title'],
                    'id': game['id'],
                    'cover_url': PLACEHOLDER_IMAGE,
                    '3d_cover_url': PLACEHOLDER_IMAGE
                })
                # Save after each game even for placeholders
                if len(downloader.results) % 10 == 0:
                    downloader.save_json()
        
        downloader.save_json(is_final=True)
        print(f"\n✅ Created JSON with {len(downloader.results)} games")
        
    elif choice in ['1', '2', '4']:
        # Download covers
        force = (choice == '2')
        if choice == '4':
            print("📝 Resume mode: Will skip already downloaded files")
            force = False
        
        downloader.download_all_covers(force_redownload=force)
        
        print(f"\n✨ All done! Processed {len(downloader.results)} games")
        print(f"\n📁 Files:")
        print(f"   - Covers: {COVERS_FOLDER}/2d/ and {COVERS_FOLDER}/3d/")
        print(f"   - JSON data: {JSON_FILE}")
        print(f"   - Backup: {BACKUP_JSON_FILE}")
    else:
        print("❌ Invalid choice")

if __name__ == "__main__":
    # Install requests if not available
    try:
        import requests
    except ImportError:
        print("📦 Installing requests...")
        os.system("pip install requests")
        import requests
    
    main()

# Key Changes:
#     Separate folders: Now downloads to covers/2d/ and covers/3d/
#     Clean filenames: Files are just [ID].png (e.g., D2AJAF.png)
#     JSON URLs updated: Now points to covers/2d/D2AJAF.png and covers/3d/D2AJAF.png
#     HTML report updated: Shows folder badges (📁 2d/ or 📁 3d/)
#     Stats bar added: Clean stats display matching the Xemu style

# Now your folder structure will be:

# wii-covers/
# ├── covers/
# │   ├── 2d/
# │   │   ├── D2AJAF.png
# │   │   ├── D2SE18.png
# │   │   └── ...
# │   ├── 3d/
# │   │   ├── D2AJAF.png
# │   │   ├── D2SE18.png
# │   │   └── ...
# │   └── wii-cover-default.png
# ├── wii_games_covers.json
# ├── index.html
# └── wii-downloader.py

# The JSON will have clean URLs like:

# {
#   "title": "みんなで冒険！ファミリートレーナー 体験版",
#   "id": "D2AJAF",
#   "cover_url": "https://raw.githubusercontent.com/igiteam/wii-covers/main/covers/2d/D2AJAF.png",
#   "3d_cover_url": "https://raw.githubusercontent.com/igiteam/wii-covers/main/covers/3d/D2AJAF.png"
# }

# Perfect for your GitHub repo! 🎮✨