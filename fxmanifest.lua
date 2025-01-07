fx_version 'cerulean'
game 'gta5'
-- Resource Metadata
author 'EddiesLife247'
description 'Traffic Management | AI Vehicle Control | PD Blips'
version '2.0.0'
lua54 'yes' -- This ensures the asset is compatible with Lua 5.4



shared_script 'config.lua'

client_scripts {
    'client/commands.lua',
    'client/functions.lua',
    'client/leoblips.lua',
    'client/speeddensity.lua',
    'client/trafficlights.lua',
    'client/core.lua',
    'client/roadclosures.lua',
}

server_scripts {
    'server/server.lua',
    'server/roadclosures.lua',
}
escrow_ignore {
    'config.lua',              -- Ignoring the main configuration file
    'closedroads.lua'        -- JSON file for saved road closures
}

dependency 'qb-core'
dependency 'ox_lib'