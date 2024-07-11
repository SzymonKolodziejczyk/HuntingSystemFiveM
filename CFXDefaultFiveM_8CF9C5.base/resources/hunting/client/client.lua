local Config = Config or {}
local huntingStage = 0
local isNearQuestStart = false
local currentClueIndex = 1
local animal = nil
local isMissionActive = false
local clueBlips = {}
local animalBlip = nil
local playerCash = 0

local function createQuestStartMarker()
    local QuestAnimalPoint = Config.QuestAnimalPoint
    local blip = AddBlipForCoord(QuestAnimalPoint.x, QuestAnimalPoint.y, QuestAnimalPoint.z)
    SetBlipSprite(blip, 500)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 1)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Hunting Quest Start")
    EndTextCommandSetBlipName(blip)
    
    print("Quest marker added on the map.")
end

local function createClueMarker(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 1)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 5)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Hunting Clue")
    EndTextCommandSetBlipName(blip)

    table.insert(clueBlips, blip)
end

local function createAnimalBlip(animal)
    if DoesBlipExist(animalBlip) then
        RemoveBlip(animalBlip)
    end
    animalBlip = AddBlipForEntity(animal)
    SetBlipSprite(animalBlip, 141)
    SetBlipColour(animalBlip, 3)
    SetBlipScale(animalBlip, 1.0)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Hunting Animal")
    EndTextCommandSetBlipName(animalBlip)
end

local function removeAllClueMarkers()
    for _, blip in ipairs(clueBlips) do
        RemoveBlip(blip)
    end
    clueBlips = {}
end

local function createHuntingLocationMarker(coords)
    local blip = AddBlipForCoord(coords.x, coords.y, coords.z)
    SetBlipSprite(blip, 141)
    SetBlipDisplay(blip, 4)
    SetBlipScale(blip, 1.0)
    SetBlipColour(blip, 3)
    SetBlipAsShortRange(blip, true)

    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Hunting Location")
    EndTextCommandSetBlipName(blip)
end

Citizen.CreateThread(function()
    while Config.QuestAnimalPoint == nil do
        Citizen.Wait(100)
    end
end)

AddEventHandler('onClientGameTypeStart', function()
    exports.spawnmanager:setAutoSpawnCallback(function()
        exports.spawnmanager:spawnPlayer({
            x = Config.SpawnLocation.x,
            y = Config.SpawnLocation.y,
            z = Config.SpawnLocation.z,
        }, function()
            TriggerEvent('chat:addMessage', {
                args = {' Have a good hunting time! '}
            })
            createQuestStartMarker()
        end)
    end)

    exports.spawnmanager:setAutoSpawn(true)
    exports.spawnmanager:forceRespawn()
end)

RegisterNetEvent('hunting:addQuestMarker')
AddEventHandler('hunting:addQuestMarker', function(location)
    createQuestStartMarker()
end)

RegisterNetEvent('hunting:spawnPlayer')
AddEventHandler('hunting:spawnPlayer', function(location)
    Citizen.CreateThread(function()
        local playerPed = PlayerPedId()
        SetEntityCoords(playerPed, location.x, location.y, location.z, false, false, false, true)
        FreezeEntityPosition(playerPed, false)
        SetEntityHeading(playerPed, 0)
        SetGameplayCamRelativeHeading(0)
        
        print("Player spawned at fixed location.")
    end)
end)

RegisterNetEvent('hunting:restoreProgress')
AddEventHandler('hunting:restoreProgress', function(stage, location, cash)
    SetEntityCoords(PlayerPedId(), location.x, location.y, location.z)
    huntingStage = stage
    playerCash = cash
    TriggerEvent('chat:addMessage', {args = {"Your hunting progress has been restored"}})
    TriggerEvent('chat:addMessage', {args = {"Your current balance is $" .. playerCash}})
    
    if stage == 1 then
        TriggerServerEvent('hunting:assignEquipment', Config.Weapon, Config.Vehicle)
    elseif stage == 2 then
        for i, clue in ipairs(Config.ClueCoords) do
            createClueMarker(clue)
        end
    elseif stage == 3 then
        local animalHash = GetHashKey(Config.AnimalHash)
        RequestModel(animalHash)
        while not HasModelLoaded(animalHash) do
            Wait(500)
        end
        animal = CreatePed(5, animalHash, Config.HuntingLocation.x, Config.HuntingLocation.y, Config.HuntingLocation.z, 0.0, true, false)
        TaskCombatPed(animal, PlayerPedId(), 0, 16)
        createAnimalBlip(animal)
    elseif stage == 4 then
        TriggerEvent('chat:addMessage', {args = {"You need to deliver the animal skin to complete the quest"}})
    end
end)

RegisterNetEvent('hunting:assignEquipment')
AddEventHandler('hunting:assignEquipment', function(weapon, vehicle)
    GiveWeaponToPed(PlayerPedId(), GetHashKey(weapon), 100, false, true)
    
    local vehicleHash = GetHashKey(vehicle)
    RequestModel(vehicleHash)
    while not HasModelLoaded(vehicleHash) do
        Wait(500)
    end
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local spawnedVehicle = CreateVehicle(vehicleHash, playerCoords.x, playerCoords.y, playerCoords.z, GetEntityHeading(playerPed), true, false)
    TaskWarpPedIntoVehicle(playerPed, spawnedVehicle, -1)
    
    TriggerEvent('chat:addMessage', {args = {"Go to the marked location to start hunting"}})
    
    huntingStage = 1
    currentClueIndex = 1
    isMissionActive = true
    
    print("Equipment assigned: weapon " .. weapon .. ", vehicle " .. vehicle)
end)

RegisterNetEvent('hunting:animalSkinned')
AddEventHandler('hunting:animalSkinned', function()
    if DoesEntityExist(animal) then
        DeleteEntity(animal)
    end

    TriggerEvent('chat:addMessage', {args = {"You have skinned the animal. Return to the quest start point to complete the quest."}})
    huntingStage = 4
end)

RegisterNetEvent('hunting:reward')
AddEventHandler('hunting:reward', function(amount)
    TriggerEvent('chat:addMessage', {args = {"You received $" .. amount .. " for delivering the skin"}})
    huntingStage = 0
    isMissionActive = false
    
    print("Client received reward event: amount " .. amount)
end)

RegisterNetEvent('hunting:updateCash')
AddEventHandler('hunting:updateCash', function(newCash)
    playerCash = newCash
    TriggerEvent('chat:addMessage', {args = {"Your new balance is $" .. playerCash}})
    print("Client received updated cash: new balance " .. playerCash)
end)

Citizen.CreateThread(function()
    local QuestAnimalPoint = Config.QuestAnimalPoint
    while true do
        Citizen.Wait(0)
        local playerPed = PlayerPedId()
        local playerCoords = GetEntityCoords(playerPed)
        local distance = GetDistanceBetweenCoords(playerCoords, QuestAnimalPoint.x, QuestAnimalPoint.y, QuestAnimalPoint.z, true)
        
        if distance < 100.0 and not isMissionActive then
            isNearQuestStart = true
            DrawMarker(1, QuestAnimalPoint.x, QuestAnimalPoint.y, QuestAnimalPoint.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 0, 0, 150, false, true, 2, nil, nil, false)
            if distance < 2.5 then
                SetTextComponentFormat('STRING')
                AddTextComponentString("Press ~INPUT_CONTEXT~ to start the hunting quest.")
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                if IsControlJustReleased(1, 51) then
                    TriggerServerEvent('hunting:takeQuest')
                end
            end
        else
            isNearQuestStart = false
        end
    end
end)

Citizen.CreateThread(function()
    while true do
        Citizen.Wait(0)
        
        if huntingStage == 1 then
            local clueCoords = Config.ClueCoords[currentClueIndex]
            DrawMarker(1, clueCoords.x, clueCoords.y, clueCoords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 255, 0, 0, 150, false, true, 2, nil, nil, false)
            createClueMarker(clueCoords)
            
            if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), clueCoords.x, clueCoords.y, clueCoords.z, true) < 1.5 then
                TriggerEvent('chat:addMessage', {args = {"You found a clue!"}})
                removeAllClueMarkers()
                currentClueIndex = currentClueIndex + 1
                
                if currentClueIndex > #Config.ClueCoords then
                    huntingStage = 2
                end
            end
        end
        
        if huntingStage == 2 then
            local animalHash = GetHashKey(Config.AnimalHash)
            RequestModel(animalHash)
            while not HasModelLoaded(animalHash) do
                Wait(500)
            end
            animal = CreatePed(5, animalHash, Config.HuntingLocation.x, Config.HuntingLocation.y, Config.HuntingLocation.z, 0.0, true, false)
            TaskCombatPed(animal, PlayerPedId(), 0, 16)
            createAnimalBlip(animal)
            huntingStage = 3
            
            TriggerEvent('chat:addMessage', {args = {"An animal has appeared! Kill it."}})
        end
        
        if huntingStage == 3 and IsPedDeadOrDying(animal, true) then
            TriggerEvent('chat:addMessage', {args = {"You killed the animal. Now obtain its skin."}})
            huntingStage = 3.5
        end
        
        if huntingStage == 3.5 then
            DrawMarker(1, GetEntityCoords(animal).x, GetEntityCoords(animal).y, GetEntityCoords(animal).z + 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 150, false, true, 2, nil, nil, false)
            if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), GetEntityCoords(animal).x, GetEntityCoords(animal).y, GetEntityCoords(animal).z, true) < 1.5 then
                SetTextComponentFormat('STRING')
                AddTextComponentString("Press ~INPUT_CONTEXT~ to skin the animal.")
                DisplayHelpTextFromStringLabel(0, 0, 1, -1)
                if IsControlJustReleased(1, 51) then
                    TriggerServerEvent('hunting:skinAnimal')
                end
            end
        end

        if huntingStage == 4 then
            local QuestAnimalPoint = Config.QuestAnimalPoint
            DrawMarker(1, QuestAnimalPoint.x, QuestAnimalPoint.y, QuestAnimalPoint.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0, 1.0, 1.0, 0, 255, 0, 150, false, true, 2, nil, nil, false)
            
            if GetDistanceBetweenCoords(GetEntityCoords(PlayerPedId()), QuestAnimalPoint.x, QuestAnimalPoint.y, QuestAnimalPoint.z, true) < 1.5 then
                TriggerServerEvent('hunting:deliverSkin')
                huntingStage = 0
            end
        end
    end
end)