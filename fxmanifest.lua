fx_version 'cerulean'
game 'gta5'
-- Resource Metadata
author 'EddiesLife247'
description 'Traffic Management | AI Vehicle Control | PD Blips'
version '1.0.0'
lua54 'yes' -- This ensures the asset is compatible with Lua 5.4



shared_script 'config.lua'

client_scripts {
    'client/commands.lua',
    'client/functions.lua',
    'client/leoblips.lua',
    'client/speeddensity.lua',
    'client/trafficlights.lua',
    'client/core.lua',
}

server_scripts {
    'server/server.lua'
}

dependency 'qb-core'
dependency 'ox_lib'