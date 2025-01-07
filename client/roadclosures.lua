local activeRoadBlips = {}
local closedRoads = {}
local activeThreads = {}
local activeBarriers = {}

-- Create a barrier at the specified location
function CreateBarrier(coords, heading)
    -- Check if the coords parameter is valid
    if not coords or not coords.x or not coords.y or not coords.z then
        print("ERROR: Invalid coordinates passed to CreateBarrier.")
        LogDebug("Invalid barrier coordinates: " .. tostring(coords), 1)
        return nil
    end

    local model = GetHashKey("prop_barrier_work05") -- Example barrier model
    if not HasModelLoaded(model) then
        RequestModel(model)
        while not HasModelLoaded(model) do
            Wait(100)
        end
    end

    -- Create the barrier at the specified position
    local barrier = CreateObject(model, coords.x, coords.y, coords.z - 1.0, false, false, true)
    SetEntityHeading(barrier, heading)
    FreezeEntityPosition(barrier, true)
    return barrier
end



function RemoveBarriersForRoad(roadName)
    if not activeBarriers[roadName] then return end

    for _, barrier in ipairs(activeBarriers[roadName]) do
        if DoesEntityExist(barrier) then
            DeleteEntity(barrier)
            LogDebug("Barrier removed for road: " .. roadName, 2)
        end
    end

    activeBarriers[roadName] = nil
    LogDebug("Barriers removed for road: " .. roadName, 2)
end


-- Create barriers for junctions of a closed road
function CreateBarriersForRoad(roadName)
    -- Initialize the barriers table for the road
    activeBarriers[roadName] = {}

    -- Check if there are specific barriers defined for the road
    local barriers = Config.JunctionBarriers[roadName]

    -- If no specific barriers are defined for the road, use the default barrier
    if not barriers then
        LogDebug("No specific barriers defined for road: " .. roadName .. ". Using default barrier.", 2)
        barriers = {Config.DefaultBarrier}  -- Use the default barrier
    end

    -- Loop through the barriers for the road and create them
    for _, barrierData in ipairs(barriers) do
        -- Ensure that each barrier uses the correct position and heading
        local position = barrierData.position or vector3(0.0, 0.0, 0.0)  -- Default position if not defined
        local heading = barrierData.heading or 0.0  -- Default heading if not defined
        local model = barrierData.model  -- The model should be the actual barrier object, not the position
        
        -- Check if the position is a valid vector3
        if not position or not position.x or not position.y or not position.z then
            LogDebug("Invalid position for barrier. Using default position.", 2)
            position = vector3(0.0, 0.0, 0.0)  -- Use default position if invalid
        end

        -- Log the barrier creation data for debugging
        LogDebug("Creating barrier for road: " .. roadName .. " at position: " .. tostring(position) .. " with model: " .. model, 3)

        -- Create each barrier using the provided model, position, and heading
        local barrier = CreateBarrier(position, heading, model)
        
        if barrier then
            -- Add the created barrier to the activeBarriers table
            table.insert(activeBarriers[roadName], barrier)
        else
            LogDebug("Failed to create barrier for road: " .. roadName, 2)
        end
    end

    -- Log a debug message
    LogDebug("Barriers created for road: " .. roadName, 2)
end





-- Generate a unique key for a closure
local function GenerateClosureKey(coords)
    return ("%s,%s,%s"):format(math.floor(coords.x), math.floor(coords.y), math.floor(coords.z))
end
-- Lerp between two vector3 positions
function LerpVector3(posA, posB, t)
    return vector3(
        posA.x + (posB.x - posA.x) * t,
        posA.y + (posB.y - posA.y) * t,
        posA.z + (posB.z - posA.z) * t
    )
end


-- Open a road
-- Open a road
function OpenRoad(streetName)
    LogDebug("Attempting to open road: " .. (streetName or "closest"), 2)

    if not streetName then
        -- Find the closest road if none is provided
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        streetName = GetClosestClosedRoad(coords)
        if not streetName then
            SendNotification("error", "No nearby closed roads found.")
            LogDebug("No nearby closed roads found for coordinates: " .. tostring(coords), 1)
            return
        end
        LogDebug("Closest closed road determined: " .. streetName, 3)
    end

    if not closedRoads[streetName] then
        SendNotification("error", "No closure found for the specified road.")
        LogDebug("No closure found for road: " .. streetName, 1)
        return
    end

    -- Remove all closures for this road
    for key, data in pairs(closedRoads[streetName]) do
        -- Stop the thread for this closure
        if activeThreads[key] then
            activeThreads[key].active = false
            activeThreads[key] = nil
            LogDebug("Stopped thread for closure: " .. key, 2)
        end

        -- Remove associated blips
        if data.startBlip or data.endBlip then
            RemoveRoadClosureBlips(data.startBlip, data.endBlip)
            LogDebug("Blips removed for road closure: " .. streetName, 2)
        end
    end

    -- Remove barriers at junctions
    RemoveBarriersForRoad(streetName)

    -- Clear road data
    closedRoads[streetName] = nil

    -- Notify and log the action
    TriggerServerEvent("traffic:removeRoadClosure", streetName)
    SendNotification("success", "All closures for road '" .. streetName .. "' have been reopened.")
    LogDebug("All closures for road reopened: " .. streetName, 2)
end


-- Find the closest closed road
-- Find the closest closed road
function GetClosestClosedRoad(coords)
    if not coords or not coords.x or not coords.y or not coords.z then
        LogDebug("Invalid coordinates provided for finding closest closed road.", 1)
        return nil
    end

    LogDebug("Determining closest closed road to coords: " .. tostring(coords), 3)
    local closestRoad = nil
    local minDistance = math.huge

    for roadName, closures in pairs(closedRoads) do
        for key, data in pairs(closures) do
            if data.startCoords and data.startCoords.x and data.startCoords.y and data.startCoords.z then
                local startCoords = vector3(data.startCoords.x, data.startCoords.y, data.startCoords.z)
                local distance = #(coords - startCoords)
                if distance < minDistance then
                    minDistance = distance
                    closestRoad = roadName
                end
            else
                LogDebug("Invalid data for road: " .. roadName .. " at key: " .. key, 1)
            end
        end
    end

    LogDebug("Closest closed road found: " .. (closestRoad or "none") .. " at distance " .. minDistance, 3)
    return closestRoad
end





-- Open all roads
function OpenAllRoads()
    LogDebug("Attempting to open all roads", 2)

    -- Iterate over all closed roads
    for closureKey, roadData in pairs(closedRoads) do
        if type(roadData) == "table" then -- Ensure roadData is a table
            -- Remove the road closure blips first
            if roadData.startBlip or roadData.endBlip then
                RemoveRoadClosureBlips(roadData.startBlip, roadData.endBlip)
                LogDebug("Blips removed for road: " .. closureKey, 2)
            end

            -- Stop the thread for blocking AI and clearing vehicles
            if activeThreads[closureKey] then
                activeThreads[closureKey].active = false
                activeThreads[closureKey] = nil
                LogDebug("Stopped thread for closure: " .. closureKey, 2)
            end

            -- Remove the speed zones created for the road
            if roadData.speedZones then
                for _, zone in pairs(roadData.speedZones) do
                    RemoveSpeedZone(zone)
                    LogDebug("Speed zone removed for road: " .. closureKey, 2)
                end
                roadData.speedZones = nil -- Clear the speed zones list
            end

            -- Re-enable traffic and stop the vehicle despawning process
            roadData.isClosed = false  -- Set a flag that road is no longer closed
            LogDebug("Re-enabling traffic for road: " .. closureKey, 2)

        else
            LogDebug("Invalid road data for closureKey: " .. tostring(closureKey), 1)
        end

        -- Remove the road from the closedRoads list
        closedRoads[closureKey] = nil
    end

    -- Trigger server event to remove all closures
    TriggerServerEvent("traffic:removeAllRoadClosures")
    SendNotification("success", "All roads have been reopened.")
    LogDebug("All roads successfully reopened", 2)
end







-- Remove blips for a specific road
function RemoveRoadClosureBlips(startBlip, endBlip)
    if startBlip then
        RemoveBlip(startBlip)
        LogDebug("Start blip removed", 3)
    end
    if endBlip then
        RemoveBlip(endBlip)
        LogDebug("End blip removed", 3)
    end
end


-- Create blips for closed road at intersections
function CreateRoadClosureBlips(startCoords, endCoords)
    local startBlip = AddBlipForCoord(startCoords.x, startCoords.y, startCoords.z)
    SetBlipSprite(startBlip, 402)
    SetBlipColour(startBlip, 1)
    SetBlipScale(startBlip, 1.0)
    SetBlipAsShortRange(startBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Road Closed")
    EndTextCommandSetBlipName(startBlip)
    LogDebug("Start blip created at: " .. tostring(startCoords), 3)

    local endBlip = AddBlipForCoord(endCoords.x, endCoords.y, endCoords.z)
    SetBlipSprite(endBlip, 402)
    SetBlipColour(endBlip, 1)
    SetBlipScale(endBlip, 1.0)
    SetBlipAsShortRange(endBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("Road Closed")
    EndTextCommandSetBlipName(endBlip)
    LogDebug("End blip created at: " .. tostring(endCoords), 3)

    return startBlip, endBlip
end



-- Block AI and clear vehicles in the closed road area
function BlockAIAndClearVehicles(startCoords, endCoords, key)
    LogDebug("Blocking AI and clearing vehicles for closure: " .. key, 2)
    local stepCount = 100
    local radius = 50.0
    local speedZones = {}

    local threadControl = { active = true }
    activeThreads[key] = threadControl

    CreateThread(function()
        while threadControl.active do
            for i = 0, stepCount do
                local t = i / stepCount
                local currentPoint = LerpVector3(startCoords, endCoords, t)
                ClearVehiclesInRadius(currentPoint, radius)

                if not speedZones[i] then
                    local speedZone = AddSpeedZoneForCoord(currentPoint.x, currentPoint.y, currentPoint.z, radius, 0.0, false)
                    speedZones[i] = speedZone
                end
            end
            Wait(2000)
        end

        for _, zone in pairs(speedZones) do
            RemoveSpeedZone(zone)
        end
    end)
end

-- Clear vehicles in the specified radius
function ClearVehiclesInRadius(coords, radius)
    local vehicles = GetGamePool("CVehicle")
    for _, vehicle in ipairs(vehicles) do
        if not IsPedAPlayer(GetPedInVehicleSeat(vehicle, -1)) then
            local vehCoords = GetEntityCoords(vehicle)
            if #(vehCoords - coords) <= radius then
                DeleteEntity(vehicle)
                LogDebug(string.format("Vehicle cleared at %.2f, %.2f, %.2f", vehCoords.x, vehCoords.y, vehCoords.z), 3)
            end
        end
    end
end
local despawnThreads = {}  -- To track active despawn threads for roads

function DespawnVehiclesOnClosedRoads()
    CreateThread(function()
        while true do
            for streetName, roadData in pairs(closedRoads) do
                if roadData.startPoint and roadData.endPoint then
                    LogDebug("Despawning vehicles on closed road: " .. streetName, 3)

                    -- If the road is still closed, proceed to despawn vehicles
                    if roadData.isClosed then
                        local stepCount = 30 -- Number of points along the road segment
                        local radius = 30.0 -- Radius to clear vehicles around each point

                        for i = 0, stepCount do
                            local t = i / stepCount
                            local currentPoint = LerpVector3(roadData.startPoint, roadData.endPoint, t)
                            ClearVehiclesInRadius(currentPoint, radius)
                        end
                    end
                end
            end
            Wait(5000) -- Check every 5 seconds
        end
    end)
end

DespawnVehiclesOnClosedRoads()

-- Close a road
-- Close a road
function CloseRoadAtCoords(coords)
    LogDebug("Attempting to close road at coords: " .. tostring(coords), 2)
    local streetHash, _ = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local streetName = GetStreetNameFromHashKey(streetHash)

    if not streetName or streetName == "" then
        SendNotification("error", "No valid road detected at your location.")
        LogDebug("Failed to find valid road at coords: " .. tostring(coords), 1)
        return
    end

    if closedRoads[streetName] then
        SendNotification("info", "Road '" .. streetName .. "' is already closed.")
        LogDebug("Road already closed: " .. streetName, 2)
        return
    end

    -- Find closest vehicle nodes for start and end of the road
    local nodeAFound, nodeA = GetClosestVehicleNodeWithHeading(coords.x, coords.y, coords.z, 1, 3.0, 0)
    local nodeBFound, nodeB = GetClosestVehicleNodeWithHeading(coords.x + 50, coords.y, coords.z, 1, 3.0, 0)

    if not nodeAFound or not nodeBFound then
        SendNotification("error", "Unable to determine road intersections.")
        LogDebug("Failed to find intersections for road: " .. streetName, 1)
        return
    end

    local startCoords = vector3(nodeA.x, nodeA.y, nodeA.z)
    local endCoords = vector3(nodeB.x, nodeB.y, nodeB.z)

    -- Create blips and block the road
    local startBlip, endBlip = CreateRoadClosureBlips(startCoords, endCoords)
    local closureKey = GenerateClosureKey(coords)
    closedRoads[streetName] = closedRoads[streetName] or {}
    closedRoads[streetName][closureKey] = {
        startCoords = startCoords,
        endCoords = endCoords,
        startBlip = startBlip,
        endBlip = endBlip,
    }

    BlockAIAndClearVehicles(startCoords, endCoords, closureKey)

    -- Create barriers at junctions
    CreateBarriersForRoad(streetName)

    SendNotification("success", "Road '" .. streetName .. "' has been closed.")
    LogDebug("Road successfully closed: " .. streetName, 2)
end



-- Command to close a road
RegisterCommand("closeroad", function(source, args)
    if args[1] and args[1]:lower() == "help" then
        -- Display usage instructions
        SendNotification("info", "Usage: /closeroad - To close the current road you are on from AI.")
        return
    end

    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)

    LogDebug(("Executing closeroad at coords: %s"):format(coords), 2)
    CloseRoadAtCoords(coords)
end, false)

-- Command to open a road
RegisterCommand("openroad", function(source, args)
    if args[1] and args[1]:lower() == "help" then
        -- Display usage instructions
        SendNotification("info", "Usage: /openroad [roadName]\nOptions:\n  roadName - The name of the road to reopen. Leave empty to open the closest closed road.")
        return
    end

    local streetName = args[1] or nil
    LogDebug("Executing openroad for: " .. (streetName or "closest road"), 2)
    OpenRoad(streetName)
end, false)


-- Add help information for openroad and openroads commands
TriggerEvent("chat:addSuggestion", "/openroad", "Reopen a specific road", {
    { name = "roadName", help = "The name of the road to reopen. Leave empty to open the closest closed road." }
})
TriggerEvent("chat:addSuggestion", "/openroads", "Reopen all closed roads")
TriggerEvent("chat:addSuggestion", "/closeroad", "Close a road near your current location", {
    { name = "save", help = "Optional: Save the road closure to the database" }
})