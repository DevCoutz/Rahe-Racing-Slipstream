--[[ FX Information ]]--
fx_version 'cerulean'
lua54 'yes'
game 'gta5'

--[[ Resource Information ]]--
name 'rahe-slipstream'
author 'Custom Integration'
description 'Slipstream/Drafting system integrated with rahe-racing. Only active during races.'
version '1.0.0'

--[[ Dependencies ]]--
dependencies {
    'rahe-racing',
}

--[[ Scripts ]]--
shared_scripts {
    'config.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    'server.lua',
}
