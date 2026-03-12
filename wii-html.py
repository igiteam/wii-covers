#!/usr/bin/env python3
"""
Wii Games Grid Generator
Loads JSON, removes duplicates by TITLE, saves clean copy, generates grid
"""

import json
import os
from datetime import datetime

# Configuration
JSON_FILE = "wii_games_covers.json"
CLEAN_JSON_FILE = "wii_games_covers_nodup.json"  # Clean version
OUTPUT_HTML = "index.html"
PLACEHOLDER_IMAGE = "https://raw.githubusercontent.com/igiteam/wii-covers/main/covers/wii-cover-default.png"

def load_and_deduplicate():
    """Load games from JSON file and remove duplicates by TITLE"""
    if not os.path.exists(JSON_FILE):
        print(f"❌ Error: {JSON_FILE} not found!")
        return None
    
    with open(JSON_FILE, 'r', encoding='utf-8') as f:
        games = json.load(f)
    
    print(f"📊 Original: {len(games)} entries")
    
    # Remove duplicates by TITLE (case-insensitive, trimmed)
    seen_titles = {}
    unique_games = []
    
    for game in games:
        # Normalize title for comparison
        title_key = game['title'].lower().strip()
        
        # If we haven't seen this title before, keep it
        if title_key not in seen_titles:
            seen_titles[title_key] = True
            unique_games.append(game)
    
    removed = len(games) - len(unique_games)
    print(f"✅ Removed {removed} duplicates by title")
    print(f"📊 Clean: {len(unique_games)} unique games")
    
    # Save clean JSON
    with open(CLEAN_JSON_FILE, 'w', encoding='utf-8') as f:
        json.dump(unique_games, f, indent=2, ensure_ascii=False)
    print(f"💾 Saved clean JSON to {CLEAN_JSON_FILE}")
    
    return unique_games

def generate_html(games):
    """Generate the grid website HTML"""
    
    # Sort games by title
    games.sort(key=lambda x: x['title'].lower())
    
    # Stats
    total_games = len(games)
    with_2d = sum(1 for g in games if g['cover_url'] != PLACEHOLDER_IMAGE)
    with_3d = sum(1 for g in games if g['3d_cover_url'] != PLACEHOLDER_IMAGE)
    
    html = f"""<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Wii Games Collection</title>
  <link rel="icon" href="https://cdn.sdappnet.cloud/rtx/images/dolphin_wii_icon.png" type="image/png">
  <style>
    body {{
      background-color: #1a1a1a;
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, Cantarell, sans-serif;
      margin: 4px 20px;
      padding: 0;
    }}
    
    #results {{
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(200px, 1fr));
      gap: 10px;
      max-width: 1400px;
      margin: 0 auto;
      margin-top: 4px;
    }}
    
    .title-card {{
      background: #2a2a2a;
      border-radius: 8px;
      overflow: hidden;
      transition: transform 0.2s;
    }}
    
    .title-card:hover {{
      transform: scale(1.05);
      z-index: 10;
    }}
    
    .title-card-image-container {{
      width: 100%;
      aspect-ratio: 3/4;
      overflow: hidden;
    }}
    
    .title-card-image-container img {{
      width: 100%;
      height: 100%;
      object-fit: cover;
    }}
    
    /* PLAY BUTTON STYLE - GREEN BG, WHITE TEXT */
    .play-badge {{
      background-color: #42991b !important;
      color: white !important;
      font-weight: 700 !important;
      text-align: center !important;
      padding: 0.5rem 1.25rem !important;
      font-size: 0.8rem !important;
      text-transform: uppercase !important;
      letter-spacing: 0.5px !important;
      width: 100%;
      box-sizing: border-box;
    }}
    
    a {{
      text-decoration: none;
      color: inherit;
    }}
    
    /* Search container */
    #saved-search-container {{
      position: sticky;
      top: 0;
      z-index: 10000;
      background: #1a1a1a;
      padding: 10px 0;
      margin: 8px 0px;
    }}
    
    .search-row {{
      display: flex;
      align-items: center;
      gap: 10px;
    }}
    
    #saved-search-input {{
      padding: 10px;
      width: calc(100% - 20px);
      border: 1px solid #555;
      border-radius: 4px;
      background: #444;
      color: white;
      flex: 1;
    }}
    
    .hidden-game {{
      display: none !important;
    }}
    
    .highlight-saved {{
      border: 3px solid #42991b;
      box-shadow: 0 0 15px #42991b;
    }}
    
    .stats-bar {{
      background: #2a2a2a;
      border-radius: 8px;
      padding: 15px;
      color: white;
      display: flex;
      justify-content: space-between;
      flex-wrap: wrap;
      gap: 10px;
      margin: 10px auto;
      max-width: 1400px;
    }}
  </style>
</head>
<body>
  <div id="saved-search-container">
    <div class="search-row">
      <img src="https://cdn.sdappnet.cloud/rtx/images/dolphin_wii_icon.png" style="width:34px; border-radius: 4px; background: white; padding: 2px;" alt="Wii logo">
      <input type="text" id="saved-search-input" placeholder="Search games...">
      <a href="https://github.com/igiteam/wii-joycon" target="_blank">
        <img src="https://cdn.sdappnet.cloud/rtx/images/wiimote_icon.png" style="width:34px; border-radius: 4px; background: white; padding: 2px;" alt="Wiimote">
      </a>
    </div>
    <div id="saved-results-count"></div>
  </div>
  
  <div class="stats-bar">
    <div>🎮 Total Games: <strong style="color: #42991b;">{total_games}</strong></div>
    <div>🖼️ With 2D Covers: <strong style="color: #42991b;">{with_2d} ({with_2d/total_games*100:.1f}%)</strong></div>
    <div>🖼️ With 3D Covers: <strong style="color: #42991b;">{with_3d} ({with_3d/total_games*100:.1f}%)</strong></div>
  </div>
  
  <div class="row" id="results">
"""

    # Add each game card
    for game in games:
        title = game['title'].replace('"', '&quot;')
        game_id = game['id']
        
        # Determine cover URL
        if game['cover_url'] != PLACEHOLDER_IMAGE:
            cover_url = game['cover_url']
        elif game['3d_cover_url'] != PLACEHOLDER_IMAGE:
            cover_url = game['3d_cover_url']
        else:
            cover_url = PLACEHOLDER_IMAGE
        
        html += f"""
    <div class="col px-1 mb-4 title-card" data-title-name="{title}">
      <a target="_blank" rel="norefferer" href="https://meyt.netlify.app/search/{game_id} wii">
        <div class="title-card-container">
          <div class="title-card-image-container">
            <img src="{cover_url}" loading="lazy" title="{title}" onerror="this.src='{PLACEHOLDER_IMAGE}';">
          </div>
          <div class="play-badge">Play</div>
        </div>
      </a>
    </div>
"""

    html += f"""
  </div>
  
  <script>
    document.getElementById('saved-search-input').addEventListener('input', function(e) {{
      const searchTerm = e.target.value.toLowerCase();
      const cards = document.querySelectorAll('.title-card');
      let count = 0;
      
      cards.forEach(card => {{
        const title = card.getAttribute('data-title-name') || '';
        if (title.toLowerCase().includes(searchTerm) && searchTerm) {{
          card.classList.remove('hidden-game');
          card.classList.add('highlight-saved');
          count++;
        }} else if (searchTerm) {{
          card.classList.add('hidden-game');
          card.classList.remove('highlight-saved');
        }} else {{
          card.classList.remove('hidden-game');
          card.classList.remove('highlight-saved');
        }}
      }});
      
      document.getElementById('saved-results-count').textContent =
        searchTerm ? `Found ${{count}} game${{count !== 1 ? 's' : ''}}` : '';
    }});
    
    document.addEventListener('keydown', function(e) {{
      if (e.key === '/' && !document.getElementById('saved-search-input').matches(':focus')) {{
        e.preventDefault();
        document.getElementById('saved-search-input').focus();
      }}
    }});
  </script>
</body>
</html>
"""
    return html

def main():
    print("🎮 Wii Games Grid Generator (Deduplicated)")
    print("=" * 50)
    
    # Load and deduplicate games
    games = load_and_deduplicate()
    if not games:
        return
    
    # Generate HTML
    print("🔄 Generating grid website...")
    html_content = generate_html(games)
    
    # Save HTML file
    with open(OUTPUT_HTML, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"✅ Website generated: {OUTPUT_HTML}")
    print(f"\n📊 Final Statistics (no duplicates):")
    print(f"   - Total unique games: {len(games)}")
    print(f"   - With 2D covers: {sum(1 for g in games if g['cover_url'] != PLACEHOLDER_IMAGE)}")
    print(f"   - With 3D covers: {sum(1 for g in games if g['3d_cover_url'] != PLACEHOLDER_IMAGE)}")
    print(f"\n📁 Clean JSON saved: {CLEAN_JSON_FILE}")

if __name__ == "__main__":
    main()