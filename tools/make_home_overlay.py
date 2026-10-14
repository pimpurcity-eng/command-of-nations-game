#!/usr/bin/env python3
"""Create a small UI update from a complete, freshly exported Godot PCK.

Usage: python3 tools/make_home_overlay.py /absolute/new-export.pck /absolute/home.pck
Mount it before loading startup.tscn; preserve the deployed main/extras packs and audio.
A subsequent full web export includes these changes and replaces the overlay launcher.
"""
import hashlib
import re
import struct
import sys
from pathlib import Path
source, destination = map(Path, sys.argv[1:3])
with source.open('rb') as f:
    header = f.read(112)
    assert header[:4] == b'GDPC'
    base = struct.unpack('<Q', header[24:32])[0]
    f.seek(struct.unpack('<Q', header[32:40])[0])
    entries = {}
    for _ in range(struct.unpack('<I', f.read(4))[0]):
        name = f.read(struct.unpack('<I', f.read(4))[0]).rstrip(b'\0').decode()
        offset, size = struct.unpack('<QQ', f.read(16))
        entries[name] = {'name': name, 'offset': offset, 'size': size,
                         'md5': f.read(16), 'flags': struct.unpack('<I', f.read(4))[0]}
    keep = ['scripts/main.gd.remap', 'scripts/mobile_start_panel.gd.remap', 'data/home_features.json']
    for name in keep[:2]:
        e = entries[name]
        f.seek(base + e['offset'])
        keep.extend(re.findall(r'"res://([^\"]+)"', f.read(e['size']).decode()))
    selected = []
    for name in dict.fromkeys(keep):
        e = entries[name]
        f.seek(base + e['offset'])
        e['data'] = f.read(e['size'])
        assert hashlib.md5(e['data']).digest() == e['md5'], name
        selected.append(e)
with destination.open('wb') as out:
    out.write(header)
    offsets, position = [], 0
    for e in selected:
        padding = (-position) % 32
        out.write(b'\0' * padding)
        position += padding
        offsets.append(position)
        out.write(e['data'])
        position += e['size']
    padding = (-position) % 32
    out.write(b'\0' * padding)
    position += padding
    directory = 112 + position
    out.write(struct.pack('<I', len(selected)))
    for e, offset in zip(selected, offsets):
        name = e['name'].encode() + b'\0'
        name += b'\0' * ((-len(name)) % 4)
        out.write(struct.pack('<I', len(name)) + name + struct.pack('<QQ', offset, e['size']) + e['md5'] + struct.pack('<I', e['flags']))
    out.seek(32)
    out.write(struct.pack('<Q', directory))
print(f'Home update: {destination.stat().st_size:,} bytes, {len(selected)} files')
