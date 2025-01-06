-- Function to get the current weather condition
function getCurrentWeather()
    local prevWeatherHash = GetPrevWeatherTypeHashName()
    local nextWeatherHash = GetNextWeatherTypeHashName()
    local weather = "Default"

    -- Use Config.WeatherTypes to determine the current weather
    if Config.WeatherTypes[prevWeatherHash] then
        weather = Config.WeatherTypes[prevWeatherHash]
        LogDebug("Current weather determined from previous: " .. weather, 3)
    elseif Config.WeatherTypes[nextWeatherHash] then
        weather = Config.WeatherTypes[nextWeatherHash]
        LogDebug("Current weather determined from next: " .. weather, 3)
    else
        LogDebug("Current weather is Default (no match found)", 1)
    end

    return weather
end


-- Gradual density adjustment function
function interpolateDensity(current, target, step)
    if math.abs(current - target) < step then
        return target
    elseif current < target then
        return current + step
    else
        return current - step
    end
end

-- Determine which traffic zone the player is in
function getTrafficZone(coords)
    for zoneName, zoneData in pairs(Config.TrafficSpeedZones) do
        if zoneData.Center then
            local distance = #(coords - zoneData.Center)
            if distance <= zoneData.Radius then
                return zoneName, zoneData
            end
        end
    end
    return "OutOfTown", Config.TrafficSpeedZones.OutOfTown
end

-- Adjust traffic speed and density based on the player's location and weather
function adjustTrafficSpeedAndDensity(playerCoords, hour, weather)
    local zoneName, zoneData = getTrafficZone(playerCoords)

    -- Adjust speed
    local speedLimit = zoneData.Speed or Config.TrafficSpeedZones.OutOfTown.Speed
    local speedInMPS = speedLimit * 0.44704 -- Convert MPH to meters per second

    -- Ensure speed zone is removed before setting a new one
    if activeSpeedZone then
        RemoveSpeedZone(activeSpeedZone)
    end
    activeSpeedZone = AddSpeedZoneForCoord(playerCoords.x, playerCoords.y, playerCoords.z, 500.0, speedInMPS, false)

    -- Adjust densities
    local vehicleDensity = Config.Density.Default.VehicleDensity
    local parkedDensity = Config.Density.Default.ParkedDensity
    local pedDensity = Config.Density.Default.PedDensity

    -- Time-based density adjustments
    if hour >= Config.Density.Morning.Start and hour <= Config.Density.Morning.End then
        vehicleDensity = Config.Density.Morning.VehicleDensity
        parkedDensity = Config.Density.Morning.ParkedDensity
    elseif hour >= Config.Density.Evening.Start and hour <= Config.Density.Evening.End then
        vehicleDensity = Config.Density.Evening.VehicleDensity
        parkedDensity = Config.Density.Evening.ParkedDensity
    elseif hour >= Config.Density.Night.Start or hour <= Config.Density.Night.End then
        vehicleDensity = Config.Density.Night.VehicleDensity
        parkedDensity = Config.Density.Night.ParkedDensity
        pedDensity = Config.Density.Night.PedDensity
    end

    -- Apply weather adjustments
    if Config.WeatherAdjustments[weather] then
        vehicleDensity = vehicleDensity * (Config.WeatherAdjustments[weather].VehicleDensity or 1.0)
        pedDensity = pedDensity * (Config.WeatherAdjustments[weather].PedDensity or 1.0)
    end

    LogDebug(string.format(
        "Zone: %s | Speed Limit: %.2f MPH | Vehicle Density: %.2f | Parked Density: %.2f | Pedestrian Density: %.2f",
        zoneName, speedLimit, vehicleDensity, parkedDensity, pedDensity), 3)

    return vehicleDensity, parkedDensity, pedDensity, activeSpeedZone
end