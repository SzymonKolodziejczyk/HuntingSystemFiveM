local Config = Config or {}

local function debugSQLQuery(query, parameters)
    print("Executing SQL Query: " .. query)
    for k, v in pairs(parameters) do
        print(k .. " = " .. v)
    end
end

local function executeSQL(query, parameters, callback)
    MySQL.Async.execute(query, parameters, function(rowsChanged, err)
        if err then
            print("MySQL Error: " .. tostring(err))
        end
        if callback then
            callback(rowsChanged, err)
        end
    end)
end

RegisterServerEvent('hunting:takeQuest')
AddEventHandler('hunting:takeQuest', function()
    local src = source
    local user_id = GetPlayerIdentifiers(src)[1]

    local query = 'UPDATE users SET hunting_stage = 1, hunting_vehicle = @vehicle, hunting_weapon = @weapon WHERE identifier = @identifier'
    local parameters = {
        ['@vehicle'] = Config.Vehicle,
        ['@weapon'] = Config.Weapon,
        ['@identifier'] = user_id
    }

    debugSQLQuery(query, parameters)
    executeSQL(query, parameters, function(rowsChanged)
        if rowsChanged > 0 then
            TriggerClientEvent('hunting:assignEquipment', src, Config.Weapon, Config.Vehicle, Config.HuntingLocation)
            TriggerClientEvent('hunting:addHuntingMarker', src, Config.HuntingLocation)
            print("Quest taken: weapon and vehicle assigned.")
        else
            print("Failed to update the user's quest status in the database. User ID: " .. user_id)
        end
    end)
end)

RegisterServerEvent('hunting:skinAnimal')
AddEventHandler('hunting:skinAnimal', function()
    local src = source
    local user_id = GetPlayerIdentifiers(src)[1]

    local query = 'UPDATE users SET hunting_stage = 4 WHERE identifier = @identifier'
    local parameters = { ['@identifier'] = user_id }

    executeSQL(query, parameters, function(rowsChanged)
        if rowsChanged > 0 then
            TriggerClientEvent('hunting:animalSkinned', src)
            print("Animal skinned: stage updated to 4.")
        else
            print("Failed to update the user's hunting stage to 4. User ID: " .. user_id)
        end
    end)
end)

RegisterServerEvent('hunting:deliverSkin')
AddEventHandler('hunting:deliverSkin', function()
    local src = source
    local user_id = GetPlayerIdentifiers(src)[1]

    MySQL.Async.fetchScalar('SELECT cash FROM users WHERE identifier = @identifier', {
        ['@identifier'] = user_id
    }, function(currentCash, err)
        if err then
            print("MySQL Error: " .. tostring(err))
        end
        if currentCash then
            local newCash = currentCash + Config.RewardAmount
            local query = 'UPDATE users SET cash = @newCash, hunting_stage = 0 WHERE identifier = @identifier'
            local parameters = {
                ['@newCash'] = newCash,
                ['@identifier'] = user_id
            }

            debugSQLQuery(query, parameters)
            executeSQL(query, parameters, function(rowsChanged)
                if rowsChanged > 0 then
                    TriggerClientEvent('hunting:reward', src, Config.RewardAmount)
                    TriggerClientEvent('hunting:updateCash', src, newCash)
                    print("Skin delivered and player rewarded. New cash: " .. newCash)
                else
                    print("Failed to update the user's cash in the database. User ID: " .. user_id)
                end
            end)
        else
            print("Failed to fetch the user's current cash. User ID: " .. user_id)
        end
    end)
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    local user_id = GetPlayerIdentifiers(src)[1]
    local playerPed = GetPlayerPed(src)
    local coords = GetEntityCoords(playerPed)

    local query = 'UPDATE users SET hunting_stage = @stage, location = @location WHERE identifier = @identifier'
    local parameters = {
        ['@stage'] = huntingStage,
        ['@location'] = json.encode({x = coords.x, y = coords.y, z = coords.z}),
        ['@identifier'] = user_id
    }

    debugSQLQuery(query, parameters)
    executeSQL(query, parameters, function(rowsChanged)
        if rowsChanged > 0 then
            print("Player progress saved on disconnect.")
        else
            print("Failed to save player progress on disconnect. User ID: " .. user_id)
        end
    end)
end)

AddEventHandler('playerSpawned', function()
    local src = source
    local user_id = GetPlayerIdentifiers(src)[1]

    MySQL.Async.fetchAll('SELECT hunting_stage, location, cash FROM users WHERE identifier = @identifier', {
        ['@identifier'] = user_id
    }, function(result, err)
        if err then
            print("MySQL Error: " .. tostring(err))
        end
        if result[1] then
            local stage = result[1].hunting_stage
            local location = json.decode(result[1].location)
            local cash = result[1].cash
            TriggerClientEvent('hunting:restoreProgress', src, stage, location, cash)
        else
            TriggerClientEvent('hunting:spawnPlayer', src, Config.SpawnLocation)
        end
        print("Player connected, progress checked.")
    end)
end)