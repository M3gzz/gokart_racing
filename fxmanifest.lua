fx_version 'cerulean'
game 'gta5'

author 'Antigravity'
description 'Multiplayer Gokart Racing System for QBCore / Qbox'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/framework.lua'
}

client_scripts {
    'client/main.lua'
}

server_scripts {
    'server/main.lua'
}

ui_page 'nui/index.html'

files {
    'nui/index.html',
    'nui/style.css',
    'nui/script.js'
}
