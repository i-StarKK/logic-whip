fx_version 'cerulean'
game 'gta5'

name 'logic-whip'
author 'StarK (Moayed) - logic'
description 'A realistic braided bullwhip with physical lash, finger grip, hand switching, synced cracks, hits and sound'
version '1.0.1'
repository 'https://github.com/i-StarKK/logic-whip'

lua54 'yes'

shared_script 'shared/config.lua'
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/audio.js',
    'html/sounds/*.ogg',
}

data_file 'DLC_ITYP_REQUEST' 'stream/logic_whip.ytyp'
