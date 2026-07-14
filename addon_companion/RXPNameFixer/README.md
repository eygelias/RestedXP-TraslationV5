# RXPNameFixer v2.7

Addon complementario de RestedXP/RXPGuides para sincronizar nombres de mobs/NPC y la macro `RXPTargeting` con los nombres reales del cliente WoW.

## Instalación

Extrae la carpeta `RXPNameFixer` dentro de:

```text
World of Warcraft\_anniversary_\Interface\AddOns\
```

Resultado:

```text
Interface\AddOns\RXPNameFixer\RXPNameFixer.toc
Interface\AddOns\RXPNameFixer\RXPNameFixer.lua
```

Reinicia WoW o ejecuta una sola vez:

```text
/reload
```

Después funciona automáticamente al entrar, cambiar paso, seleccionar NPC o actualizar la macro. `/rxpnf stats` es solo diagnóstico; no activa el addon.

## Comandos opcionales

```text
/rxpnf stats
/rxpnf test
/rxpnf sync
/rxpnf log
/rxpnf clear
```

## Requisito

```text
RestedXP Guides / RXPGuides
```

## v2.7

- Cuando guía usa `.complete QUEST,OBJ` seguido por `.mob` sin ID, toma nombre localizado directamente del objetivo de misión.
- Ejemplo real: misión `10042` corrige `Verdugo/Invocador enigmático` usando requisitos `Verdugo/Invocador oscuro`.
- Sincroniza descripción y macro aunque comandos `.mob` no contengan `::NPCID`.
- Cuando `Nombre::ID` resuelve nombre real, aprende también `nombre viejo → nombre real`.
- La misma corrección se aplica en una pasada a requisitos, descripción y macro.
- Cambios dentro de step ahora fuerzan `Targeting.UpdateMacro`.
- Variantes con sufijo se añaden como aliases de targeting, no reemplazan objetivo base.
- Ejemplo: `Huargo gris` y `Huargo gris alfa` permanecen ambos en macro.
- Migra automáticamente mappings peligrosos de v2.4 a aliases.
- El texto del paso nunca recibe `alfa alfa alfa` por reemplazo repetido.
- Conexión al objeto AceAddon real de RXPGuides.
- Hook directo a `Targeting.UpdateMacro`.
- Corrección por ID exacto y typos seguros.
- No sustituye un mob pendiente por otro NPC targeteado.
- Mouseover/nameplates solo alimentan cache.
- Prefijo interno `*` normalizado sin acumulación.
