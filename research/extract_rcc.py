#!/usr/bin/env python3
"""Extract PoP Helper's cosmetic packs from its Qt `.rcc` resource files.

PoP Helper (the Windows app) ships each cosmetic add-on as a Qt Resource
Collection (`.rcc`) under `PoP Helper/data/`. Two shapes occur:

  * ZIP-wrapped — the rcc's single data blob is a plain ZIP (mod_girl_face,
    arena, OldQualis, ColFix, fonts, fix39, reset, rus*). We carve the ZIP by
    its PK signatures and unzip it.
  * Raw Qt resource tree — DDS/other files stored as individual resource
    nodes (CursorChanger, CrosshairTool, ui_pack). We parse the Qt rcc binary
    format (v2/v3) directly.

No part of PoP Helper is executed; this is pure file extraction. The packs are
third-party mods — extract them to the app's local Packs library, NOT into git.

Usage:
  python3 research/extract_rcc.py "<.../PoP Helper/data>" "<output Packs dir>"
"""
import os
import shutil
import sys
import zlib

PACKS = {
    "mod_girl_face": "female-faces",
    "ui_pack": "ui-pack",
    "arena": "arena-overhaul",
    "OldQualis": "old-qualis-gem",
    "ColFix": "collision-fixes",
    "fonts": "fonts",
    "fix39": "fix-3.9",
    "CursorChanger": "cursor-changer",
    "CrosshairTool": "crosshair-tool",
    "reset": "reset-vanilla",
    "rus": "rus-loc",
    "rus_warband": "rus-warband-loc",
}


def carve_zip(data, dest):
    import zipfile
    s = data.find(b"PK\x03\x04")
    e = data.rfind(b"PK\x05\x06")
    if s < 0 or e < 0:
        return None
    comment_len = int.from_bytes(data[e + 20:e + 22], "little")
    zpath = dest + ".zip"
    with open(zpath, "wb") as f:
        f.write(data[s:e + 22 + comment_len])
    with zipfile.ZipFile(zpath) as z:
        z.extractall(dest)
        n = sum(1 for i in z.namelist() if not i.endswith("/"))
    os.remove(zpath)
    return n


def parse_rcc(data, dest):
    """Parse a Qt resource (.rcc) binary tree (format v1/v2/v3)."""
    assert data[:4] == b"qres"
    version = int.from_bytes(data[4:8], "big")
    tree_off = int.from_bytes(data[8:12], "big")
    data_off = int.from_bytes(data[12:16], "big")
    name_off = int.from_bytes(data[16:20], "big")
    node_size = 22 if version >= 2 else 14
    count = [0]

    def read_name(off):
        ln = int.from_bytes(data[name_off + off:name_off + off + 2], "big")
        start = name_off + off + 6  # skip u16 length + u32 hash
        return data[start:start + ln * 2].decode("utf-16-be")

    def walk(index, prefix):
        base = tree_off + index * node_size
        name_o = int.from_bytes(data[base:base + 4], "big")
        flags = int.from_bytes(data[base + 4:base + 6], "big")
        name = "" if index == 0 else read_name(name_o)
        if flags & 0x02:  # directory
            child_count = int.from_bytes(data[base + 6:base + 10], "big")
            child_off = int.from_bytes(data[base + 10:base + 14], "big")
            nxt = os.path.join(prefix, name) if name else prefix
            for c in range(child_count):
                walk(child_off + c, nxt)
        else:  # file
            do = int.from_bytes(data[base + 10:base + 14], "big")
            ln = int.from_bytes(data[data_off + do:data_off + do + 4], "big")
            blob = data[data_off + do + 4:data_off + do + 4 + ln]
            if flags & 0x01:  # zlib (Qt qCompress: u32 size + zlib stream)
                blob = zlib.decompress(blob[4:])
            elif flags & 0x04:  # zstd
                import zstandard
                blob = zstandard.ZstdDecompressor().decompress(blob)
            full = os.path.join(dest, prefix, name)
            os.makedirs(os.path.dirname(full), exist_ok=True)
            with open(full, "wb") as f:
                f.write(blob)
            count[0] += 1

    walk(0, "")
    return count[0]


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    data_dir, out_dir = sys.argv[1], sys.argv[2]
    for rcc, pack in PACKS.items():
        src = os.path.join(data_dir, rcc + ".rcc")
        if not os.path.exists(src):
            print(f"{pack:18} (no {rcc}.rcc)")
            continue
        dest = os.path.join(out_dir, pack)
        if os.path.isdir(dest):
            shutil.rmtree(dest)
        os.makedirs(dest, exist_ok=True)
        raw = open(src, "rb").read()
        try:
            n = carve_zip(raw, dest)
            if n is None:
                n = parse_rcc(raw, dest)
                kind = "rcc-tree"
            else:
                kind = "zip"
            print(f"{pack:18} OK {n} files ({kind})")
        except Exception as exc:  # noqa: BLE001
            print(f"{pack:18} ERROR {exc}")


if __name__ == "__main__":
    main()
