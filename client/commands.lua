-- Commands for traffic control --
if Config.Commands.EnableSlowTraffic then
    RegisterCommand(Config.Commands.SlowTraffic, function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            if commandMode == true then
                commandMode = false
            else
                commandMode = true
            end
            slowTraffic()
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    RegisterCommand("slt", function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            if commandMode == true then
                commandMode = false
            else
                commandMode = true
            end
            slowTraffic()
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
end

if Config.Commands.EnableStopTraffic then
    RegisterCommand(Config.Commands.StopTraffic, function()
        if PlayerHasLEOJob() then
            if commandMode == true then
                commandMode = false
            else
                commandMode = true
            end
            stopTraffic()
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    RegisterCommand("stt", function()
        if PlayerHasLEOJob() then
            if commandMode == true then
                commandMode = false
            else
                commandMode = true
            end
            stopTraffic()
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
end

if Config.Commands.EnableResumeTraffic then
    RegisterCommand(Config.Commands.ResumeTraffic, function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            if commandMode == true then
                commandMode = false
            else
                commandMode = true
            end
            ResetTraffic()
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
    RegisterCommand("rtt", function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            if commandMode == true then
                commandMode = false
            else
                commandMode = true
            end
            ResetTraffic()
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
end
function RemoveOfficerBlip(serverId)
    if officerBlips[serverId] then
        RemoveBlip(officerBlips[serverId])
        officerBlips[serverId] = nil
    end
end
if Config.Commands.EnableForceTraffic then
    RegisterCommand(Config.Commands.ForceNormalTraffic, function()
        if PlayerHasLEOJob() or PlayerHasMechanicJob() then
            manualOverride = not manualOverride
            if manualOverride then
                ResetTraffic()
                LogDebug("Forced normal traffic mode enabled.")
                SendNotification("success", "Forced normal traffic mode enabled. Traffic controls disabled.")
            else
                LogDebug("Forced normal traffic mode disabled.")
                SendNotification("info", "Forced normal traffic mode disabled. Traffic controls enabled.")
            end
        else
            SendNotification("error", "You are not authorized to use this command.")
        end
    end, false)
end

