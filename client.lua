local QBCore = exports['qb-core']:GetCoreObject()
local sz = nil
local manualOverride = false
local trafficState = "resumed" -- Possible values: "resumed", "slowed", "stopped"

local signMode = false
local commandMode = false
local lightMode = false


-- PARAMETERS --
local SEARCH_STEP_SIZE = 10.0          -- Step size to search for traffic lights
local SEARCH_MIN_DISTANCE = 20.0       -- Minimum distance to search for traffic lights
local SEARCH_MAX_DISTANCE = 60.0       -- Maximum distance to search for traffic lights
local SEARCH_RADIUS = 10.0             -- Radius to search for traffic light after translating coordinates
local HEADING_THRESHOLD = 20.0         -- Player must match traffic light orientation within threshold (degrees)
local TRAFFIC_LIGHT_DURATION_MS = 5000 -- Duration to turn light green (ms)

-- Array of all traffic light hashes
local trafficLightObjects = {
    [0] = 0x3e2b73a4, -- prop_traffic_01a
    [1] = 0x336e5e2a, -- prop_traffic_01b
    [2] = 0xd8eba922, -- prop_traffic_01d
    [3] = 0xd4729f50, -- prop_traffic_02a
    [4] = 0x272244b2, -- prop_traffic_02b
    [5] = 0x33986eae, -- prop_traffic_03a
    [6] = 0x2323cdc5  -- prop_traffic_03b
}

-- Function to handle traffic reset after timer expiration
function HandleTrafficTimeout()
    if trafficState ~= "resumed" then
        ResetTraffic()
        lightMode = false
        RemoveBlip(tcblip)
        exitTimer = nil -- Reset the timer
        LogDebug("Traffic management reset after 10 minutes of inactivity.")
        SendNotification("info", "Traffic management reset due to inactivity.")
    end
end

-- Function to set traffic light green, wait, and reset state
function SetTrafficLightGreen(coords)
    for _, trafficLightObject in pairs(trafficLightObjects) do
        local trafficLight = GetClosestObjectOfType(coords, 1.0, trafficLightObject, false, false, false)
        if trafficLight ~= 0 then
            -- Set traffic light green, delay, and reset state
            SetEntityTrafficlightOverride(trafficLight, 0)  -- Green light
            Citizen.Wait(TRAFFIC_LIGHT_DURATION_MS)
            SetEntityTrafficlightOverride(trafficLight, -1) -- Reset to default
            break
        end
    end
end

-- Translate vector3 using 2D polar notation (ignoring z-axis)
function translateVector3(pos, angle, distance)
    local angleRad = angle * 2.0 * math.pi / 360.0
    return vector3(pos.x - distance * math.sin(angleRad), pos.y + distance * math.cos(angleRad), pos.z)
end

-- Integrated traffic light detection and control
function HandleTrafficLights()
    local ped = GetPlayerPed(-1)
    if IsPedInAnyVehicle(ped) and IsVehicleStopped(GetVehiclePedIsIn(ped)) then
        local playerPosition = GetEntityCoords(ped)
        local playerHeading = GetEntityHeading(ped)

        local trafficLight = 0
        for searchDistance = SEARCH_MAX_DISTANCE, SEARCH_MIN_DISTANCE, -SEARCH_STEP_SIZE do
            local searchPosition = translateVector3(playerPosition, playerHeading, searchDistance)
            for _, trafficLightObject in pairs(trafficLightObjects) do
                trafficLight = GetClosestObjectOfType(searchPosition, SEARCH_RADIUS, trafficLightObject, false, false,
                    false)
                if trafficLight ~= 0 then
                    local lightHeading = GetEntityHeading(trafficLight)
                    local headingDiff = math.abs(playerHeading - lightHeading)
                    if ((headingDiff < HEADING_THRESHOLD) or (headingDiff > (360.0 - HEADING_THRESHOLD))) then
                        break
                    else
                        trafficLight = 0
                    end
                end
            end
            if trafficLight ~= 0 then break end
        end

        if trafficLight ~= 0 then
            SetTrafficLightGreen(GetEntityCoords(trafficLight, false))
        end
    end
end

-- Debugging Function
function LogDebug(message)
    if Config.Debug then
        print("[DEBUG] " .. message)
    end
end

-- Notification Function
function SendNotification(type, text)
    if exports['ox_lib'] then
        exports['ox_lib']:notify({
            type = type,
            description = text,
            duration = 5000
        })
    else
        LogDebug("[Notification] " .. text)
    end
end

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

-- Function to Remove Speed Zone and Reset State
function ResetTraffic()
    if sz ~= nil then
        RemoveSpeedZone(sz)
        sz = nil
    end
    TriggerServerEvent("traffic:controlLights", "green")
    SendNotification("success", "Traffic resumed.")
    trafficState = "resumed"
    manualOverride = false
    RemoveBlip(tcblip)
end

function slowTraffic()
    -- Slow traffic
    if sz ~= nil then RemoveSpeedZone(sz) end
    sz = AddSpeedZoneForCoord(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z, 40.0, 5.0, false)
    TriggerServerEvent("traffic:controlLights", "yellow")
    SendNotification("info", "Traffic has been slowed down.")
    trafficState = "slowed"
    tcblip = AddBlipForRadius(GetEntityCoords(GetPlayerPed(-1)), 40.0)
    SetBlipAlpha(tcblip, 80)
    SetBlipColour(tcblip, 5)
    sz = AddSpeedZoneForCoord(GetEntityCoords(GetPlayerPed(-1)), 40.0, 5.0, false)
end

function stopTraffic()
    if sz ~= nil then RemoveSpeedZone(sz) end
    sz = AddSpeedZoneForCoord(GetEntityCoords(ped).x, GetEntityCoords(ped).y, GetEntityCoords(ped).z, 50.0, 0.0, false)
    TriggerServerEvent("traffic:controlLights", "red")
    SendNotification("info", "Traffic has been stopped.")
    trafficState = "stopped"
    tcblip = AddBlipForRadius(GetEntityCoords(GetPlayerPed(-1)), 50.0)
    sz = AddSpeedZoneForCoord(GetEntityCoords(GetPlayerPed(-1)), 50.0, 0.0, false)
    SetBlipAlpha(tcblip, 80)
    SetBlipColour(tcblip, 1)
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

-- Store the last known blip position
local lastBlipCoords = nil

-- Store officer blip data locally
local officerBlips = {}

-- Define UpdateOfficerBlip function
function UpdateOfficerBlip(coords, state, name, job)
    -- Ensure officerBlips table exists
    officerBlips = officerBlips or {}

    local src = GetPlayerServerId(NetworkGetEntityOwner(GetPlayerPed(-1)))

    if state == "remove" then
        if officerBlips[src] then
            RemoveBlip(officerBlips[src])
            officerBlips[src] = nil
        end
    else
        -- Create or update the blip
        if not officerBlips[src] then
            officerBlips[src] = AddBlipForCoord(coords.x, coords.y, coords.z)
            SetBlipScale(officerBlips[src], 0.8)          -- Smaller blip size
            SetBlipAsShortRange(officerBlips[src], false) -- Visible to all players with LEO jobs
        else
            -- Update the blip position without recreating it
            SetBlipCoords(officerBlips[src], coords.x, coords.y, coords.z)
        end

        -- Update the blip sprite and color based on the state
        if state == "lights" then
            SetBlipSprite(officerBlips[src], 3)   -- radar_police_ped
            SetBlipColour(officerBlips[src], 3)   -- Blue
        elseif state == "vehicle" then
            SetBlipSprite(officerBlips[src], 326) -- radar_getaway_car
            SetBlipColour(officerBlips[src], 5)   -- Yellow
        elseif state == "foot" then
            SetBlipSprite(officerBlips[src], 6)   -- radar_centre
            SetBlipColour(officerBlips[src], 1)   -- Red
        else
            SetBlipSprite(officerBlips[src], 6)   -- Default to radar_centre
            SetBlipColour(officerBlips[src], 0)   -- Default color
        end

        -- Set blip name to character name and job
        BeginTextCommandSetBlipName("STRING")
        AddTextComponentString(name .. " (" .. job .. ")")
        EndTextCommandSetBlipName(officerBlips[src])
    end
end

-- Register the Net Event AFTER defining the function
RegisterNetEvent("traffic:updateOfficerBlip")
AddEventHandler("traffic:updateOfficerBlip", function(coords, state, name, job)
    UpdateOfficerBlip(coords, state, name, job)
end)

-- Function to remove the officer's blip
function RemoveOfficerBlip()
    if blip ~= nil then
        RemoveBlip(blip)
        blip = nil
    end
end

-- Function to check and update officer state
function CheckOfficerState()
    local ped = GetPlayerPed(-1)
    local vehicle = GetVehiclePedIsIn(ped, false)
    local coords = GetEntityCoords(ped)
    local playerData = QBCore.Functions.GetPlayerData()

    if PlayerHasLEOJob() then
        local charName = playerData.charinfo.firstname .. " " .. playerData.charinfo.lastname
        local jobName = playerData.job.label

        if vehicle ~= 0 then
            local sirensOn = IsVehicleSirenOn(vehicle)

            if sirensOn then
                TriggerServerEvent("traffic:updateOfficerState", coords, "lights", charName, jobName)
            else
                TriggerServerEvent("traffic:updateOfficerState", coords, "vehicle", charName, jobName)
            end
        else
            TriggerServerEvent("traffic:updateOfficerState", coords, "foot", charName, jobName)
        end
    else
        TriggerServerEvent("traffic:updateOfficerState", coords, "remove", "", "")
    end
end

local forceNormalTraffic = false

-- Function to toggle forced normal traffic state
function ToggleForceNormalTraffic()
    forceNormalTraffic = not forceNormalTraffic
    if forceNormalTraffic then
        ResetTraffic()     -- Reset all traffic-related states
        RemoveBlip(tcblip) -- Remove any existing blips
        SendNotification("success", "Forced normal traffic mode enabled. All traffic controls are disabled.")
    else
        SendNotification("info", "Forced normal traffic mode disabled. Traffic controls are re-enabled.")
    end
end

-- Commands
if Config.Commands.EnableSlowTraffic then
    RegisterCommand(Config.Commands.SlowTraffic, function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            manualOverride = true
            if sz ~= nil then
                ResetTraffic()
                RemoveBlip(tcblip)
                commandMode = false
            else
                slowTraffic()
                commandMode = true
            end
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    RegisterCommand("slt", function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            manualOverride = true
            if sz ~= nil then
                ResetTraffic()
                RemoveBlip(tcblip)
                commandMode = false
            else
                slowTraffic()
                commandMode = true
            end
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    TriggerEvent('chat:addSuggestion', '/slt', 'Slow AI Traffic in local area', {})
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.SlowTraffic, 'Slow AI Traffic in local area', {})
end

if Config.Commands.EnableStopTraffic then
    RegisterCommand(Config.Commands.StopTraffic, function()
        if PlayerHasLEOJob() then
            manualOverride = true
            if sz ~= nil then
                ResetTraffic()
                RemoveBlip(tcblip)
                commandMode = false
            else
                stopTraffic()
                commandMode = true
            end
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    RegisterCommand("stt", function()
        if PlayerHasLEOJob() then
            manualOverride = true
            if sz ~= nil then
                ResetTraffic()
                RemoveBlip(tcblip)
                commandMode = false
            else
                stopTraffic()
                commandMode = true
            end
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    -- Add help text for the command
    TriggerEvent('chat:addSuggestion', '/stt', 'Stop AI Traffic in local area', {})
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.StopTraffic, 'Stop AI Traffic in local area', {})
end


if Config.Commands.EnableResumeTraffic then
    RegisterCommand(Config.Commands.ResumeTraffic, function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            manualOverride = true
            if sz ~= nil then
                ResetTraffic()
                RemoveBlip(tcblip)
                commandMode = false
            else
                SendNotification("info", "No active traffic zones to resume.")
            end
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    RegisterCommand("rt", function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            manualOverride = true
            if sz ~= nil then
                ResetTraffic()
                RemoveBlip(tcblip)
                commandMode = false
            else
                SendNotification("info", "No active traffic zones to resume.")
            end
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    TriggerEvent('chat:addSuggestion', '/rtt', 'Resumes Normal Traffic in local area',
        {})
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.ResumeTraffic,
        'Force AI Traffic to return to normal, even if lights/props are placed', {})
end
if Config.Commands.EnableForceTraffic then
    RegisterCommand("fnt", function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            ToggleForceNormalTraffic()
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)


    -- Register the /forcenormaltraffic command
    RegisterCommand(Config.Commands.ForceNormalTraffic, function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            ToggleForceNormalTraffic()
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    TriggerEvent('chat:addSuggestion', '/fnt', 'Force AI Traffic to return to normal, even if lights/props are placed',
        {})
    TriggerEvent('chat:addSuggestion', '/' .. Config.Commands.ForceNormalTraffic,
        'Force AI Traffic to return to normal, even if lights/props are placed', {})
end

-- Update the main monitoring thread to respect forced normal traffic state
CreateThread(function()
    local exitTimer = nil                  -- Timer for tracking time since exiting vehicle
    local maxExitDuration = 10 * 60 * 1000 -- 10 minutes in milliseconds

    while true do
        Wait(1000) -- Check every second
        if not forceNormalTraffic then
            local ped = GetPlayerPed(-1)
            local vehicle = GetVehiclePedIsIn(ped, false)

            if not commandMode then
                if not lightMode then
                    CheckForProps()
                    LogDebug("Checking for props, signs, lights")
                end

                if not signMode then
                    LogDebug("Checking for lights and speed")

                    if vehicle ~= 0 then -- Player is in a vehicle
                        local speed = GetEntitySpeed(vehicle)
                        local sirensOn = IsVehicleSirenOn(vehicle)

                        if Config.EnableStopOnLights then
                            if sirensOn then
                                LogDebug("Light's Sirens on!")
                            end

                            if PlayerHasLEOJob() and not manualOverride then
                                LogDebug("Person is LEO.. Checking for lights/sirens")

                                if sirensOn and speed < 5 then
                                    if Config.StopOrSlow == "stop" and trafficState ~= "stopped" then
                                        stopTraffic()
                                        lightMode = true
                                    elseif Config.StopOrSlow == "slow" and trafficState ~= "slowed" then
                                        slowTraffic()
                                        lightMode = true
                                    end
                                elseif not sirensOn or speed > 5 then
                                    LogDebug("Person is LEO.. No Lights/Sirens.. Resuming")

                                    if trafficState ~= "resumed" then
                                        ResetTraffic()
                                        lightMode = false
                                        RemoveBlip(tcblip)
                                    end
                                    if Config.TurnTrafficLightsGreen then
                                        TriggerServerEvent("traffic:controlLights", "green")
                                    end
                                else
                                    slowTraffic()
                                    lightMode = true
                                end
                            elseif PlayerHasMechanicJob() and not manualOverride then
                                LogDebug("Person is MECHANIC Checking for lights on.")

                                if sirensOn then
                                    LogDebug("Person is MECHANIC Lights on")

                                    if Config.StopOrSlow == "slow" and trafficState ~= "slowed" then
                                        slowTraffic()
                                        lightMode = true
                                    end
                                elseif not sirensOn or speed > 0.5 then
                                    if trafficState ~= "resumed" then
                                        ResetTraffic()
                                        lightMode = false
                                    end
                                end
                            end
                        end

                        -- Reset exit timer if player re-enters the vehicle
                        if exitTimer then
                            exitTimer = nil
                            LogDebug("Player re-entered vehicle, resetting traffic timer.")
                        end
                    else -- Player is out of a vehicle
                        if trafficState ~= "resumed" then
                            if not exitTimer then
                                exitTimer = GetGameTimer()
                                LogDebug("Player exited vehicle, starting traffic timer.")
                            elseif GetGameTimer() - exitTimer >= maxExitDuration then
                                -- Timer exceeds the limit; reset traffic
                                ResetTraffic()
                                lightMode = false
                                RemoveBlip(tcblip)
                                exitTimer = nil
                                LogDebug("Traffic management reset after 10 minutes of inactivity.")
                                SendNotification("info", "Traffic management reset due to inactivity.")
                            end
                        end
                    end
                else
                    LogDebug("Sign Mode Enabled, Cannot check for Lights")
                end
            else
                LogDebug("Command Mode Enabled, Cannot check for Props/Signs")
            end
        else
            LogDebug("Forced normal traffic mode active. Skipping all checks.")
        end
    end
end)
-- Monitor officer state changes
CreateThread(function()
    while true do
        Wait(500) -- Check every half second
        CheckOfficerState()
    end
end)

-- Listen for updates from the server
RegisterNetEvent("traffic:updateOfficerBlip")
AddEventHandler("traffic:updateOfficerBlip", function(coords, state, name, job)
    if PlayerHasLEOJob() then
        if state == "remove" then
            RemoveOfficerBlip()
        else
            UpdateOfficerBlip(coords, state, name, job)
        end
    else
        RemoveOfficerBlip()
    end
end)
AddSpeedZoneForCoord(236.2, 6565.1, 31.5, 40.0, 20.0, false)
AddSpeedZoneForCoord(161.2, 6544.5, 31.8, 40.0, 10.0, false)
