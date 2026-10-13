"""Rebuild Godot 4.6 Android sparse metadata after replacing APK resources."""
import hashlib
import struct


def build_sparse_index(resources):
    files = {n: b for n, b in resources.items()
             if n not in ("assets.sparsepck", "_cl_") and not n.endswith("/")}
    # Godot PCK v3, relative base and sparse bundle, directory at byte 104.
    data = bytearray(struct.pack("<6I2Q", 0x43504447, 3, 4, 6, 3, 6, 0, 104))
    data.extend(bytes(64))
    data.extend(struct.pack("<I", len(files)))
    for name, contents in sorted(files.items()):
        path = name.encode("utf-8")
        padding = (-len(path)) % 4
        data.extend(struct.pack("<I", len(path) + padding))
        data.extend(path + bytes(padding))
        data.extend(struct.pack("<QQ", 0, len(contents)))
        data.extend(hashlib.md5(contents).digest())
        data.extend(struct.pack("<I", 0))
    return bytes(data)


def verify_sparse_index(resources):
    data = resources["assets.sparsepck"]
    if data[:4] != b"GDPC":
        raise ValueError("Invalid Godot sparse header")
    position = struct.unpack_from("<Q", data, 32)[0]
    count = struct.unpack_from("<I", data, position)[0]
    position += 4
    names = set()
    for _ in range(count):
        length = struct.unpack_from("<I", data, position)[0]
        position += 4
        name = data[position:position + length].rstrip(b"\0").decode("utf-8")
        position += length
        offset, size = struct.unpack_from("<QQ", data, position)
        position += 16
        digest = data[position:position + 16]
        position += 16
        flags = struct.unpack_from("<I", data, position)[0]
        position += 4
        contents = resources.get(name)
        if contents is None or offset or flags or size != len(contents) or digest != hashlib.md5(contents).digest():
            raise ValueError("Sparse index does not match resource: " + name)
        names.add(name)
    expected = set(resources) - {"assets.sparsepck", "_cl_"}
    if names != expected or position != len(data):
        raise ValueError("Sparse index file list differs from packaged resources")
    return count
