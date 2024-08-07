-- CLIENT MODULE
----------------

local isOpen = false
local doOpen = false
local doClose = true
local active = false
local prop = {}
local code = nil
local store

-- events

RegisterNetEvent('gunCatalogue:sendCode')
AddEventHandler('gunCatalogue:sendCode', function(code1)
    code = code1
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        PromptSetEnabled(store, false)
        PromptSetVisible(store, false)
        FreezeEntityPosition(PlayerPedId(), false)
    end
end)

-- prompt thread

Citizen.CreateThread(function()
    StorePrompt()
    while true do
        local sleep = 7
        local ped = PlayerPedId()
        local pedcoords = GetEntityCoords(ped)
        for i = 1, #Config.storeConfig do
            if IsStoreClosed(Config.storeConfig[i]) == false then
                local distance = #(vector3(Config.storeConfig[i].location.x, Config.storeConfig[i].location.y, Config.storeConfig[i].location.z)-vector3(pedcoords["x"], pedcoords["y"], pedcoords["z"]))
                if distance < 100 then
                    if distance < 2 then
                        sleep = 5
                        if PromptIsValid(store) and not active then
                            PromptSetVisible(store, true)
                            PromptSetEnabled(store, true)
                        end                   
                        if PromptHasHoldModeCompleted(store) then
                            PromptSetEnabled(store, false)
                            PromptSetVisible(store, false)
                            active = true
                            OpenUI()
                            FreezeEntityPosition(PlayerPedId(), true)
                        end
                    else
                        if PromptIsValid(store) then
                            sleep = 50
                            PromptSetEnabled(store, false)
                            PromptSetVisible(store, false)
                        end                 
                        sleep = 1200
                    end
                end
            else
                if PromptIsValid(store) then
                    PromptSetEnabled(store, false)
                    PromptSetVisible(store, false)
                end 
                if active then
                    CloseUI()
                end
            end
        end
        Citizen.Wait(sleep)
    end
end)

-- catalogue thread

Citizen.CreateThread(function ()
    local blips = {}
    local book = GetHashKey("mp001_s_mp_catalogue01x")
    local pcoords = GetEntityCoords(PlayerPedId())
    RequestModel(book)
    while not HasModelLoaded(book) do
        Citizen.Wait(0)
    end
    for i=1, #Config.storeConfig do
        -- make blip
        local blip = Citizen.InvokeNative(0x554D9D53F696D002, 1664425300, Config.storeConfig[i].location.x, Config.storeConfig[i].location.y, Config.storeConfig[i].location.z)
        SetBlipSprite(blip, -145868367, 1)
        Citizen.InvokeNative(0x9CB1A1623062F402, blip, "Gun Store")
        table.insert(blips, blip)
        Wait(100)
        prop[i] = CreateObjectNoOffset(book, Config.storeConfig[i].location.x, Config.storeConfig[i].location.y, Config.storeConfig[i].location.z, false, false, false, false)
        SetEntityHeading(prop[i], Config.storeConfig[i].location.h)
        FreezeEntityPosition(prop[i], true)
    end
    while true do
        Citizen.Wait(1)
        for i=1, #Config.storeConfig do
            -- store close check
            if IsStoreClosed(Config.storeConfig[i]) == true then
                BlipAddModifier(blips[i], 'BLIP_MODIFIER_MP_COLOR_10')
            else
                BlipAddModifier(blips[i], 'BLIP_MODIFIER_MP_COLOR_32')
            end
        end
    end
end)

-- ui thread

Citizen.CreateThread(function(...)  
    while true do
        Citizen.Wait(5)
        if doOpen then
            doOpen = false
            OpenUI()
        elseif doClose then
            doClose = false
            CloseUI()
        end
    end
end)

-- ui funcs

function StorePrompt()
    Citizen.CreateThread(function()
        store = PromptRegisterBegin()
        PromptSetControlAction(store, 0x5E723D8C)
        PromptSetText(store, CreateVarString(10, "LITERAL_STRING", "Browse the gun store"))
        PromptSetEnabled(store, 1)
        PromptSetVisible(store, 1)
        PromptSetHoldMode(store, 1)
        PromptRegisterEnd(store)
        PromptSetGroup(store, 0, 1)       
    end)
end

function Startup()
    isOpen = false
    SetNuiFocus(isOpen, isOpen)
    SendNUIMessage({
        type = "OpenBookGui",
        value = false
    })
end

function OpenUI()
    isOpen = true
    SetNuiFocus(isOpen, isOpen)
    SendNUIMessage({
        type = "OpenBookGui",
        value = true,
    })
    TriggerEvent("vorp:Tip", "Use <- and -> to change pages and ESC to close", 4000)
end

function CloseUI()
    isOpen = false
    SetNuiFocus(isOpen, isOpen)
    active = false
    FreezeEntityPosition(PlayerPedId(), false)
    SendNUIMessage({
        type = "OpenBookGui",
        value = false,
    })
end

function Purchase(data)
    TriggerServerEvent('gunCatalogue:getCode')
    Wait(200)
    TriggerServerEvent('gunCatalogue:Purchase', data, code)
end

-- ui and sound

RegisterCommand('closeui', function(...) doClose = true; end)
RegisterNUICallback('purchaseweapon', Purchase)
RegisterNUICallback('close', CloseUI)

RegisterNUICallback('playSoundPageLeft', function()
    PlaySoundFrontend("NAV_LEFT", "Ledger_Sounds", true, 0)
    end)
    
RegisterNUICallback('playSoundPageRight', function()
    PlaySoundFrontend("NAV_RIGHT", "Ledger_Sounds", true, 0)
end)

RegisterNetEvent('gunCatalogue:playSoundPurchase')
AddEventHandler('gunCatalogue:playSoundPurchase', function()
    PlaySoundFrontend("PURCHASE", "Ledger_Sounds", true, 0)
end)

-- helpers

function IsStoreClosed(storeConfig)
    local hour = GetClockHours()
    if Config.useStoreHours == true then
        if hour >= storeConfig.storeClose or hour < storeConfig.storeOpen then
            return true
        elseif hour >= storeConfig.storeOpen then
            return false
        end
    elseif Config.useStoreHours == false then
        return false
    end
end