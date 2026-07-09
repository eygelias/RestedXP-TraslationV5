#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
extract_questie_npcs.py
Extrae nombres de NPCs de Questie y crea mapeo inglés → traducido.

Fuentes:
    - Database/{Classic,TBC,Wotlk,MoP}/...NpcDB.lua → nombres en inglés
    - Localization/lookups/{Classic,TBC,Wotlk,MoP}/lookupNpcs/{locale}.lua → nombres traducidos

Salida: database/questie_npcs_{locale}.json → {npc_id: {"en": "Name", "translated": "Nombre"}}
"""

import json
import re
from pathlib import Path

# ── Config ──
QUESTIE_DIR = Path(r"C:\Users\ELY\Desktop\Questie")
OUTPUT_DIR = Path(__file__).resolve().parent / "database"

EXPANSIONS = {
    "Classic": "classicNpcDB.lua",
    "TBC": "tbcNpcDB.lua",
    "Wotlk": "wotlkNpcDB.lua",
    "MoP": "mopNpcDB.lua",
}
LOCALES = ["esES", "esMX", "deDE", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]

# Regex for NPC DB: [123] = {'English Name', ...}
NPC_DB_RE = re.compile(r'\[(\d+)\]\s*=\s*\{\'([^\']*)\'')

# Regex for lookup: [123] = {"Translated Name", nil},
NPC_LOOKUP_RE = re.compile(r'\[(\d+)\]\s*=\s*\{"([^"]*)"(?:\s*,\s*"([^"]*)")?\s*\}')


def extract_english_npcs() -> dict:
    """Extract English NPC names from all expansion DB files."""
    all_npcs = {}  # {npc_id: english_name}

    for expansion, filename in EXPANSIONS.items():
        filepath = QUESTIE_DIR / "Database" / expansion / filename
        if not filepath.exists():
            print(f"  ⚠ No encontrado: {filepath}")
            continue

        content = filepath.read_text(encoding="utf-8", errors="ignore")
        count = 0
        for match in NPC_DB_RE.finditer(content):
            npc_id = match.group(1)
            name = match.group(2).strip()
            if name:
                all_npcs[npc_id] = name
                count += 1

        print(f"  {expansion}: {count} NPCs en inglés")

    return all_npcs


def extract_translated_npcs(locale: str) -> dict:
    """Extract translated NPC names from lookup files."""
    all_npcs = {}  # {npc_id: translated_name}

    for expansion in EXPANSIONS:
        filepath = QUESTIE_DIR / "Localization" / "lookups" / expansion / "lookupNpcs" / f"{locale}.lua"
        if not filepath.exists():
            continue

        content = filepath.read_text(encoding="utf-8", errors="ignore")
        count = 0
        for match in NPC_LOOKUP_RE.finditer(content):
            npc_id = match.group(1)
            name = match.group(2).strip()
            if name:
                all_npcs[npc_id] = name
                count += 1

        print(f"  {expansion}: {count} NPCs traducidos")

    return all_npcs


def main():
    print("=" * 50)
    print(" Questie NPC Extractor (EN → Traducido)")
    print("=" * 50)

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Step 1: Extract English names
    print("\n── Extrayendo nombres en inglés ──")
    english_npcs = extract_english_npcs()
    print(f"  Total inglés: {len(english_npcs)} NPCs")

    # Step 2: Extract translated names for each locale
    total_all = 0
    for locale in LOCALES:
        print(f"\n── {locale} ──")
        translated_npcs = extract_translated_npcs(locale)

        if not translated_npcs:
            print(f"  ⚠ No se encontraron NPCs")
            continue

        # Step 3: Create mapping {english_name: translated_name}
        mapping = {}
        for npc_id, en_name in english_npcs.items():
            if npc_id in translated_npcs:
                trans_name = translated_npcs[npc_id]
                if trans_name and trans_name != en_name:
                    mapping[en_name] = trans_name

        if mapping:
            output_file = OUTPUT_DIR / f"questie_npcs_{locale}.json"
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(mapping, f, ensure_ascii=False, indent=2)
            print(f"  ✅ {len(mapping)} NPCs con traducción → {output_file.name}")
            total_all += len(mapping)
        else:
            print(f"  ⚠ No hay NPCs con traducción diferente")

    print(f"\n{'=' * 50}")
    print(f" Total: {total_all} NPCs traducidos en {len(LOCALES)} idiomas")
    print(f"{'=' * 50}")


if __name__ == "__main__":
    main()
