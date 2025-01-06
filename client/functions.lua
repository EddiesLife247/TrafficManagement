
-- Check if Player Has LEO Job
function PlayerHasLEOJob()
    local playerData = QBCore.Functions.GetPlayerData()
    for _, job in ipairs(Config.LEOJobs) do
        if playerData and playerData.job and playerData.job.name == job then
            LogDebug("Player is a LEO!")
            return true
        end
    end
    return false
end

-- Check if Player Has Mechanic Job
function PlayerHasMechanicJob()
    local playerData = QBCore.Functions.GetPlayerData()
    for _, job in ipairs(Config.MechanicJobs) do
        if playerData and playerData.job and playerData.job.name == job then
            LogDebug("Player is a Mechanic!")
            return true
        end
    end
    return false
end

function stopTraffic()
    if trafficState == "stopped" then
        ResetTraffic()
    else
        if sz ~= nil then RemoveSpeedZone(sz) end
        local ped = GetPlayerPed(-1)
        local coords = GetEntityCoords(ped)

        sz = AddSpeedZoneForCoord(coords.x, coords.y, coords.z, currentRadius, 0.0, false)
        TriggerServerEvent("traffic:controlLights", "red")
        SendNotification("info", "Traffic has been stopped.")
        trafficState = "stopped"

        -- Create or update the blip
        if tcblip == nil then
            tcblip = AddBlipForRadius(coords.x, coords.y, coords.z, currentRadius)
            SetBlipColour(tcblip, 1) -- Red color
            SetBlipAlpha(tcblip, 80) -- Semi-transparent
        else
            SetBlipCoords(tcblip, coords.x, coords.y, coords.z)
            SetBlipScale(tcblip, currentRadius / 50.0)
        end
    end
    StartTrafficTimer("stopped", Config.MaxStopSlowTime)
end

function slowTraffic()
    if sz ~= nil then
        RemoveSpeedZone(sz)
    end

    local ped = GetPlayerPed(-1)
    local coords = GetEntityCoords(ped)

    sz = AddSpeedZoneForCoord(coords.x, coords.y, coords.z, currentRadius, 10.0, false)
    LogDebug("Slow traffic zone created at current position.")
    SendNotification("info", "Traffic has been slowed down.")
    trafficState = "slowed"

    -- Create or update the blip
    if slowTrafficBlip == nil then
        slowTrafficBlip = AddBlipForRadius(coords.x, coords.y, coords.z, currentRadius)
        SetBlipColour(slowTrafficBlip, 5) -- Yellow color
        SetBlipAlpha(slowTrafficBlip, 128) -- Semi-transparent
    else
        SetBlipCoords(slowTrafficBlip, coords.x, coords.y, coords.z)
        SetBlipScale(slowTrafficBlip, currentRadius / 100.0)
    end

    -- Update the blip dynamically as the vehicle moves
    CreateThread(function()
        while trafficState == "slowed" do
            local ped = GetPlayerPed(-1)
            local vehicle = GetVehiclePedIsIn(ped, false)

            if vehicle ~= 0 then
                local newCoords = GetEntityCoords(ped)
                RemoveSpeedZone(sz)
                sz = AddSpeedZoneForCoord(newCoords.x, newCoords.y, newCoords.z, currentRadius, 10.0, false)
                SetBlipCoords(slowTrafficBlip, newCoords.x, newCoords.y, newCoords.z)
                SetBlipScale(slowTrafficBlip, currentRadius / 100.0)
                LogDebug("Slow traffic zone and blip updated to follow the vehicle.")
            else
                ResetTraffic()
                stopTraffic()
                LogDebug("Vehicle no longer moving, stopping slow zone updates.")
                break
            end
            Wait(1000)
        end
    end)
end



-- Function to resume normal traffic
function ResetTraffic()

    if sz ~= nil then
        RemoveSpeedZone(sz) -- Remove any active speed zones
        sz = nil
    end

    if tcblip ~= nil then
        RemoveBlip(tcblip) -- Remove the blip for the traffic zone
        tcblip = nil
    end

    if slowTrafficBlip ~= nil then
        RemoveBlip(slowTrafficBlip) -- Remove the yellow blip for slow traffic
        slowTrafficBlip = nil
    end
    if trafficState == "resumed" then
        return
    end
    TriggerServerEvent("traffic:controlLights", "green") -- Trigger server event for green light
    SendNotification("success", "Traffic has been resumed.")
    trafficState = "resumed"
end


local trafficTimers = {}
local lightsLastState = false -- Tracks the last known state of the emergency lights

function StartTrafficTimer(state, maxTime)
    -- Only allow the timer to start if lights were toggled off and back on
    if lightsLastState then
        LogDebug("Cannot start traffic timer. Lights need to be toggled off and back on.")
        return
    end

    if trafficTimers[state] then
        CancelTrafficTimer(state)
    end

    trafficTimers[state] = GetGameTimer()

    CreateThread(function()
        local duration = maxTime * 60000 -- Convert minutes to milliseconds
        while GetGameTimer() - trafficTimers[state] < duration do
            Wait(1000) -- Check every second
            local ped = GetPlayerPed(-1)
            local vehicle = GetVehiclePedIsIn(ped, false)

            -- Check if lights are off to end the timer
            if not lightMode then
                ResetTraffic()
                LogDebug("Emergency lights turned off. Traffic state '" .. state .. "' ended.")
                return
            end

            -- Adjust duration for out-of-car timeout
            if vehicle == 0 then
                duration = math.min(duration, Config.MaxStopSlowTimeOutOfCar * 60000)
            end
        end

        -- Time out and reset traffic
        if trafficState == state then
            ResetTraffic()
            lightsLastState = true -- Mark lights as requiring a toggle
            LogDebug("Traffic state '" .. state .. "' timed out after " .. maxTime .. " minutes.")
        end
    end)
end

function CancelTrafficTimer(state)
    trafficTimers[state] = nil
end

local currentRadius = 50.0 -- Default radius

-- Function to increase radius
function IncreaseTrafficRadius()
    if trafficState == "stopped" or trafficState == "slowed" then
        if currentRadius + Config.RadiusStep <= Config.MaxTrafficRadius then
            currentRadius = currentRadius + Config.RadiusStep
            UpdateTrafficZoneRadius()
            SendNotification("success", "Traffic radius increased to " .. currentRadius .. " meters.")
        else
            SendNotification("error", "Maximum traffic radius reached.")
        end
    else
        SendNotification("error", "Cannot adjust radius. No active stop or slow zone.")
    end
end

-- Function to decrease radius
function DecreaseTrafficRadius()
    if trafficState == "stopped" or trafficState == "slowed" then
        if currentRadius - Config.RadiusStep >= Config.MinTrafficRadius then
            currentRadius = currentRadius - Config.RadiusStep
            UpdateTrafficZoneRadius()
            SendNotification("success", "Traffic radius decreased to " .. currentRadius .. " meters.")
        else
            SendNotification("error", "Minimum traffic radius reached.")
        end
    else
        SendNotification("error", "Cannot adjust radius. No active stop or slow zone.")
    end
end

-- Function to update traffic zone radius
function UpdateTrafficZoneRadius()
    if trafficState == "stopped" or trafficState == "slowed" then
        local ped = GetPlayerPed(-1)
        local coords = GetEntityCoords(ped)

        -- Remove the existing speed zone if any
        if sz ~= nil then
            RemoveSpeedZone(sz)
        end

        -- Set the speed limit based on the current traffic state
        local speedLimit = (trafficState == "stopped") and 0.0 or 10.0
        sz = AddSpeedZoneForCoord(coords.x, coords.y, coords.z, currentRadius, speedLimit, false)

        -- Update the blip for stopped traffic
        if trafficState == "stopped" and tcblip ~= nil then
            SetBlipCoords(tcblip, coords.x, coords.y, coords.z) -- Update blip position
            SetBlipScale(tcblip, currentRadius / 50.0) -- Adjust blip scale based on radius
        end

        -- Update the blip for slowed traffic
        if trafficState == "slowed" and slowTrafficBlip ~= nil then
            SetBlipCoords(slowTrafficBlip, coords.x, coords.y, coords.z) -- Update blip position
            SetBlipScale(slowTrafficBlip, currentRadius / 100.0) -- Adjust blip scale based on radius
        end

        -- Debug log to confirm the update
        LogDebug("Traffic zone radius updated to " .. currentRadius .. " meters. Blip updated visually.")
    else
        LogDebug("Cannot update radius. No active traffic zone.")
    end
end

-- Register keybindings
RegisterCommand("increaseRadius", function()
    IncreaseTrafficRadius()
end, false)

RegisterCommand("decreaseRadius", function()
    DecreaseTrafficRadius()
end, false)

-- Map the commands to keybinds
RegisterKeyMapping("increaseRadius", "Increase Traffic Radius", "keyboard", "PAGEUP")
RegisterKeyMapping("decreaseRadius", "Decrease Traffic Radius", "keyboard", "PAGEDOWN")


function HandleEmergencyTraffic()
    if not Config.EnableStopOnLights then return end

    local ped = GetPlayerPed(-1)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local isEmergency = IsVehicleSirenOn(vehicle) and PlayerHasLEOJob()
    local speed = GetEntitySpeed(vehicle) * 2.23694 -- Convert from m/s to MPH

    if isEmergency then
        -- Reset the light state tracker if lights are toggled back on
        if lightsLastState then
            lightsLastState = false
        end

        if speed <= 2 then
            if trafficState ~= "stopped" then
                ResetTraffic()
                stopTraffic()
                StartTrafficTimer("stopped", Config.MaxStopSlowTime)
                LogDebug("Traffic stopped for emergency vehicle at or below " .. Config.LightStopSpeed .. " MPH.")
                lightMode = true
            end
        elseif Config.EnableRollingRoadBlock and speed > Config.LightStopSpeed and speed <= Config.RollingRoadBlockSpeed then
            if trafficState ~= "slowed" then
                ResetTraffic()
                slowTraffic()
                StartTrafficTimer("slowed", Config.MaxStopSlowTime)
                LogDebug("Traffic slowed for emergency vehicle moving between " .. Config.LightStopSpeed .. " and " .. Config.RollingRoadBlockSpeed .. " MPH.")
                lightMode = true
            end
        elseif speed > Config.RollingRoadBlockSpeed then
            if trafficState ~= "resumed" then
                ResetTraffic()
                LogDebug("Traffic resumed as emergency vehicle exceeded " .. Config.RollingRoadBlockSpeed .. " MPH.")
                lightMode = false
            end
        end
    else
        -- Keep traffic stopped/slowed if lights are on, even when out of vehicle
        if trafficState == "stopped" or trafficState == "slowed" then
            if lightMode and not IsPedInAnyVehicle(ped, true) then
                LogDebug("Player out of vehicle but emergency lights are on. Keeping traffic stopped/slowed.")
                return -- Prevent resuming traffic
            end
        end

        -- Reset traffic if lights are turned off
        if trafficState ~= "resumed" then
            ResetTraffic()
            LogDebug("Traffic resumed as emergency siren was turned off.")
            lightMode = false
            lightsLastState = true -- Require toggling lights to restart
        end
    end
end

-- Monitor Props and Apply Traffic Control
function CheckForProps()
    if commandMode then
        return
    end -- disable prop check during commands.
    local ped = GetPlayerPed(-1)
    local coords = GetEntityCoords(ped)

    if Config.UseRoadClosedProp then
        local roadClosed = GetClosestObjectOfType(coords, 100.0, Config.RoadClosedProp, false, false, false)
        if DoesEntityExist(roadClosed) then
            if sz == nil then
                stopTraffic()
                signMode = true
            end
            return
        end
    end

    if Config.UsePoliceSlowProp then
        local policeSlow = GetClosestObjectOfType(coords, 100.0, Config.PoliceSlowProp, false, false, false)
        if DoesEntityExist(policeSlow) then
            if sz == nil then
                slowTraffic()
                signMode = true
            end
            return
        end
    end

    if sz ~= nil then
        if signMode == true and not commandMode then
            ResetTraffic() -- Reset the traffic as no props found nearby.. and we are in sign mode.
            RemoveBlip(tcblip)
            signMode = false
        end
    end
end