#!/usr/bin/env python3
"""Convert docs/USER_MANUAL.md to docs/manual.html with sci-fi theme."""
import re
import sys

md_path = 'docs/USER_MANUAL.md'
html_path = 'docs/manual.html'

with open(md_path, 'r', encoding='utf-8') as f:
    md = f.read()

# --- Convert Markdown to HTML ---

html = md

# Escape HTML special chars first (but preserve code blocks)
# We'll handle code blocks separately

# Split into lines for block-level processing
lines = html.split('\n')
out_lines = []
in_code_block = False
code_lang = ''
code_lines = []
in_table = False
table_rows = []

def flush_code_block():
    global code_lines, code_lang
    if code_lines:
        escaped = '\n'.join(code_lines)
        escaped = escaped.replace('&', '&amp;').replace('<', '&lt;').replace('>', '&gt;')
        out_lines.append(f'<pre><code class="lang-{code_lang}">{escaped}</code></pre>')
        code_lines = []

def flush_table():
    global table_rows
    if table_rows:
        out_lines.append('<table>')
        for i, row in enumerate(table_rows):
            tag = 'th' if i == 0 else 'td'
            cells = ''.join(f'<{tag}>{cell}</{tag}>' for cell in row)
            out_lines.append(f'<tr>{cells}</tr>')
        out_lines.append('</table>')
        table_rows = []

for line in lines:
    # Code block fences
    if line.strip().startswith('```'):
        if in_code_block:
            flush_code_block()
            in_code_block = False
        else:
            flush_table()
            in_code_block = True
            code_lang = line.strip()[3:].strip()
        continue
    if in_code_block:
        code_lines.append(line)
        continue

    # Table rows
    if line.strip().startswith('|') and not line.strip().startswith('|---'):
        cells = [c.strip() for c in line.strip().strip('|').split('|')]
        table_rows.append(cells)
        in_table = True
        continue
    else:
        if in_table:
            flush_table()
            in_table = False

    # Horizontal rule
    if line.strip() == '---':
        out_lines.append('<hr>')
        continue

    # Headings
    m = re.match(r'^(#{1,6})\s+(.+)$', line)
    if m:
        level = len(m.group(1))
        text = m.group(2)
        # Strip inline markdown for heading text
        text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
        text = re.sub(r'`([^`]+)`', r'<code>\1</code>', text)
        # Generate id from heading text
        slug = re.sub(r'[^a-z0-9\- ]', '', text.lower())
        slug = re.sub(r'\s+', '-', slug.strip())
        slug = re.sub(r'-+', '-', slug)
        slug = slug.strip('-')
        out_lines.append(f'<h{level} id="{slug}">{text}</h{level}>')
        continue

    # Paragraphs / inline content
    stripped = line.strip()
    if stripped == '':
        out_lines.append('')
        continue

    # Inline formatting
    content = stripped
    content = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', content)
    content = re.sub(r'`([^`]+)`', r'<code>\1</code>', content)
    def inline_link(m):
        text = m.group(1)
        url = m.group(2)
        if url.startswith('#'):
            slug = re.sub(r'[^a-z0-9\- ]', '', text.lower())
            slug = re.sub(r'\s+', '-', slug.strip())
            slug = re.sub(r'-+', '-', slug)
            slug = slug.strip('-')
            return f'<a href="#{slug}">{text}</a>'
        return f'<a href="{url}">{text}</a>'
    content = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', inline_link, content)

    # List items
    if content.startswith('- '):
        content = '<li>' + content[2:] + '</li>'
        out_lines.append(content)
        continue
    else:
        # If we had pending list items, they're already flushed per-line
        pass

    out_lines.append(f'<p>{content}</p>')

flush_code_block()
flush_table()

body_html = '\n'.join(out_lines)

# --- Wrap in HTML page ---

full_html = f"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>ChameleonDrummer — User Manual</title>
<link rel="stylesheet" href="style.css">
</head>
<body>

<header>
  <div class="container">
    <h1><span class="logo">◉</span> CHAMELEON<span class="accent">DRUMMER</span></h1>
    <nav>
      <a href="index.html">HOME</a>
      <a href="concepts.html">CONCEPTS</a>
      <a href="docs.html">MANUAL</a>
      <a href="download.html">DOWNLOAD</a>
    </nav>
  </div>
</header>

<section class="main-content">
  <div class="container">
    <h2>USER MANUAL</h2>
    {body_html}
  </div>
</section>

<footer>
  <div class="container">
    <p>ChameleonDrummer — FreePascal / Lazarus MIDI Drum Generation.</p>
    <p>Source: <code>ChameleonDrummer/</code> · Manual: <code>docs/USER_MANUAL.md</code> · Pascal docs: <code>docs/PASCAL_PROGRAMS.md</code></p>
  </div>
</footer>

</body>
</html>"""

with open(html_path, 'w', encoding='utf-8', newline='\r\n') as f:
    f.write(full_html)

print(f'Converted {md_path} -> {html_path}')
print(f'Lines: {len(lines)} -> HTML body chars: {len(body_html)}')
