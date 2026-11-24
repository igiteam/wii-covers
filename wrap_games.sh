
cd ~/Downloads

cp index.html index.html.backup3

ruby <<'RUBY'
file = "index.html"
html = File.read(file, encoding: "UTF-8")

marker = "    // Search functionality - NO GREEN BORDERS"

js = <<~'JS'
    // FIX: Wrap ALL remaining title cards in search links
    function wrapRemainingCardsWithLinks() {
      document.querySelectorAll('.title-card').forEach(card => {

        // Skip cards already wrapped
        if (card.closest('a.title-card-link')) return;

        const title =
          card.getAttribute('data-title-name') ||
          card.querySelector('img')?.getAttribute('title') ||
          card.querySelector('.fallback-title')?.textContent.trim();

        if (!title) return;

        const link = document.createElement('a');

        link.href = 'https://meyt.macosxjs.com/search/' +
                    encodeURIComponent(title + ' wii');

        link.className = 'title-card-link';
        link.rel = 'noopener noreferrer';
        link.target = '_blank';

        link.style.display = 'block';
        link.style.textDecoration = 'none';
        link.style.color = 'inherit';

        link.setAttribute('data-title-name', title);

        const status = card.getAttribute('data-title-status');
        if (status) {
          link.setAttribute('data-title-status', status);
        }

        card.parentNode.insertBefore(link, card);
        link.appendChild(card);
      });
    }

    wrapRemainingCardsWithLinks();

    if (document.readyState === 'loading') {
      document.addEventListener('DOMContentLoaded', wrapRemainingCardsWithLinks);
    }

    setTimeout(wrapRemainingCardsWithLinks, 500);

JS

unless html.include?(marker)
  abort "ERROR: JavaScript insertion point not found. Original unchanged."
end

if html.include?("FIX: Wrap ALL remaining title cards")
  abort "Fallback already exists. No changes made."
end

html.sub!(marker, js + marker)

File.write(file, html, encoding: "UTF-8")

puts "===================================="
puts " ALL TITLE CARDS WRAPPED"
puts "===================================="
puts "JavaScript fallback installed."
puts "Backup: index.html.backup3"
puts "===================================="
RUBY
