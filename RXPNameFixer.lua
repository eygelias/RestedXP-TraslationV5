-- RXPNameFixer.lua
-- Corrige automáticamente los nombres de mobs en RestedXP
-- usando los nombres reales que el cliente del juego proporciona.
-- v1.3 - Corrige macro/step usando IDs del paso activo

local addonName, ns = ...

-- ── SavedVariables ──
RXPNameFixerDB = RXPNameFixerDB or {}
RXPNameFixerLog = RXPNameFixerLog or {}

-- ── Referencia al addon RestedXP ──
local RXP = _G.RXPGuides
if not RXP then return end

local addon = RXP

-- ── Cache local ──
local NameCache = {}    -- npcID -> nombre real del cliente
local NameCacheReverse = {} -- nombre_lower -> npcID (para búsquedas inversas)
local FixCount = 0
local MacroFixCount = 0
local ScanCount = 0
local LogMaxEntries = 500

local function EscapePattern(text)
    return tostring(text):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function ExtractNpcID(value)
    if type(value) == "number" then return value end
    if type(value) ~= "string" then return nil end
    return tonumber(value:match("::(%d+)$") or value:match("^(%d+)$"))
end

local function ExtractNpcName(value)
    if type(value) ~= "string" then return nil end
    return value:match("^%+?(.+)::%d+$")
end

local function GetCurrentStep()
    if not addon.currentGuide or not addon.currentGuide.steps or not RXPCData then return nil end
    return addon.currentGuide.steps[RXPCData.currentStep]
end

local function ForEachCurrentStepNpc(callback)
    local step = GetCurrentStep()
    if not step then return end
    for _, element in ipairs(step.elements or {}) do
        for _, key in ipairs({"unitlist", "mobs", "targets", "unitscan"}) do
            local list = element[key]
            if type(list) == "table" then
                for i, value in ipairs(list) do
                    local id = ExtractNpcID(value)
                    if id then callback(id, ExtractNpcName(value), element, list, i) end
                end
            end
        end
    end
end

local function FirstCurrentStepNpcID()
    local found
    ForEachCurrentStepNpc(function(id)
        if not found then found = id end
    end)
    return found
end

-- ══════════════════════════════════════════
--  LOGGING
-- ══════════════════════════════════════════

local function LogEntry(category, message, detail)
    tinsert(RXPNameFixerLog, {
        time = date("%Y-%m-%d %H:%M:%S"),
        cat = category,
        msg = message,
        detail = detail or "",
    })
    while #RXPNameFixerLog > LogMaxEntries do
        tremove(RXPNameFixerLog, 1)
    end
end

-- ══════════════════════════════════════════
--  OBTENER NOMBRE REAL DEL CLIENTE
-- ══════════════════════════════════════════

local function GetNpcIDFromGUID(guid)
    if not guid then return nil end
    local _, _, _, _, _, npcID = strsplit("-", guid)
    return tonumber(npcID)
end

local function GetRealName(npcID)
    if type(npcID) ~= "number" then return nil end
    if NameCache[npcID] then return NameCache[npcID] end
    if RXPNameFixerDB[npcID] then
        NameCache[npcID] = RXPNameFixerDB[npcID]
        return NameCache[npcID]
    end
    
    -- Intentar con GameTooltip (método de RestedXP)
    local tooltip = CreateFrame("GameTooltip", "RXPNameFixerTooltip", nil, "GameTooltipTemplate")
    tooltip:SetOwner(WorldFrame, "ANCHOR_BOTTOMRIGHT")
    tooltip:ClearLines()
    tooltip:SetHyperlink(string.format("unit:Creature-0-0-0-0-%d", npcID))
    if tooltip:IsShown() then
        local name = _G["RXPNameFixerTooltipTextLeft1"]:GetText()
        if name then
            name = name:match("^|c%x%x%x%x%x%x%x%x(.*)|r$") or name
            NameCache[npcID] = name
            RXPNameFixerDB[npcID] = name
            NameCacheReverse[name:lower()] = npcID
            LogEntry("NAME_RESOLVED", npcID .. " = " .. name)
            tooltip:Hide()
            return name
        end
    end
    tooltip:Hide()
    return nil
end

-- Buscar NPC ID por nombre (búsqueda inversa)
local function GetNpcIDByName(name)
    if not name then return nil end
    local lower = name:lower()
    if NameCacheReverse[lower] then return NameCacheReverse[lower] end
    
    -- Buscar en todo el cache
    for id, cachedName in pairs(NameCache) do
        if cachedName:lower() == lower then
            NameCacheReverse[lower] = id
            return id
        end
    end
    return nil
end

-- Corregir un nombre: si está en cache y es diferente, devolver el correcto
local function FixName(name)
    if not name or name == "" then return name end
    
    -- Buscar por nombre en cache inverso
    local npcID = GetNpcIDByName(name)
    if npcID and NameCache[npcID] then
        local correct = NameCache[npcID]
        if correct ~= name then
            return correct, npcID
        end
    end
    return name, nil
end

-- ══════════════════════════════════════════
--  CAPTURA DE MOBS
-- ══════════════════════════════════════════

local function CacheNpcName(npcID, name)
    if npcID and name and name ~= "" then
        if not NameCache[npcID] or NameCache[npcID] ~= name then
            NameCache[npcID] = name
            RXPNameFixerDB[npcID] = name
            NameCacheReverse[name:lower()] = npcID
        end
    end
end

local function CaptureUnit(unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return end
    -- ponytail: cache solo NPCs reales; pets/demonios con nombre personalizado contaminan IDs globales.
    if UnitPlayerControlled and UnitPlayerControlled(unit) then return end
    local guid = UnitGUID(unit)
    local npcID = GetNpcIDFromGUID(guid)
    local name = UnitName(unit)
    if npcID and name then
        if not NameCache[npcID] then
            ScanCount = ScanCount + 1
            LogEntry("CAPTURE", npcID .. " = " .. name)
        end
        CacheNpcName(npcID, name)
    end
end

local function ScanNearbyMobs()
    local nameplates = C_NamePlate and C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates()
    if not nameplates then return end
    for _, plate in ipairs(nameplates) do
        local unit = plate.namePlateUnitToken
        if unit then CaptureUnit(unit) end
    end
end

-- ══════════════════════════════════════════
--  HOOK: CORREGIR MACRO DE TARGETING
-- ══════════════════════════════════════════

local function FixMacroContent(content)
    if not content then return content end
    
    local changed = false
    local newContent = content:gsub("/targetexact ([^\n]+)", function(targetName)
        targetName = targetName:trim()
        local fixed, npcID = FixName(targetName)
        if fixed == targetName then
            npcID = FirstCurrentStepNpcID()
            fixed = npcID and GetRealName(npcID) or targetName
        end
        if fixed ~= targetName then
            changed = true
            MacroFixCount = MacroFixCount + 1
            LogEntry("MACRO_FIX", targetName .. " -> " .. fixed, 
                     npcID and ("ID: " .. npcID) or "")
            return "/targetexact " .. fixed
        end
        return "/targetexact " .. targetName
    end)
    
    return changed and newContent or content
end

-- Hook EditMacro para interceptar la macro de RestedXP
if EditMacro then
    local origEditMacro = EditMacro
    EditMacro = function(macroID, name, icon, body, ...)
        -- Solo interceptar la macro de targeting de RestedXP
        if name and body and (name == "RXPtargeting" or name:find("RXP")) then
            local fixedBody = FixMacroContent(body)
            if fixedBody ~= body then
                LogEntry("MACRO_INTERCEPT", "Macro '" .. name .. "' corregida")
                return origEditMacro(macroID, name, icon, fixedBody, ...)
            end
        end
        return origEditMacro(macroID, name, icon, body, ...)
    end
end

-- ══════════════════════════════════════════
--  HOOK: CORREGIR TEXTO DEL STEP
-- ══════════════════════════════════════════

local function FixStepText(element)
    if not element or not element.text or not element.step then return end
    if not element.step.active then return end
    
    local text = element.text
    local changed = false
    
    -- Patrón npc:NOMBRE:ID
    local newText = text:gsub("npc:(.-):(%d+)", function(oldName, idStr)
        local id = tonumber(idStr)
        if not id then return "npc:" .. oldName .. ":" .. idStr end
        local realName = GetRealName(id)
        if realName and realName ~= oldName then
            FixCount = FixCount + 1
            changed = true
            return realName
        end
        return "npc:" .. oldName .. ":" .. idStr
    end)
    
    -- Patrón NOMBRE::ID
    newText = newText:gsub("([^:]+)::(%d+)", function(oldName, idStr)
        local id = tonumber(idStr)
        if not id then return oldName .. "::" .. idStr end
        local realName = GetRealName(id)
        if realName and realName ~= oldName then
            FixCount = FixCount + 1
            changed = true
            return realName
        end
        return oldName .. "::" .. idStr
    end)
    
    if changed then element.text = newText end
end

local function FixCurrentStep()
    local step = GetCurrentStep()
    if not step or not step.active then return end
    local unitListChanged = false

    ForEachCurrentStepNpc(function(id, oldName, element, list, index)
        local realName = GetRealName(id)
        if not realName then return end
        if type(list) == "table" and list[index] ~= realName then
            list[index] = realName
            unitListChanged = true
        end
        if oldName and oldName ~= realName and element.text then
            local newText = element.text:gsub(EscapePattern(oldName), realName)
            if newText ~= element.text then
                element.text = newText
                FixCount = FixCount + 1
                LogEntry("STEP_FIX", oldName .. " -> " .. realName, "ID: " .. id)
            end
        end
    end)

    for _, element in ipairs(step.elements or {}) do
        FixStepText(element)
    end
    if unitListChanged and addon.targeting and addon.targeting.UpdateUnitList then
        addon:ScheduleTask(addon.targeting.UpdateUnitList)
    end
end

-- ══════════════════════════════════════════
--  HOOK: INTERCEPTAR ERRORES DE RESTEDXP
-- ══════════════════════════════════════════

local function HookRestedXP()
    -- Capturar errores de parsing
    if addon.error then
        local origError = addon.error
        addon.error = function(self, msg, ...)
            LogEntry("RXP_ERROR", tostring(msg), debugstack(2, 3, 0))
            return origError(self, msg, ...)
        end
    end
    
    -- Hook UpdateStepText
    if addon.UpdateStepText then
        hooksecurefunc(addon, "UpdateStepText", function(self)
            C_Timer.After(0.15, FixCurrentStep)
        end)
    end
    
    -- Capturar mensajes de chat de RestedXP (SIN recursión)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        hooksecurefunc(DEFAULT_CHAT_FRAME, "AddMessage", function(self, msg, ...)
            if msg and type(msg) == "string" then
                -- Evitar recursión: no capturar nuestros propios logs
                if msg:find("RXP Name Fixer") then return end
                if msg:find("RXP_CHAT_ERROR") then return end
                
                if msg:find("RestedXP") or msg:find("RXP Guides") then
                    if msg:find("Error") or msg:find("error") or msg:find("zoneskip") or msg:find("map name") then
                        LogEntry("RXP_ERROR", msg:sub(1, 200))
                    end
                end
            end
        end)
    end
    
    LogEntry("SYSTEM", "Hooks de RestedXP activados")
end

-- ══════════════════════════════════════════
--  EVENTOS
-- ══════════════════════════════════════════

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGOUT")
eventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_TARGET_CHANGED" then
        CaptureUnit("target")
        C_Timer.After(0.2, FixCurrentStep)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        CaptureUnit("mouseover")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if arg1 then CaptureUnit(arg1) end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
        if event == "ADDON_LOADED" and arg1 ~= "RXPNameFixer" then return end
        for id, name in pairs(RXPNameFixerDB) do
            if type(id) == "number" and type(name) == "string" then
                NameCache[id] = name
                NameCacheReverse[name:lower()] = id
            end
        end
        local count = 0
        for _ in pairs(NameCache) do count = count + 1 end
        LogEntry("SYSTEM", "Cache cargada: " .. count .. " nombres")
        
        C_Timer.After(3, HookRestedXP)
        LogEntry("SYSTEM", "RXP Name Fixer v1.3 cargado")
        
    elseif event == "ZONE_CHANGED_NEW_AREA" then
        LogEntry("ZONE", "Zona: " .. (GetRealZoneText() or "?"))
    end
end)

-- Timer periódico
C_Timer.NewTicker(1.5, function()
    ScanNearbyMobs()
    FixCurrentStep()
end)

-- ══════════════════════════════════════════
--  SLASH COMMANDS
-- ══════════════════════════════════════════

SLASH_RXPNAMEFIXER1 = "/rxpnf"

SlashCmdList["RXPNAMEFIXER"] = function(msg)
    if msg == "stats" or msg == "" then
        local count = 0
        for _ in pairs(NameCache) do count = count + 1 end
        print("|cff00ff00RXP Name Fixer v1.3|r")
        print("  Cache: " .. count .. " nombres")
        print("  Texto corregido: " .. FixCount .. " veces")
        print("  Macro corregida: " .. MacroFixCount .. " veces")
        print("  Mobs escaneados: " .. ScanCount)
        print("  Log: " .. #RXPNameFixerLog .. " entradas")
    elseif msg == "log" then
        print("|cff00ff00RXP Name Fixer|r - Log:")
        local start = math.max(1, #RXPNameFixerLog - 30)
        for i = start, #RXPNameFixerLog do
            local e = RXPNameFixerLog[i]
            if e then
                print("  [" .. e.time .. "] " .. e.cat .. ": " .. e.msg)
                if e.detail ~= "" then print("    " .. e.detail:sub(1, 150)) end
            end
        end
    elseif msg == "logall" then
        print("|cff00ff00RXP Name Fixer|r - Log completo:")
        for _, e in ipairs(RXPNameFixerLog) do
            print("  [" .. e.time .. "] " .. e.cat .. ": " .. e.msg)
            if e.detail ~= "" then print("    " .. e.detail:sub(1, 150)) end
        end
    elseif msg == "clearlog" then
        wipe(RXPNameFixerLog)
        print("Log limpiado")
    elseif msg == "clear" then
        wipe(RXPNameFixerDB); wipe(NameCache); wipe(NameCacheReverse)
        FixCount = 0; MacroFixCount = 0; ScanCount = 0
        print("Cache limpiada")
    elseif msg == "list" then
        print("|cff00ff00RXP Name Fixer|r - Cache:")
        local i = 0
        for id, name in pairs(NameCache) do
            i = i + 1
            if i <= 30 then print("  [" .. id .. "] " .. name) end
        end
        if i > 30 then print("  ... y " .. (i-30) .. " mas") end
    else
        print("|cff00ff00RXP Name Fixer|r - /rxpnf [stats|log|logall|list|clear|clearlog]")
    end
end

LogEntry("SYSTEM", "Addon cargado")
print("|cff00ff00RXP Name Fixer v1.3|r - /rxpnf")
