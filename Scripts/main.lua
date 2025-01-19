-- Created by TontonSamael --

local Utils = require("utils")

local VERSION = 1

---@enum AppState
APP_STATES = {
    MAIN_MENU = 0,
    IN_GAME = 1,
}

---@class ModManager
---@field AppState AppState::type
---@field GameState? ABP_BakeryGameState_Ingame_C
---@field UE4SSBeta boolean
local ModManager = {
    AppState = APP_STATES.MAIN_MENU,
    GameState = nil,

    UE4SSBeta = false,
}

-- Will log your message with the format : [Lua] [<Tag>] <message>
---@param Msg any
---@param Tag? string
---@param Ar? any
function Log(Msg, Tag, Ar)
    Msg = string.format("[%s] %s\n", Tag or "Logger", tostring(Msg))
    print(Msg)
    if Ar then
        pcall(Ar.Log, Ar, Msg)
    end
end

local Hooks = {}
local function ToggleHooks()
    for HookName, Hook in pairs(Hooks) do
        if not Hook.Enabled and (not Hook.CondFn or Hook.CondFn(ModManager)) then
            Log(string.format("Loadind hook %s ...", HookName), "INFO")
            Hook.Enabled, Hook.PreID, Hook.PostID = pcall(RegisterHook, Hook.Key,
                function(...) Hook:HookFn(ModManager, ...) end)
            if not Hook.Enabled then
                Log(string.format("Failed to register hook %s", HookName), "ERROR")
                Hook.PreID()
                Hook.PreID = nil
            end
        elseif Hook.Enabled and Hook.CondFn and not Hook.CondFn(ModManager) then
            Log(string.format("Unloading hook %s ...", HookName), "INFO")
            pcall(UnregisterHook, Hook.Key, Hook.PreID, Hook.PostID)
            -- both cases error or not, the hook is invalidated
            Hook.Enabled, Hook.PreID, Hook.PostID = nil, nil, nil
        end
    end
end

---@param Name string
---@param Key string Use Fmodel and UE4SS Lua Types dump to get thoses
---@param Callback fun(ModManager : ModManager, object : RemoteUnrealParam, ... : RemoteUnrealParam)
---@param Condition? fun(ModManager : ModManager): boolean
function ModManager.AddHook(Name, Key, Callback, Condition)
    if Hooks[Name] then
        Log(string.format("Hook %s already exists", Name), "ERROR")
    else
        Hooks[Name] = {
            Key = Key,
            HookFn = Callback,
            CondFn = Condition,
        }
    end
end

local commands = {}

---@param CommandName string
---@param Callback fun(ModManager : ModManager, Parameters: table, Ar: any): boolean?
function ModManager.AddCommand(CommandName, Callback)
    if commands[CommandName] then
        Log(string.format("Command %s already exists", CommandName), "ERROR")
    else
        commands[CommandName] = Callback
        RegisterConsoleCommandHandler(CommandName, function(FullCommand, Parameters, Ar)
            local result = Callback(ModManager, Parameters, Ar)
            if result == nil then
                return true
            end
            return result
        end)
        Log(string.format("Command %s registered", CommandName), "INFO")
    end
end

---@param Timeout number
---@param Callback fun(ModManager : ModManager): boolean
function ModManager.Loop(Timeout, Callback)
    LoopAsync(Timeout, function()
        return Callback(ModManager)
    end)
end

local function detectUE4SSBeta()
    if Utils.isDir("ue4ss\\") then
        ModManager.UE4SSBeta = true
    end
end

local submods = {}

---@param EventName string
---@param ... any
function Trigger(EventName, ...)
    for _, submod in pairs(submods) do
        if type(submod[EventName]) == "function" then
            submod[EventName](ModManager, ...)
        end
    end
end

ModManager.Trigger = Trigger

local function TryLoadSubMod(Name, MainPath)
    local status, submod = pcall(require, MainPath)
    if status and type(submod) == "table" then
        if not submod.Version then
            Log(string.format("Submod '%s' has no version", Name), "WARNING")
        elseif submod.Version < VERSION then
            Log(
                string.format("Submod '%s' is outdated (ModManager Version: %s, Submod Version: %s)", Name, VERSION,
                    submod.Version), "WARNING")
        end
        submods[Name] = submod
        Log(string.format("Submod '%s' loaded", Name))
    else
        if not status then
            Log(string.format("Failed to load submod '%s' : %s", Name, submod), "ERROR")
        else
            Log(string.format("Failed to load submod '%s' : Not a module", Name), "ERROR")
        end
    end
end

local function LoadSubMods()
    local absModDir = tostring(package.cpath):split(";")[1]:gsub("?.dll", "")
    local modDir = ""
    if ModManager.UE4SSBeta then
        absModDir = absModDir .. "ue4ss\\"
        modDir = "ue4ss\\"
    end
    absModDir = absModDir .. "Mods\\ModManager\\Mods\\"
    modDir = modDir .. "Mods\\ModManager\\Mods\\"
    for dir in io.popen("dir \"" .. absModDir .. "\" /b"):lines() do
        local path = absModDir .. dir
        if Utils.isDir(path) and Utils.fileExists(path .. "\\main.lua") then
            local subModPath = modDir .. dir .. "\\main"
            TryLoadSubMod(dir, subModPath)
        end
    end
end

local function initAppStateHooks()
    local function LoopDetectLobby()
        ModManager.Loop(500, function(M)
            if not M.GameState or not M.GameState:IsValid() then
                ---@class ABP_BakeryGameState_Ingame_C
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
    ModManager.AddHook("UpdateStateMenu", "/Game/UI/Ingame/EscapeMenu/W_EscapeMenu.W_EscapeMenu_C:OnMainMenuConfirmation",
        function(M, GameState, bConfirmed)
            if bConfirmed:get() then
                ModManager.AppState = APP_STATES.MAIN_MENU
                LoopDetectLobby()
            end
        end, function(Hook) return ModManager.AppState ~= APP_STATES.MAIN_MENU end)
end

local function Init()
    detectUE4SSBeta()

    LoadSubMods()

    initAppStateHooks()
    Trigger("Init")

    -- hooks enabling loop
    ModManager.Loop(1000, function(M)
        ToggleHooks()
        return false
    end)

    Log("ModManager Loaded!", "INFO")
end

Init()
