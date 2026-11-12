import os
import io
import json
import base64
from jinja2 import Environment, FileSystemLoader
from PIL import Image, ImageDraw, ImageFont
import pypdf

os.makedirs('tests/fixtures/raster_photos', exist_ok=True)
colors = [(180, 130, 90), (120, 150, 170), (140, 160, 120), (190, 140, 150), (160, 140, 180), (180, 160, 120)]
photo_uris = {}

for idx, col in enumerate(colors, 1):
    img = Image.new('RGB', (1200, 1200), color=col)
    draw = ImageDraw.Draw(img)
    draw.rectangle([60, 60, 1140, 1140], outline=(255, 255, 255), width=8)
    draw.text((120, 120), f"Pet Photo Slot P{idx}\nArchival KeepSafe\n1200x1200px 300DPI", fill=(255, 255, 255))
    
    # Save local fixture
    fixture_path = f"tests/fixtures/raster_photos/photo_p{idx}.jpg"
    img.save(fixture_path, format="JPEG", quality=90)
    
    # Encode as base64 data URI for 100% self-contained offline rendering
    buf = io.BytesIO()
    img.save(buf, format="JPEG", quality=85)
    b64_str = base64.b64encode(buf.getvalue()).decode('utf-8')
    photo_uris[f"p{idx}"] = f"data:image/jpeg;base64,{b64_str}"

print(f"Generated {len(photo_uris)} raster photo fixtures and data URIs.")

# Load template with Jinja2
env = Environment(loader=FileSystemLoader('templates/petstory_v1'), autoescape=True)
tmpl = env.get_template('template.html')

# Test context with all 6 photos, gift purpose, cat, and breeding origin
context = {
    'answers': {
        'pet_name': 'Cleopatra',
        'pet_type': 'cat',
        'book_purpose': 'gift',
        'life_stage': 'adult',
        'origin_type': 'breeder',
        'nicknames': 'Cleo, Queen of the Couch',
        'breed_description': 'Calico Beauty',
        'gotcha_date': 'May 14, 2022',
        'home_city': 'Taguig City',
        'personality_traits': ['Regal & Aloof', 'Playful Predator', 'Lap Warmer'],
        'quirks': ['Demands breakfast at 5 AM sharp', 'Attacks ankles from under bed', 'Purrs like an engine'],
        'owner_names': 'Auntie Maria & Uncle Robert',
        'dedication_text': 'To our dearest niece, may this archival book remind you of every purr, head-bump, and happy moment shared with Cleo.',
        'palette_id': 'terracotta',
        'icon_id': 'heart_whiskers'
    },
    'photos': photo_uris
}

rendered_html = tmpl.render(**context)

# Read style.css and inline into rendered HTML for standalone print
css_content = open('templates/petstory_v1/style.css', 'r', encoding='utf-8').read()
styled_html = f"""<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
{css_content}
@media print {{
    .page {{
        break-after: page !important;
        page-break-after: always !important;
        width: 210mm !important;
        height: 210mm !important;
    }}
}}
</style>
</head>
<body class="palette-{context['answers']['palette_id']}">
{rendered_html[rendered_html.find('<!-- ==================== PAGE 1:'):rendered_html.find('</body>')]}
</body>
</html>
"""

output_html_path = 'test_cleopatra_raster.html'
with open(output_html_path, 'w', encoding='utf-8') as f:
    f.write(styled_html)

print("Rendered HTML with raster photos saved to:", output_html_path)

