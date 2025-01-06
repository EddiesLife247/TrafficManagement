-- BLIPS CHANGES
--- 
-- Monitor officer state changes every 500ms
CreateThread(function()
    while true do
        if not Config.LeoBlips then
            LogDebug("Leo Blips disabled.. skipping!")
            return
        end
        Wait(500) -- Check every half second
        CheckOfficerState()
    end
end)

-- Function to check and update officer state
function CheckOfficerState()
    if not Config.LeoBlips then
        LogDebug("Leo Blips disabled.. skipping!")
        return
    end
    local ped = GetPlayerPed(-1)
    local vehicle = GetVehiclePedIsIn(ped, false) -- Get the vehicle the player is in
    local coords = GetEntityCoords(ped) -- Get the player's current position
    local playerData = QBCore.Functions.GetPlayerData() -- Retrieve player data

    -- Check if the player has a Law Enforcement Officer (LEO) job
    if PlayerHasLEOJob() then
        local charName = playerData.charinfo.firstname .. " " .. playerData.charinfo.lastname
        local jobName = playerData.job.label

        -- Determine the officer's state based on their situation
        if vehicle ~= 0 then
            local sirensOn = IsVehicleSirenOn(vehicle)

            if sirensOn then
                -- Officer is in a vehicle with lights/sirens
                TriggerServerEvent("traffic:updateOfficerState", coords, "lights", charName, jobName)
            else
                -- Officer is in a vehicle without lights/sirens
                TriggerServerEvent("traffic:updateOfficerState", coords, "vehicle", charName, jobName)
            end
        else
            -- Officer is on foot
            TriggerServerEvent("traffic:updateOfficerState", coords, "foot", charName, jobName)
        end
    else
        -- Player is not a LEO, remove their state from the server
        TriggerServerEvent("traffic:updateOfficerState", coords, "remove", "", "")
    end
end


local officerBlips = {} -- Table to store blips for officers

RegisterNetEvent("traffic:updateOfficerBlip")
AddEventHandler("traffic:updateOfficerBlip", function(src, coords, state, name, job)

    if not Config.LeoBlips then
        LogDebug("Leo Blips disabled.. skipping!")
        return
    end
    if not Config.ShowLeoBlipsToAll and not PlayerHasLEOJob() then
        -- Non-LEO players should not see officer blips if restricted
        LogDebug("Non-LEO player. Blip visibility restricted.")
        return
    end
    LogDebug("Updating officer blip to state: " .. state .. "for officer: " .. name .. "on job: " .. job)
    if state == "remove" then
        if officerBlips[src] then
            RemoveBlip(officerBlips[src])
            officerBlips[src] = nil
        end
    else
        -- Create or update the blip
        if not officerBlips[src] then
            officerBlips[src] = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipScale(officerBlips[src], 0.8) -- Adjust blip size
            SetBlipAsShortRange(officerBlips[src], false) -- Make it visible to all
        else
            SetBlipCoords(officerBlips[src], coords.x, coords.y, coords.z)
        end

        -- Update blip appearance based on state
        if state == "lights" then
            SetBlipSprite(officerBlips[src], 41) -- Police car icon
        elseif state == "vehicle" then
            SetBlipSprite(officerBlips[src], 227) -- Vehicle icon
            SetBlipColour(officerBlips[src], 3) -- Yellow color
        elseif state == "foot" then
            SetBlipSprite(officerBlips[src], 6) -- Pedestrian icon
            SetBlipColour(officerBlips[src], 1) -- Red color
        end

        -- Set blip name
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(name .. " (" .. job .. ")")
        EndTextCommandSetBlipName(officerBlips[src])
    end
end)

-- Cleanup blips when resource stops
AddEventHandler("onClientResourceStop", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        for _, blip in pairs(officerBlips) do
            if DoesBlipExist(blip) then
                RemoveBlip(blip)
            end
        end
        officerBlips = {}
    end
end)

