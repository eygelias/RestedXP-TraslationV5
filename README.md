# RXPNameFixer + RXP Translator V5

Corrección automática de nombres de NPCs en RestedXP usando datos reales del cliente WoW.

## Proyectos incluidos

### RXPNameFixer (Addon WoW) — v1.3
Addon companion de RestedXP que corrige nombres de mobs en tiempo real.

**Cómo funciona:**
1. RestedXP parsea guía y crea pasos con IDs de NPCs (`Nombre::7856`)
2. RXPNameFixer lee los IDs del paso activo (`element.unitlist`)
3. Pregunta al cliente WoW el nombre real vía `GameTooltip:SetHyperlink`
4. Reemplaza nombres incorrectos en la lista del step y en el texto visible
5. Corrige macros `/targetexact` antes de que RestedXP las guarde
6. Cache persistente en `RXPNameFixerDB` (SavedVariables)

**Comandos:**
```
/rxpnf stats    — Ver estadísticas y cache
/rxpnf log      — Últimas 30 entradas del log
/rxpnf logall   — Log completo
/rxpnf list     — Primeros 30 NPCs en cache
/rxpnf clear    — Limpiar cache
/rxpnf clearlog — Limpiar log
```

**Archivos:**
- `RXPNameFixer.lua` — Addon principal
- `RXPNameFixer.toc` — Manifest
- `export_npc_names.py` — Exportar cache SavedVariables → JSON

**Instalación:**
```
Copiar carpeta RXPNameFixer a:
C:\Program Files (x86)\World of Warcraft\_anniversary_\Interface\AddOns\
```

### RXP Translator V5
Traductor de guías RestedXP de inglés a 9 idiomas usando CMaNGOS + QuestieDB como fuentes.

**Archivos incluidos:**
- `RXP_Translator_V5_translate_guides.py` — Motor de traducción (1400+ líneas)
- `RXP_Translator_V5_build_database.py` — Constructor de DB combinada
- `RXP_Translator_V5_validate_output.py` — Validador de salida
- `RXP_Translator_V5_app.py` — GUI PyQt5
- `RXP_Translator_V5_locales_config.py` — Configuración de 9 idiomas

**Fixes aplicados:**
- `.zoneskip` / `.subzoneskip` no traducen nombres de zona (RestedXP espera inglés)
- Filtro de pets/demonios en cache de NPCs (`UnitPlayerControlled`)
- Prioridad de fuentes: Cliente WoW > Wowhead TBC ES > QuestieDB > CMaNGOS

### hermes-español-UI.zip
Traducción española de la interfaz de Hermes Agent (Electron desktop app).

**Fix aplicado:**
- Eliminadas claves obsoletas que causaban errores TypeScript
- `dismiss`, `or`, `escToCancel`, `tokensK`, `shortcutSuffix` → eliminadas
- `continueLabel: 'Continuar'` → agregada

## Fuentes de datos NPC (prioridad)

1. **Cliente WoW en vivo** (via RXPNameFixer) — más oficial
2. **Wowhead TBC Classic ES** por NPC ID — mejor fallback externo
3. **QuestieDB** — mejor fuente local estática
4. **RXPGuides NPCnames** — fallback incompleto
5. **CMaNGOS merged** — fallback amplio

## Errores conocidos corregidos

| Error | Causa | Fix |
|-------|-------|-----|
| `.zoneskip Stranglethon Vale` | Traductor no protegía zoneskip | Traductor ahora ignora zona en zoneskip |
| Log infinito RXPNameFixer | Hook AddMessage capturaba sus propios mensajes | Filtro anti-recursión |
| Macro `/targetexact` con nombre mal | Cache contaminada por pets/demonios | Filtro `UnitPlayerControlled` |
| Macro sin ID en step | FixName solo buscaba por texto | Ahora usa ID del paso activo |
| `Object has been destroyed` (Hermes) | Timer tocaba ventana destruida | Guard en `readLinkTitleWindowTitle` |
| `es.ts` TypeScript errors | Claves obsoletas en traducción | Eliminadas claves no válidas |

## Requisitos

- WoW TBC Classic Anniversary (2.5.5+)
- RestedXP Guides instalado
- Python 3.8+ (para translator y export)

## Changelog

### v1.3 (2026-07-07)
- Fix macro usando ID del paso activo
- Corrección de unitlist en tiempo real
- Funciones helper: `ForEachCurrentStepNpc`, `FirstCurrentStepNpcID`

### v1.2 (2026-07-06)
- Hook en `EditMacro` para corregir `/targetexact`
- Sistema de logging con SavedVariables
- Filtro anti-recursión en `AddMessage`

### v1.1
- Cache de nombres reales del cliente
- Nameplate scanning

### v1.0
- Versión inicial
