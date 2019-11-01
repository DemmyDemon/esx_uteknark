local ESX = nil
local ESXTries = 60
local oneSyncEnabled = GetConvar('onesync_enabled', false)
local octree = pOctree(vector3(0,1500,0),vector3(12000,12000,2000)) -- Covers the whole damn map!

function log (...)
    local numElements = select('#',...)
    local elements = {...}
    local line = ''
    local prefix = '['..os.date("%H:%M:%S")..'] '
    suffix = '\n'
    local resourceName = '<'..GetCurrentResourceName()..'>'

    for i=1,numElements do
        local entry = elements[i]
        line = line..' '..tostring(entry)
    end
    Citizen.Trace(prefix..resourceName..line..suffix)
end

if not oneSyncEnabled then
    log('OneSync not available: Will have to trust client for locations!')
end

function HasItem(who, what, count)
    count = count or 1
    if ESX == nil then
        log("HasItem: No ESX Object!")
        return false
    end
    local xPlayer = ESX.GetPlayerFromId(who)
    if xPlayer == nil then
        log("HasItem: Failed to resolve xPlayer from", who)
        return false
    end
    local itemspec =  xPlayer.getInventoryItem(what)
    if itemspec then
        if itemspec.count >= count then
            return true
        else
            return false
        end
    else
        log("HasItem: Failed to get item data for item", what)
        return false
    end
end

function TakeItem(who, what, count)
    count = count or 1
    if ESX == nil then
        log("TakeItem: No ESX Object!")
        return false
    end
    local xPlayer = ESX.GetPlayerFromId(who)
    if xPlayer == nil then
        log("TakeItem: Failed to resolve xPlayer from", who)
        return false
    end
    local itemspec =  xPlayer.getInventoryItem(what)
    if itemspec then
        if itemspec.count >= count then
            xPlayer.removeInventoryItem(what, count)
            return true
        else
            return false
        end
    else
        log("TakeItem: Failed to get item data for item", what)
        return false
    end
end

function GiveItem(who, what, count)
    count = count or 1
    if ESX == nil then
        log("GiveItem: No ESX Object!")
        return false
    end
    local xPlayer = ESX.GetPlayerFromId(who)
    if xPlayer == nil then
        log("GiveItem: Failed to resolve xPlayer from", who)
        return false
    end
    local itemspec =  xPlayer.getInventoryItem(what)
    if itemspec then
        if itemspec.limit == -1 or itemspec.count + count <= itemspec.limit then
            xPlayer.addInventoryItem(what, count)
            return true
        else
            return false
        end
    else
        log("GiveItem: Failed to get item data for item", what)
        return false
    end
end

function makeToast(target, subject, message)
    TriggerClientEvent('esx_uteknark:make_toast', target, subject, message)
end
function inChat(target, message)
    TriggerClientEvent('chat:addMessage',target,{args={'Uteknark', message}})
end

function plantSeed(location, soil)
    log('plantSeed called -- NOT IMPLEMENTED')
    return false
end

RegisterNetEvent('esx_uteknark:success_plant')
AddEventHandler ('esx_uteknark:success_plant', function(location, soil)
    local src = source
    if oneSyncEnabled then
        local ped = GetPlayerPed(src)
        --log('ped:',ped)
        local pedLocation = GetEntityCoords(ped)
        --log('pedLocation:',pedLocation)
        --log('location:', location)
        local distance = #(pedLocation - location)
        if distance > Config.Distance.Interact then
            if distance > 10 then
                log(GetPlayerName(src),'attempted planting at',distance..'m - Cheating?')
            end
            makeToast(src, _U('planting_text'), _U('planting_too_far'))
            return
        end
    end
    if soil and Config.Soil[soil] then
        local hits = octree:searchSphere(location, Config.Distance.Space)
        if #hits == 0 then
            if TakeItem(src, Config.Items.Seed) then
                if plantSeed(location, soil) then
                    makeToast(src, _U('planting_text'), _U('planting_ok'))
                else
                    GiveItem(src, Config.Items.Seed)
                    makeToast(src, _U('planting_text'), _U('planting_failed'))
                end
            else
                makeToast(src, _U('planting_text'), _U('planting_no_seed'))
            end
        else
            makeToast(src, _U('planting_text'), _U('planting_too_close'))
        end
    else
        makeToast(src, _U('planting_text'), _U('planting_not_suitable_soil'))
    end
end)

RegisterNetEvent('esx_uteknark:log')
AddEventHandler ('esx_uteknark:log',function(...)
    local src = source
    log(src,GetPlayerName(src),...)
end)

Citizen.CreateThread(function()
	while ESX == nil and ESXTries > 0 do
        TriggerEvent('esx:getSharedObject', function(obj)
            ESX = obj
            ESX.RegisterUsableItem(Config.Items.Seed, function(source)
                if HasItem(source, Config.Items.Seed) then
                    TriggerClientEvent('esx_uteknark:attempt_plant', source)
                else
                    makeToast(source, _U('planting_text'), _U('planting_no_seed'))
                end
            end)
        end)
        Citizen.Wait(1000)
        ESXTries = ESXTries - 1
    end
    if not ESX then
        Citizen.Trace("esx_uteknark could not obtain ESX object!\n")
    end
end)

local commands = {
    debug = function(source, args)
        if source == 0 then
            log('Client debugging on the console? Nope.')
        else
            TriggerClientEvent('esx_uteknark:toggle_debug', source)
        end
    end,
}

RegisterCommand('uteknark', function(source, args, raw)
    if #args > 0 then
        local directive = string.lower(args[1])
        if commands[directive] then
            if #args > 1 then
                local newArgs = {}
                for i,entry in ipairs(args) do
                    if i > 1 then
                        table.insert(newArgs, entry)
                    end
                end
                args = newArgs
            else
                args = {}
            end
            commands[directive](source,args)
        elseif source == 0 then
            log('Invalid directive: ' .. directive)
        else
            inChat(source,_U('command_invalid', directive))
        end
    else
        if source == 0 then
            log('Uteknark at your service!')
        else
            inChat(source, _U('command_empty'))
        end
    end
end,true)