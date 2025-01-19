---@enum AppState
APP_STATES = {
    MAIN_MENU = 0,
    IN_GAME = 1,
}

---@enum LogType
LOG = {
    DEBUG = "DEBUG",
    INFO = "INFO",
    WARN = "WARNING",
    ERR = "ERROR",
}

---@class ModModule
---@field ID? string
---@field Version integer
---@field Init? fun(ModManager: ModManager)
---@field Unload? fun(ModManager: ModManager)

---@class ModManager : ModModule
---@field DEBUG boolean
---@field Version? string
---@field AppState AppState::type
---@field GameState? UObject|ABP_BakeryGameState_Ingame_C
---@field UE4SSBeta boolean
---@field Loop fun(Mod: ModModule, Timeout: integer, Callback: fun(ModManager : ModManager): boolean)
---@field AddHook fun(Mod : ModModule, Name: string, Key : string, Callback: fun(ModManager : ModManager, object : RemoteUnrealParam, ... : RemoteUnrealParam), Condition: fun(ModManager : ModManager): boolean)
---@field AddCommand fun(Mod : ModModule, CommandName: string, Callback: fun(ModManager : ModManager, Parameters: table, Ar: any): boolean?)
---@field AddKey fun(Mod : ModModule, Key: Key, Description: string, Callback: fun(ModManager : ModManager), Modifiers?: ModifierKey[])
---@field Trigger fun(Mod : ModModule, EventName: string, ...: any)
---@field AddSound fun(Mod : ModModule, SoundPath: string): SoundID: integer
---@field PlaySound fun(Mod: ModModule, SoundID: integer)

---@class HookCache
---@field Key string
---@field Enabled boolean
---@field CallbackFn fun(ModManager : ModManager, ... : any)
---@field PreID? integer
---@field PostID? integer
---@field CondFn? fun(ModManager : ModManager): boolean

---@class CommandCache
---@field Command string
---@field Enabled boolean
---@field LoadError? string
---@field CallBackFn? fun(ModManager : ModManager, Parameters: table, Ar: any): boolean?

---@class KeyCache
---@field Key Key
---@field KeyLabel string
---@field Description string
---@field Enabled boolean
---@field LoadError? string
---@field CallbackFn? fun(ModManager : ModManager)
---@field Modifiers? ModifierKey[]

---@class ModCache : ModModule
---@field ID string
---@field Version? integer
---@field Loaded boolean
---@field LoadError? string error when trying to load the mod
---@field LastLoadedTime number last time we tried to load, -1 if never
---@field Hooks? table<string, HookCache>
---@field Commands? table<string, CommandCache>
---@field Keys? table<Key, KeyCache>
---@field Sounds? table<integer, string>
