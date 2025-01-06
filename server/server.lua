local officerStates = {} -- Table to store officer states
RegisterServerEvent("traffic:updateOfficerState")
AddEventHandler("traffic:updateOfficerState", function(coords, state, name, job)
    local src = source

    -- Initialize officerStates entry if not already set
    if not officerStates[src] then
        officerStates[src] = { coords = coords, state = state, name = name, job = job }
    end

    -- Check for significant changes
    local prevState = officerStates[src]
    local distance = #(coords - prevState.coords)
    if distance > 1.0 or prevState.state ~= state then
        officerStates[src] = { coords = coords, state = state, name = name, job = job }
        -- Broadcast to all clients
        TriggerClientEvent("traffic:updateOfficerBlip", -1, src, coords, state, name, job)
    end
end)


RegisterServerEvent("traffic:controlLights")
AddEventHandler("traffic:controlLights", function(state)
    -- Broadcast the light state to all clients
    TriggerClientEvent("traffic:updateLights", -1, state)
end)


RegisterNetEvent("traffic:updateTrafficLight")
AddEventHandler("traffic:updateTrafficLight", function(trafficLightNetId, state)
    local trafficLight = NetworkGetEntityFromNetworkId(trafficLightNetId)

    if trafficLight and DoesEntityExist(trafficLight) then
        print("Updating traffic light:", trafficLight, "State:", state) -- Debugging
        -- Update traffic light state here
    else
        print("Traffic light entity not found!") -- Debugging
    end
end)



-- Handle traffic light change requests
RegisterNetEvent("traffic:changeTrafficLight")
AddEventHandler("traffic:changeTrafficLight", function(netId, state)
    if netId and type(state) == "number" then
        print("Traffic light change requested. Net ID:", netId, "State:", state)
        TriggerClientEvent("traffic:updateTrafficLight", -1, netId, state)
    else
        print("Invalid traffic light update request.")
    end
end)


-- Cleanup on player disconnect
AddEventHandler("playerDropped", function()
    local src = source

    -- Remove the officer state
    if officerStates[src] then
        officerStates[src] = nil

        -- Notify other clients to remove the blip
        for playerId, _ in pairs(officerStates) do
            TriggerClientEvent("traffic:updateOfficerBlip", playerId, src, {}, "remove", "", "")
        end
    end
end)

-- Print a message to the server console when the script is loaded
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("^2[TRAFFIC CONTROL]^0 Server-side script loaded, developed by EddiesLife247 Scripts. Support at: https://discord.eddieslife247.co.uk/")
    end
end)
