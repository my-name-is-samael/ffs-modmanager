---@class ExampleMod: ModModule
local M = {
    Author = "TontonSanael",
    Version = 1,
}

---@param ModManager ModManager
---@param MainMenu RemoteUnrealParam
local function OnClickSingleplayerButton(ModManager, MainMenu)
    Log(M, LOG.INFO, "SinglePlayer button clicked")
end

---@param ModManager ModManager
---@param OrderMonitor RemoteUnrealParam
---@param Interactor RemoteUnrealParam
---@param bAuthority RemoteUnrealParam
---@param Interacted RemoteUnrealParam
---@param InputAction RemoteUnrealParam
local function onOrderMonitorInteraction(ModManager, OrderMonitor, bAuthority, Interactor, Interacted, InputAction)
    local params = {
        bAuthority = bAuthority:get(),
        Interactor = Interactor:get():GetFName():ToString(),
        Interacted = Interacted:get():GetFName():ToString(),
        InputAction = InputAction:get():GetFName():ToString(),
    }
    local strParams = {}
    for k, v in pairs(params) do
        table.insert(strParams, string.format("%s = %s", k, tostring(v)))
    end

    Log(M, LOG.INFO, string.format("OrderMonitor interacted with (%s)", table.join(strParams, " ; ")))
end

---@param ModManager ModManager
---@param data1 number
---@param data2 boolean
function M.MyCustomEvent(ModManager, data1, data2)
    Log(M, LOG.INFO, string.format("MyCustomEvent received => %s ; %s", tostring(data1), tostring(data2)))
end

---@param ModManager ModManager
local function OnPressCustomKey(ModManager)
    Log(M, LOG.INFO, "Custom key pressed !")
    Log(M, LOG.INFO, string.format("My Mod Folder : %s", ModManager.GetAbsolutePath(M)))
end

---@param ModManager ModManager
local function OnPressCustomKey2(ModManager)
    Log(M, LOG.INFO, "Custom key 2 pressed !")
    ModManager.PlaySound(M, M.DingSound)
end

-- when the mod is loaded
---@param ModManager ModManager
function M.Init(ModManager)
    Log(M, LOG.INFO, "Example Init !")

    -- Example Hook 1
    ModManager.AddHook(M, "ExampleHookMainMenuSingleplayerButton",
        "/Game/UI/MainMenu/W_MainMenu.W_MainMenu_C:BndEvt__W_MainMenu_SingleplayerBtn_K2Node_ComponentBoundEvent_0_OnButtonPressed__DelegateSignature",
        OnClickSingleplayerButton, -- callback
        function(ModManager2)      -- condition to enable and disable the hook
            return ModManager2.AppState == APP_STATES.MAIN_MENU
        end
    )

    -- Example Hook 2
    ModManager.AddHook(M, "ExampleHookInGameOrderMonitorInteraction",
        "/Game/Blueprints/Gameplay/Restaurant/BP_OrderMonitor.BP_OrderMonitor_C:OrderMonitorInteractionStarted",
        onOrderMonitorInteraction,
        function(ModManager2)
            return ModManager2.AppState == APP_STATES.IN_GAME and FindFirstOf("BP_OrderMonitor_C"):IsValid()
        end
    )

    -- Example Loop
    local value = 0
    ModManager.Loop(M, 1000, function(ModManager2)
        value = value + 1
        -- Example Custom Event
        ModManager2.Trigger(M, "MyCustomEvent", value, true)
        return value == 5 -- loop stops when value reaches 5
    end)

    -- Example command
    ModManager.AddCommand(M, "example", function(ModManager2, Parameters, Ar)
        Log(M, LOG.INFO, string.format("Here is an example command (%s)", table.join(Parameters, " ; ")), Ar)
        -- can return false if the command is not meant for the mod or the mod wants to hide it
        -- no return will accept the command for this mod
    end)

    ModManager.AddKey(M, Key.F3, "My example key 1", OnPressCustomKey, { ModifierKey.SHIFT, ModifierKey.CONTROL })

    M.DingSound = ModManager.AddSound(M, "ding.wav")
    ModManager.AddKey(M, Key.F6, "My example key 2 with sound", OnPressCustomKey2)
end

function M.Unload(ModManager)
    Log(M, LOG.INFO, "Example Unloaded !")
end

return M
