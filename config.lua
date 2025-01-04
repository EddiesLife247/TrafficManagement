Config = {}

-- Debugging
Config.Debug = false

-- Traffic Control Props
Config.UseRoadClosedProp = true -- Enable/disable traffic stop on road_closed prop
Config.UsePoliceSlowProp = true -- Enable/disable traffic slow on police_slow prop
Config.RoadClosedProp = `lgmods_policeroadclosed` -- Replace with actual road_closed prop model name
Config.PoliceSlowProp = `lgmods_policeslow` -- Replace with actual police_slow prop model name

-- Emergency Lights Traffic Control
Config.EnableStopOnLights = true -- Enable/disable stopping traffic when emergency lights are on
Config.StopOrSlow = "stop" -- Choose between "stop" or "slow" for emergency lights

-- Traffic Light Synchronization
Config.TurnTrafficLightsGreen = true -- Enable/disable turning traffic lights green for emergency vehicles

-- Jobs
Config.LEOJobs = { "police", "roadspolicing", "response", "cid", "firearms", "ambulance", "fire", "highways", "government" } -- these jobs can stop and slow traffic.
Config.MechanicJobs = { "mechanic", "towtruck", "repair" } -- These jobs can slow traffic, but can't stop it.

-- Commands
Config.Commands = {
    EnableSlowTraffic = true, -- Enable/disable the /slowtraffic command
    EnableStopTraffic = true, -- Enable/disable the /stoptraffic command
    EnableResumeTraffic = true, -- Enable/disable the /resumetraffic command
    SlowTraffic = "slowtraffic", -- Command to slow traffic (can be done via /slt)
    StopTraffic = "stoptraffic", -- Command to stop traffic (can be done via (/stt)
    ResumeTraffic = "resumetraffic", -- Command to resume traffic (can be done via (/rt)
    EnableForceTraffic = true,
    ForceNormalTraffic = "forcenormaltraffic"  -- Command to resume traffic (can be done via (/ftt)
}
