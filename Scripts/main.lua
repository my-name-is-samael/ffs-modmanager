-- Created by TontonSamael --

Utils = require("utils")

require("types")

local AbsPath = debug.getinfo(1, "S").source
    :match("@(.*[/\\])")
    :gsub("scripts\\$", "")
local RelPath = AbsPath:gsub("^.*(\\Win64\\Mods\\)", "Mods\\")

local VERSION = 1

---@type ModManager
local ModManager = {
    DEBUG = false,
    ID = "ModManager",
    AppState = APP_STATES.MAIN_MENU,
    GameState = nil,

    UE4SSBeta = false,

    -- TMP functions
    Loop = function() end,
    AddHook = function() end,
    AddCommand = function() end,
    AddKey = function() end,
    Trigger = function() end,
    AddSound = function() return -1 end,
    PlaySound = function() end,
}

-- Will log your message with the format : [<Type>] [<Tag>] <message>
---@param Mod ModModule
---@param Type LogType
---@param Msg any
---@param Ar? any
function Log(Mod, Type, Msg, Ar)
    if Type ~= LOG.DEBUG or ModManager.DEBUG then
        Msg = string.format("[%s] [%s] %s\n", Type, Mod.ID, tostring(Msg))
        print(Msg)
        if Ar then -- log in game console (F10)
            pcall(Ar.Log, Ar, Msg)
        end
    end
end

---@type table<string, ModCache>
local Mods = {}

local function TryLoadMod(Name)
    Mods[Name] = {
        ID = Name,
        Loaded = false,
        LastLoadedTime = -1,
    }
    local status, submod = pcall(require, string.format("%sMods\\%s\\main", RelPath, Name))
    if status and type(submod) == "table" then
        submod.ID = Name
        if not submod.Version then
            Log(ModManager, LOG.WARN, string.format("Submod '%s' has no version", Name))
        elseif submod.Version < VERSION then
            Log(ModManager,
                LOG.WARN,
                string.format("Submod '%s' is outdated (ModManager Version: %s, Submod Version: %s)", Name, VERSION,
                    submod.Version))
        end
        table.assign(Mods[Name], submod)
        Mods[Name].Loaded = true
        Log(ModManager, LOG.INFO, string.format("Submod '%s' loaded (%s)", Name, submod.ID))
    else
        if not status then
            Mods[Name].LoadError = submod
            Log(ModManager, LOG.ERR, string.format("Failed to load submod '%s' : %s", Name, submod))
        else
            Mods[Name].LoadError = "Not a module"
            Log(ModManager, LOG.ERR, string.format("Failed to load submod '%s' : Not a module", Name))
        end
    end
    Mods[Name].LastLoadedTime = os.time()
end

local function LoadMods()
    local ModsDir = AbsPath .. "Mods\\"
    for dir in io.popen("dir \"" .. ModsDir .. "\" /b"):lines() do
        local path = ModsDir .. dir
        if Utils.isDir(path) and Utils.fileExists(path .. "\\main.lua") then
            TryLoadMod(dir)
        end
    end
end

function ModManager.Loop(Mod, Timeout, Callback)
    local CachedMod = table.find(Mods, function(Cached) return Cached.ID == Mod.ID end)
    if CachedMod then
        LoopAsync(Timeout, function()
            -- maybe bench loop process to warn for heavy duty tasks
            return Callback(ModManager)
        end)
    end
end

local function ToggleHooks()
    table.forEach(Mods, function(Mod)
        if Mod.Hooks then
            table.forEach(Mod.Hooks, function(Hook, HookName)
                if not Hook.Enabled and (not Hook.CondFn or Hook.CondFn(ModManager)) then
                    Log(ModManager, LOG.DEBUG, string.format("Loadind hook %s ...", HookName))
                    Hook.Enabled, Hook.PreID, Hook.PostID = pcall(RegisterHook, Hook.Key,
                        function(...) Hook.CallbackFn(ModManager, ...) end)
                    if not Hook.Enabled then
                        Log(ModManager, LOG.ERR, string.format("Failed to register hook %s", HookName))
                        Hook.PreID()
                        Hook.PreID = nil
                    end
                elseif Hook.Enabled and Hook.CondFn and not Hook.CondFn(ModManager) then
                    Log(ModManager, LOG.DEBUG, string.format("Unloading hook %s ...", HookName))
                    pcall(UnregisterHook, Hook.Key, Hook.PreID, Hook.PostID)
                    -- both cases error or not, the hook is invalidated
                    Hook.Enabled, Hook.PreID, Hook.PostID = nil, nil, nil
                end
            end)
        end
    end)
end

function ModManager.AddHook(Mod, Name, Key, Callback, Condition)
    local CachedMod = table.find(Mods, function(Cached) return Cached.ID == Mod.ID end)
    if CachedMod then
        if not CachedMod.Hooks then
            CachedMod.Hooks = {}
        end
        if CachedMod.Hooks[Name] then
            Log(Mod, LOG.WARN, string.format("Hook %s already exists", Name))
        else
            CachedMod.Hooks[Name] = {
                Enabled = false,
                Key = Key,
                CallbackFn = Callback,
                CondFn = Condition,
            }
            Log(Mod, LOG.INFO, string.format("Hook %s registered", Name))
        end
    end
end

function ModManager.AddCommand(Mod, CommandName, Callback)
    local CachedMod = table.find(Mods, function(Cached) return Cached.ID == Mod.ID end)
    if CachedMod then
        if not CachedMod.Commands then
            CachedMod.Commands = {}
        end
        if CachedMod.Commands[CommandName] then
            Log(Mod, LOG.ERR, string.format("Command %s already exists", CommandName))
        else
            local status, err = pcall(RegisterConsoleCommandHandler, CommandName, function(FullCommand, Parameters, Ar)
                local result = Callback(ModManager, Parameters, Ar)
                if result == nil then
                    return true
                end
                return result
            end)
            if status then
                CachedMod.Commands[CommandName] = {
                    Command = CommandName,
                    Enabled = true,
                    CallBackFn = Callback
                }
                Log(Mod, LOG.INFO, string.format("Command %s registered", CommandName))
            else
                CachedMod.Commands[CommandName] = {
                    Command = CommandName,
                    Enabled = false,
                    Error = err
                }
                Log(Mod, LOG.ERR, string.format("Failed to register command %s : %s", CommandName, err))
            end
        end
    end
end

local function GenerateKeyID(Key, Modifiers)
    local KeyID = tostring(Key)
    if Modifiers then
        local Modifiers2 = table.clone(Modifiers)
        table.sort(Modifiers2)
        for _, Modifier in pairs(Modifiers2) do
            KeyID = KeyID .. "-" .. tostring(Modifier)
        end
    end
    return KeyID
end

local function GenerateKeylabel(KeyValue, Modifiers)
    local KeyLabel = string.capitalize(table.reduce(Key, function(Value, V, K)
        return V == KeyValue and K or Value
    end, ""))
    local ModifiersLabel = ""
    if Modifiers then
        local Modifiers2 = table.clone(Modifiers)
        table.sort(Modifiers2, function(a, b)
            -- SHIFT is wrongly sorted by default, it should be last
            if a == ModifierKey.SHIFT then
                return false
            elseif b == ModifierKey.SHIFT then
                return true
            else
                return a < b
            end
        end)
        ModifiersLabel = table.join(
            table.map(Modifiers2, function(M1)
                return string.capitalize(table.reduce(ModifierKey, function(Value, V, K)
                    return V == M1 and K or Value
                end, "")) .. " + "
            end))
    end
    return ModifiersLabel .. KeyLabel
end

function ModManager.AddKey(Mod, Key, Description, Callback, Modifiers)
    local CachedMod = table.find(Mods, function(Cached) return Cached.ID == Mod.ID end)
    if CachedMod then
        if not CachedMod.Keys then
            CachedMod.Keys = {}
        end
        local KeyID = GenerateKeyID(Key, Modifiers)
        local KeyLabel = GenerateKeylabel(Key, Modifiers)
        if CachedMod.Keys[KeyID] then
            Log(Mod, LOG.WARN, string.format("Key \"%s\" (%s) already exists", Description, KeyLabel))
        else
            local status, err
            local FinalCallBackFn = function()
                Callback(ModManager)
            end
            if type(Modifiers) == "table" then
                status, err = pcall(RegisterKeyBind, Key, Modifiers, FinalCallBackFn)
            else
                status, err = pcall(RegisterKeyBind, Key, FinalCallBackFn)
            end
            if not status then
                CachedMod.Keys[KeyID] = {
                    Key = Key,
                    KeyLabel = KeyLabel,
                    Description = Description,
                    Enabled = false,
                    LoadError = err,
                    Modifiers = Modifiers,
                }
                Log(Mod, LOG.ERR, string.format("Failed to register key \"%s\" (%s) : %s", Description, KeyLabel, err))
            else
                CachedMod.Keys[KeyID] = {
                    Key = Key,
                    KeyLabel = KeyLabel,
                    Description = Description,
                    Enabled = true,
                    CallbackFn = FinalCallBackFn,
                    Modifiers = Modifiers,
                }
                Log(Mod, LOG.INFO, string.format("Key \"%s\" (%s) registered", Description, KeyLabel))
            end
        end
    end
end

function ModManager.Trigger(Mod, EventName, ...)
    Log(Mod, LOG.DEBUG, string.format("Triggering event %s", EventName))
    for _, CachedMod in pairs(Mods) do
        if type(CachedMod[EventName]) == "function" then
            Log(CachedMod, LOG.DEBUG, string.format("Catching event %s", EventName))
            CachedMod[EventName](ModManager, ...)
        end
    end
end

function ModManager.AddSound(Mod, SoundPath)
    if not SoundPath:find(".wav$") then
        Log(Mod, LOG.ERR, string.format("%s must be a WAV file", SoundPath))
        return -1
    end

    local CachedMod = table.find(Mods, function(Cached) return Cached.ID == Mod.ID end)
    if not CachedMod then
        return -1
    end
    local AbsSoundPath = string.format("%sMods\\%s\\%s", AbsPath, Mod.ID, SoundPath)
    if not Utils.fileExists(AbsSoundPath) or Utils.isDir(AbsSoundPath) then
        Log(Mod, LOG.ERR, string.format("Invalid sound path %s", SoundPath))
        return -1
    end

    if not CachedMod.Sounds then
        CachedMod.Sounds = {}
    end

    if table.find(CachedMod.Sounds, function(V)
            return V == AbsSoundPath
        end) then
        Log(Mod, LOG.WARN, string.format("Sound %s already exists", SoundPath))
    else
        table.insert(CachedMod.Sounds, AbsSoundPath)
        Log(Mod, LOG.INFO, string.format("Sound %s registered", SoundPath))
    end

    return table.reduce(CachedMod.Sounds, function(Value, V, K) return V == AbsSoundPath and K or Value end, -1)
end

function ModManager.PlaySound(Mod, SoundID)
    local CachedMod = table.find(Mods, function(Cached) return Cached.ID == Mod.ID end)
    if CachedMod and SoundID > -1 then
        if CachedMod.Sounds and CachedMod.Sounds[SoundID] then
            -- play sound async
            io.popen(string.format("powershell -c (New-Object Media.SoundPlayer '%s').PlaySync();", CachedMod.Sounds[SoundID]))
        end
    end
end

-- detect with version
local function detectUE4SSBeta()
    if Utils.isDir("ue4ss\\") then
        ModManager.UE4SSBeta = true
    end
end

-- TODO improve by constructor and onDestruct hooks
local function initAppStateHooks()
    local function LoopDetectLobby()
        ModManager.Loop(ModManager, 500, function(M)
            if not M.GameState or not M.GameState:IsValid() then
                ---@return ABP_BakeryGameState_Ingame_C
                M.GameState = FindFirstOf("BP_BakeryGameState_Ingame_C")
                if M.GameState:IsValid() then
                    M.AppState = APP_STATES.IN_GAME
                end
            end
            return M.GameState and M.GameState:IsValid() or false
        end)
    end
    LoopDetectLobby()

    -- Hook to detect when get back to main menu
    ModManager.AddHook(ModManager, "UpdateStateMenu",
        "/Game/UI/Ingame/EscapeMenu/W_EscapeMenu.W_EscapeMenu_C:OnMainMenuConfirmation",
        function(M, GameState, bConfirmed)
            if bConfirmed:get() then
                ModManager.AppState = APP_STATES.MAIN_MENU
                LoopDetectLobby()
            end
        end, function(Hook) return ModManager.AppState ~= APP_STATES.MAIN_MENU end)
end

local function Init()
    detectUE4SSBeta()

    LoadMods()

    initAppStateHooks()
    ModManager.Trigger(ModManager, "Init")

    -- hooks enabling loop
    ModManager.Loop(ModManager, 1000, function()
        ToggleHooks()
        return false
    end)

    Log(ModManager, LOG.INFO, "ModManager Loaded!")
end

Init()
