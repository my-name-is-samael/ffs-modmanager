local M = {
    log = "ExampleMod",
    Version = 1,
}

---@param ModManager ModManager
---@param MainMenu RemoteUnrealParam
local function OnClickSingleplayerButton(ModManager, MainMenu)
    Log("SinglePlayer button clicked", M.log)
end

---@param ModManager ModManager
---@param OrderMonitor RemoteUnrealParam
---@param Interactor RemoteUnrealParam
---@param bAuthority RemoteUnrealParam
---@param Interacted RemoteUnrealParam
---@param InputAction RemoteUnrealParam
local function onOrderMonitorInteraction(ModManager, OrderMonitor, Interactor, bAuthority, Interacted, InputAction)
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

    Log(string.format("OrderMonitor interacted with (%s)", table.join(strParams, " ; ")), M.log)
end

---@param ModManager ModManager
---@param data1 number
---@param data2 boolean
function M.MyCustomEvent(ModManager, data1, data2)
    Log(string.format("MyCustomEvent received => %s ; %s", tostring(data1), tostring(data2)), M.log)
end

-- when the mod is loaded
---@param ModManager ModManager
function M.Init(ModManager)
    Log("Init", M.log)

    -- Example Hook 1
    ModManager.AddHook("ExampleHookMainMenuSingleplayerButton",
        "/Game/UI/MainMenu/W_MainMenu.W_MainMenu_C:BndEvt__W_MainMenu_SingleplayerBtn_K2Node_ComponentBoundEvent_0_OnButtonPressed__DelegateSignature",
        OnClickSingleplayerButton, -- callback
        function(ModManager2) -- condition to enable and disable the hook
            return ModManager2.AppState == APP_STATES.MAIN_MENU
        end
    )

    -- Example Hook 2
    ModManager.AddHook("ExampleHookInGameOrderMonitorInteraction",
        "/Game/Blueprints/Gameplay/Restaurant/BP_OrderMonitor.BP_OrderMonitor_C:OrderMonitorInteractionStarted",
        onOrderMonitorInteraction,
        function(ModManager2)
            return ModManager2.AppState == APP_STATES.IN_GAME and FindFirstOf("BP_OrderMonitor_C"):IsValid()
        end
    )

    -- Example Loop
    local value = 0
    ModManager.Loop(1000, function(ModManager2)
        value = value + 1
        -- Example Custom Event
        Trigger("MyCustomEvent", value, true)
        return value == 5 -- loop stops when value reaches 5
    end)

    -- Example command
    ModManager.AddCommand("example", function(ModManager2, Parameters, Ar)
        Log(string.format("Here is an example command (%s)", table.join(Parameters, " ; ")), M.log, Ar)
        -- can return false if the command is not meant for the mod or the mod wants to hide it
        -- no return will accept the command for this mod
    end)
end

return M
