-- Created by TontonSamael --

JSON = require("json")
require("utils")

require("types")

local AbsPath = debug.getinfo(1, "S").source
    :match("@(.*[/\\])")
    :gsub("scripts\\$", "")
local RelPath = AbsPath:gsub("^.*(\\Win64\\Mods\\)", "Mods\\")
    :gsub("^.*(\\Win64\\ue4ss\\Mods\\)", "ue4ss\\Mods\\")

-- ENetRole.ROLE_Authority
local ROLE_AUTHORITY = 3

---@type ModManager
local ModManager = {
    ID = "ModManager",
    Version = 1,

    DEBUG = true,
    AppState = APP_STATES.MAIN_MENU,
    GameState = nil,
    IsHost = false,

    -- TMP functions
    Loop = function() end,
    AddHook = function() end,
    AddCommand = function() end,
    AddKey = function() end,
    Trigger = function() end,
    AddSound = function() return -1 end,
    PlaySound = function() end,
    GetAbsolutePath = function() return "" end,
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
        Author = "",
        Loaded = false,
        LastLoadedTime = -1,
    }
    local status, submod = pcall(require, string.format("%sMods\\%s\\main", RelPath, Name))
    if status and type(submod) == "table" then
        submod.ID = Name
        if not submod.Version then
            Log(ModManager, LOG.WARN, string.format("Submod '%s' has no version", Name))
        elseif submod.Version < ModManager.Version then
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
        if file.isDir(path) and file.exists(path .. "\\main.lua") then
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
        table.forEach(Mod.Hooks, function(Hook, HookName)
            if not Hook.Enabled and Hook.CondFn(ModManager) then
                Log(ModManager, LOG.DEBUG, string.format("Activating hook %s.%s ...", Mod.ID, HookName))
                Hook.Enabled, Hook.PreID, Hook.PostID = pcall(RegisterHook, Hook.Key, function(...)
                    Log(ModManager, LOG.DEBUG, string.format("Triggering hook %s.%s", Mod.ID, HookName))
                    return Hook.CallbackFn(ModManager, ...)
                end)
                if Hook.Enabled then
                    Log(ModManager, LOG.DEBUG, string.format("Hook %s.%s activated", Mod.ID, HookName))
                else
                    Log(ModManager, LOG.ERR, string.format("Failed to activate hook %s.%s", Mod.ID, HookName))
                    if ModManager.DEBUG and type(Hook.PreID) == "function" then
                        ExecuteInGameThread(function()
                            -- executes in its own thread cause it's throwing an error
                            Hook.PreID()
                        end)
                    end
                    Hook.PreID = nil
                end
            elseif Hook.Enabled and not Hook.CondFn(ModManager) then
                Log(ModManager, LOG.DEBUG, string.format("Disabling hook %s.%s ...", Mod.ID, HookName))
                Hook.Enabled = false -- marked first for next loop pass
                ExecuteInGameThread(function()
                    -- In its own thread because it can throw an error, even with pcall
                    pcall(UnregisterHook, Hook.Key, Hook.PreID, Hook.PostID)
                end)
                ExecuteInGameThread(function()
                    -- In its own thread to be executed after the unregistering
                    Hook.PreID, Hook.PostID = nil, nil
                    Log(ModManager, LOG.DEBUG, string.format("Hook %s.%s disabled", Mod.ID, HookName))
                end)
            end
        end)
    end)
end

function ModManager.AddHook(Mod, Name, HookKey, Callback, Condition)
    local CachedMod = table.find(Mods, function(Cached) return Cached.ID == Mod.ID end)
    if CachedMod then
        if not CachedMod.Hooks then
            CachedMod.Hooks = {}
        end
        if CachedMod.Hooks[Name] then
            Log(Mod, LOG.WARN, string.format("Hook %s.%s already exists", Mod.ID, Name))
        else
            CachedMod.Hooks[Name] = {
                Enabled = false,
                Key = HookKey,
                CallbackFn = Callback,
                CondFn = Condition or function() return true end,
            }
            Log(Mod, LOG.INFO, string.format("Hook %s.%s registered", Mod.ID, Name))
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
    if not file.exists(AbsSoundPath) or file.isDir(AbsSoundPath) then
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
            io.popen(string.format("powershell -c (New-Object Media.SoundPlayer '%s').PlaySync();",
                CachedMod.Sounds[SoundID]))
        end
    end
end

function ModManager.GetAbsolutePath(Mod)
    local CachedMod = table.find(Mods, function(Cached) return Cached.ID == Mod.ID end)
    if not CachedMod then
        return ""
    end

    return string.format("%sMods\\%s\\", AbsPath, CachedMod.ID)
end

---@param M ModManager
---@param Parameters string[]
---@param Ar any
local function ReloadCommand(M, Parameters, Ar)
    local usageStr = "Usage : reload <all|mod_name>"

    ---@param Mod ModCache
    local function ReloadMod(Mod)
        if type(Mod.Unload) == "function" then
            Mod.Unload(M)
        end
        for HookName, Hook in pairs(Mod.Hooks) do
            if Hook.Enabled then
                UnregisterHook(Hook.Key, Hook.PreID, Hook.PostID)
            end
            Mod.Hooks[HookName] = nil
        end
        Mod.Hooks = nil
        -- commands cannot be reloaded for now
        -- keys cannot be reloaded for now
        Mod.Sounds = nil
        if type(Mod.Init) == "function" then
            Mod.Init(M)
        end
    end

    if #Parameters < 1 then
        Log(M, LOG.ERR, usageStr, Ar)
        return true
    else
        local Param = table.join(Parameters)
        if Param == "all" then
            for _, Mod in pairs(Mods) do
                if Mod.ID ~= ModManager.ID then
                    ReloadMod(Mod)
                end
            end
            Log(M, LOG.INFO, "All mods reloaded", Ar)
            return true
        end

        local Mod = Mods[Param]
        if not Mod or Param == ModManager.ID then
            Log(M, LOG.ERR, string.format("Mod %s not found", Param), Ar)
            return true
        end

        ReloadMod(Mod)

        Log(M, LOG.INFO, string.format("Mod %s reloaded", Param), Ar)
        return true
    end
end

local function DebugCommand(M, Parameters, Ar)
    if #Parameters == 0 then
        M.DEBUG = not M.DEBUG
    else
        local ValueStr = Parameters[1]
        if not table.includes({ "true", "false" }, ValueStr) then
            Log(M, LOG.ERR, string.format("Invalid value %s", ValueStr), Ar)
            return true
        end

        M.DEBUG = ValueStr == "true"
    end
    Log(M, LOG.INFO, string.format("Debug mode %s", M.DEBUG and "enabled" or "disabled"), Ar)
    return true
end

local function InitData()
    -- ModManager is treated like a regular mod
    Mods[ModManager.ID] = {
        ID = ModManager.ID,
        Name = "ModManager",
        Enabled = true,
        Version = ModManager.Version,
    }

    ModManager.AddHook(ModManager, "OnClientRestart",
        "/Script/Engine.PlayerController:ClientRestart",
        function()
            ModManager.GameState = FindFirstOf("BP_BakeryGameState_Ingame_C")
            local changed = false
            if ModManager.GameState and ModManager.GameState:IsValid() then
                if ModManager.AppState ~= APP_STATES.IN_GAME then
                    ModManager.AppState = APP_STATES.IN_GAME
                    changed = true
                end
            else
                if ModManager.AppState ~= APP_STATES.MAIN_MENU then
                    ModManager.AppState = APP_STATES.MAIN_MENU
                    changed = true
                end
            end
            if changed then
                ModManager.IsHost = ModManager.GameState:IsValid() and ModManager.GameState.Role == ROLE_AUTHORITY
                ModManager.Trigger(ModManager, "AppStateChanged", ModManager.AppState)
            end
        end)

    -- first init state
    ModManager.GameState = FindFirstOf("BP_BakeryGameState_Ingame_C")
    if ModManager.GameState and ModManager.GameState:IsValid() then
        ModManager.AppState = APP_STATES.IN_GAME
        ModManager.IsHost = ModManager.GameState.Role == ROLE_AUTHORITY
        ModManager.Trigger(ModManager, "AppStateChanged", ModManager.AppState)
    end

    ModManager.AddCommand(ModManager, "reload", ReloadCommand)

    ModManager.AddCommand(ModManager, "debug", DebugCommand)
end

local function CheckUE4SSVersion()
    local Major, Minor, Patch = UE4SS.GetVersion()
    if Major < 3 or (Major == 3 and Minor == 0 and Patch < 1) then
        Log(ModManager, LOG.ERR, "UE4SS version too old", true)
        return false
    end

    -- detect if there is a folder named "ue4ss" in Win64
    local CheckPath = AbsPath:gsub("\\Win64\\.*$", "\\Win64\\ue4ss\\")
    if not file.exists(CheckPath) or not file.isDir(CheckPath) then
        Log(ModManager, LOG.ERR, "UE4SS folder not found", true)
        return false
    end

    return true
end

local function Init()
    if CheckUE4SSVersion() then
        LoadMods()

        InitData()

        ModManager.Trigger(ModManager, "Init")

        -- hooks toggling loop
        ModManager.Loop(ModManager, 1000, function()
            ToggleHooks()
            return false
        end)

        Log(ModManager, LOG.INFO, "ModManager Loaded!")

        --local LogicMods = IterateGameDirectories().Game.Content.Paks.LogicMods;
    end
end

Init()
