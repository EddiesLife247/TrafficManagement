-- Check if Player Has LEO Job
function PlayerHasLEOJob()
    local playerData = QBCore.Functions.GetPlayerData()
    for _, job in ipairs(Config.LEOJobs) do
        if playerData and playerData.job and playerData.job.name == job then
            LogDebug("Player is a LEO!", 3)
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
            LogDebug("Player is a Mechanic!", 3)
            return true
        end
    end
    return false
end

local currentRadius = Config.DefaultRadius

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
            if tcblip then
                SetBlipColour(tcblip, 1) -- Red color
                SetBlipAlpha(tcblip, 80) -- Semi-transparent
                LogDebug("Blip created successfully for stopped traffic at " .. coords.x .. ", " .. coords.y)
            else
                LogDebug("Failed to create blip for stopped traffic zone. Using fallback.", 1)
                tcblip = CreateFallbackBlip(coords, 1, currentRadius / 50.0)
            end
        else
            SetBlipCoords(tcblip, coords.x, coords.y, coords.z)
            SetBlipScale(tcblip, currentRadius / 50.0)
            LogDebug("Blip updated for stopped traffic zone.")
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
        if slowTrafficBlip then
            SetBlipColour(slowTrafficBlip, 5) -- Yellow color
            SetBlipAlpha(slowTrafficBlip, 128) -- Semi-transparent
            LogDebug("Blip created successfully for slow traffic at " .. coords.x .. ", " .. coords.y)
        else
            LogDebug("Failed to create blip for slow traffic zone. Using fallback.", 1)
            slowTrafficBlip = CreateFallbackBlip(coords, 5, currentRadius / 100.0)
        end
    else
        SetBlipCoords(slowTrafficBlip, coords.x, coords.y, coords.z)
        SetBlipScale(slowTrafficBlip, currentRadius / 100.0)
        LogDebug("Blip updated for slow traffic zone.")
    end
    if commandMode or signMode then
        LogDebug("Either commandMode or signMode is active. Skipping traffic reset.", 2)
        return
    end
    if CheckForActiveProps() then
        LogDebug("CheckForProps is true! Skipping traffic reset.", 2)
        return
    end
    if not CheckForActiveProps() then
        ResetTraffic()
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
                LogDebug("Slow traffic zone and blip updated to follow the vehicle.", 2)
            else
-- Check if commandMode or signMode is active
if commandMode or signMode then
    LogDebug("Either commandMode or signMode is active. Skipping traffic reset.")
    return
end

-- Reset traffic if not already resumed
if trafficState ~= "resumed" then
    ResetTraffic()
    LogDebug("Traffic state reset due to mode change or vehicle no longer moving.")
end
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
    -- Prevent starting a timer if lights were toggled off and back on
    if lightsLastState then
        LogDebug("Cannot start traffic timer. Lights need to be toggled off and back on.")
        return
    end

    -- Cancel any existing timer for the given state
    if trafficTimers[state] then
        CancelTrafficTimer(state)
    end

    -- Initialize the timer
    trafficTimers[state] = GetGameTimer()
    local originalDuration = maxTime * 60000 -- Convert minutes to milliseconds
    local remainingDuration = originalDuration

    CreateThread(function()
        while remainingDuration > 0 do
            Wait(1000) -- Check every second
            local ped = GetPlayerPed(-1)
            local vehicle = GetVehiclePedIsIn(ped, false)

            -- Extend the timer if props or commands are active
            if CheckForActiveProps() or commandMode then
                LogDebug("Props or commands detected. Resetting timer duration.")
                trafficTimers[state] = GetGameTimer() -- Reset the timer
                remainingDuration = originalDuration
                goto continue -- Skip the rest of the loop for this iteration
            end

            -- Check if lights are off to end the timer
            if not lightMode then
                ResetTraffic()
                LogDebug("Emergency lights turned off. Traffic state '" .. state .. "' ended.", 1)
                return
            end

            -- Dynamically adjust the timer if the player exits the vehicle
            if vehicle == 0 and remainingDuration > Config.MaxStopSlowTimeOutOfCar * 60000 then
                remainingDuration = Config.MaxStopSlowTimeOutOfCar * 60000
                LogDebug("Adjusted remaining duration for out-of-car timeout: " .. remainingDuration / 60000 .. " minutes.", 2)
            end

            -- Update the remaining duration
            remainingDuration = originalDuration - (GetGameTimer() - trafficTimers[state])

            ::continue::
        end

        -- Timeout reached, reset traffic
        if trafficState == state then
            ResetTraffic()
            lightsLastState = true -- Mark lights as requiring a toggle
            LogDebug("Traffic state '" .. state .. "' timed out after " .. maxTime .. " minutes.", 1)
        end
    end)
end


-- Check for active props
function CheckForActiveProps()
    local ped = GetPlayerPed(-1)
    local coords = GetEntityCoords(ped)

    local roadClosed = false
    local policeSlow = false

    if Config.UseRoadClosedProp then
        roadClosed = DoesEntityExist(GetClosestObjectOfType(coords, 100.0, Config.RoadClosedProp, false, false, false))
    end

    if Config.UsePoliceSlowProp then
        policeSlow = DoesEntityExist(GetClosestObjectOfType(coords, 100.0, Config.PoliceSlowProp, false, false, false))
    end

    return roadClosed or policeSlow
end


function CancelTrafficTimer(state)
    trafficTimers[state] = nil
end

-- Function to increase radius
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
        SendNotification("error", "Cannot adjust radius. No active stop or slow zone.", 1)
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
        if trafficState == "stopped" then
            if tcblip ~= nil then
                RemoveBlip(tcblip)
            end
            tcblip = AddBlipForRadius(coords.x, coords.y, coords.z, currentRadius)
            SetBlipColour(tcblip, 1) -- Red color
            SetBlipAlpha(tcblip, 80) -- Semi-transparent
        end

        -- Update the blip for slowed traffic
        if trafficState == "slowed" then
            if slowTrafficBlip ~= nil then
                RemoveBlip(slowTrafficBlip)
            end
            slowTrafficBlip = AddBlipForRadius(coords.x, coords.y, coords.z, currentRadius)
            SetBlipColour(slowTrafficBlip, 5) -- Yellow color
            SetBlipAlpha(slowTrafficBlip, 128) -- Semi-transparent
        end

        -- Debug log to confirm the update
        LogDebug("Traffic zone radius updated to " .. currentRadius .. " meters. Blip updated visually.")
    else
        LogDebug("Cannot update radius. No active traffic zone.", 1)
    end
end

-- Register keybindings
RegisterCommand("increaseRadius", function()
    if trafficState == "stopped" or trafficState == "slowed" then

    IncreaseTrafficRadius()
    end
end, false)

RegisterCommand("decreaseRadius", function()
    if trafficState == "stopped" or trafficState == "slowed" then

    DecreaseTrafficRadius()
    end
end, false)

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
                LogDebug("Traffic stopped for emergency vehicle at or below " .. Config.LightStopSpeed .. " MPH.", 1)
                lightMode = true
            end
        elseif Config.EnableRollingRoadBlock and speed > Config.LightStopSpeed and speed <= Config.RollingRoadBlockSpeed then
            if trafficState ~= "slowed" then
                ResetTraffic()
                slowTraffic()
                StartTrafficTimer("slowed", Config.MaxStopSlowTime)
                LogDebug("Traffic slowed for emergency vehicle moving between " .. Config.LightStopSpeed .. " and " .. Config.RollingRoadBlockSpeed .. " MPH.", 1)
                lightMode = true
            end
        elseif speed > Config.RollingRoadBlockSpeed then
            if trafficState ~= "resumed" then
                ResetTraffic()
                LogDebug("Traffic resumed as emergency vehicle exceeded " .. Config.RollingRoadBlockSpeed .. " MPH.", 1)
                lightMode = false
            end
        end
    else
        -- Keep traffic stopped/slowed if lights are on, even when out of vehicle
        if trafficState == "stopped" or trafficState == "slowed" then
            if lightMode and not IsPedInAnyVehicle(ped, true) then
                LogDebug("Player out of vehicle but emergency lights are on. Keeping traffic stopped/slowed.", 2)
                return -- Prevent resuming traffic
            end
        end

        -- Reset traffic if lights are turned off
        if trafficState ~= "resumed" and lightMode == true then
            if not signMode or not commandMode then
            ResetTraffic()
            LogDebug("Traffic resumed as emergency siren was turned off.", 1)
            lightMode = false
            lightsLastState = true -- Require toggling lights to restart
            end
        end
    end
end
local roadClosedProcessed = false
local policeSlowProcessed = false
local detectedProps = {} -- Cache detected props
local debounceTimer = nil
local debounceDuration = 3000 -- Time in milliseconds to wait before resetting

function CheckForProps()
    if commandMode then
        return
    end -- Disable prop check during commands.

    local ped = GetPlayerPed(-1)
    local coords = GetEntityCoords(ped)

    -- Reset detectedProps table for new checks
    detectedProps = {}

    -- Check for road-closed props
    if Config.UseRoadClosedProp and PlayerHasLEOJob() then
        local roadClosed = GetClosestObjectOfType(coords, 100.0, Config.RoadClosedProp, false, false, false)
        if DoesEntityExist(roadClosed) then
            table.insert(detectedProps, roadClosed)
            if not roadClosedProcessed then
                stopTraffic()
                roadClosedProcessed = true
                LogDebug("Road closed prop detected and processed.", 1)
            end
        else
            if roadClosedProcessed then
                roadClosedProcessed = false
                LogDebug("Road closed prop removed.", 1)
            end
        end
    end

    -- Check for police-slow props
    if Config.UsePoliceSlowProp and (PlayerHasLEOJob() or PlayerHasMechanicJob()) then
        local policeSlow = GetClosestObjectOfType(coords, 100.0, Config.PoliceSlowProp, false, false, false)
        if DoesEntityExist(policeSlow) then
            table.insert(detectedProps, policeSlow)
            if not policeSlowProcessed then
                slowTraffic()
                policeSlowProcessed = true
                LogDebug("Police slow prop detected and processed.", 1)
            end
        else
            if policeSlowProcessed then
                policeSlowProcessed = false
                LogDebug("Police slow prop removed.", 1)
            end
        end
    end

    -- Handle case where no props are detected
    if #detectedProps == 0 and not debounceTimer then
        debounceTimer = GetGameTimer() + debounceDuration
        LogDebug("Debounce timer started.", 2)
    elseif debounceTimer and GetGameTimer() > debounceTimer then
        ResetTraffic()
        signMode = false
        debounceTimer = nil
        LogDebug("Debounce timer expired. Traffic reset.", 2)
    elseif #detectedProps > 0 then
        debounceTimer = nil -- Cancel debounce if props are detected
        LogDebug("Debounce timer canceled as props were detected.", 2)
    end
    
end

