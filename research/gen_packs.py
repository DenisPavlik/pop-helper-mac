#!/usr/bin/env python3
"""Generate PoPHelper/Resources/packs.json from the extracted cosmetic packs.

The pack ASSET files live locally in ~/Library/Application Support/PoP Helper
Mac/Packs/<id>/ (third-party mods, not in git). This manifest — which IS in git
— describes how each pack installs into the mod: file source->target mappings,
"choice" options (auto-enumerated for crosshair/ui), preview images, and any
module.ini `load_mod_resource` names a .brf pack needs.

Run from repo root: python3 research/gen_packs.py
"""
import json
import os
import re

PACKS_DIR = os.path.expanduser("~/Library/Application Support/PoP Helper Mac/Packs")
OUT = os.path.join(os.path.dirname(__file__), "..", "PoPHelper", "Resources", "packs.json")


def num_key(s):
    m = re.search(r"(\d+)", s)
    return (int(m.group(1)) if m else 0, s)


def crosshair_options():
    base = os.path.join(PACKS_DIR, "crosshair-tool", "files/other/CrosshairChanger")
    opts = []
    for f in sorted(os.listdir(base), key=num_key):
        n = re.search(r"(\d+)", f).group(1)
        opts.append({
            "id": n,
            "name": {"en": f"Crosshair {n}", "uk": f"Приціл {n}"},
            "preview": f"image/pic/crosshair/{n}.png",
            "files": [{"from": f"files/other/CrosshairChanger/{f}", "to": "Textures/ui_gadgets.dds"}],
        })
    return opts


def ui_options():
    base = os.path.join(PACKS_DIR, "ui-pack", "files/other/ui_pack")
    labels = {
        "got": "Game of Thrones", "knightly": "Knightly", "ngold": "Native Gold",
        "ngreen": "Native Green", "np": "Native Purple", "nr": "Native Red",
        "ns": "Native Silver", "ny": "Native Yellow", "v": "Vaegir", "vg": "Vaegir Gold",
    }
    opts = []
    for d in sorted(os.listdir(base)):
        if not os.path.isdir(os.path.join(base, d)):
            continue
        label = labels.get(d, d)
        opts.append({
            "id": d,
            "name": {"en": label, "uk": label},
            "files": [{"from": f"files/other/ui_pack/{d}/user_interface_b.dds", "to": "Textures/user_interface_b.dds"}],
        })
    return opts


def main():
    packs = [
        {
            "id": "female-faces",
            "name": {"en": "Alternative female faces", "uk": "Покращені жіночі обличчя"},
            "description": {"en": "Prettier female face meshes and textures (PoP Helper's faces1).",
                            "uk": "Гарніші меші й текстури жіночих облич (faces1 з PoP Helper)."},
            "kind": "copy",
            "files": [
                {"from": "Textures", "to": "Textures"},
                {"from": "Resource", "to": "Resource"},
                {"from": "skins.txt", "to": "skins.txt"},
            ],
            "moduleResources": ["wb_textures_face_gen", "wb_materials_face_gen", "wb_meshes_face_gen",
                                "materials_face_gen", "materials_face_gen_gaolu", "meshes_face_gen_gaolu",
                                "hair_gaolu"],
        },
        {
            "id": "crosshair-tool",
            "name": {"en": "Crosshair", "uk": "Приціл"},
            "description": {"en": "Replace the aiming crosshair — choose a style.",
                            "uk": "Заміна прицілу під час стрільби — обери стиль."},
            "kind": "choice",
            "options": crosshair_options(),
        },
        {
            "id": "ui-pack",
            "name": {"en": "UI skin", "uk": "Скін інтерфейсу"},
            "description": {"en": "Dezlaros UI pack — reskin the in-game panels.",
                            "uk": "UI-пак Dezlaros — змінює вигляд ігрових панелей."},
            "kind": "choice",
            "options": ui_options(),
        },
        {
            "id": "arena-overhaul",
            "name": {"en": "Arena Overhaul", "uk": "Оновлені арени"},
            "description": {"en": "Reworked tournament arena scenes.",
                            "uk": "Перероблені сцени турнірних арен."},
            "kind": "copy",
            "files": [{"from": ".sco", "to": "SceneObj"}],
        },
        {
            "id": "fonts",
            "name": {"en": "Font", "uk": "Шрифт"},
            "description": {"en": "Alternative in-game font.", "uk": "Альтернативний ігровий шрифт."},
            "kind": "copy",
            "files": [{"from": "Textures/font.dds", "to": "Textures/font.dds"},
                      {"from": "Data/font_data.xml", "to": "Data/font_data.xml"}],
        },
        {
            "id": "old-qualis-gem",
            "name": {"en": "Old Qualis Gem look", "uk": "Старий вигляд Qualis Gem"},
            "description": {"en": "Restore the old Qualis Gem appearance.",
                            "uk": "Повернути старий вигляд каменя Qualis."},
            "kind": "copy",
            "files": [{"from": "Resource/pop_random.brf", "to": "Resource/pop_random.brf"},
                      {"from": "Textures/aqs_objects.dds", "to": "Textures/aqs_objects.dds"}],
            "moduleResources": ["pop_random"],
        },
        {
            "id": "collision-fixes",
            "name": {"en": "Collision fixes", "uk": "Виправлення колізій"},
            "description": {"en": "Mesh collision fixes (PoP Helper's colfix).",
                            "uk": "Виправлення колізій мешів (colfix з PoP Helper)."},
            "kind": "copy",
            "files": [{"from": "ColFix.brf", "to": "Resource/ColFix.brf"}],
            "moduleResources": ["ColFix"],
        },
    ]
    manifest = {"schemaVersion": 1, "packs": packs}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(manifest, f, ensure_ascii=False, indent=2)
        f.write("\n")
    n_opts = sum(len(p.get("options", [])) for p in packs)
    print(f"Wrote {os.path.normpath(OUT)}: {len(packs)} packs, {n_opts} options")


if __name__ == "__main__":
    main()
