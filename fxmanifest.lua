-- Resource Metadata
fx_version 'cerulean'
games { 'gta5' }

author 'ItsANoBrainer'
description 'Standalone lapraces for QB-Core'
version '1.0.1'

ui_page 'html/index.html'
shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
}
client_script 'client/main.lua'
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}
files {
    'html/*.html',
    'html/*.css',
    'html/*.js',
    'html/fonts/*.otf',
    'html/img/*'
}
lua54 'yes'
