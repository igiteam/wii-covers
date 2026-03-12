#!/usr/bin/env python3
"""
Wii Games Grid Generator
Creates an Xemu-style grid website from your Wii games JSON
Matches exact HTML pattern from the Xbox Xemu page
"""

import json
import os
from datetime import datetime

# Configuration
JSON_FILE = "wii_games_covers.json"
OUTPUT_HTML = "index.html"
PLACEHOLDER_IMAGE = "https://raw.githubusercontent.com/igiteam/wii-covers/main/covers/wii-cover-default.png"
RAW_BASE_URL = "https://raw.githubusercontent.com/igiteam/wii-covers/main/covers"

def load_games_data():
    """Load games from JSON file"""
    if not os.path.exists(JSON_FILE):
        print(f"❌ Error: {JSON_FILE} not found!")
        print("Please run the cover downloader first to generate the JSON file.")
        return None
    
    with open(JSON_FILE, 'r', encoding='utf-8') as f:
        games = json.load(f)
    
    print(f"✅ Loaded {len(games)} games from {JSON_FILE}")
    return games

def generate_html(games):
    """Generate the grid website HTML matching the exact pattern"""
    
    # Sort games by title for better browsing
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
  <link rel="apple-touch-icon" href="https://cdn.sdappnet.cloud/rtx/images/dolphin_wii_icon.png" sizes="180x180">
  <link rel="icon" type="image/png" href="https://cdn.sdappnet.cloud/rtx/images/dolphin_wii_icon.png" sizes="192x192">
  <link rel="icon" type="image/png" href="https://cdn.sdappnet.cloud/rtx/images/dolphin_wii_icon.png" sizes="512x512">
  <meta itemprop="name" content="Wii Games Collection">
  <meta property="og:title" content="Wii Games Collection">
  <meta property="og:url" content="">
  <meta property="og:type" content="website">
  <meta name="twitter:title" content="Wii Games Collection">
  <meta name="twitter:card" content="summary_large_image">
  <link rel="apple-touch-icon" href="https://cdn.sdappnet.cloud/rtx/images/dolphin_wii_icon.png" sizes="180x180">

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
      background-color: #1a1a1a;
      margin-top: 4px;
      z-index: 1000;
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

    .title-card-container {{
      width: 100%;
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

    .fill-color-Playable {{
      color: #fff !important;
      background-color: #42991b !important;
      font-weight: 700 !important;
    }}

    .card-body {{
      flex: 1 1 auto;
      min-height: 1px;
      padding: 0.5rem 1.25rem !important;
    }}

    .text-center {{
      text-align: center !important;
    }}

    .py-1 {{
      padding-top: 0.25rem !important;
      padding-bottom: 0.25rem !important;
    }}

    .my-0 {{
      margin-top: 0 !important;
      margin-bottom: 0 !important;
    }}

    small {{
      font-size: 80%;
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
      margin-left: auto;
      margin-right: auto;
      margin: 8px 0px;
      background: #1a1a1a;
      padding: 10px 0;
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

    .search-row {{
      display: flex;
      align-items: center;
      gap: 10px;
    }}

    #saved-search-input::placeholder {{
      color: #aaa;
    }}

    #saved-results-count {{
      color: white;
      font-size: 14px;
      text-align: center;
      margin-top: 5px;
    }}

    .hidden-game {{
      display: none !important;
    }}

    .highlight-saved {{
      border: 3px solid #42991b;
      box-shadow: 0 0 15px #42991b;
    }}
  </style>
</head>

<body>
  <div id="saved-search-container">
    <div class="search-row">
      <img src="https://cdn.sdappnet.cloud/rtx/images/dolphin_wii_icon.png" style="width:34px; border-radius: 4px; background: white; padding: 2px;"
        alt="Wii logo">
      <input type="text" id="saved-search-input" placeholder="Search games...">
      <a href="https://github.com/igiteam/wii-joycon" target="_blank">
        <img src="https://cdn.sdappnet.cloud/rtx/images/wiimote_icon.png" 
             style="width:34px; border-radius: 4px; background: white; padding: 2px;" 
             alt="GitHub">
      </a>
      <a href="https://cdn.sdappnet.cloud/rtx/nintendo-magazine.html" target="_blank">
        <img src="https://cdn.sdappnet.cloud/rtx/images/nintendo-magazine.png" 
             style="width:34px; border-radius: 4px; background: white; padding: 2px;" 
             alt="Nintendo">
      </a>
    </div>
    <div id="saved-results-count"></div>
  </div>

  <div class="row" id="results">
"""

    # Add each game card - exactly matching the Xbox structure
    for game in games:
        game_id = game['id']
        title = game['title'].replace('"', '&quot;')
        
        # Determine cover URL
        if game['cover_url'] != PLACEHOLDER_IMAGE:
            cover_url = game['cover_url']
            status_text = "Play"
        elif game['3d_cover_url'] != PLACEHOLDER_IMAGE:
            cover_url = game['3d_cover_url']
            status_text = "Play"
        else:
            cover_url = PLACEHOLDER_IMAGE
            status_text = "Play"
        
        html += f"""
    <div class="col px-1 mb-4 title-card" data-title-name="{title}" data-title-status="{status_text}">
      <a target="_blank" rel="norefferer" href="https://github.com/igiteam/wii-covers">
        <div class="mx-auto title-card-container">

          <div class="title-card-image-container" style="background-position: -3520px -4600px; filter: none;">
            <img
              data-src="{cover_url}"
              class="img-fluid loaded" loading="lazy" title="{title}"
              src="{cover_url}"
              onerror="this.onerror=null; this.src='{PLACEHOLDER_IMAGE}';"
              style="opacity: 1;">
          </div>

          <div class="fill-color-Playable card-body text-center py-1 my-0"><small><strong>{status_text}</strong></small></div>
        </div>
      </a>
    </div>
"""

    html += f"""
  </div>

  <script>
    // Convert title cards to links - run immediately and also after dynamic content loads
    function wrapCardsWithLinks() {{
      // Find all title cards
      document.querySelectorAll('.title-card').forEach(card => {{
        const serial = card.getAttribute('data-serial');
        const title = card.getAttribute('data-title-name');
        const status = card.getAttribute('data-title-status');

        // Remove the existing anchor tag that's INSIDE the card
        const existingInnerLink = card.querySelector('a');
        if (existingInnerLink) {{
          // Move all children of the anchor to the card
          while (existingInnerLink.firstChild) {{
            card.insertBefore(existingInnerLink.firstChild, existingInnerLink);
          }}
          // Remove the empty anchor
          existingInnerLink.remove();
        }}

        // Determine the path - USE TITLE FIRST, then fall back to serial
        let url_path = '';
        if (title) {{
          url_path = title
            .toLowerCase()
            .replace(/[^\\w\\s-]/g, '')  // Remove special characters
            .replace(/\\s+/g, '-')       // Replace spaces with hyphens
            .replace(/-+/g, '-')        // Replace multiple hyphens with single
            .replace(/^-|-$/g, '');     // Remove leading/trailing hyphens
        }} else if (serial) {{
          url_path = serial;  // Fallback to serial if no title
        }}

        if (url_path) {{
          // Get the base URL from current page
          const urlParams = new URLSearchParams(window.location.search);
          const targetUrl = urlParams.get('url');

          // Create the new link
          const link = document.createElement('a');

          // Set href based on targetUrl
          if (targetUrl) {{
            link.href = targetUrl.replace(/\\/$/, '') + '/wii/' + url_path;
          }} else {{
            link.href = 'https://meyt.netlify.app/search/' + encodeURIComponent(title) + ' wii';
          }}

          link.className = 'title-card-link';
          link.rel = 'noopener noreferrer';
          link.target = '_blank';
          
          // Copy data attributes to link for search
          if (title) link.setAttribute('data-title-name', title);
          if (serial) link.setAttribute('data-serial', serial);
          if (status) link.setAttribute('data-title-status', status);

          // Wrap the card with the new link
          card.parentNode.insertBefore(link, card);
          link.appendChild(card);

          // Update status badge appearance
          const badge = card.querySelector('.fill-color-Playable, .status-badge');
          if (badge) {{
            // Remove existing fill-color classes
            badge.className = badge.className.replace(/fill-color-\\S+/g, '');
            // Add new status class
            if (status) {{
              badge.classList.add('status-' + status.toLowerCase());
            }}
          }}
        }}
      }});
    }}

    // Run immediately
    wrapCardsWithLinks();

    // Also run after dynamic content loads
    if (document.readyState === 'loading') {{
      document.addEventListener('DOMContentLoaded', wrapCardsWithLinks);
    }} else {{
      wrapCardsWithLinks();
    }}

    // Run again after a short delay for any late-loading content
    setTimeout(wrapCardsWithLinks, 500);

    // Search functionality
    document.getElementById('saved-search-input').addEventListener('input', function (e) {{
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

    // Keyboard shortcut: / to focus search
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
    print("🎮 Wii Games Grid Generator (Xemu Style)")
    print("=" * 50)
    
    # Load games data
    games = load_games_data()
    if not games:
        return
    
    # Generate HTML
    print("🔄 Generating grid website...")
    html_content = generate_html(games)
    
    # Save HTML file
    with open(OUTPUT_HTML, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    print(f"✅ Website generated: {OUTPUT_HTML}")
    print(f"\n📊 Statistics:")
    print(f"   - Total games: {len(games)}")
    print(f"   - With 2D covers: {sum(1 for g in games if g['cover_url'] != PLACEHOLDER_IMAGE)}")
    print(f"   - With 3D covers: {sum(1 for g in games if g['3d_cover_url'] != PLACEHOLDER_IMAGE)}")
    print(f"\n🌐 Open {OUTPUT_HTML} in your browser to view the grid!")
    print("\n✨ Features:")
    print("   - Exact Xemu page structure")
    print("   - Sticky search bar (press '/' to focus)")
    print("   - Real-time filtering by game name")
    print("   - Hover animations (scale effect)")
    print("   - Green 'Play' status for games with covers")
    print("   - Placeholder image for missing covers")

if __name__ == "__main__":
    main()