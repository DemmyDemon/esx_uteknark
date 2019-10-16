resource_manifest_version '44febabe-d386-4d18-afbe-5e627f4af937'
description 'ESX UteKnark by DemmyDemon and Breze'

dependencies {'es_extended','mysql-async'}

shared_scripts {
    'config.lua',
    'octree.lua',
    'locales\*.lua',
}
client_scripts {
    'cl_uteknark.lua',
}
server_scripts {
    'sv_uteknark.lua',
}
