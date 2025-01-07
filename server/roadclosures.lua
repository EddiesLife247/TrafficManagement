local roadClosures = {}

-- Load road closures from file on resource start
AddEventHandler("onResourceStart", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    local file = LoadResourceFile(GetCurrentResourceName(), "closedroads.json")
    if file then
        roadClosures = json.decode(file) or {}
        print("[Traffic Management] Loaded road closures.")
    else
        print("[Traffic Management] No saved road closures found.")
    end
end)




-- Save road closures to file on resource stop
function tableToString(tbl)
    local result = "{\n"
    for k, v in pairs(tbl) do
        result = result .. "  [" .. tostring(k) .. "] = " .. tostring(v) .. ",\n"
    end
    result = result .. "}"
    return result
end

-- Save road closures to file on resource stop
AddEventHandler("onResourceStop", function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    local fileContent = json.encode(roadClosures, { indent = true }) -- Convert table to JSON format

    -- Save the JSON data to a file
    SaveResourceFile(GetCurrentResourceName(), "closedroads.json", fileContent, -1)
    print("[Traffic Management] Saved road closures.")
end)


-- Save a road closure
RegisterNetEvent("traffic:saveRoadClosure", function(streetName, coords, radius)
    roadClosures[streetName] = { x = coords.x, y = coords.y, z = coords.z, radius = radius }
    TriggerClientEvent("traffic:loadRoadClosures", -1, roadClosures)
    print("[Traffic Management] Road closure saved: " .. streetName)
end)

-- Remove a road closure
RegisterNetEvent("traffic:removeRoadClosure", function(streetName)
    if not roadClosures[streetName] then
        print("[Traffic Management] Attempt to remove non-existent road closure: " .. streetName)
        return
    end

    roadClosures[streetName] = nil
    TriggerClientEvent("traffic:loadRoadClosures", -1, roadClosures)
    print("[Traffic Management] Road closure removed: " .. streetName)
end)

