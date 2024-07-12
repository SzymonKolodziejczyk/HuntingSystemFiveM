fx_version 'cerulean'
game 'gta5'

name 'Hunting Mission'
author 'MaxBurnHeart'
version '1.0.0'
description 'Hunting Mission'

server_scripts {
    '@mysql-async/lib/MySQL.lua',
    'server/server.lua'
}

client_scripts {
    'client/client.lua'
}

shared_scripts {
    'config.lua'
}