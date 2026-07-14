-- RXPNameFixer.lua
-- Sincroniza RestedXP con nombres reales del cliente WoW en tiempo real.
-- v2.7 - Empareja .complete QUEST,OBJ con .mob sin ID usando Quest Log.

local ADDON_NAME = ...
local AceAddon = LibStub and LibStub("AceAddon-3.0", true)
local addon = AceAddon and AceAddon:GetAddon("RXPGuides", true)
if not addon then
    print("|cffff0000RXP Name Fixer v2.7|r: no encontró AceAddon RXPGuides")
    return
end

RXPNameFixerDB = RXPNameFixerDB or {}
RXPNameFixerLog = RXPNameFixerLog or {}
RXPNameFixerDB.names = RXPNameFixerDB.names or {}
RXPNameFixerDB.overrides = RXPNameFixerDB.overrides or {}
RXPNameFixerDB.wordOverrides = RXPNameFixerDB.wordOverrides or {}
RXPNameFixerDB.aliases = RXPNameFixerDB.aliases or {}

local namesByID = RXPNameFixerDB.names
local overrides = RXPNameFixerDB.overrides
local wordOverrides = RXPNameFixerDB.wordOverrides
local aliases = RXPNameFixerDB.aliases
local logMax = 300
local stats = {captures = 0, learned = 0, macro = 0, text = 0}
local hooksReady = false
local syncingMacro = false
local pendingMacroSync = false
local updatingText = false
local lastUnitName

-- Migrar cache v1.x (IDs numéricos en raíz).
for key, value in pairs(RXPNameFixerDB) do
    if type(key) == "number" and type(value) == "string" then
        namesByID[key] = value
    end
end

-- Correcciones verificadas conocidas.
overrides["Akoru el Clamafuegos"] = "Akoru el Pirotigma"
wordOverrides["Umbropantano"] = "Umbrapantano"

local function Log(category, message, detail)
    table.insert(RXPNameFixerLog, {
        time = date("%Y-%m-%d %H:%M:%S"),
        cat = category,
        msg = tostring(message or ""),
        detail = tostring(detail or ""),
    })
    while #RXPNameFixerLog > logMax do table.remove(RXPNameFixerLog, 1) end
end

local function EscapePattern(text)
    return tostring(text):gsub("([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1")
end

local function StripEntry(value)
    if type(value) ~= "string" then return value end
    local name = value:match("^[%+%*]*(.+)::%d+$") or value
    return name:gsub("^[%+%*]+", "")
end

local function PreserveLowPriority(value, fixed)
    if fixed and type(value) == "string" and value:match("^%*+") then
        return "*" .. fixed
    end
    return fixed
end

local function ExtractID(value)
    if type(value) == "number" then return value end
    if type(value) ~= "string" then return nil end
    return tonumber(value:match("::(%d+)$") or value:match("^(%d+)$"))
end

local function FirstToken(value)
    local name = StripEntry(value)
    return type(name) == "string" and strlower(name):match("^%S+") or nil
end

local function IsSuffixVariant(left, right)
    left, right = StripEntry(left), StripEntry(right)
    if type(left) ~= "string" or type(right) ~= "string" then return false end
    if right:sub(1, #left + 1) == left .. " " then return true, left, right end
    if left:sub(1, #right + 1) == right .. " " then return true, right, left end
    return false
end

local function StoreAlias(base, variant)
    aliases[base] = aliases[base] or {}
    aliases[base][variant] = true
end

-- Migrar mappings peligrosos v2.4 a aliases y purgar entidades distintas.
local invalidOverrides = {}
for wrong, correct in pairs(overrides) do
    local isVariant, base, variant = IsSuffixVariant(wrong, correct)
    if isVariant then
        StoreAlias(base, variant)
        table.insert(invalidOverrides, {wrong, correct, "migrado a alias"})
    elseif FirstToken(wrong) ~= FirstToken(correct) then
        table.insert(invalidOverrides, {wrong, correct, "entidades distintas sin ID"})
    end
end
for _, entry in ipairs(invalidOverrides) do
    Log("PURGE", entry[1] .. " -/-> " .. entry[2], entry[3])
    overrides[entry[1]] = nil
end

local function ResolveName(name)
    name = StripEntry(name)
    if type(name) ~= "string" then return name end
    local seen = {}
    while overrides[name] and not seen[name] do
        seen[name] = true
        name = overrides[name]
    end
    name = name:gsub("(%S+)", function(word)
        return wordOverrides[word] or word
    end)
    return name
end

local function ReplaceKnownNames(text)
    if type(text) ~= "string" then return text, false end
    local changed = false
    for wrong, correct in pairs(overrides) do
        if wrong ~= correct and not IsSuffixVariant(wrong, correct) then
            local fixed = text:gsub(EscapePattern(wrong), correct)
            if fixed ~= text then
                text = fixed
                changed = true
            end
        end
    end
    for wrong, correct in pairs(wordOverrides) do
        local fixed = text:gsub("%f[%a]" .. EscapePattern(wrong) .. "%f[%A]", correct)
        if fixed ~= text then
            text = fixed
            changed = true
        end
    end
    return text, changed
end

local function GetNpcID(unit)
    local guid = UnitGUID(unit)
    if not guid then return nil end
    local _, _, _, _, _, id = strsplit("-", guid)
    return tonumber(id)
end

-- Crear una sola vez. v1.x recreaba el mismo frame en cada consulta.
local scanTooltip = CreateFrame("GameTooltip", "RXPNameFixerTooltip", UIParent, "GameTooltipTemplate")
scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function GetNameByID(id)
    if not id then return nil end
    if namesByID[id] then return namesByID[id] end

    scanTooltip:ClearLines()
    local ok = pcall(scanTooltip.SetHyperlink, scanTooltip, "unit:Creature-0-0-0-0-" .. id)
    if not ok then return nil end
    local line = _G.RXPNameFixerTooltipTextLeft1
    local name = line and line:GetText()
    scanTooltip:Hide()
    if name and name ~= "" then
        namesByID[id] = name
        return name
    end
    return nil
end

local function CacheUnit(unit)
    if not unit or not UnitExists(unit) or UnitIsPlayer(unit) then return nil, nil end
    if UnitPlayerControlled and UnitPlayerControlled(unit) then return nil, nil end
    local id = GetNpcID(unit)
    local name = UnitName(unit)
    if id and name and name ~= "" then
        if namesByID[id] ~= name then
            namesByID[id] = name
            stats.captures = stats.captures + 1
            Log("CAPTURE", id .. " = " .. name, unit)
        end
        return id, name
    end
    return nil, nil
end

local function GetTargetLists()
    if not addon.targeting or not addon.targeting.GetCurrentTargets then return {} end
    local unitscan, mobs, targets, rares = addon.targeting.GetCurrentTargets()
    return {unitscan, mobs, targets, rares}
end

local function ContainsName(lists, wanted)
    for _, list in ipairs(lists) do
        if type(list) == "table" then
            for _, value in pairs(list) do
                if ResolveName(value) == wanted then return true end
            end
        end
    end
    return false
end

local function CollectNames(lists)
    local result, seen = {}, {}
    for _, list in ipairs(lists) do
        if type(list) == "table" then
            for _, value in pairs(list) do
                local name = StripEntry(value)
                if type(name) == "string" and name ~= "" and not seen[name] then
                    seen[name] = true
                    table.insert(result, name)
                end
            end
        end
    end
    return result
end

local stopWords = {de = true, del = true, la = true, las = true, el = true, los = true, y = true}

local function Tokens(text)
    local result = {}
    text = strlower(tostring(text or "")):gsub("[%p%c]", " ")
    for token in text:gmatch("%S+") do
        if #token > 2 and not stopWords[token] then result[token] = true end
    end
    return result
end

local function Similarity(a, b)
    if a == b then return 1 end
    local ta, tb = Tokens(a), Tokens(b)
    local common, countA, countB = 0, 0, 0
    for token in pairs(ta) do countA = countA + 1; if tb[token] then common = common + 1 end end
    for _ in pairs(tb) do countB = countB + 1 end
    if countA + countB == 0 then return 0 end
    local score = (2 * common) / (countA + countB)
    local firstA = strlower(tostring(a or "")):match("^%S+")
    local firstB = strlower(tostring(b or "")):match("^%S+")
    if firstA and firstA == firstB then score = math.min(1, score + 0.35) end
    return score
end

local function LearnWordOverride(wrong, correct, silent)
    local wrongWords, correctWords = {}, {}
    for word in tostring(wrong or ""):gmatch("%S+") do table.insert(wrongWords, word) end
    for word in tostring(correct or ""):gmatch("%S+") do table.insert(correctWords, word) end
    if #wrongWords ~= #correctWords or #wrongWords == 0 then return false end

    local wrongWord, correctWord, differences
    differences = 0
    for index = 1, #wrongWords do
        if wrongWords[index] ~= correctWords[index] then
            differences = differences + 1
            wrongWord, correctWord = wrongWords[index], correctWords[index]
        end
    end
    if differences ~= 1 or #wrongWord ~= #correctWord then return false end

    local byteDifferences = 0
    for index = 1, #wrongWord do
        if wrongWord:byte(index) ~= correctWord:byte(index) then byteDifferences = byteDifferences + 1 end
    end
    if byteDifferences > 2 or wordOverrides[wrongWord] == correctWord then return false end

    wordOverrides[wrongWord] = correctWord
    if not silent then
        Log("WORD_LEARN", wrongWord .. " -> " .. correctWord, "propagación al grupo activo")
        print("|cff00ff00RXP Name Fixer|r: typo compartido " .. wrongWord .. " -> " .. correctWord)
    end
    return true
end

local function LearnAlias(left, right, reason)
    local isVariant, base, variant = IsSuffixVariant(left, right)
    if not isVariant then return false end
    if aliases[base] and aliases[base][variant] then return false end
    StoreAlias(base, variant)
    stats.learned = stats.learned + 1
    Log("ALIAS", base .. " + " .. variant, reason)
    print("|cff00ff00RXP Name Fixer|r: variante añadida " .. variant)
    return true
end

local function LearnOverride(wrong, correct, reason, trustedID)
    wrong, correct = StripEntry(wrong), StripEntry(correct)
    if type(wrong) ~= "string" or type(correct) ~= "string" then return false end
    if wrong == "" or correct == "" or wrong == correct then return false end
    if not trustedID and FirstToken(wrong) ~= FirstToken(correct) then
        Log("REJECT", wrong .. " -/-> " .. correct, "sin ID exacto")
        return false
    end
    if overrides[wrong] == correct then
        LearnWordOverride(wrong, correct, true)
        return false
    end
    overrides[wrong] = correct
    LearnWordOverride(wrong, correct, false)
    stats.learned = stats.learned + 1
    Log("LEARN", wrong .. " -> " .. correct, reason)
    print("|cff00ff00RXP Name Fixer|r: " .. wrong .. " -> " .. correct)
    return true
end

local function WalkActiveSteps(callback)
    local visited = {}
    local function WalkStep(step)
        if type(step) ~= "table" or visited[step] then return end
        visited[step] = true
        callback(step)
    end

    if addon.RXPFrame and addon.RXPFrame.activeSteps then
        for _, step in pairs(addon.RXPFrame.activeSteps) do WalkStep(step) end
    end
    for _, context in pairs(addon.generatedSteps or {}) do
        for _, step in pairs(context) do if step.active ~= false then WalkStep(step) end end
    end
end

local function WalkActiveElements(callback)
    WalkActiveSteps(function(step)
        for _, element in pairs(step.elements or {}) do callback(element) end
    end)
end

local function QuestObjectiveName(text)
    if type(text) ~= "string" then return nil end
    text = strtrim(text)
    text = text:gsub("%s*:%s*%d+/%d+.*$", "")
    text = text:gsub("%s+%d+/%d+.*$", "")
    return strtrim(text)
end

local function LearnFromQuestObjectives()
    if not addon.GetQuestObjectives then return false end
    local changed = false

    WalkActiveSteps(function(step)
        local pending
        for _, element in ipairs(step.elements or {}) do
            if element.questId and element.obj then
                local objectives = addon.GetQuestObjectives(element.questId, step.index)
                local objective = objectives and objectives[element.obj]
                local name = objective and objective.type == "monster" and QuestObjectiveName(objective.text)
                pending = name and name ~= "" and {
                    name = name,
                    questId = element.questId,
                    obj = element.obj,
                } or nil
            elseif pending then
                local matched
                for _, key in ipairs({"unitscan", "mobs", "targets"}) do
                    local list = element[key]
                    if type(list) == "table" then
                        for _, value in pairs(list) do
                            local oldName = StripEntry(value)
                            if type(oldName) == "string" and not oldName:match("^%d+$") and
                               oldName ~= pending.name then
                                local reason = "QUEST_OBJECTIVE " .. pending.questId .. "," .. pending.obj
                                if LearnOverride(oldName, pending.name, reason, true) then
                                    changed = true
                                    Log("QUEST_OBJECTIVE", oldName .. " -> " .. pending.name, reason)
                                end
                            end
                        end
                        matched = true
                    end
                end
                if matched then pending = nil end
            end
        end
    end)

    return changed
end

local function LearnByElementID(id, realName)
    local learned = false
    WalkActiveElements(function(element)
        for _, key in ipairs({"unitscan", "mobs", "targets"}) do
            local list = element[key]
            if type(list) == "table" then
                for _, value in pairs(list) do
                    if ExtractID(value) == id then
                        local wrong = StripEntry(value)
                        if LearnOverride(wrong, realName, "ID " .. id, true) then learned = true end
                    end
                end
            end
        end
    end)
    return learned
end

local function LearnFromUnit(unit)
    local id, realName = CacheUnit(unit)
    if not id or not realName then return false end
    lastUnitName = realName

    if LearnByElementID(id, realName) then return true end

    local lists = GetTargetLists()
    if ContainsName(lists, realName) then return false end
    local candidates = CollectNames(lists)
    if #candidates == 0 then return false end

    for _, candidate in ipairs(candidates) do
        if IsSuffixVariant(candidate, realName) then
            return LearnAlias(candidate, realName, "variante seleccionada, ID " .. id)
        end
    end

    local best, bestScore, secondScore
    bestScore, secondScore = 0, 0
    for _, candidate in ipairs(candidates) do
        local score = Similarity(candidate, realName)
        if score > bestScore then
            secondScore = bestScore
            bestScore = score
            best = candidate
        elseif score > secondScore then
            secondScore = score
        end
    end
    if best and bestScore >= 0.55 and bestScore - secondScore >= 0.15 and
       FirstToken(best) == FirstToken(realName) then
        local learned = LearnWordOverride(best, realName, false)
        if learned then stats.learned = stats.learned + 1 end
        return learned
    end
    Log("UNRESOLVED", realName, "ID " .. id .. "; candidatos: " .. table.concat(candidates, ", "))
    return false
end

local function ApplyOverridesToLists()
    local changed = false
    for _, list in ipairs(GetTargetLists()) do
        if type(list) == "table" then
            for key, value in pairs(list) do
                local fixed = PreserveLowPriority(value, ResolveName(value))
                if type(fixed) == "string" and fixed ~= value then
                    list[key] = fixed
                    changed = true
                end
            end
        end
    end
    return changed
end

local function ApplyAliasesToLists()
    local changed = false
    for _, list in ipairs(GetTargetLists()) do
        if type(list) == "table" then
            local existing, priority, additions = {}, {}, {}
            for _, value in pairs(list) do
                local name = ResolveName(value)
                if type(name) == "string" then
                    existing[name] = true
                    if type(value) == "string" and value:match("^%*+") then priority[name] = "*" end
                end
            end
            for base, variants in pairs(aliases) do
                if existing[base] then
                    for variant in pairs(variants) do
                        if not existing[variant] then
                            existing[variant] = true
                            table.insert(additions, (priority[base] or "") .. variant)
                        end
                    end
                end
            end
            for _, variant in ipairs(additions) do
                table.insert(list, variant)
                changed = true
            end
        end
    end
    return changed
end

local function ApplyOverridesToSteps()
    if updatingText then return false end
    updatingText = true
    local changed = false
    WalkActiveElements(function(element)
        for _, key in ipairs({"unitscan", "mobs", "targets"}) do
            local list = element[key]
            if type(list) == "table" then
                for index, value in pairs(list) do
                    local id = ExtractID(value)
                    local oldName = StripEntry(value)
                    local fixed = id and GetNameByID(id) or ResolveName(value)
                    local learnedFromID = false
                    if id and fixed and type(oldName) == "string" and
                       not oldName:match("^%d+$") and oldName ~= fixed then
                        learnedFromID = LearnOverride(oldName, fixed, "ID " .. id, true)
                    end
                    fixed = PreserveLowPriority(value, fixed)
                    if learnedFromID then changed = true end
                    if fixed and fixed ~= value then list[index] = fixed; changed = true end
                end
            end
        end
        for _, key in ipairs({"text", "rawtext"}) do
            if type(element[key]) == "string" then
                local fixed, didChange = ReplaceKnownNames(element[key])
                if didChange then
                    element[key] = fixed
                    changed = true
                    stats.text = stats.text + 1
                end
            end
        end
        if changed and addon.UpdateStepText and element.step then addon.UpdateStepText(element) end
    end)
    updatingText = false
    return changed
end

local function RewriteMacro(body)
    if type(body) ~= "string" then return body, false end
    local changed = false
    local fixed = body:gsub("(/targetexact%s+)([^\r\n]+)", function(prefix, name)
        name = strtrim(name or "")
        local resolved = ResolveName(name)
        if resolved ~= name then changed = true; return prefix .. resolved end
        return prefix .. name
    end)
    return fixed, changed
end

local function SyncTargetMacro()
    if syncingMacro or not addon.targeting then return end
    if InCombatLockdown and InCombatLockdown() then pendingMacroSync = true; return end
    local macroName = addon.targeting.macroName or "RXPTargeting"
    local name, icon, body = GetMacroInfo(macroName)
    if not name or not body then return end
    local fixed, changed = RewriteMacro(body)
    if not changed then return end

    syncingMacro = true
    local ok = pcall(EditMacro, macroName, macroName, icon, fixed)
    syncingMacro = false
    if ok then
        pendingMacroSync = false
        stats.macro = stats.macro + 1
        Log("MACRO", "Macro sincronizada", fixed)
        if MacroFrame and MacroFrame:IsShown() and MacroFrameText then MacroFrameText:SetText(fixed) end
    else
        pendingMacroSync = true
    end
end

local function RefreshRuntime(unit)
    local learned = unit and LearnFromUnit(unit)
    local learnedFromQuest = LearnFromQuestObjectives()
    local changedLists = ApplyOverridesToLists()
    local changedAliases = ApplyAliasesToLists()
    local changedSteps = ApplyOverridesToSteps()

    if addon.targeting then
        if (learned or learnedFromQuest or changedLists or changedAliases or changedSteps) and addon.targeting.UpdateMacro and not InCombatLockdown() then
            addon.targeting:UpdateMacro()
        end
        if addon.targeting.UpdateTargetFrame and not InCombatLockdown() then
            addon.targeting:UpdateTargetFrame(unit or "target")
        end
    end
    SyncTargetMacro()
    return learned or learnedFromQuest or changedLists or changedAliases or changedSteps
end

local function ScanNameplates()
    if not C_NamePlate or not C_NamePlate.GetNamePlates then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates() or {}) do
        if plate.namePlateUnitToken then CacheUnit(plate.namePlateUnitToken) end
    end
end

local function InstallHooks()
    if hooksReady or not addon.targeting then return end
    hooksReady = true

    -- Targeting.lua capturó EditMacro en un local. Hookear UpdateMacro directamente.
    if addon.targeting.UpdateMacro then
        hooksecurefunc(addon.targeting, "UpdateMacro", function()
            C_Timer.After(0, SyncTargetMacro)
        end)
    end
    if addon.targeting.UpdateUnitList then
        hooksecurefunc(addon.targeting, "UpdateUnitList", function()
            C_Timer.After(0, function()
                local changed = LearnFromQuestObjectives()
                if ApplyOverridesToLists() then changed = true end
                if ApplyAliasesToLists() then changed = true end
                local changedSteps = ApplyOverridesToSteps()
                if changedSteps then changed = true end
                if changed and not InCombatLockdown() then addon.targeting:UpdateMacro() end
                SyncTargetMacro()
            end)
        end)
    end
    Log("SYSTEM", "Hooks directos instalados")
end

local frame = CreateFrame("Frame")
for _, event in ipairs({
    "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
    "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED"
}) do frame:RegisterEvent(event) end

frame:SetScript("OnEvent", function(_, event, arg1)
    InstallHooks()
    if event == "PLAYER_TARGET_CHANGED" then
        C_Timer.After(0, function() RefreshRuntime("target") end)
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        C_Timer.After(0, function() CacheUnit("mouseover"); SyncTargetMacro() end)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        CacheUnit(arg1)
    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1, function() RefreshRuntime("target") end)
    elseif event == "PLAYER_REGEN_ENABLED" and pendingMacroSync then
        C_Timer.After(0, SyncTargetMacro)
    end
end)

C_Timer.NewTicker(0.75, function()
    InstallHooks()
    ScanNameplates()
    local changed = LearnFromQuestObjectives()
    if ApplyOverridesToLists() then changed = true end
    if ApplyAliasesToLists() then changed = true end
    local changedSteps = ApplyOverridesToSteps()
    if changedSteps then changed = true end
    if changed and addon.targeting and addon.targeting.UpdateMacro and not InCombatLockdown() then
        addon.targeting:UpdateMacro()
    end
    SyncTargetMacro()
end)

SLASH_RXPNAMEFIXER1 = "/rxpnf"
SlashCmdList.RXPNAMEFIXER = function(message)
    message = strlower(strtrim(message or ""))
    if message == "" or message == "stats" then
        local cached, learned, wordCount, aliasCount = 0, 0, 0, 0
        for _ in pairs(namesByID) do cached = cached + 1 end
        for _ in pairs(overrides) do learned = learned + 1 end
        for _ in pairs(wordOverrides) do wordCount = wordCount + 1 end
        for _, variants in pairs(aliases) do for _ in pairs(variants) do aliasCount = aliasCount + 1 end end
        print("|cff00ff00RXP Name Fixer v2.7|r ACTIVO")
        print("  Cache NPC: " .. cached .. " | Overrides: " .. learned .. " | Palabras: " .. wordCount .. " | Alias: " .. aliasCount)
        print("  Capturas: " .. stats.captures .. " | Aprendidos: " .. stats.learned)
        print("  Macros: " .. stats.macro .. " | Textos: " .. stats.text)
        print("  Hooks: " .. (hooksReady and "OK" or "esperando RXPGuides"))
    elseif message == "sync" then
        RefreshRuntime("target")
        print("|cff00ff00RXP Name Fixer|r sincronización ejecutada")
    elseif message == "test" then
        local macroName = addon.targeting and addon.targeting.macroName or "RXPTargeting"
        local _, _, body = GetMacroInfo(macroName)
        print("|cff00ff00RXP Name Fixer|r macro " .. macroName .. ":")
        print(body or "NO EXISTE")
        local lists = GetTargetLists()
        print("Objetivos RXP: " .. table.concat(CollectNames(lists), " | "))
        print("Objetivo real: " .. tostring(UnitName("target")))
    elseif message == "log" then
        local first = math.max(1, #RXPNameFixerLog - 20)
        for i = first, #RXPNameFixerLog do
            local entry = RXPNameFixerLog[i]
            print("[" .. entry.cat .. "] " .. entry.msg .. (entry.detail ~= "" and (" — " .. entry.detail) or ""))
        end
    elseif message == "clear" then
        wipe(namesByID)
        wipe(overrides)
        wipe(wordOverrides)
        wipe(aliases)
        overrides["Akoru el Clamafuegos"] = "Akoru el Pirotigma"
        wordOverrides["Umbropantano"] = "Umbrapantano"
        print("|cff00ff00RXP Name Fixer|r cache y aprendizaje limpiados")
    else
        print("/rxpnf [stats|sync|test|log|clear]")
    end
end

-- Derivar typos compartidos de correcciones aprendidas en sesiones anteriores.
for wrong, correct in pairs(overrides) do LearnWordOverride(wrong, correct, true) end

InstallHooks()
Log("SYSTEM", "RXP Name Fixer v2.7 cargado")
print("|cff00ff00RXP Name Fixer v2.7|r ACTIVO — objetivos de misión sincronizan texto y macro")
