-- TRAFFIC LIGHT CHANGES
CreateThread(function()
    while true do
        Wait(Config.TrafficLightChangeDelay)

        if Config.TurnTrafficLightsGreen then
            local playerPed = PlayerPedId()
            local vehicle = GetVehiclePedIsIn(playerPed, false)

            if vehicle ~= 0 and IsVehicleSirenOn(vehicle) then
                local playerCoords = GetEntityCoords(playerPed)
                LogDebug("Emergency lights on, checking traffic lights...") -- Debugging
                ChangeTrafficLightsToGreen(playerCoords, Config.TrafficLightRadius)
            end
        end
    end
end)

-- Function to apply the traffic light state locally
function ApplyTrafficLightState(trafficLight, state)
    if not DoesEntityExist(trafficLight) then
        print("Traffic light entity does not exist!")
        return
    end

    if state == 0 then
        LogDebug("Setting traffic light to GREEN locally for entity:", trafficLight)
        SetEntityTrafficlightOverride(trafficLight, 0) -- Green
    elseif state == 1 then
        LogDebug("Setting traffic light to YELLOW locally for entity:", trafficLight)
        SetEntityTrafficlightOverride(trafficLight, 1) -- Yellow
    elseif state == 2 then
        LogDebug("Setting traffic light to RED locally for entity:", trafficLight)
        SetEntityTrafficlightOverride(trafficLight, 2) -- Red
    else
        print("Invalid state provided:", state)
    end
end

-- Function to change traffic lights to green within a specified radius
function ChangeTrafficLightsToGreen(coords, radius)
    local objects = GetGamePool("CObject")

    for _, object in ipairs(objects) do
        if IsLGTrafficLight(object) and #(GetEntityCoords(object) - coords) <= radius then
            ApplyTrafficLightState(object, 0) -- Set to green (0)
        end
    end
end

-- Function to identify LG British traffic light objects
function IsLGTrafficLight(object)
    local model = GetEntityModel(object)
    LogDebug("Detected object model:", model) -- Debugging

    for _, lightModel in ipairs(Config.TrafficLightModels) do
        if model == lightModel then
            LogDebug("Traffic light identified:", model)
            return true
        end
    end

    return false
end