#!/usr/bin/env python3
"""Update the static website from the same feature catalogue used by the Godot lobby."""
import json
import re
from html import escape
from pathlib import Path
root = Path(__file__).resolve().parents[1]
data = json.loads((root / 'game/data/home_features.json').read_text())
page = root / 'website/index.html'
text = page.read_text()
features = '\n'.join(f'<article><img src="/assets/icons/{escape(f["icon"])}.svg" width="27" height="27" alt="" loading="lazy"><h3>{escape(f["title"])}</h3><p>{escape(f["text"])}</p></article>' for f in data['features'])
updates = '\n'.join(f'<article><time datetime="2026-10-14">{escape(u["date"])}</time><h3>{escape(u["title"])}</h3><p>{escape(u["text"])}</p></article>' for u in data['updates'])
for key, value in [('FEATURES', features), ('UPDATES', updates)]:
    marker = f'<!-- {key} -->'
    end = f'<!-- /{key} -->'
    pattern = re.escape(marker) + r'(?:.*?' + re.escape(end) + r')?'
    text, count = re.subn(pattern, marker + '\n' + value + '\n' + end, text, count=1, flags=re.S)
    assert count == 1, f'Missing {key} marker'
page.write_text(text)
(root / 'website/assets/features.json').write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
print(f'Synced {len(data["features"])} features and {len(data["updates"])} updates.')
