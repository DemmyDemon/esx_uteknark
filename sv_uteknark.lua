local ESX = nil
local ESXTries = 60
local oneSyncEnabled = GetConvar('onesync_enabled', false)
local octree = pOctree(vector3(0,1500,0),vector3(12000,12000,2000)) -- Covers the whole damn map!
local VERBOSE = true
local lastPlant = {}

AddEventHandler('playerDropped',function(why)
    lastPlant[source] = nil
end)

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

function verbose(...)
    if VERBOSE then
        log(...)
    end
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
    TriggerClientEvent('chat:addMessage',target,{args={'UteKnark', message}})
end

function plantSeed(location, soil)
    
    local hits = cropstate.octree:searchSphere(location, Config.Distance.Space)
    if #hits > 0 then
        return false
    end

    verbose('Planting at',location,'in soil', soil)
    cropstate:plant(location, soil)
    return true
end

function abortAction(who)
    TriggerClientEvent('esx_uteknark:abort', who)
end

RegisterNetEvent('esx_uteknark:success_plant')
AddEventHandler ('esx_uteknark:success_plant', function(location, soil)
    local src = source
    if oneSyncEnabled and false then -- "and false" because something is weird in my OneSync stuff
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
                    abortAction(src)
                end
            else
                makeToast(src, _U('planting_text'), _U('planting_no_seed'))
                abortAction(src)
            end
        else
            makeToast(src, _U('planting_text'), _U('planting_too_close'))
            abortAction(src)
        end
    else
        makeToast(src, _U('planting_text'), _U('planting_not_suitable_soil'))
        abortAction(src)
    end
end)

RegisterNetEvent('esx_uteknark:log')
AddEventHandler ('esx_uteknark:log',function(...)
    local src = source
    log(src,GetPlayerName(src),...)
end)

RegisterNetEvent('esx_uteknark:test_forest')
AddEventHandler ('esx_uteknark:test_forest',function(forest)
    local src = source


    if IsPlayerAceAllowed(src, 'command.uteknark') then

        local soil
        for candidate, quality in pairs(Config.Soil) do
            soil = candidate
            if quality >= 1.0 then
                break
            end
        end

        log(GetPlayerName(src),'('..src..') is magically planting a forest of',#forest,'plants')
        for i, tree in ipairs(forest) do
            cropstate:plant(tree.location, soil, tree.stage)
            if i % 25 == 0 then
                Citizen.Wait(0)
            end
        end
    else
        log('OY!', GetPlayerName(src),'with ID',src,'tried to spawn a test forest, BUT IS NOT ALLOWED!')
    end
end)

Citizen.CreateThread(function()
	while ESX == nil and ESXTries > 0 do
        TriggerEvent('esx:getSharedObject', function(obj)
            ESX = obj
            ESX.RegisterUsableItem(Config.Items.Seed, function(source)
                local now = os.time()
                local last = lastPlant[source] or 0
                if now > last + (Config.ActionTime/1000) then
                    if HasItem(source, Config.Items.Seed) then
                        TriggerClientEvent('esx_uteknark:attempt_plant', source)
                        lastPlant[source] = now
                    else
                        makeToast(source, _U('planting_text'), _U('planting_no_seed'))
                        abortAction(source)
                    end
                else
                    makeToast(source, _U('planting_text'), _U('planting_too_fast'))
                    abortAction(source)
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

Citizen.CreateThread(function()
    local databaseReady = false
    while not databaseReady do
        Citizen.Wait(500)
        local state = GetResourceState('mysql-async')
        if state == "started" then
            Citizen.Wait(500)
            cropstate:load(function(plantCount)
                if plantCount == 1 then
                    log('Uteknark loaded a single plant!')
                else
                    log('Uteknark loaded',plantCount,'plants')
                end
            end)
            databaseReady = true
        end
    end

    while true do
        Citizen.Wait(0)
        local now = os.time()
        local plantsHandled = 0
        for id, plant in pairs(cropstate.index) do
            if type(id) == 'number' then -- Because of the whole "hashtable = true" thing
                local stageData = Growth[plant.data.stage]
                local growthTime = (stageData.time * 60 * Config.TimeMultiplier)
                local soilQuality = Config.Soil[plant.data.soil] or 1.0

                if stageData.interact then
                    local relevantTime = plant.data.time + ((growthTime / soilQuality) * Config.TimeMultiplier)
                    if now >= relevantTime then
                        verbose('Plant',id,'has died: No interaction in time')
                        cropstate:remove(id)
                    end
                else
                    local relevantTime = plant.data.time + ((growthTime * soilQuality) * Config.TimeMultiplier)
                    if now >= relevantTime then
                        if plant.data.stage < #Growth then
                            verbose('Plant',id,'has grown to stage',plant.data.stage + 1)
                            cropstate:update(id, plant.data.stage + 1)
                        else
                            verbose('Plant',id,'has died: Ran out of stages')
                            cropstate:remove(id)
                        end
                    end
                end

                plantsHandled = plantsHandled + 1
                if plantsHandled % 10 == 0 then
                    Citizen.Wait(0)
                end
            end
        end
        -- verbose('Uteknark growth tick took',os.time() - now,'seconds for',plantsHandled,'plants')
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
    stage = function(source, args)
        if args[1] and string.match(args[1], "^%d+$") then
            local plant = tonumber(args[1])
            if args[2] and string.match(args[2], "^%d+$") then
                local stage = tonumber(args[2])
                if (stage <= #Growth) then
                    cropstate:update(plant, stage)
                end
            end
        end
    end,
    forest = function(source, args)
        if source == 0 then
            log('Forests can\'t grow in a console, buddy!')
        else

            local count = #Growth * #Growth
            if args[1] and string.match(args[1], "%d+$") then
                count = tonumber(args[1])
            end

            local randomStage = false
            if args[2] then randomStage = true end

            TriggerClientEvent('esx_uteknark:test_forest', source, count, randomStage)

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