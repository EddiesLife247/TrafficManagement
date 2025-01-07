Config = {}

-- Debugging
Config.Debug = true -- Enable or disable debug messages for troubleshooting.
Config.DebugLevel = 1 -- set debug level

-- Traffic Control Props
Config.UseRoadClosedProp = true -- Allow the use of a "road closed" prop to stop traffic.
Config.UsePoliceSlowProp = true -- Allow the use of a "police slow" prop to slow traffic.
Config.RoadClosedProp = `lgmods_policeroadclosed` -- Model name for the "road closed" prop.
Config.PoliceSlowProp = `lgmods_policeslow` -- Model name for the "police slow" prop.

-- Emergency Lights Traffic Control
Config.EnableStopOnLights = true -- Stop traffic when emergency lights are activated.
Config.StopOrSlow = "stop" -- Choose "stop" to halt traffic or "slow" to reduce speed when lights are active.
Config.EnableRollingRoadBlock = true -- Enable rolling roadblocks to reduce traffic speed.
Config.RollingRoadBlockSpeed = 30 -- Speed limit (in MPH) during a rolling roadblock.
Config.LightStopSpeed = 5 -- Speed (in MPH) at which traffic stops when emergency lights are active.
Config.MaxStopSlowTime = 5 -- Time in Minutes
Config.MaxStopSlowTimeOutOfCar = 5 -- Time in minutes when the player is out of the car
Config.MaxTrafficRadius = 200.0 -- Maximum radius in meters
Config.MinTrafficRadius = 20.0 -- Minimum radius in meters
Config.RadiusStep = 10.0       -- Step size for increasing/decreasing radius
Config.DefaultRadius = 30.0

-- Traffic Light Configuration
Config.LGModTrafficLights = true -- Enable or disable LG Mods British traffic lights detection
Config.TrafficLightModels = {
    2063962179, -- Example LG traffic light models
    600967813,
    200846641,
    -1986480816,
    666561306
}
Config.TrafficLightChangeDelay = 500 -- Delay in milliseconds
Config.TrafficLightRadius = 50.0 -- Radius to detect traffic lights
Config.TurnTrafficLightsGreen = true -- Enable or disable traffic light changes



-- Law Enforcement and Emergency Services Blips
Config.LeoBlips = true -- Enable blips for law enforcement and emergency vehicles.
Config.ShowLeoBlipsToAll = false -- Restrict blip visibility to specific players.

-- Job Roles
Config.LEOJobs = { "police", "roadspolicing", "response", "cid", "firearms", "ambulance", "fire", "highways", "staff" } -- Jobs that can stop and slow traffic.
Config.MechanicJobs = { "mechanic", "towtruck", "repair" } -- Jobs that can slow but not stop traffic.

-- Commands
Config.Commands = {
    EnableSlowTraffic = true, -- Enable or disable the /slowtraffic command.
    EnableStopTraffic = true, -- Enable or disable the /stoptraffic command.
    EnableResumeTraffic = true, -- Enable or disable the /resumetraffic command.
    SlowTraffic = "slowtraffic", -- Command to slow traffic.
    StopTraffic = "stoptraffic", -- Command to stop traffic.
    ResumeTraffic = "resumetraffic", -- Command to resume traffic flow.
    EnableForceTraffic = true, -- Enable or disable forced traffic normalization.
    ForceNormalTraffic = "forcenormaltraffic" -- Command to reset traffic to normal.
}

-- Dynamic Traffic Adjustments
Config.TrafficDynamicChanges = true -- Enable or disable dynamic traffic adjustments.
Config.UseWeatherUpdates = true -- Adjust traffic based on weather conditions.
Config.DensityChangeMins = 3 -- Time interval (in minutes) to adjust density levels dynamically.

-- Traffic Density Settings
Config.Density = {
    Morning = {
        Start = 6, -- Start of morning rush hour.
        End = 9, -- End of morning rush hour.
        VehicleDensity = 5.0, -- Vehicle density during morning hours.
        ParkedDensity = 0.2 -- Parked vehicle density in the morning.
    },
    Evening = {
        Start = 16, -- Start of evening rush hour.
        End = 19, -- End of evening rush hour.
        VehicleDensity = 5.0, -- Vehicle density during evening hours.
        ParkedDensity = 0.3 -- Parked vehicle density in the evening.
    },
    Night = {
        Start = 22, -- Start of nighttime traffic settings.
        End = 4, -- End of nighttime traffic settings.
        VehicleDensity = 0.1, -- Low vehicle density at night.
        ParkedDensity = 1.8, -- Higher parked vehicle density at night.
        PedDensity = 0.1 -- Reduced pedestrian density at night.
    },
    Default = {
        VehicleDensity = 0.5, -- Default vehicle density.
        ParkedDensity = 0.5, -- Default parked vehicle density.
        PedDensity = 0.5 -- Default pedestrian density.
    }
}

-- Weather-Based Adjustments
Config.WeatherTypes = {
    [GetHashKey("RAIN")] = "Rainy",
    [GetHashKey("THUNDER")] = "Rainy",
    [GetHashKey("EXTRASUNNY")] = "Sunny",
    [GetHashKey("CLEAR")] = "Sunny",
    [GetHashKey("FOGGY")] = "Foggy",
    [GetHashKey("OVERCAST")] = "Overcast",
    [GetHashKey("CLOUDS")] = "Cloudy",
    [GetHashKey("SNOW")] = "Snowy",
    [GetHashKey("BLIZZARD")] = "Snowy",
    [GetHashKey("SNOWLIGHT")] = "Snowy",
    [GetHashKey("XMAS")] = "Snowy"
}

Config.WeatherAdjustments = {
    Rainy = {
        VehicleDensity = 0.7, -- Increased vehicle density during rain.
        PedDensity = 0.3 -- Reduced pedestrian density during rain.
    },
    Sunny = {
        VehicleDensity = 0.3, -- Reduced vehicle density during sunny weather.
        PedDensity = 1.0 -- Increased pedestrian density during sunny weather.
    }
}

-- City Speed Limits
Config.TrafficSpeedZones = {
    City = {
        Center = vector3(200.0, -900.0, 30.0), -- Coordinates for the city center.
        Radius = 2500.0, -- Radius defining the city area.
        Speed = 60.0 -- Speed limit (in MPH) within the city.
    },
    Paleto = {
        Center = vector3(-400.0, 6000.0, 30.0), -- Coordinates for Paleto Bay center.
        Radius = 1000.0, -- Radius defining Paleto Bay.
        Speed = 60.0 -- Speed limit (in MPH) within Paleto Bay.
    },
    Sandy = {
        Center = vector3(1700.0, 3600.0, 30.0), -- Coordinates for Sandy Shores center.
        Radius = 1000.0, -- Radius defining Sandy Shores.
        Speed = 60.0 -- Speed limit (in MPH) within Sandy Shores.
    },
    OutOfTown = {
        Speed = 90.0 -- Speed limit (in MPH) outside defined zones.
    }
}
Config.UseTrafficSpeedAdjustment = true -- Enable or disable traffic speed adjustments.

-- Additional Configurations
Config.TrafficControlTimeout = 10 * 60 * 1000 -- Time (in ms) before traffic controls reset automatically.
Config.TrafficLightDuration = 5000 -- Duration (in ms) for controlled traffic lights.
Config.NotificationDuration = 5000 -- Duration (in ms) for in-game notifications.


--- CONFIG FOR ROAD CLOSURES

Config.RoadClosures = {
    Enabled = true,                     -- Enable or disable road closures feature
    CloseRoadEnabled = true,            -- Allow closing roads
    CloseRoadCommand = "closeroad",     -- Command to close a road
    OpenRoadEnabled = true,             -- Allow opening roads
    OpenRoadCommand = "openroad",       -- Command to open a road
    DespawnClosedRoads = true,          -- Despawn traffic on closed roads
    RoadDespawnRadius = 50.0,           -- Radius for despawning vehicles around a closed road
    SaveRoadClosures = true,            -- Enable saving road closures to JSON
    RoadClosureFile = "closed_roads.json", -- File to save road closures
    ExcludePlayerVehicles = true,       -- Exclude player vehicles when despawning traffic
    BlipSettings = {                    -- Blip configuration for closed roads
        Sprite = 285,                   -- Blip sprite
        Color = 1,                      -- Blip color
        Alpha = 255,                    -- Blip transparency
        ShortRange = true               -- Short-range visibility
    }
}

-- MODEL FEATURE DOES NOT WORK WITH THIS VERSION

Config.DefaultBarrier = {
    model = "prop_barrier_work01a",  -- Default model for barriers
    position = vector3(0.0, 0.0, 0.0),  -- Default position, this will be overwritten later
    heading = 0.0,  -- Default heading (rotation)
}

-- Specific barriers for roads
Config.JunctionBarriers = {
    ["road_name_1"] = {
        {
            model = "prop_barrier_work01a",
            position = vector3(100.0, 200.0, 30.0),
            heading = 90.0,
        },
    },
    -- Other roads can be added here...
}