QBCore = exports['qb-core']:GetCoreObject()
sz = nil
manualOverride = false
trafficState = "resumed" -- Possible values: "resumed", "slowed", "stopped"

signMode = false
commandMode = false
lightMode = false
activeSpeedZone = nil -- To store the active speed zone for cleanup
slowTrafficBlip = nil -- Store the yellow blip for the slow traffic state


-- Traffic Density and Speed Adjustment Thread
CreateThread(function()
    if not Config.TrafficDynamicChanges then
        LogDebug("Dynamic traffic changes are disabled in the config.")
        return
    end

    local currentVehicleDensity = Config.Density.Default.VehicleDensity
    local currentParkedDensity = Config.Density.Default.ParkedDensity
    local currentPedDensity = Config.Density.Default.PedDensity
    local densityStep = 0.05 -- Step size for gradual adjustment

    while true do
        local ped = GetPlayerPed(-1)
        local playerCoords = GetEntityCoords(ped)
        local hour = GetClockHours()
        local weather = Config.UseWeatherUpdates and getCurrentWeather() or "Default"

        -- Adjust traffic speed and density
        local vehicleDensity, parkedDensity, pedDensity, speedZone =
            adjustTrafficSpeedAndDensity(playerCoords, hour, weather)

        -- Gradually adjust densities
        currentVehicleDensity = interpolateDensity(currentVehicleDensity, vehicleDensity, densityStep)
        currentParkedDensity = interpolateDensity(currentParkedDensity, parkedDensity, densityStep)
        currentPedDensity = interpolateDensity(currentPedDensity, pedDensity, densityStep)

        -- Apply densities
        SetParkedVehicleDensityMultiplierThisFrame(currentParkedDensity)
        SetVehicleDensityMultiplierThisFrame(currentVehicleDensity)
        SetRandomVehicleDensityMultiplierThisFrame(currentVehicleDensity)
        SetPedDensityMultiplierThisFrame(currentPedDensity)

        LogDebug(string.format(
            "Current Density: Vehicle %.2f | Parked %.2f | Pedestrian %.2f",
            currentVehicleDensity, currentParkedDensity, currentPedDensity
        ))

        Wait(1000) -- Update once per second
    end
end)

-- LEO/LIGHTS/SPEED/SLOW/STOP zones



CreateThread(function()
    while true do
        -- Stop the thread if manual override is active
        if manualOverride then
            Wait(1000) -- Wait longer since nothing will run
        else
            -- Handle emergency traffic control if command and sign modes are off
            if not commandMode and not signMode then
                HandleEmergencyTraffic()
            end

            -- Check for props if light mode is off
            if not lightMode then
                CheckForProps()
            end
        end

        Wait(500) -- Adjust delay as needed
    end
end)


--- BLIPS CHANGES
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

-- Debug message on resource start
AddEventHandler("onClientResourceStart", function(resourceName)
    if GetCurrentResourceName() == resourceName then
        print("^3[TRAFFIC CONTROL]^0 Client-side script loaded, developed by EddiesLife247 Scripts.")
    end
end)
CreateThread(function()
    LogDebug(
    "Traffic Control has been loaded, developed by EddiesLife247 Scripts. Support at: https://discord.eddieslife247.co.uk/")
    print(
    "^2[TRAFFIC CONTROL]^0 Client-side script loaded, developed by EddiesLife247 Scripts. Support at: https://discord.eddieslife247.co.uk/")
end)




