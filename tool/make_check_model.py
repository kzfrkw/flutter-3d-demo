#!/usr/bin/env python3
"""s0-check 用の glb(アニメ付きの箱 1 つ)を生成する。

このスクリプトと出力の assets/models/check_cube.glb は自作で、CC0 1.0 とする。
使い方: python3 tool/make_check_model.py
"""
import json
import math
import struct

# 24 頂点(面ごとに法線を持つ)の箱。一辺 1。
faces = [
    ((0, 0, 1), [(-.5, -.5, .5), (.5, -.5, .5), (.5, .5, .5), (-.5, .5, .5)]),
    ((0, 0, -1), [(.5, -.5, -.5), (-.5, -.5, -.5), (-.5, .5, -.5), (.5, .5, -.5)]),
    ((1, 0, 0), [(.5, -.5, .5), (.5, -.5, -.5), (.5, .5, -.5), (.5, .5, .5)]),
    ((-1, 0, 0), [(-.5, -.5, -.5), (-.5, -.5, .5), (-.5, .5, .5), (-.5, .5, -.5)]),
    ((0, 1, 0), [(-.5, .5, .5), (.5, .5, .5), (.5, .5, -.5), (-.5, .5, -.5)]),
    ((0, -1, 0), [(-.5, -.5, -.5), (.5, -.5, -.5), (.5, -.5, .5), (-.5, -.5, .5)]),
]
pos, nor, idx = [], [], []
for n, vs in faces:
    base = len(pos)
    for v in vs:
        pos.append(v)
        nor.append(n)
    idx += [base, base + 1, base + 2, base, base + 2, base + 3]

times = [0.0, 1.0, 2.0, 3.0]
rots = []
for deg in (0, 120, 240, 360):
    h = math.radians(deg) / 2
    rots.append((0.0, math.sin(h), 0.0, math.cos(h)))

def pad(b, c=b"\x00"):
    return b + c * (-len(b) % 4)

bin_parts, views, accessors = [], [], []

def add(data, target, count, ctype, atype, mn=None, mx=None):
    off = sum(len(p) for p in bin_parts)
    bin_parts.append(pad(data))
    view = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
    if target:
        view["target"] = target
    views.append(view)
    acc = {"bufferView": len(views) - 1, "componentType": ctype,
           "count": count, "type": atype}
    if mn:
        acc["min"], acc["max"] = mn, mx
    accessors.append(acc)
    return len(accessors) - 1

flat = lambda xs: [c for x in xs for c in x]
a_pos = add(struct.pack(f"<{len(pos)*3}f", *flat(pos)), 34962, len(pos), 5126, "VEC3",
            [-.5, -.5, -.5], [.5, .5, .5])
a_nor = add(struct.pack(f"<{len(nor)*3}f", *flat(nor)), 34962, len(nor), 5126, "VEC3")
a_idx = add(struct.pack(f"<{len(idx)}H", *idx), 34963, len(idx), 5123, "SCALAR")
a_t = add(struct.pack(f"<{len(times)}f", *times), None, len(times), 5126, "SCALAR",
          [times[0]], [times[-1]])
a_r = add(struct.pack(f"<{len(rots)*4}f", *flat(rots)), None, len(rots), 5126, "VEC4")

gltf = {
    "asset": {"version": "2.0", "generator": "tool/make_check_model.py (CC0 1.0)"},
    "scene": 0,
    "scenes": [{"nodes": [0]}],
    "nodes": [{"name": "Cube", "mesh": 0}],
    "meshes": [{"name": "Cube", "primitives": [{
        "attributes": {"POSITION": a_pos, "NORMAL": a_nor},
        "indices": a_idx, "material": 0}]}],
    "materials": [{"name": "Orange", "pbrMetallicRoughness": {
        "baseColorFactor": [0.95, 0.5, 0.1, 1.0], "metallicFactor": 0.0,
        "roughnessFactor": 0.6}}],
    "animations": [{"name": "Spin",
                    "samplers": [{"input": a_t, "output": a_r, "interpolation": "LINEAR"}],
                    "channels": [{"sampler": 0, "target": {"node": 0, "path": "rotation"}}]}],
    "accessors": accessors,
    "bufferViews": views,
    "buffers": [{"byteLength": sum(len(p) for p in bin_parts)}],
}
js = pad(json.dumps(gltf, separators=(",", ":")).encode(), b" ")
bn = b"".join(bin_parts)
total = 12 + 8 + len(js) + 8 + len(bn)
out = struct.pack("<III", 0x46546C67, 2, total)
out += struct.pack("<II", len(js), 0x4E4F534A) + js
out += struct.pack("<II", len(bn), 0x004E4942) + bn
open("assets/models/check_cube.glb", "wb").write(out)
print("wrote assets/models/check_cube.glb", total, "bytes")
