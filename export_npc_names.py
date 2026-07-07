"""
export_npc_names.py
Lee el archivo SavedVariables de RXPNameFixer y exporta los nombres a JSON
para usarlos en RXP Translator como fuente primaria de nombres de mobs.

Uso: python export_npc_names.py [ruta_a_SavedVariables]
"""

import json
import re
import sys
from pathlib import Path

def parse_wow_table(content, var_name):
    """Parsea una tabla de SavedVariables de WoW."""
    # Buscar RXPNameFixerDB = { ... }
    pattern = rf'{var_name}\s*=\s*\{{(.*?)\n\}}'
    match = re.search(pattern, content, re.DOTALL)
    if not match:
        return {}
    
    table_content = match.group(1)
    result = {}
    
    # Parsear entradas [12345] = "nombre"
    for m in re.finditer(r'\[(\d+)\]\s*=\s*"([^"]*)"', table_content):
        npc_id = int(m.group(1))
        name = m.group(2)
        # Decodificar escapes de WoW
        name = name.replace('\\n', '\n').replace('\\"', '"')
        result[npc_id] = name
    
    return result

def main():
    # Buscar archivo SavedVariables
    if len(sys.argv) > 1:
        sv_path = Path(sys.argv[1])
    else:
        # Ruta por defecto de WoW
        sv_path = Path(r"C:\Program Files (x86)\World of Warcraft\_anniversary_\WTF\Account\SavedVariables\RXPNameFixer.lua")
        
        if not sv_path.exists():
            # Buscar dentro de Account/<cuenta>/SavedVariables (ruta real de WoW)
            wow_base = Path(r"C:\Program Files (x86)\World of Warcraft")
            for variant in ["_anniversary_", "_classic_", "_classic_era_", ""]:
                account_dir = wow_base / variant / "WTF" / "Account"
                for candidate in account_dir.glob("*/SavedVariables/RXPNameFixer.lua"):
                    sv_path = candidate
                    break
                if sv_path.exists():
                    break
    
    if not sv_path.exists():
        print(f"ERROR: No se encontró {sv_path}")
        print("Uso: python export_npc_names.py [ruta_a_RXPNameFixer.lua]")
        return
    
    print(f"Leyendo: {sv_path}")
    content = sv_path.read_text(encoding="utf-8-sig", errors="ignore")
    
    names = parse_wow_table(content, "RXPNameFixerDB")
    print(f"NPCs encontrados: {len(names)}")
    
    if not names:
        print("No se encontraron nombres. ¿Has jugado con el addon activado?")
        return
    
    # Exportar a JSON
    output_path = sv_path.parent / "rxp_npc_names_export.json"
    
    # Organizar por ID
    export_data = {}
    for npc_id, name in sorted(names.items()):
        export_data[str(npc_id)] = name
    
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(export_data, f, ensure_ascii=False, indent=2)
    
    print(f"Exportado a: {output_path}")
    print(f"Total: {len(export_data)} nombres de NPCs")
    
    # Mostrar algunos ejemplos
    print("\nEjemplos:")
    for i, (npc_id, name) in enumerate(sorted(names.items(), key=lambda x: x[0])):
        if i >= 10:
            print(f"  ... y {len(names) - 10} más")
            break
        print(f"  [{npc_id}] = {name}")

if __name__ == "__main__":
    main()
