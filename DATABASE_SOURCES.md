# Database Sources — RXP Translator V5

URLs y fuentes de datos usadas por el traductor.

## Fuentes de datos (prioridad)

### 1. Cliente WoW en vivo (RXPNameFixer)
- **Tipo:** Runtime, más oficial
- **Método:** `GameTooltip:SetHyperlink("unit:Creature-0-0-0-0-"..npcID)`
- **Addon:** `RXPNameFixer.lua` (incluido en este repo)
- **Cache:** `RXPNameFixerDB` SavedVariables

### 2. Wowhead TBC Classic ES
- **Tipo:** Externo, fallback por NPC ID
- **URL patrón:** `https://www.wowhead.com/tbc/es/npc=<ID>`
- **Ejemplo:** https://www.wowhead.com/tbc/es/npc=7856
- **Uso:** Título de página = nombre localizado
- **Nota:** No automatizable masivamente sin scraping

### 3. QuestieDB v0.7.x
- **Tipo:** Local estático, fuente principal
- **GitHub:** https://github.com/Questie/QuestieDB
- **Descarga release:** https://github.com/Questie/QuestieDB/releases
- **Archivo:** `QuestieDB-v0.7.0.zip` (~90 MB)
- **Contenido:** NPCs, Items, Objects, Quests con nombres en 9 idiomas
- **Formato:** Lua tables con HTML embebido
- **Uso en translator:** `build_database.py` extrae y genera `questiedb_es.json`

### 4. RXPGuides (RestedXP)
- **Tipo:** Addon WoW, fuente de NPCs + interfaz
- **GitHub:** https://github.com/RestedXP/RXPGuides/releases
- **CurseForge:** https://www.curseforge.com/wow/addons/restedxp-guide
- **Descarga directa:** https://download.restedxp.com/
- **Archivos usados:**
  - `locale/NPCnames.lua` — Nombres de NPCs del cliente
  - `locale/esES.lua` — Frases de interfaz del addon
  - `locale/localization_strings.lua` — Strings de localización
- **Genera:** `npcnames_esES.json`, `addon_phrases.json`

### 5. CMaNGOS TBC Database
- **Tipo:** Local estático, fallback amplio
- **GitHub:** https://github.com/cmangos/tbc-db
- **Repo alterno:** https://github.com/TBC-DB/Database
- **Servidor:** https://github.com/cmangos/mangos-tbc
- **Archivos SQL relevantes:**
  - `creature_template_locale.sql` — Nombres de NPCs traducidos
  - `item_template_locale.sql` — Nombres de items
  - `quest_template_locale.sql` — Nombres de quests
  - `gameobject_template_locale.sql` — Nombres de objetos
- **Formato:** SQL INSERT statements
- **Genera:** `merged_esES.json` (combinado con Questie)

### 6. Questie NPCs (fallback)
- **Tipo:** Local estático, fallback menor
- **GitHub:** https://github.com/Questie/Questie
- **Archivo:** `questie_npcs_esES.json`
- **Contenido:** Subset de NPCs con nombres traducidos

## Archivos de base de datos generados

| Archivo | Fuente principal | Contenido |
|---------|-----------------|-----------|
| `questiedb_es.json` | QuestieDB + CMaNGOS | NPCs, Items, Objects, Quests con IDs |
| `npcnames_esES.json` | RXPGuides NPCnames.lua | Nombres de NPCs del addon |
| `questie_npcs_esES.json` | Questie addon | NPCs fallback |
| `merged_esES.json` | CMaNGOS + Questie | Combinado, prioridad CMaNGOS |
| `zones_esES.json` | Questie + manual | Nombres de zonas |
| `spells_es.json` | QuestieDB | Nombres de hechizos |
| `addon_phrases.json` | RXPGuides esES.lua | Frases de interfaz |
| `manual_overrides.json` | Manual | Correcciones manuales (máxima prioridad) |

## Workflow de actualización de bases

```bash
# 1. Descargar QuestieDB más reciente
# https://github.com/Questie/QuestieDB/releases
# Copiar QuestieDB-vX.X.X.zip a RXP_Translator_V5/

# 2. Descargar RXPGuides más reciente
# https://github.com/RestedXP/RXPGuides/releases
# Extraer locale/NPCnames.lua y locale/esES.lua a rxpguides_locale/

# 3. (Opcional) Actualizar CMaNGOS
# https://github.com/cmangos/tbc-db
# Extraer creature_template_locale.sql

# 4. Reconstruir base de datos
python build_database.py

# 5. Exportar cache del cliente WoW (si hay datos nuevos)
python export_npc_names.py
```

## Notas

- **CMaNGOS** tiene nombres ya traducidos — usar directamente, no re-traducir
- **QuestieDB** es la fuente más completa con IDs mapeados
- **RXPGuides NPCnames** viene del cliente real pero puede estar incompleto
- **Wowhead** es el mejor fallback externo pero requiere scraping por ID
- **manual_overrides.json** siempre tiene máxima prioridad
