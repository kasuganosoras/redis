fx_version  'cerulean'
games       { 'gta5' }
author      'Akkariin'
description 'A Redis library for FiveM'
version     '1.0.0'
server_only 'yes'

server_scripts {
    'server/main.js',
    'lib/Redis.lua',
}

server_exports {
    'GetInstance',
}

provide 'redis'
provide 'fivem-redis'