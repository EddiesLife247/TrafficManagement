RegisterServerEvent("traffic:controlLights")
AddEventHandler("traffic:controlLights", function(state)
    -- Broadcast the light state to all clients
    TriggerClientEvent("traffic:updateLights", -1, state)
end)

-- Store officer states
local officerStates = {}

RegisterServerEvent("traffic:updateOfficerState")
AddEventHandler("traffic:updateOfficerState", function(coords, state, name, job)
    local src = source

    -- Initialize officerStates entry if not already set
    if not officerStates[src] then
        officerStates[src] = { coords = coords, state = state, name = name, job = job }
        -- Broadcast to all clients
        for playerId, _ in pairs(officerStates) do
            TriggerClientEvent("traffic:updateOfficerBlip", playerId, coords, state, name, job)
        end
        return
    end

    -- Check for significant changes
    local prevState = officerStates[src]
    local distance = #(vector3(coords.x, coords.y, coords.z) - vector3(prevState.coords.x, prevState.coords.y, prevState.coords.z))
    if distance > 1.0 or prevState.state ~= state then
        officerStates[src] = { coords = coords, state = state, name = name, job = job }
        -- Broadcast to all clients
        for playerId, _ in pairs(officerStates) do
            TriggerClientEvent("traffic:updateOfficerBlip", playerId, coords, state, name, job)
        end
    end
end)

-- Cleanup on player disconnect
AddEventHandler("playerDropped", function()
    local src = source
    officerStates[src] = nil

    -- Notify other clients to remove the blip
    for playerId, _ in pairs(officerStates) do
        TriggerClientEvent("traffic:updateOfficerBlip", playerId, {}, "remove", "", "")
    end
end)
